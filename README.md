### WrtForge: ImmortalWrt firmware build on Slurm with Apptainer

This README documents how to reproduce the ImmortalWrt firmware build on this cluster using Apptainer inside Slurm allocations. No Docker/Podman is required.

### Files in this folder
- `immortalwrt-build-env-ubuntu2204.def`: Apptainer definition with full Ubuntu build dependencies (msmtp omitted to avoid fakeroot postinst issues)
- `immortalwrt-build-env-ubuntu2204.sif`: Built Apptainer image
- `immortalwrt-firmware-build.sbatch`: Slurm batch script that clones the repo (with submodules), prepares config, updates feeds, and runs the build
- `logs/`: Slurm job output

### Prerequisites
- Slurm available (`srun`, `sbatch`)
- Apptainer available on compute nodes

Validate Apptainer on a compute node:
```bash
srun -N1 -t 5 apptainer --version
```

### 1) Build (or rebuild) the Apptainer image
If you have modified `immortalwrt-build-env-ubuntu2204.def`, rebuild the SIF on a compute node:
```bash
srun -N1 -t 60 apptainer build ./immortalwrt-build-env-ubuntu2204.sif ./immortalwrt-build-env-ubuntu2204.def
```

### 2) Submit the firmware build job
By default, the batch script requests what a typical node on this cluster can provide (80 CPUs, 192000 MB, exclusive). Adjust to your needs/quotas. It clones the repo with submodules, selects a seed (default: `cr6606`), updates feeds, and builds.
```bash
sbatch /home/lqing/containers/immortalwrt-firmware-build.sbatch
```

### 3) Monitor, view logs, cancel
```bash
squeue -u $USER                 # or: squeue -j <JOBID>
tail -f logs/iwrt-repo-<JOBID>.out
scancel <JOBID>
```

### 4) Output location
After success, firmware images appear under:
```
immortalwrt/bin/targets/<target>/<subtarget>/
```

### Change target/seed config
- The job uses the `cr6606` seed by default. You can choose another profile (e.g., `tr3000`) or provide a custom `.config` via environment variables when submitting:
```bash
# Use another seed profile from the repo (e.g., tr3000)
sbatch --export=ALL,OWRT_SEED=tr3000 /home/lqing/containers/immortalwrt-firmware-build.sbatch

# Use a custom .config file
sbatch --export=ALL,OWRT_CONFIG=/absolute/or/relative/path/to/.config /home/lqing/containers/immortalwrt-firmware-build.sbatch
```
- You can run interactive menuconfig inside the container if desired:
```bash
srun --pty -N1 -c 4 -t 60 apptainer exec /home/lqing/containers/immortalwrt-build-env-ubuntu2204.sif bash -lc 'cd /home/lqing/immortalwrt && make menuconfig'
```

### Adjust resources (CPUs, memory, walltime)
Edit `build_repo_and_firmware.sbatch` as needed. Example below matches a typical node here; lower or raise per your requirements:
```bash
#SBATCH -c 80
#SBATCH --mem=192000
#SBATCH --exclusive
#SBATCH -t 1-00:00:00   # example: 1 day
```
Inside the script, `make` uses the CPUs requested via `SLURM_CPUS_PER_TASK`.

### Cluster example (this supercomputer)
- CPU topology per node: 2 sockets × 20 cores/socket × 2 threads/core ⇒ 40 physical cores, 80 logical CPUs.
- Memory per node:
  - di1–di36: 192000 MB (≈187.5 GiB)
  - di37–di38: 384000 MB (≈375.0 GiB)

Inspect resources yourself:
```bash
sinfo -h -N -o '%N %m'
scontrol show nodes | awk -v EQ='=' '/NodeName=/{for(i=1;i<=NF;i++) if($i ~ /^NodeName=/){split($i,a,EQ);n=a[2]}} /RealMemory=/{for(i=1;i<=NF;i++) if($i ~ /^RealMemory=/){split($i,a,EQ);m=a[2]; printf("%s %s MB (%.1f GiB)\n", n, m, m/1024)}}'
```

### Re-run the same build
If you want to re-run with the same settings:
```bash
sbatch /home/lqing/containers/immortalwrt-firmware-build.sbatch
```

### Notes and troubleshooting
- The image installs a full dependency set inside the container. No host packages are needed.
- `msmtp` is excluded due to group creation failing under fakeroot in this environment. If you need it, consider installing at runtime with a writable overlay or enabling setuid/fakeroot support site-wide.
- If `git` or submodules in the repo move, the batch script will re-fetch and re-init submodules on subsequent runs.

### Source repo (with seeds and submodule)
- ImmortalWrt Firmware Builder: [coachpo/immortalwrt-firmware-builder](https://github.com/coachpo/immortalwrt-firmware-builder)


## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.