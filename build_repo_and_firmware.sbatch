#!/bin/bash
#SBATCH -J iwrt-repo
#SBATCH -N 1
#SBATCH -c 80
#SBATCH --mem=192000
#SBATCH --exclusive
#SBATCH -t 12:00:00
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

set -euo pipefail

# Ensure we operate relative to the directory where the job was submitted
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

mkdir -p logs

# Config: which git ref (branch/tag) to use; shallow clone depth for compiling only
GIT_REF="${GIT_REF:-main}"
GIT_DEPTH="${GIT_DEPTH:-1}"
OWRT_SEED="${OWRT_SEED:-cr6606}"            # e.g. cr6606, tr3000 (profiles in the repo)
OWRT_CONFIG="${OWRT_CONFIG:-}"               # optional absolute/relative path to a custom .config

# Clone repo with submodules
if [ ! -d immortalwrt-firmware-builder/.git ]; then
  git clone --recursive --depth "${GIT_DEPTH}" --shallow-submodules --branch "${GIT_REF}" https://github.com/coachpo/immortalwrt-firmware-builder.git immortalwrt-firmware-builder
else
  cd immortalwrt-firmware-builder && \
  git fetch --depth "${GIT_DEPTH}" origin "${GIT_REF}" && \
  ( git checkout -B "${GIT_REF}" "origin/${GIT_REF}" || git checkout "${GIT_REF}" ) && \
  git submodule update --init --recursive
fi

# Resolve build configuration (.config)
if [ -n "$OWRT_CONFIG" ]; then
  if [ ! -f "$OWRT_CONFIG" ]; then
    echo "OWRT_CONFIG not found: $OWRT_CONFIG" >&2
    exit 1
  fi
  echo "Using custom config: $OWRT_CONFIG"
  cp -f "$OWRT_CONFIG" immortalwrt-firmware-builder/immortalwrt/.config
else
  SEED_PATH="immortalwrt-firmware-builder/${OWRT_SEED}/seed.config"
  if [ ! -f "$SEED_PATH" ]; then
    echo "Seed config not found: $SEED_PATH (set OWRT_SEED or OWRT_CONFIG)" >&2
    exit 1
  fi
  echo "Using seed profile: ${OWRT_SEED} -> $SEED_PATH"
  cp -f "$SEED_PATH" immortalwrt-firmware-builder/immortalwrt/.config
fi

apptainer exec ./wrtforge-build.sif bash -lc '
  set -euo pipefail
  cd immortalwrt-firmware-builder/immortalwrt
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  make defconfig
  make -j${SLURM_CPUS_PER_TASK:-$(nproc)}
'
