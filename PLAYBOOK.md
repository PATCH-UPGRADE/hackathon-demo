# PATCH VMP Demo Playbook

| | |
|---|---|
| **Platform** | PATCH Vulnerability Mitigation Platform (VMP) — TA1 |
| **Stack** | TapirXL → BlueFlow → Viper |
| **Phase 1** | Engineering smoke: mounted PCAP → BlueFlow upsert (one-shot) |
| **Phase 2** | Audience demo: Viper asset sync via Inngest (live replay requires `tapirxl:demo-0.3.1`) |

---

## Prerequisites

```bash
# Tools
docker --version   # ≥ 24, Compose v2 plugin required
just --version
curl --version
jq --version

# First-time setup
cp .env.example .env
# Edit .env — set BLUEFLOW_API_TOKEN to a value of your choice.
# The same token is used by both BlueFlow and TapirXL; do not use two values.
```

---

## Phase 1 — PCAP smoke (engineering / QA)

**What it proves:** mounted PCAP → TapirXL → Vector → BlueFlow upsert.
Viper is running but not exercised.

```bash
# Boot stack, seed BlueFlow, run one-shot PCAP ingest
just smoke

# Verify
just check
# expect: count = 8, all assets named
```

**Pass criteria:**
- First run: 8 × `201 Created`
- Re-run: 8 × `200 OK` (idempotent)
- All assets have `manufacturer`, `model`, `category`, `open_ports_tcp`, `external_keys.tapirxl_confidence` populated

---

## Phase 2 — Viper integration (audience demo)

Phase 1 must pass first. Run on the same running stack.

### Step 1 — Generate Viper API key

```bash
docker compose exec viper npm run db:create-test-api-key
export VIPER_API_KEY=<key printed above>
```

### Step 2 — Register integration and trigger sync

```bash
just integration
```

`init/register-viper.sh` does two things:
- **Step A:** `integrations.create` (tRPC) — registers BlueFlow as a PARTNER integration in Viper with `integrationUri = http://blueflow:8000/api/viper/webhook/`
- **Step B:** `integrations.triggerSync` (tRPC) — fires an immediate Inngest sync event

**Sync flow (automatic after Step B):**
1. Viper Inngest generates a one-time callback token
2. POSTs `{callback, since, max_pages, page_size}` to BlueFlow's `/api/viper/webhook/`
3. BlueFlow executes the Celery task synchronously (`CELERY_TASK_ALWAYS_EAGER=True` in dev settings)
4. BlueFlow POSTs paginated assets to `http://viper:3000/api/v1/assets/integrationUpload/{token}`

The `blueflow-worker` container is not required in this configuration.

### Step 3 — Verify assets in Viper

```bash
# BlueFlow
just check

# Viper
open http://localhost:3000
```

Both should show the same 8 assets. Viper re-syncs automatically every 5 minutes via Inngest cron.

### Step 4 — Live replay (requires `tapirxl:demo-0.3.1`)

> **Not yet available.** Live capture support ships in `tapirxl:demo-0.3.1`.
> Until then, re-run `docker compose run --rm tapirxl` to replay the PCAP.

```bash
# When 0.3.1 is released:
just demo-up
docker compose logs -f tapirxl
```

---

## Teardown

```bash
just fresh   # wipes all named volumes; start from Phase 1 on next run
```

---

## Quick reference

```bash
just smoke        # Phase 1: boot stack + one-shot PCAP ingest
just integration  # Phase 2: register BlueFlow ↔ Viper + trigger sync
just demo-up      # Phase 2: start live replay (tapirxl:demo-0.3.1+)
just fresh        # Tear down + wipe volumes
just check        # Print asset count + names from BlueFlow
just logs         # Tail tapirxl + blueflow-worker
just ps           # Show service health
```

---

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `tapirxl` exits `401` | `BLUEFLOW_API_TOKEN` mismatch | Both services read the same `.env` value — verify |
| `tapirxl` exits `415` | Stale image missing `Content-Type` header | `docker compose pull tapirxl` |
| Vector logs `failed to lookup address: blueflow` | Network split | `docker network inspect tapirxl-demo_clinical_demo` — both must be members |
| BlueFlow assets present; Viper stays empty | Integration not registered or sync not triggered | Re-run `just integration` |
| `just integration` fails Step A with `400` | `VIPER_API_KEY` stale or DB reset | Re-generate: `docker compose exec viper npm run db:create-test-api-key` |
| `just integration` fails to extract integration ID | Viper returned an error | Check Step A response printed above the error |
| Viper UI blank / 502 | Viper still initializing | Wait for `docker compose ps` to show `viper` as `(healthy)` |
| Assets disappear after `just fresh` | Expected — volumes wiped | Start from Phase 1 |
