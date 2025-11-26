# WrtForge

Build ImmortalWrt firmware reproducibly on Slurm using an Apptainer/Singularity image—no Docker/Podman needed. This repo wraps the upstream **coachpo/immortalwrt-firmware-builder** with a container recipe and a Slurm job script so you can submit one job and get firmware artifacts.

## What’s here
- `immortalwrt-build-env-ubuntu2204.def` – Apptainer definition (Ubuntu 22.04 + build deps)
- `immortalwrt-build-env-ubuntu2204.sif` – Built image (generated)
- `immortalwrt-build-task.sbatch` – Slurm batch script that clones, configures, and builds
- `iwrt-repo-<JOBID>.out` / `iwrt-repo-<JOBID>.err` – Job logs (generated)

## Requirements
- Slurm with `sbatch`, `srun`, `squeue`
- Apptainer or Singularity available on compute nodes
- Git + outbound network (unless `SKIP_GIT_FETCH=1`)

Quick runtime check:
```bash
srun -N1 -t 5 apptainer --version || srun -N1 -t 5 singularity --version
```

## Quick start
1) Build (or rebuild) the container if you changed the `.def` file:
```bash
srun -N1 -t 60 apptainer build immortalwrt-build-env-ubuntu2204.sif immortalwrt-build-env-ubuntu2204.def
```

2) Submit the firmware build:
```bash
sbatch immortalwrt-build-task.sbatch
```

3) Monitor:
```bash
squeue -u "$USER"
tail -f iwrt-repo-<JOBID>.out
scancel <JOBID>
```

4) Find outputs:
```
immortalwrt-firmware-builder/immortalwrt/bin/targets/<target>/<subtarget>/
```

## Configuration (env vars)
Pass overrides with `--export=ALL,<VAR>=...` or by prefixing the command.

| Variable | Default | Purpose |
| --- | --- | --- |
| `GIT_REF` | `main` | Branch/tag of upstream repo |
| `GIT_DEPTH` | `1` | Shallow clone depth |
| `SKIP_GIT_FETCH` | unset | `1` to reuse existing checkout offline |
| `WRT_SEED` | `cr6606` | Seed profile under `<repo>/<seed>/seed.config` |
| `WRT_CONFIG` | empty | Path to custom `.config` (overrides seed) |
| `BUILD_THREADS` | `4` | Parallel `make` jobs |
| `CONTAINER_CMD` | auto-detect | Force `apptainer` or `singularity` |

Examples:
```bash
sbatch --export=ALL,WRT_SEED=tr3000 immortalwrt-build-task.sbatch
sbatch --export=ALL,WRT_CONFIG=$PWD/my.config immortalwrt-build-task.sbatch
BUILD_THREADS=$(nproc) sbatch immortalwrt-build-task.sbatch
sbatch --export=ALL,GIT_REF=v24.10.2,GIT_DEPTH=1 immortalwrt-build-task.sbatch
sbatch --export=ALL,SKIP_GIT_FETCH=1 immortalwrt-build-task.sbatch    # offline rebuild
```

To change Slurm resources, edit the directives at the top of `immortalwrt-build-task.sbatch` (nodes, walltime, partition).

## How it works
1. The Slurm job clones `coachpo/immortalwrt-firmware-builder` (or reuses local copy).
2. It copies either `WRT_CONFIG` or the seed config (`<seed>/seed.config`) into `immortalwrt/.config`.
3. The container executes feeds update/install, `make defconfig`, then `make -j${BUILD_THREADS}` inside `immortalwrt`.

## Troubleshooting
- **Container runtime not found:** set `CONTAINER_CMD=apptainer` or `CONTAINER_CMD=singularity` and ensure it is on `$PATH` on compute nodes.
- **Seed missing:** pick another `WRT_SEED` or provide `WRT_CONFIG` with an absolute/relative path.
- **Slow builds:** raise `BUILD_THREADS` to available CPUs; also increase Slurm walltime.
- **Network-restricted cluster:** use `SKIP_GIT_FETCH=1` after a successful online clone.

## Upstream
ImmortalWrt Firmware Builder: https://github.com/coachpo/immortalwrt-firmware-builder

## License
MIT License – see `LICENSE`.
