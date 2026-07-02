"""BenchTop agent: serves GPU + job + campaign + stats state over the local
network for the BenchTop iOS/macOS app to poll, and advertises itself via
mDNS/Bonjour so the app can find it without a typed-in IP.

Run with:
    uvicorn benchtop_agent.main:app --host 0.0.0.0 --port 8420
"""
from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI

from . import gpu, jobs, stats as stats_module
from .config import settings
from .discovery import AgentAdvertiser
from .models import Campaign, GPUStatus, Job, Stats

_advertiser = AgentAdvertiser(settings)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # AgentAdvertiser.start()/stop() call zeroconf's synchronous API, which
    # itself coordinates with a background asyncio loop via
    # run_coroutine_threadsafe — calling it directly from *this* event loop
    # deadlocks (zeroconf raises EventLoopBlocked after its internal
    # timeout). Running it in a worker thread avoids the conflict.
    await asyncio.to_thread(_advertiser.start)
    yield
    await asyncio.to_thread(_advertiser.stop)


app = FastAPI(title="BenchTop Agent", lifespan=lifespan)


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


@app.get("/api/stats", response_model=Stats)
def get_stats() -> Stats:
    return stats_module.compute_stats(jobs.read_jobs(), settings, datetime.now(timezone.utc))
