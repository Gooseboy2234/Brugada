"""BenchTop agent: serves GPU + job + campaign state over the local network
for the BenchTop iOS/macOS app to poll.

Run with:
    uvicorn benchtop_agent.main:app --host 0.0.0.0 --port 8420
"""
from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import gpu, jobs
from .config import settings
from .models import Campaign, GPUStatus, Job

app = FastAPI(title="BenchTop Agent")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "mode": "mock" if settings.mock else "live"}


@app.get("/api/gpus", response_model=list[GPUStatus])
def get_gpus() -> list[GPUStatus]:
    gpus = gpu.read_gpus()
    running_jobs = {j.gpu_id: j.id for j in jobs.read_jobs() if j.status == "running" and j.gpu_id}
    for g in gpus:
        g.current_job_id = running_jobs.get(g.id)
    return gpus


@app.get("/api/jobs", response_model=list[Job])
def get_jobs() -> list[Job]:
    return jobs.read_jobs()


@app.get("/api/campaigns", response_model=list[Campaign])
def get_campaigns() -> list[Campaign]:
    return jobs.read_campaigns()
