# Demo init scripts

Scripts under `init/` fall into two groups. Host scripts are invoked by `just` from the repo root. Container scripts are bind-mounted at `/demo-init` and run inside BlueFlow or TapirXL containers.

## Host (runs on machine with Docker)

| Script | `just` recipe | Role |
|--------|---------------|------|
| `parse.sh` | `parse` | PCAP → JSON only (no BlueFlow upload) |
| `capture.sh` | `capture` | Boot stack, seed BlueFlow, one-shot ingest |
| `integrate.sh` | `integrate` | U3 backfill + `register-viper.sh` |
| `backfill-last-pinged.sh` | _(via integrate)_ | Stamp `Asset.last_pinged` before Viper sync |
| `register-viper.sh` | _(via integrate)_ | BlueFlow ↔ Viper §5.3 ceremony |
| `check.sh` | `check` | Asset counts from BlueFlow and Viper APIs |

## Container (runs inside compose services)

| Script | Invoked from | Role |
|--------|--------------|------|
| `seed-blueflow.sh` | `capture` → `docker compose exec blueflow` | Admin user + API token from env |
| `tapirxl-pretty-ingest.sh` | `capture` → `docker compose run tapirxl` | Pretty-printed ingest + Vector upload |

## Other

| Path | Role |
|------|------|
| `blueflow-patches/tasks.py` | Bind-mount overlay for U4/U5 (see PLAYBOOK) |

**Viper API key** is not a `just` recipe. After `just capture`:

```bash
docker compose exec viper npm run db:create-test-api-key
export VIPER_API_KEY=<key printed above>
```
