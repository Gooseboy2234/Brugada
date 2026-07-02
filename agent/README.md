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
```

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

## Tests

```bash
cd agent
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest tests/
```

Covers the checkpoint-merge and status-resolution logic in `jobs.py`, and a
couple of end-to-end checks through the actual FastAPI app.

## Endpoints

| Method | Path             | Returns                              |
|--------|------------------|---------------------------------------|
| GET    | `/api/health`    | `{"status": "ok", "mode": "mock"\|"live"}` |
| GET    | `/api/gpus`      | `GPUStatus[]`                         |
| GET    | `/api/jobs`      | `Job[]`                               |
| GET    | `/api/campaigns` | `Campaign[]`                          |

Schemas are defined in `benchtop_agent/models.py` and mirrored by the Swift
models in `../BenchTop/Sources/BenchTop/Models`.

## Exposing it on your LAN

The app connects by IP/hostname (no discovery yet — see the spec's "later"
section). Find the rig's LAN IP and enter `<ip>:8420` in the app's Settings
sheet. If you'd rather use a hostname, `benchtop.local` (the app's default)
works if the rig advertises itself via mDNS/Bonjour — e.g. `avahi-daemon` on
Linux — otherwise just use the IP.
