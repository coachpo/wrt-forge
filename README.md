# WrtForge

**ImmortalWrt firmware build on Slurm with Apptainer**

This repository provides a complete solution for building ImmortalWrt firmware using Apptainer containers on Slurm clusters. No Docker/Podman required.

## Project Files

- `immortalwrt-build-env-ubuntu2204.def` - Apptainer definition with full Ubuntu build dependencies
- `immortalwrt-build-env-ubuntu2204.sif` - Built Apptainer image (generated)
- `immortalwrt-build-task.sbatch` - Slurm batch script for automated builds
- `iwrt-repo-<JOBID>.out` and `iwrt-repo-<JOBID>.err` - Slurm job logs (generated in working directory)

## Prerequisites

- Slurm available (`srun`, `sbatch`)
- Apptainer or Singularity available on compute nodes

**Validate container runtime:**
```bash
srun -N1 -t 5 apptainer --version || srun -N1 -t 5 singularity --version
```

## Quick Start

### 1. Build the Apptainer Image

If you've modified the definition file, rebuild the container:

```bash
srun -N1 -t 60 apptainer build ./immortalwrt-build-env-ubuntu2204.sif ./immortalwrt-build-env-ubuntu2204.def
```

### 2. Submit Build Job

Submit the build job with default settings:

```bash
sbatch ./immortalwrt-build-task.sbatch
```

### 3. Monitor Progress

```bash
squeue -u $USER                    # Check job status
tail -f iwrt-repo-<JOBID>.out      # View live output
scancel <JOBID>                    # Cancel if needed
```

### 4. Locate Output

After successful build, firmware images are available at:

```
immortalwrt-firmware-builder/immortalwrt/bin/targets/<target>/<subtarget>/
```

## Configuration Options

### Change Target Device

Default seed profile: `cr6606`.

**Use different seed profile:**
```bash
sbatch --export=ALL,WRT_SEED=tr3000 ./immortalwrt-build-task.sbatch
```

**Use custom config file:**
```bash
sbatch --export=ALL,WRT_CONFIG=/path/to/.config ./immortalwrt-build-task.sbatch
```

### Set Build Threads

By default the build uses 4 threads:

```bash
sbatch ./immortalwrt-build-task.sbatch
```

Override the number of threads with `BUILD_THREADS`:

```bash
BUILD_THREADS=12 sbatch ./immortalwrt-build-task.sbatch
# or equivalently
sbatch --export=ALL,BUILD_THREADS=12 ./immortalwrt-build-task.sbatch
# Example to use all avaiable CPUs
sbatch --export=ALL,BUILD_THREADS=$(nproc) ./immortalwrt-build-task.sbatch
```

### Git Options

- `GIT_REF` — branch or tag to build from (default: `main`)
- `GIT_DEPTH` — shallow clone depth (default: `1`)
- `SKIP_GIT_FETCH=1` — reuse existing checkout without network fetch/update

```bash
sbatch --export=ALL,GIT_REF=v24.10.2,GIT_DEPTH=1 ./immortalwrt-build-task.sbatch
# Offline rebuild using existing checkout
sbatch --export=ALL,SKIP_GIT_FETCH=1 ./immortalwrt-build-task.sbatch
```

### Adjust Resources

Edit `immortalwrt-build-task.sbatch` to match your cluster:

```bash
#SBATCH -N 1                       # 1 Node
#SBATCH -t 6:00:00                 # Wall time (6 hours)
```

## Source Repository

**ImmortalWrt Firmware Builder:** [coachpo/immortalwrt-firmware-builder](https://github.com/coachpo/immortalwrt-firmware-builder)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.