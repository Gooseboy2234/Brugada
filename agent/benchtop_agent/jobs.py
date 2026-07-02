"""Job and campaign state.

Real mode: a `jobs.json` manifest holds per-job metadata that rarely changes
(name, campaign, kind, gpu). Each job's live progress comes from the last
line of `checkpoints/<job_id>.jsonl` — the pipeline scripts append one JSON
object per checkpoint (stage, units_done, units_total, throughput_per_hour,
timestamp, and optionally status/error_message). This is the "clever hook":
any job type shows up automatically as long as it checkpoints in this shape,
with no agent changes needed and no need to go back and edit the manifest.

A job's status resolves in this order:
  1. `status` on the latest checkpoint line, if present (lets a script
     explicitly say "failed" with an `error_message`, or "completed").
  2. Inferred as "completed" if `units_done >= units_total` and the
     manifest didn't already say "failed".
  3. Whatever `jobs.json` declared (typically "queued" or "running", set
     once when the job is created).

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


def _resolve_status(entry: dict[str, Any], checkpoint: dict[str, Any], units_done: float, units_total: float | None) -> str:
    if "status" in checkpoint:
        return checkpoint["status"]
    manifest_status = entry.get("status", "queued")
    if manifest_status == "failed":
        return manifest_status
    if units_total is not None and units_done >= units_total:
        return "completed"
    return manifest_status


def _read_real_jobs() -> list[Job]:
    if not settings.jobs_manifest_path.exists():
        return []
    manifest = json.loads(settings.jobs_manifest_path.read_text())

    jobs: list[Job] = []
    for entry in manifest:
        checkpoint_path = settings.checkpoints_dir / f"{entry['id']}.jsonl"
        checkpoint = (_last_jsonl_line(checkpoint_path) if checkpoint_path.exists() else None) or {}

        units_done = checkpoint.get("units_done", entry.get("units_done", 0))
        units_total = checkpoint.get("units_total", entry.get("units_total"))

        merged = {
            **entry,
            "stage": checkpoint.get("stage", entry.get("stage", "queued")),
            "units_done": units_done,
            "units_total": units_total,
            "throughput_per_hour": checkpoint.get(
                "throughput_per_hour", entry.get("throughput_per_hour")
            ),
            "last_checkpoint_at": checkpoint.get(
                "timestamp", entry.get("last_checkpoint_at", entry.get("started_at"))
            ),
            "status": _resolve_status(entry, checkpoint, units_done, units_total),
            "error_message": checkpoint.get("error_message", entry.get("error_message")),
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
