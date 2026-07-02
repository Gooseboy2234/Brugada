"""Reads live GPU stats via nvidia-smi, or serves mock data when running on a
machine with no NVIDIA GPU (e.g. while developing the app UI).
"""
from __future__ import annotations

import json
import shutil
import subprocess

from .config import settings
from .models import GPUStatus

_NVIDIA_SMI_FIELDS = [
    "index",
    "name",
    "utilization.gpu",
    "memory.used",
    "memory.total",
    "temperature.gpu",
    "power.draw",
]


def _query_nvidia_smi() -> list[GPUStatus]:
    binary = shutil.which("nvidia-smi")
    if binary is None:
        return []

    query = ",".join(_NVIDIA_SMI_FIELDS)
    result = subprocess.run(
        [binary, f"--query-gpu={query}", "--format=csv,noheader,nounits"],
        capture_output=True,
        text=True,
        check=False,
        timeout=5,
    )
    if result.returncode != 0:
        return []

    gpus: list[GPUStatus] = []
    for line in result.stdout.strip().splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != len(_NVIDIA_SMI_FIELDS):
            continue
        index, name, util, mem_used, mem_total, temp, power = parts
        gpus.append(
            GPUStatus(
                id=f"gpu-{index}",
                index=int(index),
                name=name,
                utilization_percent=float(util),
                memory_used_mb=float(mem_used),
                memory_total_mb=float(mem_total),
                temperature_c=float(temp),
                power_watts=float(power),
            )
        )
    return gpus


def _mock_gpus() -> list[GPUStatus]:
    path = settings.data_dir / "gpus.json"
    if not path.exists():
        return []
    raw = json.loads(path.read_text())
    return [GPUStatus.model_validate(entry) for entry in raw]


def read_gpus() -> list[GPUStatus]:
    if settings.mock:
        return _mock_gpus()
    return _query_nvidia_smi()
