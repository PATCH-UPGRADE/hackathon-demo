#!/usr/bin/env bash
# Runs on: host (repo root)
# Invoked by: just parse
set -euo pipefail

: "${TAPIRXL_PCAP_PATH:=/pcap/ct_to_pacs_scenario.pcap}"

docker compose run --rm --no-deps --entrypoint tapirxl tapirxl \
  parse "${TAPIRXL_PCAP_PATH}" --json 2>/dev/null \
  | grep '^{' | jq .