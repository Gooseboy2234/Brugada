import dataclasses
import json
from pathlib import Path

import pytest

from benchtop_agent.config import Settings


@pytest.fixture
def real_mode_settings(tmp_path: Path) -> Settings:
    """A Settings instance pointed at an empty tmp dir, real (non-mock) mode."""
    return Settings(data_dir=tmp_path, mock=False)


def write_manifest(data_dir: Path, jobs: list[dict]) -> None:
    (data_dir / "jobs.json").write_text(json.dumps(jobs))


def write_checkpoints(data_dir: Path, job_id: str, lines: list[dict]) -> None:
    checkpoints_dir = data_dir / "checkpoints"
    checkpoints_dir.mkdir(parents=True, exist_ok=True)
    path = checkpoints_dir / f"{job_id}.jsonl"
    path.write_text("\n".join(json.dumps(line) for line in lines) + "\n")
