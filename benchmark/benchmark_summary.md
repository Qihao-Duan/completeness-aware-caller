# STM815 degradation benchmark — master table

Truth genome: *Paraburkholderia phymatum* STM815 (GCF_000020045.1, complete,
8.68 Mb, 4 replicons; all 21 nif/nod/fix genes on plasmid pBPHY02).
Windows: 175 × 50 kb, fixed seed 42. BUSCO 6.0.0, bacteria_odb12 (n=116).
FastANI 1.34. References: *P. xenovorans* LB400 (environmental) and
*B. cenocepacia* J2315 (clinical).

| Retention | BUSCO C% | sym genes lost / fragmented (of 21) | Naive pipeline says | completeness-aware-caller says | ANI → LB400 | ANI → J2315 | Margin | ANI gate (2 × 0.82 × (1−C)) |
|-----------|----------|--------------------------------------|---------------------|-------------------------------|-------------|-------------|--------|------------------------------|
| 100%      | 98.3     | 0 / 0                                | —                   | absence calls allowed          | 81.69       | 81.02       | 0.67   | RANK (0.67 > 0.03)           |
| 90%       | 78.4     | 0 / 0                                | —                   | cannot conclude (C < 95%)      | 81.51       | 80.83       | 0.68   | RANK (0.68 > 0.35)           |
| 70%       | 68.1     | 6 / 1 — incl. **nifH**, **nodC**     | "does not fix N₂" (false) | CANNOT CONCLUDE           | 81.45       | 80.75       | 0.70   | RANK (0.70 > 0.52)           |
| 50%       | 48.3     | 7 / 1                                | "does not fix N₂" (false) | CANNOT CONCLUDE           | 81.28       | 80.58       | 0.70   | **CANNOT CONCLUDE** (0.70 < 0.85) |

## The three demo punchlines

1. **Functional layer.** At 70% retention the assembly loses nifH and nodC —
   the two canonical symbiosis markers. A naive pipeline declares a textbook
   nitrogen fixer unable to fix nitrogen. The caller refuses: at C=68.1% a
   truly present gene is missed with ~32% probability.
2. **Taxonomic layer.** The ANI gap separating the environmental relative
   (LB400) from the clinical lineage (J2315) is only 0.67–0.70 points, while
   degradation alone drifts ANI by 0.41 points at 50% retention. At C=48.3%
   the gate fires: margin 0.70 < 0.85 (2× modelled drift) — do not report
   which reference is closer.
3. **Completeness is itself noisy.** Dropping 9.7% of bases produced
   M=19.8% (marker loss clusters); BUSCO C% is an estimate with variance,
   which is why absence needs C ≥ 95%.

## Provenance

- Genomes: NCBI Datasets API, accessions verified live before download.
- Degradation: `scripts/degrade_genome.py` (seed 42, deterministic).
- BUSCO runs: via ClawBio `busco-assessor` (after fixing its
  `--out-path` → `--out_path` BUSCO-6 flag bug); outputs in `data/busco/`.
- ANI: `data/fastani_matrix.tsv`.
- Gene truth: RefSeq GFF coordinate intersection, `data/degraded/gene_status.tsv`.
