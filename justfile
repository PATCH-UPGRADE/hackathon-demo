# TapirXL / BlueFlow / Viper demo stack
# See demo_playbook.md for the full runbook.
#
# Prerequisites: docker, just, curl, jq
# First run:  cp .env.example .env  (fill in BLUEFLOW_API_TOKEN)

set dotenv-load := true

# ── Phase 1: PCAP smoke ───────────────────────────────────────────────────────

# Boot persistent stack + run one-shot PCAP ingest
smoke:
    docker compose up -d blueflow-psql blueflow-redis blueflow blueflow-worker viper-psql viper inngest
    docker compose exec blueflow bash /demo-init/seed-blueflow.sh
    docker compose run --rm tapirxl
    @echo ""
    @echo "==> Smoke complete. Verify asset count:"
    @echo "    curl -sS -H 'Authorization: Token ${BLUEFLOW_API_TOKEN}' http://localhost:8000/api/assets/ | jq .count"

# ── Phase 2: integration + live demo ─────────────────────────────────────────

# Register BlueFlow ↔ Viper integration (requires VIPER_API_KEY in shell)
# Before running: docker compose exec viper npm run db:create-test-api-key
#                 export VIPER_API_KEY=<value>
integration:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "${VIPER_API_KEY:-}" ]; then
      echo "ERROR: VIPER_API_KEY is not set." >&2
      echo "Run:  docker compose exec viper npm run db:create-test-api-key" >&2
      echo "Then: export VIPER_API_KEY=<value>" >&2
      exit 1
    fi
    bash init/register-viper.sh

# Start live replay + tapirxl listener (Phase 2)
demo-up:
    TAPIRXL_MODE=live docker compose --profile live up -d tapirxl replay
    @echo ""
    @echo "==> Live demo running. Watch logs:"
    @echo "    docker compose logs -f tapirxl blueflow-worker"

# ── Teardown ──────────────────────────────────────────────────────────────────

# Tear down all services and wipe named volumes (full reset)
fresh:
    docker compose --profile live down --volumes

# ── Utilities ─────────────────────────────────────────────────────────────────

# Show asset count + display names from BlueFlow
check:
    curl -sS -H "Authorization: Token ${BLUEFLOW_API_TOKEN}" \
      http://localhost:8000/api/assets/ | jq '{count: .count, names: [.results[].display_name]}'

# Tail tapirxl + blueflow-worker logs
logs:
    docker compose logs -f tapirxl blueflow-worker

# Show service health status
ps:
    docker compose ps
