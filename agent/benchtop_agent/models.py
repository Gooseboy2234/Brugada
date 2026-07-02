"""Pydantic schemas mirroring the Swift models in
BenchTop/Sources/BenchTop/Models. Keep field names/shape in sync with those —
the Swift side decodes with convertFromSnakeCase + ISO-8601 dates.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel


class GPUStatus(BaseModel):
    id: str
    index: int
    name: str
    utilization_percent: float
    memory_used_mb: float
    memory_total_mb: float
    temperature_c: float
    power_watts: float
    current_job_id: Optional[str] = None


JobKind = Literal["docking_screen", "md_simulation", "ml_surrogate", "other"]
JobStatus = Literal["queued", "running", "completed", "failed"]


class Job(BaseModel):
    id: str
    campaign_id: str
    name: str
    kind: JobKind
    gpu_id: Optional[str] = None
    status: JobStatus
    stage: str
    units_done: float
    units_total: Optional[float] = None
    unit_label: str
    throughput_per_hour: Optional[float] = None
    started_at: datetime
    last_checkpoint_at: datetime
    error_message: Optional[str] = None


class FunnelStage(BaseModel):
    name: str
    count: int


class Campaign(BaseModel):
    id: str
    name: str
    target: str
    funnel: list[FunnelStage]
