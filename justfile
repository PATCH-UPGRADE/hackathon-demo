# TapirXL / BlueFlow / Viper demo stack
# See PLAYBOOK.md for the full runbook.
#
# Prerequisites: docker, just, curl, jq
# First run:  cp .env.example .env  (fill in BLUEFLOW_API_TOKEN)

set dotenv-load := true

# ── Phase 1: PCAP smoke ───────────────────────────────────────────────────────

# Print TapirXL InventoryRecord JSONL pretty-printed (no BlueFlow upload)
parse:
    bash init/parse.sh

# Boot stack + seed BlueFlow
boot:
    docker compose up -d blueflow-psql blueflow-redis blueflow blueflow-worker viper-psql viper inngest
    docker compose exec blueflow bash /demo-init/seed-blueflow.sh

# Run one-shot PCAP ingest
capture:
    bash init/capture.sh

# ── Phase 2: integration + live demo ─────────────────────────────────────────

# Register BlueFlow ↔ Viper integration (requires VIPER_API_KEY; see PLAYBOOK Step 1)
integrate:
    bash init/integrate.sh

# Start live replay + tapirxl listener (Phase 2)
demo:
    TAPIRXL_MODE=live docker compose --profile live up -d tapirxl replay
    @echo ""
    @echo "==> Live demo running. Watch logs:"
    @echo "    just logs"

# ── Teardown ──────────────────────────────────────────────────────────────────

# Tear down all services and wipe named volumes (full reset)
fresh:
    docker compose --profile live down --volumes

# ── Utilities ─────────────────────────────────────────────────────────────────

# Show asset counts + names from BlueFlow and Viper (VIPER_API_KEY for Viper)
check $SERVICE:
    bash init/check.sh $SERVICE

# Tail tapirxl + blueflow-worker logs
logs:
    docker compose logs -f tapirxl blueflow-worker

# Show service health status
ps:
    docker compose ps
