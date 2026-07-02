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
curl http://localhost:8420/api/rigs
curl http://localhost:8420/api/campaigns
curl http://localhost:8420/api/jobs
curl http://localhost:8420/api/alerts
```

The agent also advertises itself over mDNS/Bonjour on startup (service type
`_benchtop._tcp`), so the app's Settings screen should find it automatically
under "Found on this network" instead of needing a typed-in host — see
"Configuration" below to name it or turn that off.

## Run it for real, on the rig

1. Point `BENCHTOP_DATA_DIR` at where your pipeline writes state (see
   `sample_data/real_mode_example/`): a `rigs.json` (the machine's
   `dollars_per_hour` / `is_cloud` / `budget_usd`), a `campaigns.json`
   (hypothesis, journey funnel, live result), a `jobs.json` (tag, kind,
   target, metric shape), and one `checkpoints/<job_id>.jsonl` per job.
2. Set `BENCHTOP_MOCK=0`. Rig telemetry (temp/util/VRAM/power) is then read
   live from `nvidia-smi` and overlaid onto the configured rigs.
3. Have each run append one JSON line per heartbeat to
   `checkpoints/<job_id>.jsonl` — `{"units_done", "metric_value", "temp",
   "util", "timestamp"}`. That single append is the whole integration
   contract: the agent builds the job's metric + resource **sparklines** from
   the recent lines, updates `units_done`, and flips a running job to `done`
   once it reaches its target. You never edit `jobs.json` as a job
   progresses.

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
| `BENCHTOP_MOCK`                | `1` (on)              | Serve the bundled R104Q journey instead of `nvidia-smi` + checkpoint files |
| `BENCHTOP_DATA_DIR`            | `agent/sample_data`   | Where `rigs.json`/`campaigns.json`/`jobs.json`/`checkpoints/` live |
| `BENCHTOP_ADVERTISE`           | `1` (on)              | Advertise via mDNS/Bonjour. Best-effort — set `0` to disable, or it disables itself if `zeroconf` isn't installed or the network blocks multicast |
| `BENCHTOP_SERVICE_NAME`       | `BenchTop Rig`        | Name shown in the app's discovery list |

Cost/budget aren't env vars — they live on each rig in `rigs.json`
(`dollars_per_hour`, `is_cloud`, `budget_usd`), because they're a property of
the machine, not the process. Home rigs (`is_cloud: false`) are always free.

## Tests

```bash
cd agent
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest tests/
```

Covers checkpoint → sparkline building in `data.py`, the honest per-rig spend
and campaign %/alert logic in `compute.py` (pure functions), end-to-end checks
through the actual FastAPI app, and a real mDNS register → independently browse
round trip (skips gracefully where multicast is blocked).

## Endpoints

| Method | Path             | Returns                              |
|--------|------------------|---------------------------------------|
| GET    | `/api/health`    | `{"status": "ok", "mode": "mock"\|"live"}` |
| GET    | `/api/rigs`      | `Rig[]` — telemetry + honest weekly spend (home = $0) |
| GET    | `/api/campaigns` | `Campaign[]` — hypothesis, journey funnel, live result, weighted % |
| GET    | `/api/jobs`      | `Job[]` — per-type metric-that-matters + sparklines + log tail |
| GET    | `/api/alerts`    | `Alert[]` — failures, thermals, budget, completions (ranked) |

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
