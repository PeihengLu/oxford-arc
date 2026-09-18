#!/usr/bin/env bash
# Pull DVC-tracked folders and gitignored env.sh from ARC onto this laptop.
# Run locally (VPN → htc-login, or ProxyJump via gateway off-net).
#
# Usage:
#   ./bin/pull.sh
#   ./bin/pull.sh YOUR_ARC_USER
#   DRY_RUN=1 ./bin/pull.sh
#   ONLY=env ./bin/pull.sh YOUR_ARC_USER
#   SKIP=datasets/reference ./bin/pull.sh YOUR_ARC_USER

set -euo pipefail

ARC_TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/_rsync.sh
source "${ARC_TOOLS}/lib/_rsync.sh"
arc_rsync_main pull "$@"
