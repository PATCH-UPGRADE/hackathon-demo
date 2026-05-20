#!/usr/bin/env bash
# Runs on: host (repo root)
# Invoked by: just parse
set -euo pipefail

docker compose run --rm --no-deps --entrypoint tapirxl tapirxl \
  parse /pcap/synthetic_philips_demo.pcap --json 2>/dev/null \
  | grep '^{' | jq .