"""BenchTop agent: serves Rig / Campaign / Job / Alert state over the local
network for the BenchTop iOS/macOS app to render, and advertises itself via
mDNS/Bonjour so the app can find it without a typed-in IP.

Run with:
    uvicorn benchtop_agent.main:app --host 0.0.0.0 --port 8420
"""
from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI

from . import compute, data
from .config import settings
from .discovery import AgentAdvertiser
from .models import Alert, Campaign, Job, Rig

_advertiser = AgentAdvertiser(settings)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # zeroconf's sync API deadlocks if called directly from this event loop
    # (EventLoopBlocked); run it on a worker thread.
    await asyncio.to_thread(_advertiser.start)
    yield
    await asyncio.to_thread(_advertiser.stop)


app = FastAPI(title="BenchTop Agent", lifespan=lifespan)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "mode": "mock" if settings.mock else "live"}


@app.get("/api/rigs", response_model=list[Rig])
def get_rigs() -> list[Rig]:
    return compute.enrich_rigs(data.read_rigs(), data.read_campaigns(), data.read_jobs())


@app.get("/api/campaigns", response_model=list[Campaign])
def get_campaigns() -> list[Campaign]:
    jobs = data.read_jobs()
    campaigns = data.read_campaigns()
    for campaign in campaigns:
        campaign.percent_complete = compute.campaign_percent(campaign, jobs)
    return campaigns


@app.get("/api/jobs", response_model=list[Job])
def get_jobs() -> list[Job]:
    return data.read_jobs()


@app.get("/api/alerts", response_model=list[Alert])
def get_alerts() -> list[Alert]:
    rigs = compute.enrich_rigs(data.read_rigs(), data.read_campaigns(), data.read_jobs())
    return compute.compute_alerts(rigs, data.read_campaigns(), data.read_jobs())
