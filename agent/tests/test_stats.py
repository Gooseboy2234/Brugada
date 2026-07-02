from datetime import datetime, timedelta, timezone

from benchtop_agent.config import Settings
from benchtop_agent.models import Job
from benchtop_agent.stats import compute_stats

NOW = datetime(2026, 7, 2, 12, 0, 0, tzinfo=timezone.utc)


def make_job(**overrides) -> Job:
    defaults = dict(
        id="job-1",
        campaign_id="campaign-x",
        name="Test job",
        kind="md_simulation",
        gpu_id="gpu-0",
        status="running",
        stage="Production",
        units_done=10.0,
        units_total=100.0,
        unit_label="ns",
        started_at=NOW - timedelta(hours=2),
        last_checkpoint_at=NOW - timedelta(minutes=5),
    )
    defaults.update(overrides)
    return Job.model_validate(defaults)


def test_running_job_gpu_hours_measured_to_now():
    job = make_job(status="running", started_at=NOW - timedelta(hours=3))
    result = compute_stats([job], Settings(cost_per_gpu_hour=0.0), NOW)
    assert result.total_gpu_hours == 3.0


def test_completed_job_gpu_hours_measured_to_last_checkpoint_not_now():
    job = make_job(
        status="completed",
        started_at=NOW - timedelta(hours=5),
        last_checkpoint_at=NOW - timedelta(hours=1),
    )
    result = compute_stats([job], Settings(cost_per_gpu_hour=0.0), NOW)
    assert result.total_gpu_hours == 4.0


def test_job_without_gpu_id_excluded_from_gpu_hours():
    job = make_job(gpu_id=None, status="running", started_at=NOW - timedelta(hours=10))
    result = compute_stats([job], Settings(cost_per_gpu_hour=0.0), NOW)
    assert result.total_gpu_hours == 0.0


def test_cost_derived_from_rate():
    job = make_job(status="running", started_at=NOW - timedelta(hours=2))
    result = compute_stats([job], Settings(cost_per_gpu_hour=0.5), NOW)
    assert result.total_gpu_hours == 2.0
    assert result.total_cost_usd == 1.0


def test_budget_crossed_flag():
    job = make_job(status="running", started_at=NOW - timedelta(hours=10))
    under = compute_stats([job], Settings(cost_per_gpu_hour=1.0, budget_usd=20.0), NOW)
    over = compute_stats([job], Settings(cost_per_gpu_hour=1.0, budget_usd=5.0), NOW)
    assert under.budget_crossed is False
    assert over.budget_crossed is True


def test_no_budget_configured_never_crossed():
    job = make_job(status="running", started_at=NOW - timedelta(hours=1000))
    result = compute_stats([job], Settings(cost_per_gpu_hour=1.0, budget_usd=None), NOW)
    assert result.budget_crossed is False


def test_totals_by_unit_grouped_across_jobs_regardless_of_gpu():
    jobs = [
        make_job(id="a", unit_label="ns", units_done=63, gpu_id="gpu-0"),
        make_job(id="b", unit_label="ns", units_done=12, gpu_id="gpu-1"),
        make_job(id="c", unit_label="molecules", units_done=1_200_000, gpu_id=None),
    ]
    result = compute_stats(jobs, Settings(), NOW)
    assert result.totals_by_unit == {"ns": 75.0, "molecules": 1_200_000.0}
