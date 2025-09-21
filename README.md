# WrtForge

**ImmortalWrt firmware build on Slurm with Apptainer**

This repository provides a complete solution for building ImmortalWrt firmware using Apptainer containers on Slurm clusters. No Docker/Podman required.

## Project Files

- `immortalwrt-build-env-ubuntu2204.def` - Apptainer definition with full Ubuntu build dependencies
- `immortalwrt-build-env-ubuntu2204.sif` - Built Apptainer image (generated)
- `immortalwrt-build-task.sbatch` - Slurm batch script for automated builds
- `logs/` - Slurm job output directory (created automatically)

## Prerequisites

- Slurm available (`srun`, `sbatch`)
- Apptainer available on compute nodes

**Validate Apptainer:**
```bash
srun -N1 -t 5 apptainer --version
```

## Quick Start

### 1. Build the Apptainer Image

If you've modified the definition file, rebuild the container:

```bash
srun -N1 -t 60 apptainer build ./immortalwrt-build-env-ubuntu2204.sif ./immortalwrt-build-env-ubuntu2204.def
```

### 2. Submit Build Job

The script requests 80 CPUs, 192GB RAM, and exclusive node access by default:

```bash
sbatch ./immortalwrt-build-task.sbatch
```

### 3. Monitor Progress

```bash
squeue -u $USER                    # Check job status
tail -f iwrt-repo-<JOBID>.out      # View live output
scancel <JOBID>                     # Cancel if needed
```

### 4. Locate Output

After successful build, firmware images are available at:

```
immortalwrt-firmware-builder/immortalwrt/bin/targets/<target>/<subtarget>/
```

## Configuration Options

### Change Target Device

**Use different seed profile:**
```bash
sbatch --export=ALL,WRT_SEED=tr3000 ./immortalwrt-build-task.sbatch
```

**Use custom config file:**
```bash
sbatch --export=ALL,WRT_CONFIG=/path/to/.config ./immortalwrt-build-task.sbatch
```

### Interactive Configuration

Run menuconfig inside the container:

```bash
srun --pty -N1 -c 4 -t 60 apptainer exec ./immortalwrt-build-env-ubuntu2204.sif bash -lc 'cd immortalwrt-firmware-builder/immortalwrt && make menuconfig'
```

### Adjust Resources

Edit `immortalwrt-build-task.sbatch` to match your cluster:

```bash
#SBATCH -c 80                      # CPU cores
#SBATCH --mem=192000               # Memory (MB)
#SBATCH --exclusive                # Exclusive node access
#SBATCH -t 1-00:00:00              # Wall time (1 day)
```

## Cluster Specifications

**CPU Topology:** 2 sockets × 20 cores/socket × 2 threads/core = 80 logical CPUs

**Memory per Node:**
- di1–di36: 192,000 MB (≈187.5 GiB)
- di37–di38: 384,000 MB (≈375.0 GiB)

**Check available resources:**
```bash
sinfo -h -N -o '%N %m'
scontrol show nodes | awk -v EQ='=' '/NodeName=/{for(i=1;i<=NF;i++) if($i ~ /^NodeName=/){split($i,a,EQ);n=a[2]}} /RealMemory=/{for(i=1;i<=NF;i++) if($i ~ /^RealMemory=/){split($i,a,EQ);m=a[2]; printf("%s %s MB (%.1f GiB)\n", n, m, m/1024)}}'
```

## Re-running Builds

To rebuild with the same settings:

```bash
sbatch ./immortalwrt-build-task.sbatch
```

## Notes & Troubleshooting

- **Dependencies:** Full dependency set installed in container - no host packages required
- **msmtp:** Excluded due to fakeroot issues in this environment
- **Git Updates:** Script automatically re-fetches and updates submodules on subsequent runs
- **Local Testing:** Can run without Slurm using `bash ./immortalwrt-build-task.sbatch`

## Source Repository

**ImmortalWrt Firmware Builder:** [coachpo/immortalwrt-firmware-builder](https://github.com/coachpo/immortalwrt-firmware-builder)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.