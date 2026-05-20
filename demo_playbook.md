# PATCH VMP Demo Playbook

| | |
|---|---|
| **Platform** | PATCH Vulnerability Mitigation Platform (VMP) — TA1 |
| **Stack** | TapirXL → BlueFlow → Viper |
| **Phase 1** | Engineering smoke: mounted PCAP → BlueFlow upsert (one-shot) |
| **Phase 2** | Audience demo: live replay → VMP pipeline → Viper UI (automatic) |

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

# Place the demo PCAP
ls pcap/synthetic_philips_demo.pcap   # must exist before running smoke
```

---

## Phase 1 — PCAP smoke (engineering / QA)

**What it proves:** mounted PCAP → VMP parser (TapirXL) → Vector → BlueFlow upsert.
Viper is running but not exercised. No live capture, no replay sidecar.

```bash
# 1. Boot persistent stack and run one-shot PCAP ingest
just smoke

# The command above:
#   - starts blueflow-*, viper-*, inngest
#   - waits for all healthchecks
#   - runs `docker compose run --rm tapirxl` (exits when done)

# 2. Verify BlueFlow received the assets
curl -sS -H "Authorization: Token $BLUEFLOW_API_TOKEN" \
  http://localhost:8000/api/assets/ | jq '{count: .count, names: [.results[].display_name]}'
# expect: count = 8, names populated

# Re-run for idempotency check (expect 200 OK on all, not 201)
docker compose run --rm tapirxl
```

**Pass criteria:**
- First run: 8 × `201 Created`
- Re-run: 8 × `200 OK`
- All assets have `manufacturer`, `model`, `category`, `open_ports_tcp`, `external_keys.tapirxl_confidence` populated

---

## Phase 2 — Live demo (audience)

Phase 1 must pass before Phase 2. Run Phase 2 steps on the same running stack.

### Step 1 — Generate Viper API key

```bash
docker compose exec viper npm run db:create-test-api-key
# Copy the key printed to stdout

export VIPER_API_KEY=<key>
```

### Step 2 — Register BlueFlow ↔ Viper integration

```bash
just integration
```

This runs `init/register-viper.sh`, which:
- **Step A:** POSTs to Viper tRPC (`integrations.create`) — registers BlueFlow as an integration source; captures `VIPER_INTEGRATION_KEY` from the response
- **Step B:** POSTs to BlueFlow (`/api/viper/webhook/`) — registers Viper's callback URL using `VIPER_INTEGRATION_KEY` as the auth token

After this, every BlueFlow asset create/update enqueues a Celery task on `blueflow-worker` that POSTs to `http://viper:3000/api/v1/assets/integrationUpload`.

### Step 3 — Verify empty inventories

```bash
# BlueFlow: expect count = 0
curl -sS -H "Authorization: Token $BLUEFLOW_API_TOKEN" \
  http://localhost:8000/api/assets/ | jq .count

# Viper: open http://localhost:3000 in browser — no assets yet
```

### Step 4 — Start live replay

```bash
just demo-up

# Starts tapirxl (live mode, listening on eth0) + replay (tcpreplay in shared netns)

# Watch assets populate in real time
docker compose logs -f tapirxl blueflow-worker
```

### Step 5 — Show the audience

| URL | What to show |
|---|---|
| `http://localhost:8000/api/assets/` | BlueFlow assets populating as TapirXL classifies |
| `http://localhost:3000` | Viper mirroring BlueFlow automatically (no manual sync) |

---

## Teardown

```bash
# Full reset — wipes all named volumes
just fresh

# To re-run Phase 2 on same machine: start from Phase 1 step 1
```

---

## Quick reference

```bash
just smoke        # Phase 1: boot stack + one-shot PCAP ingest
just integration  # Phase 2 pre-flight: register BlueFlow ↔ Viper
just demo-up      # Phase 2: start live replay
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
| BlueFlow assets present; Viper stays empty | Integration not registered or `blueflow-worker` down | Re-run `just integration`; check `docker compose logs blueflow-worker` |
| Celery logs 4xx to Viper callback | Stale `VIPER_INTEGRATION_KEY` / wrong webhook URL | `just fresh && just smoke`, then redo Phase 2 steps |
| `VIPER_API_KEY` not found in `just integration` | Key not exported | Run `docker compose exec viper npm run db:create-test-api-key` and `export VIPER_API_KEY=<value>` |
| Replay starts before tapirxl is listening | Race on `service_started` dependency | Replay entrypoint sleeps 2 s by default; increase `REPLAY_RATE` to slow replay |
| Viper UI blank / 502 | Viper still initializing | Wait for `docker compose ps` to show `viper` as `(healthy)` |
