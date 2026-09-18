#!/usr/bin/env bash
# Submit a stage script to Oxford ARC HTC (GPU).
#
# Usage:
#   cp env.sh.example env.sh   # edit REPO_ROOT, ARC_PROJECT, CONDA_ENV
#   ./bin/submit.sh path/to/stage.sh
#   ./bin/submit.sh 01_tune_base_library1.sh   # resolved via ARC_STAGE_PATHS
#
# Smoke / overrides:
#   SMOKE=1 ./bin/submit.sh 01_tune_base_library1.sh
#   ARC_PARTITION=short ARC_TIME=01:00:00 ./bin/submit.sh myscript.sh
#
# Extra sbatch flags after -- :
#   ./bin/submit.sh myscript.sh -- --constraint='gpu_sku:A100'
#
# SLURM dependency:
#   ARC_DEPENDENCY=afterok:123456 ./bin/submit.sh train.sh
#
# Dry-run:
#   DRY_RUN=1 ./bin/submit.sh myscript.sh

set -euo pipefail

ARC_TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ARC_TOOLS
# shellcheck source=../lib/common.sh
source "${ARC_TOOLS}/lib/common.sh"

# Preserve caller SLURM/device overrides across env.sh.
_SAVE_ARC_KEYS=(
    ARC_CLUSTER ARC_PARTITION ARC_TIME ARC_GPUS ARC_GPU_CONSTRAINT
    ARC_CPUS ARC_MEM ARC_MAIL_USER DEVICE REPO_ROOT PE_HUB_ROOT ARC_PROFILE
)
for _k in "${_SAVE_ARC_KEYS[@]}"; do
    if [[ -n "${!_k+x}" ]]; then
        printf -v "_SAVE_${_k}" '%s' "${!_k}"
    else
        unset "_SAVE_${_k}" 2>/dev/null || true
    fi
done

arc_source_env "${ARC_TOOLS}"

for _k in "${_SAVE_ARC_KEYS[@]}"; do
    _sk="_SAVE_${_k}"
    if [[ -n "${!_sk+x}" ]]; then
        export "${_k}=${!_sk}"
    fi
done
unset _k _sk _SAVE_ARC_KEYS
for _k in ARC_CLUSTER ARC_PARTITION ARC_TIME ARC_GPUS ARC_GPU_CONSTRAINT ARC_CPUS ARC_MEM ARC_MAIL_USER DEVICE REPO_ROOT PE_HUB_ROOT ARC_PROFILE; do
    unset "_SAVE_${_k}" 2>/dev/null || true
done
unset _k

arc_resolve_roots || exit 1

STAGE_SCRIPT="${1:?Usage: $0 <stage_script.sh> [-- extra sbatch args]}"
shift || true

EXTRA_SBATCH=()
if [[ "${1:-}" == "--" ]]; then
    shift
    EXTRA_SBATCH=("$@")
fi

STAGE_BASENAME="$(basename "${STAGE_SCRIPT}")"

# Optional matrix fan-out hook (pe-hub scratch-benchmark).
if [[ "${STAGE_BASENAME}" == 01_tune_matrix.sh || "${STAGE_BASENAME}" == 02_train_matrix.sh ]] \
    && [[ "${SUBMIT_MATRIX_AS_ONE:-0}" != "1" ]] \
    && [[ "${_ARC_MATRIX_CELL:-0}" != "1" ]] \
    && [[ -z "${INDEX:-}" ]]; then
    MATRIX_SUBMIT="${REPO_ROOT}/scripts/experiments/scratch-benchmark/submit_arc_matrix.sh"
    if [[ -x "${MATRIX_SUBMIT}" ]]; then
        echo "Matrix stage ${STAGE_BASENAME}: submitting one SLURM job per seed."
        exec "${MATRIX_SUBMIT}" "${STAGE_BASENAME}"
    fi
fi

SBATCH_SCRIPT="${ARC_TOOLS}/lib/run_stage.sbatch"
JOB_PREFIX="${ARC_JOB_PREFIX:-arc}"
JOB_NAME="${JOB_PREFIX}-$(basename "${STAGE_SCRIPT}" .sh | tr '_' '-' | cut -c1-40)"
if [[ -n "${MODEL:-}" && -n "${BENCHMARK:-}" ]]; then
    JOB_SUFFIX="$(echo "${MODEL}__${BENCHMARK}" | tr '[:upper:]' '[:lower:]' | tr '_/' '-' | tr -cd 'a-z0-9.-')"
    JOB_NAME="${JOB_PREFIX}-$(basename "${STAGE_SCRIPT}" .sh | tr '_' '-' | cut -c1-24)-${JOB_SUFFIX}"
    if [[ -n "${INDEX:-}" ]]; then
        JOB_NAME="${JOB_NAME}-s${INDEX}"
    fi
    JOB_NAME="${JOB_NAME:0:40}"
fi

if [[ "${SMOKE:-0}" == "1" && -z "${SMOKE_FULL_DATA:-}" ]]; then
    export SMOKE_FULL_DATA=1
fi

SBATCH_ARGS=(
    --job-name="${JOB_NAME}"
    --clusters="${ARC_CLUSTER}"
    --partition="${ARC_PARTITION}"
    --time="${ARC_TIME}"
    --cpus-per-task="${ARC_CPUS}"
    --mem="${ARC_MEM}"
    --gres="gpu:${ARC_GPUS}"
    --parsable
    --export=ALL,ARC_TOOLS="${ARC_TOOLS}",REPO_ROOT="${REPO_ROOT}",PE_HUB_ROOT="${PE_HUB_ROOT}",STAGE_SCRIPT="${STAGE_SCRIPT}",SMOKE="${SMOKE:-0}",SMOKE_FULL_DATA="${SMOKE_FULL_DATA:-0}",MODEL="${MODEL:-}",BENCHMARK="${BENCHMARK:-}",RUN_ID="${RUN_ID:-}",N_SEEDS="${N_SEEDS:-3}",N_TRIALS="${N_TRIALS:-10}",PROTOCOL="${PROTOCOL:-holdout_3}",INDEX="${INDEX:-}",SKIP_IF_DONE="${SKIP_IF_DONE:-0}",SKIP_IF_TUNED="${SKIP_IF_TUNED:-0}",PRETRAINED_WEIGHTS="${PRETRAINED_WEIGHTS:-}",CELL_LINE="${CELL_LINE:-}",FOLD="${FOLD:-}",FIXED_HP_JSON="${FIXED_HP_JSON:-}",ARC_PROFILE="${ARC_PROFILE:-}"
    --chdir="${REPO_ROOT}"
)

if [[ -n "${ARC_GPU_CONSTRAINT:-}" ]]; then
    SBATCH_ARGS+=(--constraint="${ARC_GPU_CONSTRAINT}")
fi
if [[ -n "${ARC_MAIL_USER:-}" ]]; then
    SBATCH_ARGS+=(--mail-type=END,FAIL --mail-user="${ARC_MAIL_USER}")
fi
if [[ -n "${ARC_DEPENDENCY:-}" ]]; then
    SBATCH_ARGS+=(--dependency="${ARC_DEPENDENCY}")
fi

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "+ sbatch --test-only ${SBATCH_ARGS[*]} ${EXTRA_SBATCH[*]} ${SBATCH_SCRIPT}"
    sbatch --test-only "${SBATCH_ARGS[@]}" "${EXTRA_SBATCH[@]}" "${SBATCH_SCRIPT}"
    exit 0
fi

echo "Submitting ${STAGE_SCRIPT}"
echo "  cluster=${ARC_CLUSTER} partition=${ARC_PARTITION} time=${ARC_TIME} gpus=${ARC_GPUS}"
echo "  REPO_ROOT=${REPO_ROOT} DEVICE=${DEVICE} SMOKE=${SMOKE:-0}"
if [[ -n "${ARC_DEPENDENCY:-}" ]]; then
    echo "  dependency=${ARC_DEPENDENCY}"
fi
_SBATCH_OUT="$(sbatch "${SBATCH_ARGS[@]}" "${EXTRA_SBATCH[@]}" "${SBATCH_SCRIPT}")"
SUBMIT_JOB_ID="${_SBATCH_OUT%%;*}"
export SUBMIT_JOB_ID
echo "Submitted batch job ${SUBMIT_JOB_ID}${_SBATCH_OUT#${SUBMIT_JOB_ID}}"
echo "${SUBMIT_JOB_ID}"
