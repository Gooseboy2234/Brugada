from benchtop_agent import jobs as jobs_module
from benchtop_agent.config import Settings
from tests.conftest import write_checkpoints, write_manifest

MANIFEST_ENTRY = {
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


def _read(settings: Settings, manifest_entry: dict, checkpoint_lines: list[dict], monkeypatch) -> jobs_module.Job:
    monkeypatch.setattr(jobs_module, "settings", settings)
    write_manifest(settings.data_dir, [manifest_entry])
    if checkpoint_lines:
        write_checkpoints(settings.data_dir, manifest_entry["id"], checkpoint_lines)
    result = jobs_module.read_jobs()
    assert len(result) == 1
    return result[0]


def test_progress_comes_from_latest_checkpoint(real_mode_settings, monkeypatch):
    job = _read(
        real_mode_settings,
        MANIFEST_ENTRY,
        [
            {"stage": "Equilibration", "units_done": 5, "units_total": 200, "timestamp": "2026-06-30T13:00:00Z"},
            {"stage": "Production", "units_done": 63, "units_total": 200, "timestamp": "2026-07-01T02:00:00Z"},
        ],
        monkeypatch,
    )
    assert job.stage == "Production"
    assert job.units_done == 63
    assert job.status == "running"


def test_no_checkpoint_falls_back_to_manifest(real_mode_settings, monkeypatch):
    job = _read(real_mode_settings, MANIFEST_ENTRY, [], monkeypatch)
    assert job.stage == "queued"
    assert job.units_done == 0
    assert job.status == "running"


def test_status_inferred_completed_when_units_reach_total(real_mode_settings, monkeypatch):
    job = _read(
        real_mode_settings,
        MANIFEST_ENTRY,
        [{"stage": "Production", "units_done": 200, "units_total": 200, "timestamp": "2026-07-02T00:00:00Z"}],
        monkeypatch,
    )
    assert job.status == "completed"


def test_status_not_inferred_completed_without_units_total(real_mode_settings, monkeypatch):
    job = _read(
        real_mode_settings,
        MANIFEST_ENTRY,
        [{"stage": "Screening", "units_done": 999999, "timestamp": "2026-07-02T00:00:00Z"}],
        monkeypatch,
    )
    assert job.status == "running"


def test_checkpoint_can_explicitly_report_failure(real_mode_settings, monkeypatch):
    job = _read(
        real_mode_settings,
        MANIFEST_ENTRY,
        [
            {
                "stage": "Docking",
                "units_done": 2100,
                "units_total": 4800,
                "status": "failed",
                "error_message": "OpenMM CUDA context creation failed",
                "timestamp": "2026-06-25T14:00:00Z",
            }
        ],
        monkeypatch,
    )
    assert job.status == "failed"
    assert job.error_message == "OpenMM CUDA context creation failed"


def test_manifest_failed_status_is_sticky_even_if_units_still_climbing(real_mode_settings, monkeypatch):
    failed_entry = {**MANIFEST_ENTRY, "status": "failed"}
    job = _read(
        real_mode_settings,
        failed_entry,
        [{"stage": "Docking", "units_done": 100, "units_total": 4800, "timestamp": "2026-06-25T14:00:00Z"}],
        monkeypatch,
    )
    assert job.status == "failed"


def test_missing_manifest_returns_empty_list(real_mode_settings, monkeypatch):
    monkeypatch.setattr(jobs_module, "settings", real_mode_settings)
    assert jobs_module.read_jobs() == []


def test_mock_mode_reads_bundled_sample_data(monkeypatch):
    mock_settings = Settings(mock=True)  # defaults to the bundled sample_data dir
    monkeypatch.setattr(jobs_module, "settings", mock_settings)
    result = jobs_module.read_jobs()
    assert any(job.id == "job-42" for job in result)
