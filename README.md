# Absent, or just missing?

**A completeness-aware caller for incomplete genomes and MAGs.**
Built at the ClawBio + Nebius Hackathon, Berlin, 18 August 2026 — Open Challenge track.

A fragmented genome makes missing genes look absent and close relatives look
functionally identical. This skill separates **taxonomic confidence** from
**functional confidence** and refuses to conclude when completeness cannot
support the claim. The deliverable is the refusal.

---

## The problem, in one number

Take *Paraburkholderia phymatum* STM815 — a textbook symbiont, complete
genome, 21 `nif`/`nod`/`fix` records across 18 distinct gene names — 18 of
those records on the symbiosis plasmid pBPHY02, three (`fixL`, `fixJ` and one
copy of `nodI`) on chromosome 1. Degrade
it to 70% of its contigs, the sort of completeness that passes as a perfectly
publishable MAG, and every copy of `nodB`, `nodC`, `nodS` and `nodU` falls
into the discarded fraction — the entire Nod-factor biosynthesis set, the
machinery this strain uses to signal its legume host and trigger nodulation.

A naive pipeline now reports: **this organism cannot nodulate.**
It is wrong, and nothing in its output says so.

`completeness-aware-caller` reports instead:

```
| nodC | CANNOT CONCLUDE | 0.68 | CANNOT CONCLUDE absence: the assembly is only
68% complete, so a truly present gene would be missed with ~32% probability.
Re-sequence or close the assembly before asserting loss of function. |
```

**And a finding we did not go looking for.** `nifH` survives every degradation
level — not by luck, but because STM815 carries *two* copies of it on pBPHY02
(at 517,691 and 582,554). One copy is lost at 70% retention; the other keeps
the gene detectable. `nifT` is likewise duplicated on pBPHY02, and `nodI`
carries its two copies on *different replicons* — chromosome 1 and pBPHY02 —
which is what keeps it findable at frag70 after the plasmid copy is lost. Whether a gene
goes silently missing from a fragmented assembly is decided by its copy
number, not by its importance — and single-copy genes are the vulnerable ones.
No pipeline currently tells you this.

---

## Benchmark: truth-known degradation

*P. phymatum* STM815 (GCF_000020045.1, complete, 8.68 Mb, 4 replicons) cut into
175 × 50 kb windows, seed 42, retained at four levels. BUSCO 6.0.0
(`bacteria_odb12`, n=116) and FastANI 1.34 run on every level. References:
*P. xenovorans* LB400 (environmental) and *B. cenocepacia* J2315 (clinical).

These are two independent stories, so here are two tables.

**Functional layer — when may you say a gene is absent?**
"Undetectable" means *every* copy fell into a discarded window, so a gene
search genuinely returns nothing. The truth never changes: all of these genes
are present in the organism throughout.

| Retention | BUSCO C% | Undetectable genes | A naive search concludes | Absence gate |
|-----------|----------|--------------------|--------------------------|--------------|
| 100% | 98.3 | none | (nothing missing) | open — absence callable |
| 90%  | 78.4 | none | (nothing missing) | shut — C below 95% |
| 70%  | 68.1 | **nodB nodC nodS nodU** | "cannot nodulate" ❌ | shut — CANNOT CONCLUDE |
| 50%  | 48.3 | + nodI → five genes | "cannot nodulate" ❌ | shut — CANNOT CONCLUDE |

**Taxonomic layer — the signal stays put while the noise climbs.**

| Retention | Completeness | ANI→LB400 | ANI→J2315 | Margin (signal) | Drift (noise) | Threshold 2×drift | Decision |
|-----------|--------------|-----------|-----------|-----------------|---------------|-------------------|----------|
| 100% | 0.983 | 81.69 | 81.02 | 0.67 | 0.01 | 0.03 | rank |
| 90%  | 0.784 | 81.51 | 80.83 | 0.68 | 0.18 | 0.35 | rank |
| 70%  | 0.681 | 81.45 | 80.75 | 0.70 | 0.26 | 0.52 | rank |
| 50%  | 0.483 | 81.28 | 80.58 | 0.70 | 0.42 | **0.85** | **CANNOT CONCLUDE** |

Read the last three columns. The margin stays near 0.67–0.70 — it is a
property of the two organisms, not of the assembly — while the modelled
threshold climbs from 0.03 to 0.85 as drift grows. They cross at 50%
retention and the gate shuts. What is being separated is worth naming: 0.70
ANI points is the entire evidentiary distance between a nitrogen-fixing soil
organism and a cystic-fibrosis pathogen, and fragmentation alone shifts
absolute ANI by 0.41 points.

**State this result conservatively.** LB400 is the closer reference at every
level and the ranking never flips; the margin in fact *widens* slightly
(0.6679 → 0.7034) rather than shrinking. So the benchmark bounds the noise
fragmentation introduces — it does not contain a case where fragmentation
produced a wrong species call. The functional failure in the first table is
demonstrated, with a known right answer. This second one is suggestive, and
the gate fires on a modelling decision rather than on a caught error. The two
gates close at different depths, functional at 90% and taxonomic at 50%, but
only the first depth was established by an observed mistake.

A footnote worth stating: at frag90, dropping 9.8% of bases produced M=19.8%
missing BUSCOs — roughly double. At frag70 and frag50 the two track closely
(30.5 vs 30.2, 49.6 vs 48.3), so this is a mild-degradation effect rather than
general clustering. Completeness is an estimate carrying variance, which is why
the thresholds are conservative. Note also that frag100 already scores 98.3%,
not 100%: it keeps every base but is cut into 175 contigs, so this axis mixes
base loss with loss of contiguity.

---

## Domain decisions

| Decision | Value | Grounding |
|----------|-------|-----------|
| Minimum completeness to assert absence | 0.95 | Caps P(missed \| present) ≈ 1−C at 5%; anchored to MIMAG tiers (Bowers et al. 2017) |
| ANI drift model | 0.82 × (1−C) points | Calibrated on this benchmark (0.41 pts observed drift at 50% retention) |
| Ranking safety factor | 2× drift | Signal must beat twice the noise |
| Species-boundary zone | 94–96% ANI | Jain et al. 2018 |

---

## Usage

```bash
# Demo: the STM815 @ 70% scenario
python3 completeness_aware_caller.py --demo --output /tmp/cac_demo

# Chained after ClawBio's busco-assessor
python3 completeness_aware_caller.py \
  --busco-json /path/to/busco_out/result.json \
  --genes examples/demo_genes.json \
  --ani-a 81.445 --ani-b 80.749 \
  --output /tmp/cac_out

# Direct completeness value
python3 completeness_aware_caller.py \
  --completeness 0.98 --genes examples/demo_genes.json --output /tmp/cac_out
```

Outputs `report.md` (three-state call table), `result.json` (machine-readable
calls, thresholds, gate decision) and `commands.sh` (replay).

Zero third-party dependencies — Python standard library only.

## Tests

```bash
pytest tests/          # 12 tests, red/green TDD per ClawBio contribution rules
```

## Reproducing the benchmark

```bash
bash scripts/download_genomes.sh          # 3 genomes from NCBI Datasets API
python3 scripts/degrade_genome.py \
  --fasta data/stm815/...genomic.fna \
  --gff   data/stm815_gff/...genomic.gff \
  --outdir data/degraded
# then BUSCO + FastANI per benchmark/benchmark_summary.md
```

Raw evidence is committed under `benchmark/`. For each retention level,
`benchmark/busco/frag*/` holds BUSCO's own unedited output — `short_summary.txt`
(the C/S/D/F/M score string as BUSCO printed it), `full_table.tsv` (per-ortholog
status) and `missing_busco_list.tsv` (exactly which markers were not found) —
alongside the parsed `result.json`. `benchmark/fastani_matrix.tsv` is FastANI's
raw output, and `benchmark/gene_status.tsv` is the per-gene truth table derived
from RefSeq GFF coordinates.

The three source genomes are deliberately *not* vendored. Accessions
(`GCF_000020045.1`, `GCF_000013645.1`, `GCF_000009485.1`) are more verifiable
than a copy, and `scripts/download_genomes.sh` fetches them byte-identical.
The degraded assemblies are likewise omitted: `degrade_genome.py` regenerates
them deterministically from seed 42.

---

## ClawBio integration

This is a ClawBio skill (`SKILL.md` conforms to the project template:
Trigger, Scope, Domain Decisions, Workflow, Gotchas, Safety, Agent Boundary,
Chaining Partners, Maintenance, Citations).

| Upstream | Handoff | Downstream |
|----------|---------|-----------|
| `busco-assessor` | `result.json` (C%) | **`completeness-aware-caller`** |
| FastANI / `galaxy-bridge` | ANI values | **`completeness-aware-caller`** |
| **`completeness-aware-caller`** | three-state calls | `profile-report` |

**Upstream bug found and fixed while building this:** ClawBio's
`busco-assessor` constructs its BUSCO command with `--out-path`, but BUSCO 6
only accepts `--out_path`. Every real (non-demo) invocation fails with
`unrecognized arguments`. The skill's own demo never calls the BUSCO binary,
which is why it went unnoticed. One-line fix submitted separately.

---

## Why being wrong matters

*Paraburkholderia* is largely environmental — nitrogen fixation, pollutant
degradation. Its close relatives in *Burkholderia* sensu stricto include the
*B. cepacia* complex and *B. pseudomallei*. Misclassification is costly in
both directions: a pathogen read as an environmental isolate, or a beneficial
strain blocked in registration because of a bad relative. The same
core-versus-mobile logic transfers directly to antibiotic-resistance
surveillance, where the resistance genes ride the same mobile elements that
ANI cannot see.

## Citations

- Bowers R.M. et al. (2017). MIMAG/MISAG standards. *Nature Biotechnology*. https://doi.org/10.1038/nbt.3893
- Jain C. et al. (2018). High-throughput ANI analysis reveals clear species boundaries. *Nature Communications*. https://doi.org/10.1038/s41467-018-07641-9
- Manni M. et al. (2021). BUSCO Update. *Molecular Biology and Evolution*. https://doi.org/10.1093/molbev/msab199

---

*ClawBio is a research and educational tool. It is not a medical device and
does not provide clinical diagnoses.*
