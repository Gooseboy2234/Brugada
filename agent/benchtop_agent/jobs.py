"""Job and campaign state.

Real mode: a `jobs.json` manifest holds per-job metadata that rarely changes
(name, campaign, kind, gpu). Each job's live progress comes from the last
line of `checkpoints/<job_id>.jsonl` — the pipeline scripts append one JSON
object per checkpoint (stage, units_done, units_total, throughput_per_hour,
timestamp). This is the "clever hook": any job type shows up automatically
as long as it checkpoints in this shape, with no agent changes needed.

Mock mode: everything comes straight from sample_data/jobs.json and
sample_data/campaigns.json, already in the shape the app expects.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .config import settings
from .models import Campaign, Job


def _last_jsonl_line(path: Path) -> dict[str, Any] | None:
    last: dict[str, Any] | None = None
    with path.open("r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                last = json.loads(line)
            except json.JSONDecodeError:
                continue
    return last


def _read_real_jobs() -> list[Job]:
    if not settings.jobs_manifest_path.exists():
        return []
    manifest = json.loads(settings.jobs_manifest_path.read_text())

    jobs: list[Job] = []
    for entry in manifest:
        checkpoint_path = settings.checkpoints_dir / f"{entry['id']}.jsonl"
        checkpoint = _last_jsonl_line(checkpoint_path) if checkpoint_path.exists() else None

        merged = {
            **entry,
            "stage": (checkpoint or {}).get("stage", entry.get("stage", "queued")),
            "units_done": (checkpoint or {}).get("units_done", entry.get("units_done", 0)),
            "units_total": (checkpoint or {}).get("units_total", entry.get("units_total")),
            "throughput_per_hour": (checkpoint or {}).get(
                "throughput_per_hour", entry.get("throughput_per_hour")
            ),
            "last_checkpoint_at": (checkpoint or {}).get(
                "timestamp", entry.get("last_checkpoint_at", entry.get("started_at"))
            ),
        }
        jobs.append(Job.model_validate(merged))
    return jobs


def _read_mock_jobs() -> list[Job]:
    path = settings.data_dir / "jobs.json"
    if not path.exists():
        return []
    raw = json.loads(path.read_text())
    return [Job.model_validate(entry) for entry in raw]


def read_jobs() -> list[Job]:
    if settings.mock:
        return _read_mock_jobs()
    return _read_real_jobs()


def read_campaigns() -> list[Campaign]:
    if not settings.campaigns_path.exists():
        return []
    raw = json.loads(settings.campaigns_path.read_text())
    return [Campaign.model_validate(entry) for entry in raw]
