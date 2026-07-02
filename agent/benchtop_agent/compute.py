"""Derived values the app shouldn't have to compute itself: campaign
percent-complete, per-rig weekly spend (honest about home = free), and the
alert list. All pure functions of the current Rig/Campaign/Job state.
"""
from __future__ import annotations

from .models import Alert, Campaign, Job, Rig


def campaign_percent(campaign: Campaign, jobs: list[Job]) -> float | None:
    """% of the computational journey for this campaign, weighted by units done
    across its jobs (e.g. ns across the 9 replicates). None if nothing to weigh.
    """
    batch = [j for j in jobs if j.campaign_id == campaign.id and j.units_total]
    if not batch:
        return None
    done = sum(j.units_done for j in batch)
    total = sum(j.units_total or 0 for j in batch)
    if total <= 0:
        return None
    return round(min(done / total, 1.0), 4)


def enrich_rigs(rigs: list[Rig], campaigns: list[Campaign], jobs: list[Job]) -> list[Rig]:
    """Fill each rig's weekly spend and energy from its jobs. Home rigs
    (`is_cloud == False`) always come out at $0 — the honesty feature.
    """
    rig_of_campaign = {c.id: c.rig_id for c in campaigns}
    for rig in rigs:
        rig_jobs = [j for j in jobs if rig_of_campaign.get(j.campaign_id) == rig.id]
        if rig.is_cloud:
            rig.cost_this_week = round(sum(j.cost_so_far for j in rig_jobs), 2)
            rig.energy_kwh_this_week = 0.0
        else:
            rig.cost_this_week = 0.0
            # Rough energy stand-in: current draw over uptime. Enough to show
            # "you spent kWh, not dollars" for a local rig.
            rig.energy_kwh_this_week = round(rig.power_w / 1000 * min(rig.uptime_hours, 168), 2)
    return rigs


def compute_alerts(rigs: list[Rig], campaigns: list[Campaign], jobs: list[Job]) -> list[Alert]:
    """Derive the current alert list from state. Rare and meaningful only:
    failures, thermals, completed work, budget pressure. Never "util is high".
    """
    alerts: list[Alert] = []
    rig_of_campaign = {c.id: c.rig_id for c in campaigns}

    for job in jobs:
        rig_id = rig_of_campaign.get(job.campaign_id)
        if job.status == "failed":
            alerts.append(Alert(
                id=f"fail-{job.id}", kind="job_failed", severity="critical",
                title=f"{job.tag} failed",
                detail=job.error_message or "Job failed.", rig_id=rig_id,
            ))
        elif job.status == "done":
            alerts.append(Alert(
                id=f"done-{job.id}", kind="job_done", severity="good",
                title=f"{job.tag} done",
                detail=f"{int(job.units_done)} {job.unit_label} complete.", rig_id=rig_id,
            ))

    for rig in rigs:
        # Thermal: sustained high temp likely means throttling. We only see a
        # snapshot, so treat a hot reading as the signal.
        if rig.temp_c >= 85:
            alerts.append(Alert(
                id=f"thermal-{rig.id}", kind="thermal", severity="warning",
                title=f"{rig.name} at {int(rig.temp_c)} °C",
                detail="Throttling likely — check airflow.", rig_id=rig.id,
            ))
        # Budget pressure only makes sense for cloud rigs that cost money.
        if rig.is_cloud and rig.budget_usd:
            if rig.cost_this_week >= rig.budget_usd:
                alerts.append(Alert(
                    id=f"budget-{rig.id}", kind="budget", severity="critical",
                    title=f"{rig.name} over budget",
                    detail=f"${rig.cost_this_week:.0f} spent of ${rig.budget_usd:.0f} cap.", rig_id=rig.id,
                ))
            elif rig.cost_this_week >= 0.8 * rig.budget_usd:
                alerts.append(Alert(
                    id=f"budget-{rig.id}", kind="budget", severity="warning",
                    title=f"{rig.name} approaching cap",
                    detail=f"${rig.cost_this_week:.0f} of ${rig.budget_usd:.0f} — ${rig.budget_usd - rig.cost_this_week:.0f} left.", rig_id=rig.id,
                ))

    for campaign in campaigns:
        # A campaign whose whole batch is done and that has a verdict is a
        # milestone worth surfacing.
        batch = [j for j in jobs if j.campaign_id == campaign.id]
        if batch and all(j.status == "done" for j in batch) and campaign.so_what:
            alerts.append(Alert(
                id=f"milestone-{campaign.id}", kind="campaign", severity="good",
                title=f"{campaign.title} — batch complete",
                detail=campaign.so_what,
            ))

    severity_rank = {"critical": 0, "warning": 1, "good": 2}
    alerts.sort(key=lambda a: severity_rank[a.severity])
    return alerts
