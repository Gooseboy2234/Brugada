from fastapi.testclient import TestClient

from benchtop_agent import gpu as gpu_module
from benchtop_agent import jobs as jobs_module
from benchtop_agent import main as main_module
from benchtop_agent.config import Settings
from benchtop_agent.main import app
from benchtop_agent.models import GPUStatus
from tests.conftest import write_checkpoints, write_manifest


def test_health_reports_mode():
    client = TestClient(app)
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_gpu_only_gets_current_job_id_while_job_is_running(real_mode_settings, monkeypatch):
    monkeypatch.setattr(jobs_module, "settings", real_mode_settings)
    # GPU stats themselves aren't under test here (that's nvidia-smi's job) —
    # stub a single fixed GPU so we can isolate the gpu<->job join logic in
    # main.get_gpus().
    monkeypatch.setattr(
        gpu_module,
        "read_gpus",
        lambda: [
            GPUStatus(
                id="gpu-0", index=0, name="Test GPU", utilization_percent=50,
                memory_used_mb=100, memory_total_mb=1000, temperature_c=60, power_watts=100,
            )
        ],
    )

    manifest_entry = {
        "id": "job-1",
        "campaign_id": "campaign-x",
        "name": "Test job",
        "kind": "md_simulation",
        "gpu_id": "gpu-0",
        "status": "running",
        "stage": "queued",
        "units_done": 0,
        "unit_label": "ns",
        "started_at": "2026-06-30T12:00:00Z",
        "last_checkpoint_at": "2026-06-30T12:00:00Z",
    }
    write_manifest(real_mode_settings.data_dir, [manifest_entry])

    client = TestClient(app)

    # Job still running -> GPU should report it as the current job.
    write_checkpoints(
        real_mode_settings.data_dir,
        "job-1",
        [{"stage": "Production", "units_done": 50, "units_total": 200, "timestamp": "2026-07-01T00:00:00Z"}],
    )
    gpus = client.get("/api/gpus").json()
    assert gpus[0]["current_job_id"] == "job-1"

    # Job completes (inferred from units_done >= units_total) -> GPU should
    # no longer report a current job.
    write_checkpoints(
        real_mode_settings.data_dir,
        "job-1",
        [{"stage": "Production", "units_done": 200, "units_total": 200, "timestamp": "2026-07-02T00:00:00Z"}],
    )
    gpus = client.get("/api/gpus").json()
    assert gpus[0]["current_job_id"] is None


def test_stats_endpoint_reflects_jobs(real_mode_settings, monkeypatch):
    settings_with_rate = Settings(
        data_dir=real_mode_settings.data_dir, mock=False, cost_per_gpu_hour=2.0, budget_usd=1.0
    )
    monkeypatch.setattr(jobs_module, "settings", settings_with_rate)
    monkeypatch.setattr(main_module, "settings", settings_with_rate)

    manifest_entry = {
        "id": "job-1",
        "campaign_id": "campaign-x",
        "name": "Test job",
        "kind": "md_simulation",
        "gpu_id": "gpu-0",
        "status": "running",
        "stage": "queued",
        "units_done": 0,
        "unit_label": "ns",
        "started_at": "2020-01-01T00:00:00Z",
        "last_checkpoint_at": "2020-01-01T00:00:00Z",
    }
    write_manifest(real_mode_settings.data_dir, [manifest_entry])
    write_checkpoints(
        real_mode_settings.data_dir,
        "job-1",
        [{"stage": "Production", "units_done": 42, "units_total": 200, "timestamp": "2020-01-01T01:00:00Z"}],
    )

    client = TestClient(app)
    body = client.get("/api/stats").json()
    assert body["totals_by_unit"] == {"ns": 42.0}
    # Job started in 2020 and is still "running", so plenty of GPU-hours have
    # accrued -> budget of $1 at $2/hr should already be crossed.
    assert body["budget_crossed"] is True
    assert body["total_cost_usd"] > 1.0
