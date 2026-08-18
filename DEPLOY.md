# Running this in a cluster

Two workloads live here and they have nothing in common, so there are two
images and two Jobs.

| | caller | benchmark |
|---|---|---|
| What it does | gates gene calls against a completeness estimate | reproduces the STM815 evidence from scratch |
| Base | `python:3.12-slim` | `mambaorg/micromamba` + BUSCO 6 + FastANI |
| Size | ~120 MB | ~2 GB |
| Runtime | seconds | 30–90 min |
| Network | none | NCBI + BUSCO dataset servers |
| Arch | amd64 + arm64 | amd64 only¹ |

¹ bioconda ships no `linux-aarch64` build for BUSCO's dependency chain.

## Build

```bash
docker build --target caller    -t completeness-aware-caller:0.1.0 .
docker build --target benchmark -t completeness-aware-caller:0.1.0-benchmark .

# Smoke test — the demo must abstain, or the build is not doing its job
docker run --rm -v "$PWD/out:/data" completeness-aware-caller:0.1.0
grep "CANNOT CONCLUDE" out/demo/report.md
```

The caller image runs its own demo during build and fails if the report comes
back without a `CANNOT CONCLUDE`, so a broken abstention path never ships.

## Deploy

```bash
kubectl apply -k k8s/                      # namespace, PVC, ConfigMap, caller Job
kubectl -n clawbio logs -f job/caller
kubectl -n clawbio exec -it <pod> -- cat /data/calls/manual/report.md
```

The benchmark Job is deliberately left out of `kustomization.yaml` — it is
long and expensive, so it is opt-in:

```bash
kubectl apply -f k8s/job-benchmark.yaml
kubectl -n clawbio logs -f job/benchmark
```

Run the benchmark first if you want the caller to read real BUSCO output: it
populates `/data/busco/frag*/result.json` on the shared volume, which the
caller Job can then point at with `--busco-json` instead of a literal
`--completeness`.

## What to change for your cluster

**Storage class.** `k8s/base.yaml` requests 26 Gi with no `storageClassName`,
so you get the cluster default. Set it explicitly if the default is slow —
BUSCO is IO-heavy. 10 Gi is the realistic floor; the genomes and their
degraded copies account for most of it.

**Access mode.** `ReadWriteOnce` is enough for Jobs that run one after the
other. If you want the caller and benchmark running at once against the same
volume, you need `ReadWriteMany` and a storage class that supports it.

**Egress.** The benchmark Job talks to `api.ncbi.nlm.nih.gov` and the BUSCO
dataset servers. Under a default-deny NetworkPolicy it will hang on the first
download; allow those hosts first. The caller Job needs no network at all and
is safe to lock down completely.

**Resources.** The benchmark requests 4 CPU / 8 Gi and caps at 8 CPU / 16 Gi.
BUSCO scales with `BUSCO_CPU`, set as an env var on the Job; keep it at or
below the CPU request or you will just queue threads.

**Lineage cache.** `BUSCO_DOWNLOAD_PATH` points at the PVC, so the ~74 MB
`bacteria_odb12` download happens once and re-runs skip it. Point it at an
`emptyDir` instead if you would rather re-download than keep it.

## Keeping images in step with the repo

`.github/workflows/container.yml` builds on every push and PR. Pushes to
`main` publish `:edge`; a `v*` tag publishes the version tags and is the only
thing that rebuilds the 2 GB benchmark image. Pull requests build without
pushing, so a broken Dockerfile fails review rather than the registry. The
same workflow runs the test suite and asserts the demo still abstains.

```bash
git tag v0.1.0 && git push --tags     # publishes both images
```

Images land at `ghcr.io/qihao-duan/completeness-aware-caller`. The package is
private until you flip it to public in the repo's Packages settings; a cluster
pulling a private package needs an image pull secret.

## Security posture

Both Jobs run as non-root with all capabilities dropped, no privilege
escalation and the `RuntimeDefault` seccomp profile. The caller additionally
runs with a read-only root filesystem and a 64 Mi `emptyDir` for `/tmp`. The
benchmark cannot: BUSCO writes scratch outside the data volume.

Note the uid difference. The caller image creates uid 10001; the micromamba
base runs as uid 1000. The two Jobs set `runAsUser` accordingly, and `fsGroup`
matches so both can write the shared volume. If you rebuild on a different
base, check these still line up or the Job will fail on a permission error at
first write.

## Not verified here

These manifests and the Dockerfile were written without a Docker daemon or
cluster available. What *was* checked: every YAML file parses, both shell
scripts pass `bash -n`, and the caller Job's exact arguments and ConfigMap
contents were run locally end to end and produced the expected abstention
report. The image builds themselves are unproven — expect to iterate on the
first `docker build`.
