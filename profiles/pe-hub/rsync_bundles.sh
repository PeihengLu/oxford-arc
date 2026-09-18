#!/usr/bin/env bash
# Named rsync path bundles for pe-hub (sourced by lib/_rsync.sh).

arc_rsync_is_bundle() {
    case "$1" in
        pridict2-repro|pridict2_repro|pridict2-reproduction) return 0 ;;
        *) return 1 ;;
    esac
}

arc_rsync_expand_bundle() {
    local name="$1"
    local manifest="${REPO_ROOT}/scripts/experiments/pridict2-reproduction/supplementary_artifacts.txt"
    case "${name}" in
        pridict2-repro|pridict2_repro|pridict2-reproduction)
            if [[ ! -f "${manifest}" ]]; then
                echo "Error: missing ${manifest}" >&2
                return 1
            fi
            local line
            while IFS= read -r line || [[ -n "${line}" ]]; do
                [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
                echo "${line%%[[:space:]]*}"
            done < "${manifest}"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
