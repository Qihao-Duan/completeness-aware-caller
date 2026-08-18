# STM815 degradation benchmark, v1

**A truth-known test of when an incomplete bacterial genome stops supporting a
conclusion.**

Generated 18 August 2026 · CC BY 4.0 (data) / MIT (scripts) · 86 KB

---

## 1. What this is

A complete bacterial genome was deliberately fragmented to four levels of
completeness. Because the starting genome is complete and annotated, the
correct answer is known at every level. The dataset records what two standard
tools — BUSCO 6.0.0 and FastANI 1.34 — actually reported at each level, and
what the correct answer was.

It exists to answer one question with measurements rather than argument:

> At what completeness does a gene-presence call, or a species assignment,
> stop being supportable — and what does a pipeline that ignores this get
> wrong?

**Scope, stated plainly.** This is one genome, one clade, one degradation
model. It is a worked example, not a survey. It is sufficient to demonstrate
a failure mode and to calibrate a threshold; it is not sufficient to claim
those thresholds generalise across taxa. Treat n=1 as the headline limitation.

## 2. The organism and the references

| Role | Organism | Accession | Assembly | Level | Length |
|---|---|---|---|---|---|
| Truth genome | *Paraburkholderia phymatum* STM815 | `GCF_000020045.1` | ASM2004v1 | Complete | 8,676,562 bp |
| Environmental reference | *Paraburkholderia xenovorans* LB400 | `GCF_000013645.1` | ASM1364v1 | Complete | — |
| Clinical reference | *Burkholderia cenocepacia* J2315 | `GCF_000009485.1` | ASM948v1 | Complete | — |

STM815 is a nitrogen-fixing legume symbiont. LB400 is environmental
(pollutant degradation). J2315 belongs to the *B. cepacia* complex and is a
cystic-fibrosis pathogen. The two references were chosen because telling them
apart is a decision with real consequences in both directions.

STM815 has four replicons:

| Accession | Molecule |
|---|---|
| `NC_010622.1` | chromosome 1 |
| `NC_010623.1` | chromosome 2 |
| `NC_010625.1` | plasmid pBPHY01 |
| `NC_010627.1` | plasmid pBPHY02 (symbiosis plasmid) |

## 3. The symbiosis gene set

The RefSeq annotation carries **21 gene records** matching `nif*`, `nod*` or
`fix*`, which resolve to **18 distinct gene names**. Their distribution is not
uniform, and this matters for interpreting the results:

- **18 records on pBPHY02**, the symbiosis plasmid.
- **3 records on chromosome 1**: `fixJ`, `fixL`, and one copy of `nodI`.

Three names carry more than one copy:

| Gene | Copies | Locations |
|---|---|---|
| `nifH` | 2 | pBPHY02 517,691–518,572 and 582,554–583,435 |
| `nifT` | 2 | pBPHY02 514,280–514,498 and 548,416–548,634 |
| `nodI` | 2 | **chromosome 1** 1,855,625–1,856,539 and pBPHY02 488,393–489,307 |

`nodI` is the only gene whose copies sit on different replicons. This is
consequential: copy number, and where the copies live, decides which genes a
fragmented assembly can still show you. See §6.

## 4. How the data was generated

```
GCF_000020045.1 (complete, 8.68 Mb, 4 replicons)
        │
        ├── cut into 175 windows of 50 kb            scripts/degrade_genome.py
        │
        ├── retain a seeded random subset            seed = 42, fixed
        │     → frag100 / frag90 / frag70 / frag50
        │
        ├── BUSCO 6.0.0, lineage bacteria_odb12 (n=116), per level
        │
        ├── FastANI 1.34, each level × {LB400, J2315}
        │
        └── gene fate by RefSeq GFF coordinate intersection
              (not by re-running a search — keeps truth independent of tooling)
```

Retention is the **only** variable between levels: all four are windowed
identically, and the seed is fixed, so the degradation is deterministic and
exactly reproducible.

## 5. Results

### 5.1 Completeness

| Level | Windows kept | Bases kept | Bases dropped | BUSCO score string | Missing markers |
|---|---|---|---|---|---|
| frag100 | 175/175 | 8,676,562 | 0.0% | `C:98.3%[S:98.3%,D:0.0%],F:1.7%,M:0.0%,n:116` | 0.0% |
| frag90 | 158/175 | 7,826,562 | 9.8% | `C:78.4%[S:78.4%,D:0.0%],F:1.7%,M:19.8%,n:116` | 19.8% |
| frag70 | 122/175 | 6,031,454 | 30.5% | `C:68.1%[S:68.1%,D:0.0%],F:1.7%,M:30.2%,n:116` | 30.2% |
| frag50 | 88/175 | 4,376,561 | 49.6% | `C:48.3%[S:48.3%,D:0.0%],F:3.4%,M:48.3%,n:116` | 48.3% |

Two things about this table need stating before anyone reuses it.

**frag100 is not the intact genome.** It retains every base of
`GCF_000020045.1` — BUSCO's reported total length, 8,676,562 bp, matches
exactly — but it is presented as 175 contigs of 50 kb rather than 4 replicons.
It therefore scores `C:98.3%`, not 100%: two markers straddle window
boundaries and are reported Fragmented. The completeness axis of this
benchmark consequently mixes **base loss** with **loss of contiguity**, and
every level shares the same 50 kb contig structure (scaffold N50 = 50 kb
throughout). A tool sensitive to contiguity rather than to missing sequence
will see a confounded signal here.

**The base-loss / marker-loss disproportion is a mild-degradation effect
only.** Dropping 9.8% of bases removed 19.8% of markers, roughly double. But
at frag70 and frag50 the two track closely (30.5 vs 30.2, 49.6 vs 48.3). The
amplification is real at one of three data points, so read it as "marker loss
is noisy at low loss", not as "marker loss clusters" in general. Fragmented
stays flat at 2 markers for frag100/90/70 and rises to 4 only at frag50;
Duplicated is 0 everywhere, so C and S are identical throughout.

### 5.2 Gene detectability

A gene is **undetectable** at a level only when *every* copy fell into a
discarded window, so a search genuinely returns nothing. The truth never
changes: all 18 genes are present in the organism at every level.

| Level | Undetectable | Saved by duplication | Any copy fragmented |
|---|---|---|---|
| frag100 | — | — | — |
| frag90 | — | — | — |
| frag70 | `nodB` `nodC` `nodS` `nodU` | `nifH`, `nodI` | `nifA` |
| frag50 | `nodB` `nodC` `nodI` `nodS` `nodU` | `nifH` | `nifA` |

At frag70 the entire Nod-factor biosynthesis set goes dark. A pipeline that
converts "not found" into "absent" concludes **this strain cannot nodulate** —
false, and unmarked as uncertain.

`nodI` is instructive: at frag70 it survives only because its second copy sits
on chromosome 1, a different replicon from the one carrying the rest of the
cluster. By frag50 both copies are gone.

### 5.3 Species assignment

| Level | Completeness | ANI→LB400 | ANI→J2315 | Margin | Observed ANI drop vs frag100 (LB400) |
|---|---|---|---|---|---|
| frag100 | 0.983 | 81.6851 | 81.0172 | 0.6679 | — |
| frag90 | 0.784 | 81.5069 | 80.8304 | 0.6765 | 0.1782 |
| frag70 | 0.681 | 81.4450 | 80.7490 | 0.6960 | 0.2401 |
| frag50 | 0.483 | 81.2787 | 80.5753 | 0.7034 | 0.4064 |

Both ANI arms drift downward monotonically as retention falls, by 0.41 points
at frag50 for LB400 and 0.44 for J2315. The margin between them is close to
constant, but it does not shrink — it *widens* slightly and monotonically,
from 0.6679 to 0.7034.

**Read this result conservatively.** LB400 is the closer reference at every
level, and the ranking is stable throughout: at no point does degradation
actually flip or threaten the assignment in this dataset. What the numbers
establish is that fragmentation alone shifts absolute ANI by an amount
(0.41 points) comparable to the distance separating the two references
(0.70 points). Whether a *gate* should fire on that basis is a modelling
decision, not something these four points demonstrate. A tool that refuses at
frag50 is refusing because its noise estimate grew, not because this benchmark
caught it getting the answer wrong.

That distinction matters for anyone reusing this dataset: the functional
result in §5.2 is a **demonstrated** false-call failure, with a known correct
answer. The taxonomic result here is **suggestive** — it bounds the noise, it
does not exhibit an error.

## 6. Two findings worth carrying away

1. **Absence is unprovable below a completeness floor, and pipelines do not
   say so.** At frag70, four real genes are undetectable and a naive caller
   reports them absent with no uncertainty attached.

2. **Copy number, not importance, decides what survives fragmentation.**
   `nifH` — the canonical nitrogen-fixation marker, the first gene anyone
   looks for — is detectable at every level, purely because STM815 carries two
   copies. Single-copy genes are the vulnerable ones. No completeness metric
   in common use reports this, and it means a gene-presence result carries a
   hidden dependency on the genome's own redundancy.

## 7. Files

Full paths, sizes and SHA-256 for every file are in `MANIFEST.tsv`.

| Path | What it is |
|---|---|
| `raw_evidence/busco/frag*/short_summary.txt` | BUSCO's own unedited score output |
| `raw_evidence/busco/frag*/full_table.tsv` | per-ortholog status, all 116 markers |
| `raw_evidence/busco/frag*/missing_busco_list.tsv` | exactly which markers were not found |
| `raw_evidence/busco/frag*/result.json` | parsed scores |
| `raw_evidence/fastani_matrix.tsv` | FastANI's raw output, all query × reference pairs |
| `derived/ground_truth.json` | machine-readable answer key — use this to score a tool |
| `derived/gene_status.tsv` | per-**copy** gene fate per level |
| `derived/manifest.json` | windows and bases retained per level |
| `scripts/download_genomes.sh` | fetches the three genomes by accession |
| `scripts/degrade_genome.py` | regenerates the four assemblies, seed 42 |
| `scripts/evaluate.py` | scores a tool's calls against `ground_truth.json` |
| `environment.yml` | the exact toolchain |

### What is deliberately not included

The three source genomes (26 MB) and the four degraded assemblies (26 MB) are
not shipped. Accessions plus a download script are more verifiable than a
vendored copy, and the degraded assemblies regenerate deterministically. To
confirm you regenerated them correctly, compare against the checksums recorded
in `derived/ground_truth.json`:

```
stm815_frag100.fna  b73d9eacd51355364d750a00fdeb2c208e2cf04af3e6f9a2dccfa700bd77bfa2
stm815_frag90.fna   b3766b5a5f99312f43eab97a86d7f1b1cfffdf2345576158bacd3c33aa64ca77
stm815_frag70.fna   7bc1dbec2d1ba1b90ea0b996ed0c1758992ab7c7f3edd29dfd060c397946a3f3
stm815_frag50.fna   08e7b2dd4501b2f6e3a3b6fcabe623a57c5e8699ed99812f10cc954e4a60d1aa
```

BUSCO's lineage datasets and its intermediate hmmer/prodigal output are also
excluded — the former is not ours to redistribute, the latter is scratch.

## 8. Using this to score a tool

```bash
bash scripts/download_genomes.sh data
python3 scripts/degrade_genome.py --fasta data/stm815/*.fna \
        --gff data/stm815_gff/*.gff --outdir data/degraded
# verify against the checksums above, then run your own tool, then:
python3 scripts/evaluate.py --truth derived/ground_truth.json --calls my_calls.json
```

`my_calls.json` is a list of `{"level": "frag70", "gene": "nodC", "call": "absent"}`,
where `call` is `present`, `absent` or `cannot_conclude`.

The scoring deliberately treats abstention as a legitimate outcome. Calling a
truly-present gene `absent` is scored as a **false absence** — the failure this
benchmark exists to catch. A tool that abstains on everything records zero
false absences but is exposed by the *over-cautious* count, so the trivial
strategy does not win.

## 9. Limitations

- **n = 1.** One genome, one clade (Burkholderiaceae), one degradation model,
  one random seed, two references. Four points on a trajectory with no
  replicate and no error bar. Thresholds calibrated here should not be assumed
  to transfer.
- **Completeness confounds base loss with contiguity loss.** See §5.1:
  frag100 already scores 98.3% because it is 175 contigs, not 4 replicons.
- **The taxonomic result exhibits no error.** The reference ranking is stable
  at all four levels and the margin widens rather than shrinks. This dataset
  bounds the noise that fragmentation introduces; it does not contain a case
  where fragmentation produced a wrong species assignment. Do not cite it as
  though it does.
- **"Fragmented" is weaker than the word suggests.** `nifA` retains 164 of
  1,644 bp at frag70 and frag50. Whether such a remnant is detectable at all
  depends entirely on the search method, which this dataset does not fix.
- **The degradation model is uniform random window loss.** Real assembly
  incompleteness is not random: GC-extreme, repetitive and low-coverage
  regions are lost preferentially. This benchmark is therefore optimistic
  about which genes go missing.
- **Any ANI drift coefficient fitted to these numbers is circular.** The
  observed drift here (0.41 points at frag50) is a measurement from this one
  experiment. A tool that fits its threshold to this dataset and is then
  evaluated on it is not being tested; describe such a coefficient as
  calibrated, never as validated.
- **BUSCO completeness is an estimate with variance**, most visibly at frag90,
  where 9.8% base loss produced 19.8% marker loss.
- **No contamination axis.** Real MAGs are both incomplete *and* contaminated;
  only incompleteness is modelled here.

## 10. Citation and provenance

Everything was produced on 18 August 2026 with BUSCO 6.0.0 (`bacteria_odb12`,
n=116), FastANI 1.34 and prodigal 2.6.3, on genomes fetched the same day from
the NCBI Datasets API. Accessions were resolved and verified live before
download.

Reference standards the interpretation leans on:

- Bowers R.M. *et al.* (2017) MIMAG/MISAG standards. *Nature Biotechnology*. https://doi.org/10.1038/nbt.3893
- Jain C. *et al.* (2018) High-throughput ANI analysis reveals clear species boundaries. *Nature Communications*. https://doi.org/10.1038/s41467-018-07641-9
- Manni M. *et al.* (2021) BUSCO Update. *Molecular Biology and Evolution*. https://doi.org/10.1093/molbev/msab199

Tool built against this benchmark:
https://github.com/Qihao-Duan/completeness-aware-caller
