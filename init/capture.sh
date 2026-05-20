#!/usr/bin/env bash
# Runs on: host (repo root)
# Invoked by: just capture
set -euo pipefail

docker compose --progress quiet run --rm --no-deps --entrypoint bash tapirxl /demo-init/tapirxl-pretty-ingest.sh