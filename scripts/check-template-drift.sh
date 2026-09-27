#!/usr/bin/env bash
# Thin wrapper so the drift checker sits beside the other fleet scripts.
# See check-template-drift.mjs for usage.
set -euo pipefail
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-template-drift.mjs" "$@"
