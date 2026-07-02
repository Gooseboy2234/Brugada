from fastapi.testclient import TestClient

from benchtop_agent.main import app


def test_health():
    r = TestClient(app).get("/api/health")
    assert r.status_code == 200 and r.json()["status"] == "ok"


def test_rigs_endpoint_enriches_cost():
    rigs = TestClient(app).get("/api/rigs").json()
    home = next(r for r in rigs if r["id"] == "home")
    assert home["cost_this_week"] == 0.0  # home is free
    assert home["energy_kwh_this_week"] > 0
    modal = next(r for r in rigs if r["is_cloud"])
    assert modal["cost_this_week"] > 0


def test_campaigns_endpoint_fills_percent():
    campaigns = TestClient(app).get("/api/campaigns").json()
    r104q = next(c for c in campaigns if c["id"] == "r104q-replicates")
    assert r104q["percent_complete"] is not None
    assert 0 < r104q["percent_complete"] <= 1
    assert any(s["is_wall"] for s in r104q["funnel"])


def test_jobs_endpoint_shape():
    jobs = TestClient(app).get("/api/jobs").json()
    running = next(j for j in jobs if j["status"] == "running")
    assert running["metric"]["sparkline"]
    assert running["rate_per_day"]


def test_alerts_endpoint_surfaces_failure_and_budget():
    alerts = TestClient(app).get("/api/alerts").json()
    kinds = {a["kind"] for a in alerts}
    assert "job_failed" in kinds  # R104Q seed 3 CUDA OOM
    assert "budget" in kinds      # Modal $25 / $30
