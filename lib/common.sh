#!/usr/bin/env bash
# Shared path helpers for oxford-arc. Sourced by bin/* and lib/*.
#
# ARC_TOOLS  — this toolkit checkout (directory containing bin/ and lib/)
# REPO_ROOT  — consumer project (pe-hub or another repo) whose jobs to run
#
# Resolution order for REPO_ROOT:
#   1. REPO_ROOT or PE_HUB_ROOT already in the environment / env.sh
#   2. Nested layout: <repo>/scripts/cluster/oxford-arc → parent repo
#   3. Fail with a clear error

_arc_tools_root() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # lib/common.sh → toolkit root
    cd "${here}/.." && pwd
}

_arc_looks_like_repo() {
    local root="$1"
    [[ -d "${root}/.git" || -f "${root}/README.md" || -f "${root}/pyproject.toml" || -f "${root}/environment.yml" ]]
}

# Populate ARC_TOOLS and REPO_ROOT (exported). Safe to source multiple times.
arc_resolve_roots() {
    if [[ -z "${ARC_TOOLS:-}" ]]; then
        export ARC_TOOLS="$(_arc_tools_root)"
    fi

    if [[ -z "${REPO_ROOT:-}" && -n "${PE_HUB_ROOT:-}" ]]; then
        export REPO_ROOT="${PE_HUB_ROOT}"
    fi

    if [[ -z "${REPO_ROOT:-}" ]]; then
        # Nested: .../scripts/cluster/oxford-arc
        local nested
        nested="$(cd "${ARC_TOOLS}/../../.." 2>/dev/null && pwd || true)"
        if [[ -n "${nested}" && "$(_arc_tools_root)" == "${ARC_TOOLS}" ]] \
            && [[ "$(basename "$(dirname "${ARC_TOOLS}")")" == "cluster" ]] \
            && [[ "$(basename "$(dirname "$(dirname "${ARC_TOOLS}")")")" == "scripts" ]] \
            && _arc_looks_like_repo "${nested}"; then
            export REPO_ROOT="${nested}"
        fi
    fi

    if [[ -z "${REPO_ROOT:-}" ]]; then
        echo "Error: set REPO_ROOT in env.sh to your project checkout." >&2
        echo "  cp ${ARC_TOOLS}/env.sh.example ${ARC_TOOLS}/env.sh" >&2
        echo "  # then: export REPO_ROOT=\$DATA/my-project" >&2
        return 1
    fi

    # Keep PE_HUB_ROOT in sync for older pe-hub stage scripts.
    export PE_HUB_ROOT="${PE_HUB_ROOT:-${REPO_ROOT}}"
    return 0
}

arc_source_env() {
    local tools="${1:-${ARC_TOOLS:-}}"
    if [[ -z "${tools}" ]]; then
        tools="$(_arc_tools_root)"
        export ARC_TOOLS="${tools}"
    fi
    if [[ -f "${tools}/env.sh" ]]; then
        # shellcheck source=/dev/null
        source "${tools}/env.sh"
    elif [[ -f "${tools}/env.sh.example" ]]; then
        echo "Warning: ${tools}/env.sh missing — using env.sh.example defaults" >&2
        # shellcheck source=/dev/null
        source "${tools}/env.sh.example"
    fi
}

# Relative path of env.sh inside the consumer repo when nested; otherwise
# toolkit-local env.sh for standalone rsync of cluster config.
arc_env_relpath() {
    if [[ -n "${REPO_ROOT:-}" && "${ARC_TOOLS}" == "${REPO_ROOT}/scripts/cluster/oxford-arc" ]]; then
        echo "scripts/cluster/oxford-arc/env.sh"
    else
        # Standalone: sync toolkit env.sh via absolute ARC_REMOTE layout
        # encoded as a sentinel path under the toolkit when REPO_ROOT sync runs.
        echo ".oxford-arc-env.sh"
    fi
}
