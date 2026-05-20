# PATCH VMP Demo

ARPA-H Hackathon demo of the **PATCH Vulnerability Mitigation Platform (VMP)** — a TA1 clinical-device intelligence and asset-management stack composed of TapirXL, BlueFlow, and Viper.

**Pipeline:** TapirXL → (Vector HTTP) → BlueFlow → (Celery webhook) → Viper

| Phase | Mode | What it proves |
|---|---|---|
| **1 — smoke** | Mounted PCAP, one-shot | VMP parse → ship → store, end to end |
| **2 — live** | tcpreplay on shared netns | Real-time VMP classify → BlueFlow → Viper (no manual sync) |

---

## Stack

| Service | Image | Role |
|---|---|---|
| `tapirxl` | `virtalabsinc/tapirxl:demo-<ver>` | Packet parser + Vector shipper |
| `blueflow` | `virtalabsinc/blueflow:demo-<ver>` | Django REST API; asset store |
| `blueflow-worker` | same image | Celery worker; pushes to Viper |
| `blueflow-psql` | `postgres:16-alpine` | BlueFlow DB |
| `blueflow-redis` | `redis:7-alpine` | Celery broker |
| `viper` | built from source | Next.js UI; mirrors BlueFlow |
| `viper-psql` | `postgres:17-alpine` | Viper DB |
| `inngest` | built from source | Background job server for Viper |
| `replay` | built here | Alpine + tcpreplay; Phase 2 only (`live` profile) |

**Requires:** `docker` ≥ 24 (Compose v2), `just`, `curl`, `jq`

---

## Directory structure

```
├── compose.yaml               # Canonical VMP stack definition
├── .env.example               # Copy to .env; set BLUEFLOW_API_TOKEN
├── justfile                   # Runbook targets
├── demo_playbook.md           # Full step-by-step runbook
├── pcap/synthetic_philips_demo.pcap
├── replay/                    # tcpreplay sidecar image
└── init/register-viper.sh     # BlueFlow ↔ Viper webhook registration
```

---

## Usage

```bash
cp .env.example .env       # set BLUEFLOW_API_TOKEN

just smoke                 # Phase 1: boot VMP stack + one-shot PCAP ingest
just check                 # verify asset count (expect 8)

# Phase 2 pre-flight
docker compose exec viper npm run db:create-test-api-key
export VIPER_API_KEY=<key>
just integration

just demo-up               # Phase 2: live replay → BlueFlow → Viper
just fresh                 # teardown + wipe volumes
```

See [`demo_playbook.md`](demo_playbook.md) for the full runbook and failure modes.
