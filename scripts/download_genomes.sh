#!/bin/sh
# Fetch the three benchmark genomes from the NCBI Datasets API.
# All are complete, publicly available RefSeq assemblies.
#
#   STM815 — Paraburkholderia phymatum, nitrogen fixer, truth genome
#   LB400  — Paraburkholderia xenovorans, environmental relative
#   J2315  — Burkholderia cenocepacia, clinical lineage
set -e

OUT="${1:-data}"
mkdir -p "$OUT"

fetch() {
  acc="$1"; name="$2"; types="$3"
  echo "Fetching $name ($acc, $types)"
  curl -sL --max-time 300 \
    "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/$acc/download?include_annotation_type=$types" \
    -o "$OUT/$name.zip"
  unzip -o -q "$OUT/$name.zip" -d "$OUT/$name"
  rm -f "$OUT/$name.zip"
}

fetch GCF_000020045.1 stm815     GENOME_FASTA
fetch GCF_000020045.1 stm815_gff GENOME_GFF
fetch GCF_000013645.1 lb400      GENOME_FASTA
fetch GCF_000009485.1 j2315      GENOME_FASTA

echo "Done. Genomes under $OUT/"
find "$OUT" -name "*.fna" -o -name "*.gff" | sort
