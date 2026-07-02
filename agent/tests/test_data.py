from benchtop_agent import data
from benchtop_agent.config import Settings
from tests.conftest import write_checkpoints, write_json


def test_mock_reads_bundled_r104q_journey(monkeypatch):
    monkeypatch.setattr(data, "settings", Settings(mock=True))

    rigs = data.read_rigs()
    assert any(r.id == "home" and not r.is_cloud and r.dollars_per_hour == 0 for r in rigs)
    assert any(r.is_cloud for r in rigs), "a cloud rig demonstrates the money story"

    campaigns = data.read_campaigns()
    r104q = next(c for c in campaigns if c.id == "r104q-replicates")
    assert r104q.hypothesis.startswith("R104Q")
    # The simulation wall must be present — the honesty contract.
    assert any(s.is_wall for s in r104q.funnel)
    # Live scientific result with per-system series.
    assert r104q.live_result is not None
    names = {s.name for s in r104q.live_result.series}
    assert {"WT", "R104Q", "rescued"} <= names

    jobs = data.read_jobs()
    # 3 systems x 3 seeds for the replicate batch.
    replicate_jobs = [j for j in jobs if j.campaign_id == "r104q-replicates"]
    assert len(replicate_jobs) == 9
    assert any(j.status == "failed" for j in replicate_jobs)
    running = next(j for j in replicate_jobs if j.status == "running")
    assert running.metric is not None and running.metric.sparkline


def test_real_mode_builds_sparklines_from_checkpoints(real_mode_settings, monkeypatch):
    monkeypatch.setattr(data, "settings", real_mode_settings)

    write_json(real_mode_settings.data_dir, "rigs.json", [{
        "id": "home", "name": "Home", "gpu_model": "4060 Ti", "vram_gb": 16, "vram_used_gb": 0,
        "temp_c": 0, "util_percent": 0, "power_w": 0, "dollars_per_hour": 0,
        "is_cloud": False, "uptime_hours": 5,
    }])
    write_json(real_mode_settings.data_dir, "campaigns.json", [])
    write_json(real_mode_settings.data_dir, "jobs.json", [{
        "id": "wt-s2", "campaign_id": "c", "tag": "WT · seed 2", "kind": "md",
        "status": "running", "units_done": 0, "units_total": 100, "unit_label": "ns",
        "metric": {"label": "R104–D84 min distance", "value": 0, "unit": "Å", "sparkline": []},
    }])
    write_checkpoints(real_mode_settings.data_dir, "wt-s2", [
        {"units_done": 20, "metric_value": 3.4, "temp": 59, "util": 95},
        {"units_done": 45, "metric_value": 3.0, "temp": 60, "util": 96},
        {"units_done": 72, "metric_value": 3.1, "temp": 61, "util": 94},
    ])

    jobs = data.read_jobs()
    job = jobs[0]
    assert job.units_done == 72
    assert job.metric.sparkline == [3.4, 3.0, 3.1]
    assert job.metric.value == 3.1
    assert job.temp_spark == [59, 60, 61]
    assert job.util_spark == [95, 96, 94]


def test_real_mode_infers_done_when_units_reached(real_mode_settings, monkeypatch):
    monkeypatch.setattr(data, "settings", real_mode_settings)
    write_json(real_mode_settings.data_dir, "jobs.json", [{
        "id": "j", "campaign_id": "c", "tag": "t", "kind": "md", "status": "running",
        "units_done": 0, "units_total": 100, "unit_label": "ns",
    }])
    write_checkpoints(real_mode_settings.data_dir, "j", [{"units_done": 100}])
    assert data.read_jobs()[0].status == "done"
