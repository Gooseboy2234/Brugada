"""Cumulative totals across currently-known jobs: GPU-hours spent, a $
estimate derived from a configurable rate, whether a configured budget has
been crossed, and totals grouped by unit label (ns simulated, molecules
screened, ...) — the numbers the spec calls "the emotional payoff of running
a rig for months."

This only sees jobs currently in the manifest; if your pipeline archives/
removes finished jobs from jobs.json, their contribution to these totals
disappears too. Good enough for a scaffold — true persistent lifetime totals
would need the agent to keep its own running ledger, which is a reasonable
"later" if jobs get pruned in practice.
"""
from __future__ import annotations

from datetime import datetime

from .config import Settings
from .models import Job, Stats


def compute_stats(jobs: list[Job], settings: Settings, now: datetime) -> Stats:
    total_gpu_hours = 0.0
    totals_by_unit: dict[str, float] = {}

    for job in jobs:
        totals_by_unit[job.unit_label] = totals_by_unit.get(job.unit_label, 0.0) + job.units_done

        if job.gpu_id is None:
            continue
        end_time = now if job.status == "running" else job.last_checkpoint_at
        elapsed_hours = max((end_time - job.started_at).total_seconds(), 0) / 3600
        total_gpu_hours += elapsed_hours

    total_cost_usd = total_gpu_hours * settings.cost_per_gpu_hour
    budget_crossed = settings.budget_usd is not None and total_cost_usd >= settings.budget_usd

    return Stats(
        total_gpu_hours=total_gpu_hours,
        total_cost_usd=total_cost_usd,
        budget_usd=settings.budget_usd,
        budget_crossed=budget_crossed,
        totals_by_unit=totals_by_unit,
    )
