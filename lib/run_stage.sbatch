#!/usr/bin/env bash
# Oxford ARC (htc) SLURM job: run a stage script under REPO_ROOT.
#
# Prefer bin/submit.sh (sets paths + SBATCH overrides). Direct use:
#   sbatch --export=ALL,REPO_ROOT=...,STAGE_SCRIPT=path/to/stage.sh \
#     lib/run_stage.sbatch

#SBATCH --job-name=arc-job
#SBATCH --clusters=htc
#SBATCH --partition=short
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gres=gpu:1
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.out

set -euo pipefail

# Slurm copies this script to /var/spool/slurmd/... — do not resolve paths via BASH_SOURCE alone.
_ARC_TOOLS_CANDIDATE=""
if [[ -n "${ARC_TOOLS:-}" && -f "${ARC_TOOLS}/lib/job_env.sh" ]]; then
    :
elif [[ -n "${SLURM_SUBMIT_DIR:-}" && -f "${SLURM_SUBMIT_DIR}/lib/job_env.sh" ]]; then
    ARC_TOOLS="${SLURM_SUBMIT_DIR}"
elif [[ -n "${REPO_ROOT:-}" && -f "${REPO_ROOT}/scripts/cluster/oxford-arc/lib/job_env.sh" ]]; then
    ARC_TOOLS="${REPO_ROOT}/scripts/cluster/oxford-arc"
elif [[ -n "${PE_HUB_ROOT:-}" && -f "${PE_HUB_ROOT}/scripts/cluster/oxford-arc/lib/job_env.sh" ]]; then
    ARC_TOOLS="${PE_HUB_ROOT}/scripts/cluster/oxford-arc"
    REPO_ROOT="${REPO_ROOT:-${PE_HUB_ROOT}}"
else
    _ARC_TOOLS_CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [[ -f "${_ARC_TOOLS_CANDIDATE}/lib/job_env.sh" ]]; then
        ARC_TOOLS="${_ARC_TOOLS_CANDIDATE}"
    fi
fi
: "${ARC_TOOLS:?Set ARC_TOOLS to the oxford-arc toolkit checkout}"
export ARC_TOOLS

if [[ -f "${ARC_TOOLS}/env.sh" ]]; then
    # shellcheck source=/dev/null
    source "${ARC_TOOLS}/env.sh"
fi
# shellcheck source=./job_env.sh
source "${ARC_TOOLS}/lib/job_env.sh"

STAGE_SCRIPT="${STAGE_SCRIPT:?Set STAGE_SCRIPT (path to an executable stage script)}"

if [[ "${STAGE_SCRIPT}" != /* ]]; then
    _resolved=""
    # Profile / project search paths (colon-separated), then REPO_ROOT-relative.
    _search="${ARC_STAGE_PATHS:-scripts/experiments/scratch-benchmark:scripts/experiments/pridict2-reproduction}"
    IFS=':' read -ra _dirs <<< "${_search}"
    for _rel in "${_dirs[@]}"; do
        if [[ -f "${REPO_ROOT}/${_rel}/${STAGE_SCRIPT}" ]]; then
            _resolved="${REPO_ROOT}/${_rel}/${STAGE_SCRIPT}"
            break
        fi
    done
    if [[ -n "${_resolved}" ]]; then
        STAGE_SCRIPT="${_resolved}"
    elif [[ -x "${REPO_ROOT}/${STAGE_SCRIPT}" || -f "${REPO_ROOT}/${STAGE_SCRIPT}" ]]; then
        STAGE_SCRIPT="${REPO_ROOT}/${STAGE_SCRIPT}"
    fi
    unset _resolved _rel _dirs _search
fi

if [[ ! -x "${STAGE_SCRIPT}" && ! -f "${STAGE_SCRIPT}" ]]; then
    echo "Error: STAGE_SCRIPT not found: ${STAGE_SCRIPT}" >&2
    exit 1
fi

chmod +x "${STAGE_SCRIPT}" 2>/dev/null || true

echo "+ ${STAGE_SCRIPT}"
# shellcheck disable=SC2086
exec bash "${STAGE_SCRIPT}" ${STAGE_EXTRA_ARGS:-}
