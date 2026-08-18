# Absent, or just missing?

**Open Challenge pitch — confidence-aware comparative genomics for incomplete genomes**

## One-liner

A fragmented genome makes missing genes look absent and close relatives look functionally identical. We build a ClawBio workflow that separates taxonomic confidence from functional confidence and **refuses to conclude** when completeness cannot support the claim.

## The problem

Relatedness (ANI / core genome), completeness (BUSCO/CheckM), and functional capacity (gene presence) are three different evidence layers, but pipelines let one answer for another. A genome at 70% BUSCO completeness in which *nifH* is not found gets printed as "absent" — yet there is roughly a 30% chance the gene is simply on a missing page. And two strains at 99% ANI can differ in the one thing that matters, because *nod*/*nif* (and AMR genes) ride on mobile elements that ANI cannot see. Disclosure of completeness in a corner of the report is not abstention.

## What we build (the deliverable)

A thin skill, `completeness-aware-caller`, chained with existing ClawBio tools (`metagenomics`, `galaxy-bridge` → BUSCO / FastANI / CheckM):

- **Input:** gene-search results + a completeness estimate for the genome/MAG.
- **Output:** a three-state call — `present` / `absent` / **`cannot conclude`** — with a confidence value, plus taxonomic and functional confidence reported **separately**.
- The `cannot conclude` state is a first-class output with a clinician/reviewer-actionable message, not a footnote.

## Demo plan (truth-known degradation experiment)

Take one complete public *Paraburkholderia* genome (truth known). Artificially degrade it to 90% / 70% / 50%. At each level, run BUSCO + gene search + ANI against a close relative, and show exactly where the "absent" call and the species assignment start to lie — then show our flag firing at precisely that point. At 16:30 we feed the system one genome it can call and one it must refuse: one answer, one honest refusal.

Thresholds are defensible from peer-reviewed standards: the ~95% ANI species boundary and MIMAG quality tiers.

## Data

Public only: RefSeq/GTDB genomes (*Paraburkholderia*/*Burkholderia*), and the soil-MAG dataset of Rodríguez del Río et al. (BMC Genomics 2026) as a real-world benchmark.

## Why being wrong matters

*Paraburkholderia* is largely environmental (N-fixation, pollutant degradation); its close relatives in *Burkholderia* sensu stricto include the *B. cepacia* complex and *B. pseudomallei*. Misclassification costs in both directions — clinical misidentification, or beneficial strains blocked in regulation because of a bad relative. The same core-vs-mobile logic transfers directly to antibiotic-resistance surveillance.

## Judging fit

- **Originality:** existing tools report ANI and completeness side by side; none couples them into a calibrated conclusion that can decline.
- **Impact:** most modern microbiome claims rest on MAGs that are 50–90% complete — every one of them needs this gate.
- **Implementation:** agentic chain of ClawBio skills + Galaxy bridge; the refusal criterion ("one input where it correctly says it cannot answer") is our centerpiece, not an afterthought.

## Future applications (out of scope today, one line each)

Rhizobia mobile *nod*/*nif* vs core genome; environmental-vs-clinical *Burkholderia* triage; AMF fragmented-assembly taxonomy; completeness-aware MAG interpretation at scale.

---

## Ready-to-paste agent prompt

```
I'm at a genomics hackathon. You are my analysis partner for the next three hours.

CHALLENGE (open track): Absent, or just missing?

The premise: a fragmented genome makes missing genes look absent, and close relatives
look functionally identical. I want a workflow that separates taxonomic confidence
from functional confidence and refuses to conclude when completeness cannot support
the claim.

STEP 0, before anything else
Use your ClawBio skill-listing tool to show me what you can run. I am looking for the
metagenomics skill and the Galaxy bridge; through the bridge I need BUSCO, FastANI or
CheckM. Describe each contract before you run anything, and tell me what inputs it
will and will not accept.

THEN, in order
1. Fetch one complete public Paraburkholderia genome. Run completeness assessment and
   a nif/nod gene search on it. This is our ground truth.
2. Degrade the same genome to 90%, 70% and 50% of its contigs. Re-run completeness,
   gene search, and ANI against a close relative at each level. Show me, with numbers,
   where the "absent" call and the species assignment start to lie.
3. Build the deliverable: a caller that returns present / absent / CANNOT CONCLUDE
   with a confidence value, thresholds justified from step 2 and from published
   standards (95% ANI species boundary, MIMAG tiers). Demo it firing on the 50%
   genome and answering correctly on the complete one.

RULES
Every number must come from something you ran, not from your training data. If a tool
will not accept an input, tell me the boundary rather than working around it silently.
An honest "this genome cannot support that conclusion" is the winning output today.

Start with step 0.
```
