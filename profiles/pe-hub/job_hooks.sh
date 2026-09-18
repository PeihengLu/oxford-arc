#!/usr/bin/env bash
# pe-hub profile: checks run inside each SLURM job after conda activate.

arc_profile_job_ready() {
    if ! "${PYTHON}" -c "import pe_common" 2>/dev/null; then
        echo "Error: ${PYTHON} cannot import pe_common." >&2
        echo "  On an interactive node: cd \$REPO_ROOT && ./scripts/install-clis.sh" >&2
        exit 1
    fi
    if ! command -v peen >/dev/null 2>&1; then
        echo "Error: peen not on PATH. On an interactive node: cd \$REPO_ROOT && ./scripts/install-clis.sh" >&2
        exit 1
    fi
    peen devices || true
}
