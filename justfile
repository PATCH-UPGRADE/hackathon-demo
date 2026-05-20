# TapirXL / BlueFlow / Viper demo stack
# See demo_playbook.md for the full runbook.
#
# Prerequisites: docker, just, curl, jq
# First run:  cp .env.example .env  (fill in BLUEFLOW_API_TOKEN)

set dotenv-load := true

# ── Phase 1: PCAP smoke ───────────────────────────────────────────────────────

# Boot persistent stack + run one-shot PCAP ingest
capture:
    docker compose up -d blueflow-psql blueflow-redis blueflow blueflow-worker viper-psql viper inngest
    docker compose exec blueflow bash /demo-init/seed-blueflow.sh
    docker compose run --rm tapirxl
    @echo ""
    @echo "==> Smoke complete. Verify asset count:"
    @echo "    curl -sS -H 'Authorization: Token ${BLUEFLOW_API_TOKEN}' http://localhost:8000/api/assets/ | jq .count"

# Print TapirXL InventoryRecord JSONL pretty-printed (no BlueFlow upload)
parse:
    docker compose run --rm --no-deps --entrypoint tapirxl tapirxl \
      parse /pcap/synthetic_philips_demo.pcap --json 2>/dev/null \
      | grep '^{' | jq .

# Phase 1 ingest + pretty-print JSONL only (no Vector log noise) while uploading
capture-verbose:
    #!/usr/bin/env bash
    set -euo pipefail
    docker compose up -d blueflow-psql blueflow-redis blueflow blueflow-worker viper-psql viper inngest
    docker compose exec blueflow bash /demo-init/seed-blueflow.sh
    docker compose run --rm --entrypoint bash tapirxl /demo-init/tapirxl-pretty-ingest.sh
    echo ""
    echo "==> Capture complete. Verify asset count:"
    echo "    just check"

# ── Phase 2: integration + live demo ─────────────────────────────────────────

# Register BlueFlow ↔ Viper integration (requires VIPER_API_KEY in shell)
# Before running: docker compose exec viper npm run db:create-test-api-key
#                 export VIPER_API_KEY=<value>
integrate:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "${VIPER_API_KEY:-}" ]; then
      echo "ERROR: VIPER_API_KEY is not set." >&2
      echo "Run:  docker compose exec viper npm run db:create-test-api-key" >&2
      echo "Then: export VIPER_API_KEY=<value>" >&2
      exit 1
    fi
    # Workaround: TapirXL ingest leaves Asset.last_pinged=NULL, but BlueFlow's
    # Viper webhook filters with `last_pinged__gte=since` (blueflow/models/viper.py
    # ViperWebhookResponseList.from_request), which excludes NULL rows — the
    # task then completes in ~10ms with zero items POSTed to Viper.
    # Backfill before sync. Remove once TapirXL (or BlueFlow's upsert) stamps
    # last_pinged on insert. See PLAYBOOK §Failure modes (U3).
    echo "==> Backfilling Asset.last_pinged for Viper sync..."
    docker compose exec -T blueflow uv run python project/manage.py shell -c "
    from django.utils import timezone
    from blueflow.models import Asset
    n = Asset.objects.filter(last_pinged__isnull=True).update(last_pinged=timezone.now())
    print(f'Backfilled last_pinged on {n} assets')
    "
    bash init/register-viper.sh

# Start live replay + tapirxl listener (Phase 2)
demo:
    TAPIRXL_MODE=live docker compose --profile live up -d tapirxl replay
    @echo ""
    @echo "==> Live demo running. Watch logs:"
    @echo "    docker compose logs -f tapirxl blueflow-worker"

# ── Teardown ──────────────────────────────────────────────────────────────────

# Tear down all services and wipe named volumes (full reset)
fresh:
    docker compose --profile live down --volumes

# ── Utilities ─────────────────────────────────────────────────────────────────

# Show asset counts + names from BlueFlow and Viper (VIPER_API_KEY for Viper)
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> BlueFlow (http://localhost:8000/api/assets/)"
    curl -sS -H "Authorization: Token ${BLUEFLOW_API_TOKEN}" \
      http://localhost:8000/api/assets/ \
      | jq '{count: .count, names: [.results[].display_name]}'
    echo ""
    if [ -z "${VIPER_API_KEY:-}" ]; then
      echo "==> Viper: skipped (VIPER_API_KEY not set)"
      echo "    docker compose exec viper npm run db:create-test-api-key"
      echo "    export VIPER_API_KEY=<value>"
      exit 0
    fi
    echo "==> Viper (http://localhost:3000/api/v1/assets)"
    viper_body=$(curl -sS -H "Authorization: Bearer ${VIPER_API_KEY}" \
      "http://localhost:3000/api/v1/assets?pageSize=100")
    if echo "${viper_body}" | jq -e '.code' >/dev/null 2>&1; then
      echo "ERROR: Viper API: $(echo "${viper_body}" | jq -r '.message')" >&2
      echo "Regenerate key: docker compose exec viper npm run db:create-test-api-key" >&2
      exit 1
    fi
    echo "${viper_body}" | jq '{count: (.totalCount // 0), names: [(.items // [])[] | (.hostname // .ip // .macAddress)]}'

# Tail tapirxl + blueflow-worker logs
logs:
    docker compose logs -f tapirxl blueflow-worker

# Show service health status
ps:
    docker compose ps
