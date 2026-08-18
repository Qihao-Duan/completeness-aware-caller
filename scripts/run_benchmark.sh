#!/usr/bin/env bash
# Reproduce the STM815 degradation benchmark end to end.
#
#   run_benchmark.sh [WORKDIR]
#
# Downloads three public genomes, degrades the truth genome to four retention
# levels, runs BUSCO and FastANI on every level, then runs the caller. Needs
# BUSCO and fastANI on PATH (the `benchmark` image target provides both).
set -euo pipefail

WORK="${1:-/data}"
LINEAGE="${BUSCO_LINEAGE:-bacteria_odb12}"
CPU="${BUSCO_CPU:-4}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$WORK"
cd "$WORK"

say() { printf '\n=== %s ===\n' "$1"; }

# ------------------------------------------------------------------ 1. data
if [ ! -d "$WORK/genomes/stm815" ]; then
  say "Fetching genomes from NCBI"
  bash "$HERE/download_genomes.sh" "$WORK/genomes"
else
  say "Genomes already present, skipping download"
fi

STM_FNA=$(find "$WORK/genomes/stm815" -name "*.fna" | head -1)
STM_GFF=$(find "$WORK/genomes/stm815_gff" -name "*.gff" | head -1)
LB400=$(find "$WORK/genomes/lb400" -name "*.fna" | head -1)
J2315=$(find "$WORK/genomes/j2315" -name "*.fna" | head -1)

for f in "$STM_FNA" "$STM_GFF" "$LB400" "$J2315"; do
  [ -n "$f" ] && [ -s "$f" ] || { echo "missing input: $f" >&2; exit 1; }
done

# -------------------------------------------------------------- 2. degrade
say "Degrading STM815 to 100/90/70/50% retention (seed 42)"
python3 "$HERE/degrade_genome.py" \
  --fasta "$STM_FNA" --gff "$STM_GFF" --outdir "$WORK/degraded"

# ----------------------------------------------------------------- 3. BUSCO
say "Running BUSCO $LINEAGE on each level"
mkdir -p "$WORK/busco"
for lvl in 100 90 70 50; do
  out="$WORK/busco/frag${lvl}"
  if [ -f "$out/short_summary.txt" ]; then
    echo "frag${lvl}: cached, skipping"
    continue
  fi
  mkdir -p "$out"
  busco -i "$WORK/degraded/stm815_frag${lvl}.fna" \
        -m genome -l "$LINEAGE" -c "$CPU" \
        --out_path "$out" --out busco_run -f \
        ${BUSCO_DOWNLOAD_PATH:+--download_path "$BUSCO_DOWNLOAD_PATH"}
  # BUSCO 6 names this file two different ways depending on config.
  find "$out" \( -name "short_summary.txt" -o -name "short_summary.specific.*.txt" \) \
       -exec cp {} "$out/short_summary.txt" \; -quit
done

# --------------------------------------------------------------- 4. FastANI
say "Running FastANI against LB400 (environmental) and J2315 (clinical)"
ls "$WORK"/degraded/stm815_frag*.fna > "$WORK/ql.txt"
printf '%s\n' "$LB400" "$J2315" > "$WORK/rl.txt"
fastANI --ql "$WORK/ql.txt" --rl "$WORK/rl.txt" -t "$CPU" \
        -o "$WORK/fastani_matrix.tsv"

# ---------------------------------------------------------------- 5. caller
say "Gating every level through the caller"
mkdir -p "$WORK/calls"
python3 - "$WORK" "$HERE" <<'PY'
import json, re, subprocess, sys
from pathlib import Path

work, here = Path(sys.argv[1]), Path(sys.argv[2])
score = re.compile(r"C:([\d.]+)%")
ani = {}
for line in (work / "fastani_matrix.tsv").read_text().splitlines():
    q, r, val, *_ = line.split("\t")
    lvl = re.search(r"frag(\d+)", q).group(1)
    ani.setdefault(lvl, {})["j2315" if "j2315" in r.lower() else
                           "lb400" if "lb400" in r.lower() else "self"] = float(val)

for lvl in ("100", "90", "70", "50"):
    summary = work / f"busco/frag{lvl}/short_summary.txt"
    if not summary.exists():
        print(f"frag{lvl}: no BUSCO summary, skipped"); continue
    c = float(score.search(summary.read_text()).group(1))
    pair = ani.get(lvl, {})
    cmd = [sys.executable, str(here.parent / "completeness_aware_caller.py"),
           "--completeness", str(c),
           "--genes", str(here.parent / "examples/demo_genes.json"),
           "--output", str(work / "calls" / f"frag{lvl}")]
    if "lb400" in pair and "j2315" in pair:
        cmd += ["--ani-a", str(pair["lb400"]), "--ani-b", str(pair["j2315"])]
    subprocess.run(cmd, check=True)
    print(f"frag{lvl}: C={c}%  ->  {work}/calls/frag{lvl}/report.md")
PY

say "Done"
echo "Reports:   $WORK/calls/frag*/report.md"
echo "BUSCO:     $WORK/busco/frag*/short_summary.txt"
echo "FastANI:   $WORK/fastani_matrix.tsv"
