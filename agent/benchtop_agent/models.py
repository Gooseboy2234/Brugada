"""Pydantic schemas mirroring the Swift models in
BenchTop/Sources/BenchTop/Models. Keep field names/shape in sync — the Swift
side decodes these snake_case keys via explicit CodingKeys (not
convertFromSnakeCase; see AgentClient.swift for why) and ISO-8601 dates.

The model follows the tracker guide exactly:  Rig → Campaign → Job → Checkpoint.
Checkpoints aren't a served object; they're the rig-side heartbeat that fills
in each job's live metric sparkline and the campaign's live result.
"""
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel


# ─────────────────────────── Rig ───────────────────────────
class Rig(BaseModel):
    """One physical machine (a home 4060 Ti box, or a cloud/Modal sandbox).

    The honesty rule lives here: `is_cloud` decides whether the app shows real
    dollars (cloud) or "home = free" + kWh (local). `dollars_per_hour` is 0 for
    home rigs and the app never pretends otherwise.
    """

    id: str
    name: str
    gpu_model: str
    vram_gb: float
    vram_used_gb: float
    temp_c: float
    util_percent: float
    power_w: float
    dollars_per_hour: float
    is_cloud: bool
    uptime_hours: float
    # Filled by the agent from this rig's jobs (see compute.enrich_rigs).
    cost_this_week: float = 0.0
    energy_kwh_this_week: float = 0.0
    budget_usd: Optional[float] = None  # a spending cap, cloud rigs only


# ─────────────────────────── Campaign ───────────────────────────
StageStatus = Literal["done", "active", "upcoming"]


class Stage(BaseModel):
    """One rung of the cure-journey funnel. `is_wall` marks the SIMULATION
    WALL divider — the hard boundary between what a GPU can answer and what
    only a wet lab can. `caveat` is the honest per-stage footnote.
    """

    index: int
    label: str
    status: StageStatus
    detail: Optional[str] = None
    is_wall: bool = False
    caveat: Optional[str] = None


class ResultSeries(BaseModel):
    """One system's trace in a campaign's live result (e.g. WT / R104Q / rescued)."""

    name: str
    value: float
    unit: Optional[str] = None
    note: Optional[str] = None  # "+37% vs WT", "most rigid"
    sparkline: list[float] = []


class LiveResult(BaseModel):
    """The number you actually care about, live — with error/comparison notes."""

    metric_label: str  # "core RMSF (res 55–85)"
    unit: str
    series: list[ResultSeries]


class Campaign(BaseModel):
    id: str
    rig_id: str
    title: str
    hypothesis: str
    funnel: list[Stage]
    live_result: Optional[LiveResult] = None
    so_what: Optional[str] = None
    # Weighted % of the *computational* journey (never "% to cure"), filled by
    # the agent from this campaign's jobs.
    percent_complete: Optional[float] = None


# ─────────────────────────── Job ───────────────────────────
JobKind = Literal["md", "fep", "docking", "folding"]
JobStatus = Literal["queued", "running", "done", "failed"]


class JobMetric(BaseModel):
    """The one scientifically-meaningful heartbeat for this job type:
    MD → salt-bridge distance, FEP → ΔΔG, docking → best score, folding → pLDDT.
    """

    label: str
    value: float
    unit: str
    note: Optional[str] = None  # "58% occupancy <4 Å"
    sparkline: list[float] = []


class Job(BaseModel):
    id: str
    campaign_id: str
    tag: str  # "WT · seed 2"
    kind: JobKind
    status: JobStatus
    units_done: float
    units_total: Optional[float] = None
    unit_label: str  # "ns", "ligands"
    rate_per_day: Optional[float] = None
    # How much recent data the rate is based on — drives the honest ETA note
    # ("based on last 20 min").
    rate_window_minutes: Optional[int] = None
    cost_so_far: float = 0.0
    metric: Optional[JobMetric] = None
    temp_spark: list[float] = []
    util_spark: list[float] = []
    log_tail: list[str] = []
    error_message: Optional[str] = None


# ─────────────────────────── Alerts ───────────────────────────
AlertKind = Literal["job_done", "campaign", "job_failed", "thermal", "budget"]
AlertSeverity = Literal["good", "warning", "critical"]


class Alert(BaseModel):
    """Rare and meaningful: either good news you were waiting for, or something
    that needs your hand. Never "FYI the GPU is at 94% util".
    """

    id: str
    kind: AlertKind
    severity: AlertSeverity
    title: str
    detail: Optional[str] = None
    rig_id: Optional[str] = None  # which rig this concerns, for per-rig counts
