#!/usr/bin/env python3
"""Simulate MAG-style incompleteness from a complete genome.

Cuts every replicon into fixed-size windows (pseudo-contigs), then for each
retention level keeps a random subset of windows (fixed seed). All levels are
windowed the same way, so retention is the only variable between them.

Also reads the RefSeq GFF and reports, per level, whether each nif/nod/fix
gene is fully retained, partially retained (fragmented), or lost.
"""

import argparse
import json
import random
import re
from pathlib import Path

WINDOW = 50_000
LEVELS = [1.0, 0.9, 0.7, 0.5]
SEED = 42
GENE_RE = re.compile(r"gene=((?:nif|nod|fix)\w*)", re.IGNORECASE)


def read_fasta(path):
    seqs, name, chunks = {}, None, []
    with open(path) as fh:
        for line in fh:
            if line.startswith(">"):
                if name:
                    seqs[name] = "".join(chunks)
                name, chunks = line[1:].split()[0], []
            else:
                chunks.append(line.strip())
    if name:
        seqs[name] = "".join(chunks)
    return seqs


def windows_of(seqs):
    wins = []
    for rep, seq in seqs.items():
        for start in range(0, len(seq), WINDOW):
            wins.append((rep, start, min(start + WINDOW, len(seq))))
    return wins


def sym_genes(gff_path):
    genes = []
    with open(gff_path) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            f = line.split("\t")
            if len(f) > 8 and f[2] == "gene":
                m = GENE_RE.search(f[8])
                if m:
                    genes.append((m.group(1), f[0], int(f[3]), int(f[4])))
    return genes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fasta", required=True)
    ap.add_argument("--gff", required=True)
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()

    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)
    seqs = read_fasta(args.fasta)
    wins = windows_of(seqs)
    genes = sym_genes(args.gff)
    rng = random.Random(SEED)
    order = list(range(len(wins)))
    rng.shuffle(order)

    manifest, gene_rows = {}, []
    for level in LEVELS:
        keep = set(order[: round(len(wins) * level)])
        tag = f"frag{int(level * 100)}"
        kept_bp = 0
        with open(out / f"stm815_{tag}.fna", "w") as fh:
            for i, (rep, s, e) in enumerate(wins):
                if i in keep:
                    fh.write(f">{rep}_{s}_{e}\n")
                    for j in range(s, e, 80):
                        fh.write(seqs[rep][j : min(j + 80, e)] + "\n")
                    kept_bp += e - s
        manifest[tag] = {"windows_total": len(wins), "windows_kept": len(keep),
                         "bp_kept": kept_bp}
        for gname, rep, gs, ge in genes:
            overlapping = [i for i, (r, s, e) in enumerate(wins)
                           if r == rep and s < ge and e > gs - 1]
            retained = [i for i in overlapping if i in keep]
            status = ("present" if len(retained) == len(overlapping)
                      else "fragmented" if retained else "lost")
            gene_rows.append((tag, gname, rep, status))

    with open(out / "manifest.json", "w") as fh:
        json.dump(manifest, fh, indent=2)
    with open(out / "gene_status.tsv", "w") as fh:
        fh.write("level\tgene\treplicon\tstatus\n")
        for row in gene_rows:
            fh.write("\t".join(row) + "\n")

    for tag, m in manifest.items():
        lost = sum(1 for r in gene_rows if r[0] == tag and r[3] == "lost")
        frag = sum(1 for r in gene_rows if r[0] == tag and r[3] == "fragmented")
        print(f"{tag}: {m['windows_kept']}/{m['windows_total']} windows, "
              f"{m['bp_kept']:,} bp | sym genes lost={lost} fragmented={frag} "
              f"of {len(genes)}")


if __name__ == "__main__":
    main()
