# BenchTop agent

A small FastAPI daemon meant to run on the GPU rig itself. It polls
`nvidia-smi` for live GPU stats and reads job/campaign state that the
pipeline scripts write locally, then serves it as JSON over the local
network for the BenchTop app to poll.

See `../docs/BENCHTOP_SPEC.md` for the full concept.

## Run it (mock mode — no GPU required)

Mock mode serves the bundled sample data from `sample_data/` and is the
easiest way to develop/preview the app's UI on any machine.

```bash
cd agent
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn benchtop_agent.main:app --host 0.0.0.0 --port 8420
```

Then, e.g.:

```bash
curl http://localhost:8420/api/gpus
curl http://localhost:8420/api/jobs
curl http://localhost:8420/api/campaigns
curl http://localhost:8420/api/stats
```

The agent also advertises itself over mDNS/Bonjour on startup (service type
`_benchtop._tcp`), so the app's Settings screen should find it automatically
under "Found on this network" instead of needing a typed-in host — see
"Configuration" below to name it or turn that off.

## Run it for real, on the rig

1. Point `BENCHTOP_DATA_DIR` at wherever your pipeline scripts write state
   (see `sample_data/real_mode_example/` for the expected layout: a
   `jobs.json` manifest, a `campaigns.json`, and one
   `checkpoints/<job_id>.jsonl` file per job).
2. Set `BENCHTOP_MOCK=0`.
3. Have your pipeline scripts append one JSON line per checkpoint to
   `checkpoints/<job_id>.jsonl` — `{"stage", "units_done", "units_total",
   "throughput_per_hour", "timestamp"}`, optionally with `"status"`
   (`"completed"` / `"failed"`) and `"error_message"`. That's the only
   integration point; any job type shows up in the app automatically as long
   as it checkpoints in this shape — you never need to go back and edit
   `jobs.json` as a job progresses.

   Status resolves in this order: an explicit `status` on the latest
   checkpoint line wins; otherwise it's inferred as `"completed"` once
   `units_done >= units_total`; otherwise it falls back to whatever
   `jobs.json` declared (typically `"queued"` or `"running"`, set once when
   the job is created). A script that can't cleanly report 100% completion
   (or that wants to report a specific error) should just set `"status"` and
   `"error_message"` on its last checkpoint line.

```bash
export BENCHTOP_MOCK=0
export BENCHTOP_DATA_DIR=/path/to/your/pipeline/state
uvicorn benchtop_agent.main:app --host 0.0.0.0 --port 8420
```

GPU stats come from `nvidia-smi` automatically in this mode — no
configuration needed beyond having the NVIDIA drivers installed.

## Configuration

All via environment variables; every one is optional.

| Variable                     | Default              | Meaning |
|-------------------------------|-----------------------|---------|
| `BENCHTOP_HOST`               | `0.0.0.0`             | Bind address |
| `BENCHTOP_PORT`                | `8420`                | Bind port |
| `BENCHTOP_MOCK`                | `1` (on)              | Serve bundled sample data instead of `nvidia-smi`/checkpoint files |
| `BENCHTOP_DATA_DIR`            | `agent/sample_data`   | Where `jobs.json`/`campaigns.json`/`checkpoints/` live |
| `BENCHTOP_COST_PER_GPU_HOUR`  | `0`                   | $/hour used to turn GPU-hours into a cost estimate in `/api/stats` — whatever you want that number to mean (electricity, amortized hardware, ...) |
| `BENCHTOP_BUDGET_USD`         | unset (no budget)     | If set, `/api/stats` reports `budget_crossed` once total cost reaches it — the app alerts on the false→true transition |
| `BENCHTOP_ADVERTISE`           | `1` (on)              | Advertise via mDNS/Bonjour. Best-effort — set to `0` to disable, or it disables itself automatically if `zeroconf` isn't installed or the network blocks multicast |
| `BENCHTOP_SERVICE_NAME`       | `BenchTop Rig`        | Name shown in the app's discovery list |

## Tests

```bash
cd agent
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest tests/
```

Covers the checkpoint-merge and status-resolution logic in `jobs.py`, the
stats/budget computation in `stats.py` (pure function, fully deterministic),
end-to-end checks through the actual FastAPI app, and a real mDNS
register → independently browse round trip (skips itself gracefully rather
than failing if the environment blocks multicast — see the module docstring
in `tests/test_discovery.py`).

## Endpoints

| Method | Path             | Returns                              |
|--------|------------------|---------------------------------------|
| GET    | `/api/health`    | `{"status": "ok", "mode": "mock"\|"live"}` |
| GET    | `/api/gpus`      | `GPUStatus[]`                         |
| GET    | `/api/jobs`      | `Job[]`                               |
| GET    | `/api/campaigns` | `Campaign[]`                          |
| GET    | `/api/stats`     | `Stats` — GPU-hours, $ spent, budget-crossed flag, totals by unit |

Schemas are defined in `benchtop_agent/models.py` and mirrored by the Swift
models in `../BenchTop/Sources/BenchTop/Models`.

## Exposing it on your LAN

The agent advertises itself via mDNS/Bonjour (`discovery.py`) so the app's
Settings screen can find it without a typed-in IP — this was actually
verified end-to-end in this environment (register with `AgentAdvertiser`,
find it with an independent `zeroconf` browser; see
`tests/test_discovery.py`). It's best-effort: some networks block multicast
entirely, `zeroconf` might not be installed, or you might just be running
this somewhere Bonjour doesn't reach — none of that stops the agent from
starting or serving its REST endpoints, it just means the app's Settings
screen won't auto-populate and you fall back to typing in `<ip>:8420`
directly.
