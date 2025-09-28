#!/bin/bash
#SBATCH -J iwrt-repo
#SBATCH -N 1
#SBATCH -t 6:00:00
#SBATCH -p normal
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail

# Config: which git ref (branch/tag) to use; shallow clone depth for compiling only
GIT_REF="${GIT_REF:-main}"
GIT_DEPTH="${GIT_DEPTH:-1}"
WRT_SEED="${WRT_SEED:-cr6606}"             # e.g. cr6606, tr3000 (profiles in the repo)
WRT_CONFIG="${WRT_CONFIG:-}"               # optional absolute/relative path to a custom .config
BUILD_THREADS="${BUILD_THREADS:-4}"        # number of parallel make jobs (default 4)


# Ensure we operate relative to the directory where the job was submitted
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

# Print basic context for debugging
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "Build threads: ${BUILD_THREADS}"
echo "Git ref: ${GIT_REF}"
echo "Git depth: ${GIT_DEPTH}"
echo "Seed: ${WRT_SEED}"
echo "Config: ${WRT_CONFIG}"

# Detect container runtime (Apptainer or Singularity)
CONTAINER_CMD="${CONTAINER_CMD:-}"
if [ -z "$CONTAINER_CMD" ]; then
  if command -v apptainer >/dev/null 2>&1; then
    CONTAINER_CMD=apptainer
  elif command -v singularity >/dev/null 2>&1; then
    CONTAINER_CMD=singularity
  else
    echo "Neither apptainer nor singularity found on this node" >&2
    exit 1
  fi
fi

# Clone repo with submodules (optionally skip any network with SKIP_GIT_FETCH=1)
if [ ! -d immortalwrt-firmware-builder/.git ]; then
  echo "Cloning repo (depth=${GIT_DEPTH}, ref=${GIT_REF})"
  git clone --recursive --depth "${GIT_DEPTH}" --branch "${GIT_REF}" https://github.com/coachpo/immortalwrt-firmware-builder.git immortalwrt-firmware-builder
else
  if [ "${SKIP_GIT_FETCH:-0}" != "1" ]; then
    echo "Updating existing repo (depth=${GIT_DEPTH}, ref=${GIT_REF})"
    cd immortalwrt-firmware-builder && \
    git fetch --depth "${GIT_DEPTH}" origin "${GIT_REF}" && \
    ( git checkout -B "${GIT_REF}" "origin/${GIT_REF}" || git checkout "${GIT_REF}" ) && \
    git submodule update --init --recursive
  else
    echo "SKIP_GIT_FETCH=1 set; using existing local repo without network fetch"
  fi
fi

# Resolve build configuration (.config)
if [ -n "$WRT_CONFIG" ]; then
  if [ ! -f "$WRT_CONFIG" ]; then
    echo "WRT_CONFIG not found: $WRT_CONFIG" >&2
    exit 1
  fi
  echo "Using custom config: $WRT_CONFIG"
  cp -f "$WRT_CONFIG" immortalwrt-firmware-builder/immortalwrt/.config
else
  SEED_PATH="immortalwrt-firmware-builder/${WRT_SEED}/seed.config"
  if [ ! -f "$SEED_PATH" ]; then
    echo "Seed config not found: $SEED_PATH (set WRT_SEED or WRT_CONFIG)" >&2
    exit 1
  fi
  echo "Using seed profile: ${WRT_SEED} -> $SEED_PATH"
  cp -f "$SEED_PATH" immortalwrt-firmware-builder/immortalwrt/.config
fi

"$CONTAINER_CMD" exec --env LANG=C.UTF-8,LC_ALL=C.UTF-8,LANGUAGE=en_US:en,BUILD_THREADS=${BUILD_THREADS} ./immortalwrt-build-env-ubuntu2204.sif bash -lc '
  set -euo pipefail
  cd immortalwrt-firmware-builder/immortalwrt
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  make defconfig
  make -j${BUILD_THREADS}
'
