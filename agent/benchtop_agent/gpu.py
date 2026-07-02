"""Live GPU telemetry via nvidia-smi. Returns raw per-GPU readings that
data.read_rigs merges into the configured Rig objects (which also carry the
non-telemetry facts: $/hr, cloud-or-home, VRAM size).
"""
from __future__ import annotations

import shutil
import subprocess

_FIELDS = [
    "index",
    "name",
    "utilization.gpu",
    "memory.used",
    "memory.total",
    "temperature.gpu",
    "power.draw",
]


def read_telemetry() -> list[dict]:
    """One dict per GPU: index, name, util_percent, vram_used_gb, vram_gb,
    temp_c, power_w. Empty list when nvidia-smi isn't available (e.g. dev box).
    """
    binary = shutil.which("nvidia-smi")
    if binary is None:
        return []

    query = ",".join(_FIELDS)
    result = subprocess.run(
        [binary, f"--query-gpu={query}", "--format=csv,noheader,nounits"],
        capture_output=True, text=True, check=False, timeout=5,
    )
    if result.returncode != 0:
        return []

    out: list[dict] = []
    for line in result.stdout.strip().splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != len(_FIELDS):
            continue
        index, name, util, mem_used, mem_total, temp, power = parts
        out.append({
            "index": int(index),
            "name": name,
            "util_percent": float(util),
            "vram_used_gb": round(float(mem_used) / 1024, 1),
            "vram_gb": round(float(mem_total) / 1024, 1),
            "temp_c": float(temp),
            "power_w": float(power),
        })
    return out
