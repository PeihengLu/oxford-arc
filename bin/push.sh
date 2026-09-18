#!/usr/bin/env bash
# Push DVC-tracked folders and gitignored env.sh from this laptop to ARC.
# Run locally (VPN → htc-login, or ProxyJump via gateway off-net).
#
# Usage:
#   ./bin/push.sh
#   ./bin/push.sh YOUR_ARC_USER
#   DRY_RUN=1 ./bin/push.sh
#   ONLY=results,slurm_output ./bin/push.sh YOUR_ARC_USER

set -euo pipefail

ARC_TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/_rsync.sh
source "${ARC_TOOLS}/lib/_rsync.sh"
arc_rsync_main push "$@"
