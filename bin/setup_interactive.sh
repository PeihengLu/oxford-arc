#!/usr/bin/env bash
# One-time / occasional setup on Oxford ARC (run on an *interactive* HTC node).
#
#   ssh YOU@htc-login.arc.ox.ac.uk
#   srun -p interactive --gres=gpu:1 --cpus-per-task=4 --mem=16G --time=02:00:00 --pty bash
#   export REPO_ROOT=$DATA/my-project
#   bash /path/to/oxford-arc/bin/setup_interactive.sh
#
# Loads Anaconda via ARC modules and creates a $DATA env prefix.
# Project-specific install steps live in profiles/<name>/setup_hooks.sh
# (set ARC_PROFILE in env.sh).

set -euo pipefail

ARC_TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ARC_TOOLS}/lib/common.sh"
arc_source_env "${ARC_TOOLS}"
arc_resolve_roots || exit 1

ARC_MODULES="${ARC_MODULES:-Anaconda3}"
CONDA_ENV="${CONDA_ENV:-${DATA:+$DATA/envs/default}}"
: "${CONDA_ENV:?Set CONDA_ENV to a prefix under \$DATA (e.g. \$DATA/envs/my-project)}"

echo "REPO_ROOT=${REPO_ROOT}"
echo "ARC_TOOLS=${ARC_TOOLS}"
echo "ARC_MODULES=${ARC_MODULES}"
echo "CONDA_ENV=${CONDA_ENV}"
echo "ARC_PROFILE=${ARC_PROFILE:-none}"

if ! _arc_looks_like_repo "${REPO_ROOT}"; then
    echo "Error: REPO_ROOT does not look like a project checkout: ${REPO_ROOT}" >&2
    exit 1
fi

if ! command -v module >/dev/null 2>&1; then
    if [[ -f /etc/profile.d/modules.sh ]]; then
        # shellcheck disable=SC1091
        source /etc/profile.d/modules.sh
    elif [[ -f /usr/share/Modules/init/bash ]]; then
        # shellcheck disable=SC1091
        source /usr/share/Modules/init/bash
    fi
fi
if ! command -v module >/dev/null 2>&1; then
    echo "Error: environment modules not available on this node." >&2
    exit 1
fi

echo "Loading modules: ${ARC_MODULES}"
# shellcheck disable=SC2086
module load ${ARC_MODULES}

if ! command -v conda >/dev/null 2>&1; then
    echo "Error: conda not on PATH after module load." >&2
    echo "  Try: module spider Anaconda   # or Mamba" >&2
    echo "  Then set ARC_MODULES in env.sh to the exact module name." >&2
    exit 1
fi

if [[ -f "$(conda info --base)/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1091
    source "$(conda info --base)/etc/profile.d/conda.sh"
fi

ENV_FILE="${REPO_ROOT}/environment.yml"
PYTHON_PIN="${PYTHON_PIN:-python=3.11.*}"

if [[ ! -x "${CONDA_ENV}/bin/python" ]]; then
    echo "Creating conda env prefix ${CONDA_ENV} (${PYTHON_PIN})…"
    mkdir -p "$(dirname "${CONDA_ENV}")"
    if [[ -f "${ENV_FILE}" ]]; then
        conda env create --prefix "${CONDA_ENV}" -f "${ENV_FILE}"
    else
        conda create -y --prefix "${CONDA_ENV}" "${PYTHON_PIN}" pip
    fi
fi

conda activate "${CONDA_ENV}" 2>/dev/null || source activate "${CONDA_ENV}"

HOOK="${ARC_TOOLS}/profiles/${ARC_PROFILE:-}/setup_hooks.sh"
if [[ -n "${ARC_PROFILE:-}" && -f "${HOOK}" ]]; then
    echo "Running profile setup hooks: ${ARC_PROFILE}"
    # shellcheck source=/dev/null
    source "${HOOK}"
    if declare -F arc_profile_setup >/dev/null 2>&1; then
        arc_profile_setup
    fi
else
    echo "No ARC_PROFILE hooks — basic conda env is ready."
    echo "Install your project deps, then verify GPU access."
fi

echo ""
echo "Ready. Submit from htc-login (with env.sh configured):"
echo "  ${ARC_TOOLS}/bin/submit.sh path/to/stage.sh"
