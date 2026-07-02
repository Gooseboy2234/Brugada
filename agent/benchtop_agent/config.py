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
    #   data_dir/rigs.json         - rig config (gpu, $/hr, cloud-or-home, budget)
    #   data_dir/campaigns.json    - campaigns: hypothesis, journey funnel, live result
    #   data_dir/jobs.json         - job manifest (tag, kind, target, metric shape)
    #   data_dir/checkpoints/*.jsonl - one file per job id, one JSON line per heartbeat
    data_dir: Path = Path(
        os.environ.get("BENCHTOP_DATA_DIR", str(_DEFAULT_SAMPLE_DATA_DIR))
    )

    # When true, everything is served from the bundled sample_data instead of
    # nvidia-smi + checkpoint files — the easiest way to run the whole app
    # without a GPU.
    mock: bool = _bool_env("BENCHTOP_MOCK", True)

    # mDNS/Bonjour advertisement so the app can find this agent on the LAN
    # without the user typing in an IP. Best-effort: some networks/sandboxes
    # block multicast, in which case this is silently skipped (see
    # discovery.py) and manual host entry in the app still works.
    advertise: bool = _bool_env("BENCHTOP_ADVERTISE", True)
    service_type: str = "_benchtop._tcp.local."
    service_name: str = os.environ.get("BENCHTOP_SERVICE_NAME", "BenchTop Rig")

    @property
    def rigs_path(self) -> Path:
        return self.data_dir / "rigs.json"

    @property
    def jobs_path(self) -> Path:
        return self.data_dir / "jobs.json"

    @property
    def campaigns_path(self) -> Path:
        return self.data_dir / "campaigns.json"

    @property
    def checkpoints_dir(self) -> Path:
        return self.data_dir / "checkpoints"


settings = Settings()
