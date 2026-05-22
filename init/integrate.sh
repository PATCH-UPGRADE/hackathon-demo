#!/usr/bin/env bash
# Runs on: host (repo root)
# Invoked by: just integrate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONLY_BACKFILL=0

for arg in "$@"; do
  case "$arg" in
    --only-backfill) ONLY_BACKFILL=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [ -z "${VIPER_API_KEY:-}" ]; then
  echo "ERROR: VIPER_API_KEY is not set." >&2
  echo "Run:  docker compose exec viper npm run db:create-test-api-key" >&2
  echo "Then: export VIPER_API_KEY=<key printed above>" >&2
  exit 1
fi

bash "${SCRIPT_DIR}/backfill-last-pinged.sh"

if [ "$ONLY_BACKFILL" -eq 0 ]; then
  bash "${SCRIPT_DIR}/register-viper.sh"
fi
