# syntax=docker/dockerfile:1.7
#
# Two workloads live in this repo and they have nothing in common, so this
# file builds two independent images.
#
#   --target caller     ~120 MB. The skill itself. Python stdlib only, no
#                       bioinformatics tooling. This is what you run at scale.
#
#   --target benchmark  ~2 GB. BUSCO 6 + FastANI + prodigal, for reproducing
#                       the STM815 degradation evidence from scratch.
#
# Build:
#   docker build --target caller    -t completeness-aware-caller:0.1.0 .
#   docker build --target benchmark -t completeness-aware-caller:0.1.0-benchmark .

# ---------------------------------------------------------------- caller
FROM python:3.12-slim-bookworm AS caller

LABEL org.opencontainers.image.title="completeness-aware-caller"
LABEL org.opencontainers.image.description="Three-state gene calls for incomplete genomes: present / absent / cannot-conclude"
LABEL org.opencontainers.image.source="https://github.com/Qihao-Duan/completeness-aware-caller"
LABEL org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# uid 10001 is arbitrary but fixed, so a k8s runAsUser can match it.
RUN groupadd --gid 10001 claw \
 && useradd --uid 10001 --gid claw --create-home --shell /usr/sbin/nologin claw

WORKDIR /app

COPY --chown=claw:claw completeness_aware_caller.py SKILL.md ./
COPY --chown=claw:claw examples/ ./examples/
COPY --chown=claw:claw tests/ ./tests/

# Fail the build rather than ship an image whose demo does not run.
RUN python3 completeness_aware_caller.py --demo --output /tmp/build_check \
 && grep -q "CANNOT CONCLUDE" /tmp/build_check/report.md \
 && rm -rf /tmp/build_check

USER claw

# Writable by default; k8s mounts a volume over this.
VOLUME ["/data"]

ENTRYPOINT ["python3", "/app/completeness_aware_caller.py"]
CMD ["--demo", "--output", "/data/demo"]


# ------------------------------------------------------------- benchmark
# micromamba because BUSCO and FastANI exist only in bioconda. Pinned to a
# specific micromamba release; conda packages pinned in the install line.
FROM mambaorg/micromamba:1.5.8-bookworm-slim AS benchmark

LABEL org.opencontainers.image.title="completeness-aware-caller-benchmark"
LABEL org.opencontainers.image.description="Reproduces the STM815 degradation benchmark: BUSCO 6 + FastANI"
LABEL org.opencontainers.image.source="https://github.com/Qihao-Duan/completeness-aware-caller"

USER root
RUN apt-get update \
 && apt-get install --no-install-recommends -y curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*
USER $MAMBA_USER

# BUSCO 6.0.0 pulls prodigal and hmmer as dependencies. FastANI 1.34 is the
# version the published benchmark numbers were produced with.
RUN micromamba install -y -n base -c conda-forge -c bioconda \
        python=3.12 \
        busco=6.0.0 \
        fastani=1.34 \
 && micromamba clean --all --yes

ARG MAMBA_DOCKERFILE_ACTIVATE=1

WORKDIR /app
COPY --chown=$MAMBA_USER:$MAMBA_USER completeness_aware_caller.py ./
COPY --chown=$MAMBA_USER:$MAMBA_USER scripts/ ./scripts/
COPY --chown=$MAMBA_USER:$MAMBA_USER examples/ ./examples/

RUN chmod +x scripts/*.sh

# BUSCO writes its downloaded lineage datasets here; mount a volume to cache
# them between runs rather than re-downloading ~74 MB every time.
ENV BUSCO_DOWNLOAD_PATH=/data/busco_downloads

VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]
CMD ["bash", "/app/scripts/run_benchmark.sh", "/data"]
