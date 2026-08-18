# Absent, or just missing?

**A completeness-aware caller for incomplete genomes and MAGs.**
Built at the ClawBio + Nebius Hackathon, Berlin, 18 August 2026 — Open Challenge track.

A fragmented genome makes missing genes look absent and close relatives look
functionally identical. This skill separates **taxonomic confidence** from
**functional confidence** and refuses to conclude when completeness cannot
support the claim. The deliverable is the refusal.

---

## The problem, in one number

Take *Paraburkholderia phymatum* STM815 — a textbook nitrogen fixer, complete
genome, all 21 `nif`/`nod`/`fix` genes sitting on plasmid pBPHY02. Degrade it
to 70% of its contigs, the sort of completeness that passes as a perfectly
publishable MAG, and `nifH` and `nodC` fall into the discarded fraction.

A naive pipeline now reports: **this organism does not fix nitrogen.**
It is wrong, and nothing in its output says so.

`completeness-aware-caller` reports instead:

```
| nifH | CANNOT CONCLUDE | 0.68 | CANNOT CONCLUDE absence: the assembly is only
68% complete, so a truly present gene would be missed with ~32% probability.
Re-sequence or close the assembly before asserting loss of function. |
```

---

## Benchmark: truth-known degradation

*P. phymatum* STM815 (GCF_000020045.1, complete, 8.68 Mb, 4 replicons) cut into
175 × 50 kb windows, seed 42, retained at four levels. BUSCO 6.0.0
(`bacteria_odb12`, n=116) and FastANI 1.34 run on every level. References:
*P. xenovorans* LB400 (environmental) and *B. cenocepacia* J2315 (clinical).

| Retention | BUSCO C% | Symbiosis genes lost / fragmented (of 21) | Naive call | This skill | ANI→LB400 | ANI→J2315 | Margin | ANI gate |
|-----------|----------|-------------------------------------------|------------|------------|-----------|-----------|--------|----------|
| 100% | 98.3 | 0 / 0 | — | absence calls allowed | 81.69 | 81.02 | 0.67 | RANK |
| 90%  | 78.4 | 0 / 0 | — | cannot conclude | 81.51 | 80.83 | 0.68 | RANK |
| 70%  | 68.1 | 6 / 1 — incl. **nifH**, **nodC** | "does not fix N₂" ❌ | **CANNOT CONCLUDE** | 81.45 | 80.75 | 0.70 | RANK |
| 50%  | 48.3 | 7 / 1 | "does not fix N₂" ❌ | **CANNOT CONCLUDE** | 81.28 | 80.58 | 0.70 | **CANNOT CONCLUDE** |

Two gates, falling at different depths. The **functional** gate closes at 90%
retention; the **taxonomic** gate holds until 50%, where the 0.70-point ANI
margin separating an environmental relative from a clinical lineage drops
below twice the drift that incompleteness alone induces. The gradient was
measured, not assumed.

A third finding worth stating: dropping 9.7% of bases produced M=19.8% missing
BUSCOs. Marker loss clusters — completeness is itself an estimate with
variance, which is why the thresholds are conservative.

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

Raw evidence is committed under `benchmark/`: BUSCO `result.json` for each
level, the FastANI matrix, and the per-gene truth table derived from RefSeq
GFF coordinates.

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
