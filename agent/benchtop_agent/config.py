"""Runtime configuration for the BenchTop agent, sourced from env vars so it
can be pointed at wherever the pipeline scripts actually write their state.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _bool_env(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


# agent/benchtop_agent/config.py -> agent/sample_data, independent of CWD.
_DEFAULT_SAMPLE_DATA_DIR = Path(__file__).resolve().parent.parent / "sample_data"


@dataclass(frozen=True)
class Settings:
    host: str = os.environ.get("BENCHTOP_HOST", "0.0.0.0")
    port: int = int(os.environ.get("BENCHTOP_PORT", "8420"))

    # Directory layout for real (non-mock) data:
    #   data_dir/jobs.json         - job manifest (metadata that doesn't change often)
    #   data_dir/campaigns.json    - campaign + funnel definitions
    #   data_dir/checkpoints/*.jsonl - one file per job id, one JSON line per checkpoint
    data_dir: Path = Path(
        os.environ.get("BENCHTOP_DATA_DIR", str(_DEFAULT_SAMPLE_DATA_DIR))
    )

    # When true, GPU stats and job/campaign state are served from the sample
    # data bundled in this repo instead of nvidia-smi / real checkpoint files.
    # Useful for developing the app UI on a machine with no NVIDIA GPU at all.
    mock: bool = _bool_env("BENCHTOP_MOCK", True)

    # Used to turn GPU-hours into a $ estimate in /api/stats. Left at 0 (no
    # cost shown) unless set — there's no universally right number here
    # (electricity rate, amortized hardware, whatever you want it to mean).
    cost_per_gpu_hour: float = float(os.environ.get("BENCHTOP_COST_PER_GPU_HOUR", "0"))

    # Optional spending cap; /api/stats reports whether it's been crossed so
    # the app can alert on it. Unset (None) means "no budget configured".
    budget_usd: float | None = (
        float(os.environ["BENCHTOP_BUDGET_USD"]) if "BENCHTOP_BUDGET_USD" in os.environ else None
    )

    # mDNS/Bonjour advertisement so the app can find this agent on the LAN
    # without the user typing in an IP. Best-effort: some networks/sandboxes
    # block multicast, in which case this is silently skipped (see
    # discovery.py) and manual host entry in the app still works.
    advertise: bool = _bool_env("BENCHTOP_ADVERTISE", True)
    service_type: str = "_benchtop._tcp.local."
    service_name: str = os.environ.get("BENCHTOP_SERVICE_NAME", "BenchTop Rig")

    @property
    def jobs_manifest_path(self) -> Path:
        return self.data_dir / "jobs.json"

    @property
    def campaigns_path(self) -> Path:
        return self.data_dir / "campaigns.json"

    @property
    def checkpoints_dir(self) -> Path:
        return self.data_dir / "checkpoints"


settings = Settings()
