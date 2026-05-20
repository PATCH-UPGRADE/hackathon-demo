#!/usr/bin/env bash
# One-shot PCAP ingest with pretty-printed InventoryRecord JSONL on stderr only.
# Vector logs and tapirxl progress are suppressed; BlueFlow upload still runs.
# Invoked by: just capture-verbose

set -euo pipefail

: "${TAPIRXL_PCAP_PATH:?TAPIRXL_PCAP_PATH is required}"
: "${BLUEFLOW_URL:?BLUEFLOW_URL is required}"
: "${BLUEFLOW_TOKEN:?BLUEFLOW_TOKEN is required}"

tapirxl parse "$TAPIRXL_PCAP_PATH" --json 2>/dev/null \
  | while IFS= read -r line; do
      case "$line" in
        \{*)
          printf '%s\n' "$line" \
            | python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read()), indent=2), flush=True)' \
            >&2
          printf '%s\n' "$line"
          ;;
      esac
    done \
  | vector --config-toml /etc/vector/upload-vector.pcap.toml >/dev/null 2>&1
