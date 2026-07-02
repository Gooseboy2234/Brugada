from benchtop_agent.compute import campaign_percent, compute_alerts, enrich_rigs
from benchtop_agent.models import Campaign, Job, Rig, Stage


def _campaign(**over) -> Campaign:
    base = dict(id="c", rig_id="home", title="t", hypothesis="h",
                funnel=[Stage(index=1, label="s", status="active")])
    base.update(over)
    return Campaign(**base)


def _job(**over) -> Job:
    base = dict(id="j", campaign_id="c", tag="t", kind="md", status="running",
                units_done=0.0, units_total=100.0, unit_label="ns")
    base.update(over)
    return Job(**base)


def _rig(**over) -> Rig:
    base = dict(id="home", name="Home", gpu_model="4060 Ti", vram_gb=16.0, vram_used_gb=11.0,
                temp_c=61.0, util_percent=94.0, power_w=168.0, dollars_per_hour=0.0,
                is_cloud=False, uptime_hours=10.0)
    base.update(over)
    return Rig(**base)


def test_campaign_percent_weighted_by_units():
    jobs = [
        _job(id="a", units_done=100, units_total=100),
        _job(id="b", units_done=50, units_total=100),
        _job(id="c", units_done=0, units_total=100),
    ]
    assert campaign_percent(_campaign(), jobs) == 0.5


def test_campaign_percent_none_when_no_measurable_jobs():
    assert campaign_percent(_campaign(), []) is None
    assert campaign_percent(_campaign(), [_job(units_total=None)]) is None


def test_home_rig_never_costs_money_and_reports_energy():
    rigs = enrich_rigs([_rig(is_cloud=False, power_w=168, uptime_hours=10)], [_campaign()],
                       [_job(cost_so_far=99)])  # even if a job claims a cost, home is free
    assert rigs[0].cost_this_week == 0.0
    assert rigs[0].energy_kwh_this_week > 0


def test_cloud_rig_sums_job_cost():
    rig = _rig(id="modal", is_cloud=True, dollars_per_hour=0.8, budget_usd=30)
    campaign = _campaign(rig_id="modal")
    jobs = [_job(cost_so_far=25.0), _job(id="j2", cost_so_far=0.0)]
    rigs = enrich_rigs([rig], [campaign], jobs)
    assert rigs[0].cost_this_week == 25.0
    assert rigs[0].energy_kwh_this_week == 0.0


def test_alerts_cover_failed_thermal_budget_and_done():
    home = _rig(id="home", temp_c=88)  # thermal
    modal = _rig(id="modal", is_cloud=True, dollars_per_hour=0.8, budget_usd=30)
    campaigns = [_campaign(id="c", rig_id="home"), _campaign(id="cm", rig_id="modal")]
    jobs = [
        _job(id="f", campaign_id="c", tag="R104Q seed 3", status="failed",
             error_message="CUDA OOM at 8 ns"),
        _job(id="d", campaign_id="c", tag="WT seed 1", status="done", units_done=100),
        _job(id="m", campaign_id="cm", cost_so_far=25.0, status="running"),
    ]
    rigs = enrich_rigs([home, modal], campaigns, jobs)
    alerts = compute_alerts(rigs, campaigns, jobs)

    kinds = {a.kind for a in alerts}
    assert {"job_failed", "job_done", "thermal", "budget"} <= kinds
    # critical sorts first
    assert alerts[0].severity == "critical"
    failed = next(a for a in alerts if a.kind == "job_failed")
    assert "CUDA OOM" in (failed.detail or "")
    assert failed.rig_id == "home"  # routed to the rig for per-rig counts
    assert next(a for a in alerts if a.kind == "budget").rig_id == "modal"
    budget = next(a for a in alerts if a.kind == "budget")
    assert budget.severity == "warning"  # $25 of $30 -> approaching, not over


def test_no_budget_alert_for_home_rig():
    home = _rig(id="home", is_cloud=False, temp_c=60)
    alerts = compute_alerts(enrich_rigs([home], [], []), [], [])
    assert all(a.kind != "budget" for a in alerts)
