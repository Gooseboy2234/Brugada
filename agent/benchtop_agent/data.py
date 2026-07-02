"""Reads Rig / Campaign / Job state.

Mock mode: everything comes straight from the bundled sample_data/*.json,
already in the shape the app expects — the easiest way to run the whole app
without a GPU.

Real mode: the same JSON config files describe the rigs/campaigns/jobs, and
the agent overlays what it can measure itself — live nvidia-smi telemetry onto
rigs, and each job's checkpoint stream onto its sparklines. A job's checkpoint
file `checkpoints/<job_id>.jsonl` has one JSON object per heartbeat:
`{units_done, metric_value, temp, util, timestamp}`. That's the whole
integration contract — write those lines and the job comes alive in the app.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from . import gpu
from .config import settings
from .models import Campaign, Job, Rig


def _load(path: Path) -> Any:
    return json.loads(path.read_text()) if path.exists() else None


def _tail_jsonl(path: Path, limit: int = 40) -> list[dict]:
    if not path.exists():
        return []
    rows: list[dict] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows[-limit:]


def read_rigs() -> list[Rig]:
    raw = _load(settings.rigs_path) or []
    rigs = [Rig.model_validate(entry) for entry in raw]
    if settings.mock:
        return rigs

    # Overlay live telemetry onto configured rigs, matched by list order.
    telemetry = gpu.read_telemetry()
    for rig, live in zip(rigs, telemetry):
        rig.util_percent = live["util_percent"]
        rig.vram_used_gb = live["vram_used_gb"]
        rig.vram_gb = live["vram_gb"]
        rig.temp_c = live["temp_c"]
        rig.power_w = live["power_w"]
        if not rig.gpu_model:
            rig.gpu_model = live["name"]
    return rigs


def read_campaigns() -> list[Campaign]:
    raw = _load(settings.campaigns_path) or []
    return [Campaign.model_validate(entry) for entry in raw]


def read_jobs() -> list[Job]:
    raw = _load(settings.jobs_path) or []
    jobs = [Job.model_validate(entry) for entry in raw]
    if settings.mock:
        return jobs

    # Overlay each job's checkpoint stream: build the metric + resource
    # sparklines and update units_done from the heartbeats.
    for job in jobs:
        checkpoints = _tail_jsonl(settings.checkpoints_dir / f"{job.id}.jsonl")
        if not checkpoints:
            continue
        last = checkpoints[-1]
        job.units_done = last.get("units_done", job.units_done)
        if job.units_total and job.units_done >= job.units_total and job.status == "running":
            job.status = "done"
        if job.metric is not None:
            job.metric.sparkline = [c["metric_value"] for c in checkpoints if "metric_value" in c]
            if job.metric.sparkline:
                job.metric.value = job.metric.sparkline[-1]
        job.temp_spark = [c["temp"] for c in checkpoints if "temp" in c]
        job.util_spark = [c["util"] for c in checkpoints if "util" in c]
    return jobs
