#!/usr/bin/env bash
# Pull gitignored env.sh from ARC onto this laptop.
# For DVC-tracked folders as well, use bin/pull.sh.

set -euo pipefail

ARC_TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ONLY="${ONLY:-env}" exec "${ARC_TOOLS}/bin/pull.sh" "$@"
