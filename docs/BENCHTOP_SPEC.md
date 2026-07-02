# BenchTop — product spec

## Background: the pipeline it tracks

A local workstation (RTX 4060 Ti class GPU) runs a continuous
**generate → dock → MD-triage → prune** loop to produce wet-lab-ready drug
shortlists for a target such as SCN5A-R104Q:

1. **Validate a druggable pocket** on the target (e.g. the NTD) from MD frames.
2. **Screen a curated small-molecule library** against that pocket — first the
   ~few-thousand approved drugs (fast, days), then a smart-sampled slice of the
   ~6B Enamine make-on-demand universe using an **ML surrogate** that predicts
   docking scores, so only the hopeful ~0.1% ever get *actually* docked.
3. **MD-triage the survivors** with short runs (~30 min each on a single card)
   to keep only molecules that stay bound and leave the pocket folded.
4. **Hand the final handful to a wet lab.**

A single consumer GPU is enough because the target is small (~22k atoms,
roughly 450–600 ns/day) and the screening is smart-sampled rather than brute
forced.

## The product: BenchTop

BenchTop makes the pipeline's progress visible from a phone or a Mac, without
any cloud dependency.

**Components:**

- **Agent** — a small daemon that runs on the rig itself. It polls `nvidia-smi`
  for live GPU stats and reads job/checkpoint state that the pipeline scripts
  write locally, then serves it as JSON over the local network (Wi-Fi/LAN).
  No cloud, no external accounts.
- **App** — a single SwiftUI codebase targeting iPhone and Mac. It talks to
  the agent over the local network and shows:
  - **Dashboard** — one tile per GPU with a percent-done ring and an ETA
    (the "how's it going / when's it done" question you keep asking).
  - **Campaign detail** — speaks in the pipeline's own terms, e.g.
    *"R104Q MD, 63 ns done, salt-bridge live"*, not generic ML job metadata.
  - **Funnel view** — visualizes the self-pruning shape of a campaign, e.g.
    *"1.2M molecules docked → 4,800 passed MD triage → 5 shortlisted."*
  - **Push/local alerts** for job done, GPU throttling, round complete, a job
    failing (including the OpenMM/CUDA class of failure), or a budget crossed.

**The checkpoint hook:** the pipeline scripts already checkpoint their own
progress. If they append one JSON line per checkpoint (stage, units done,
throughput, timestamp) to a per-job file, any job type shows up in the app
automatically — the agent and app stay generic and don't need to know about
docking or MD specifically.

**Build path:**
- v0 (built): agent (Python/FastAPI) + SwiftUI app talking to it over the
  LAN, with Bonjour/mDNS auto-discovery so host/port entry is a fallback
  rather than the only option; cumulative GPU-hours/$ spent/budget-crossed
  tracking; a macOS menu bar extra so a Mac left running near the rig acts
  as an ambient monitor without a window open; best-effort background
  refresh on iOS.
- Later, deliberately not built here: a watchOS complication (a genuinely
  separate multi-weekend target — new platform, new UI, pairing), richer
  funnel chart interactions, true push notifications (would need an APNs
  relay server, which contradicts the local-network-only design — see
  "Alerting" below for what v0 actually delivers instead).

## Why this matters

The app's job is to make the *dent being made* visible and legible over
months: total ns simulated, molecules screened, shortlist size, cost — the
emotional payoff of running a rig continuously for a long-horizon goal.
`/api/stats` and the dashboard's stats summary card are where this lives:
cumulative GPU-hours, a $ estimate from a configurable rate, an optional
budget with a crossed/not-crossed flag, and totals grouped by whatever unit
each job reports (ns, molecules, ...).

## Alerting: what "push" actually means in v0

There's no cloud/APNs relay by design — the agent and app only ever talk
over the LAN. That has a real consequence for alerts:

- **macOS**: the menu bar extra keeps the app process (and its polling loop)
  alive even with no window open, so local notifications fire whenever the
  app notices a state transition — this is the closest thing to "always on"
  v0 has, and it's genuinely reliable as long as the Mac itself is running.
- **iOS**: `BGAppRefreshTask` gives *best-effort* background polling — iOS
  decides if/when it actually runs based on usage patterns, battery, and
  charging state, which in practice can mean anywhere from ~15 minutes to
  several hours later, or not at all if the app is rarely opened. This is
  the honest ceiling without a push server component, which was ruled out to
  keep the "no cloud" property. If reliable phone alerts matter more than
  "no cloud", that's the tradeoff to revisit later.
- **Foreground, both platforms**: alerts are immediate and reliable — the
  store notices transitions on every poll while the app is open.

## Status

This repository holds a **scaffold that was never opened in Xcode**: data
models, a full-ish SwiftUI app (Dashboard with GPU tiles + stats summary,
Campaign detail with funnel chart, Settings with Bonjour discovery, a macOS
menu bar extra, iOS background refresh), and the Python agent with mock and
real (`nvidia-smi`-backed) data sources, mDNS advertisement, and stats/budget
computation. The agent side has been run and has an automated test suite
(`agent/tests/`, including a real mDNS register→browse round trip — not
just "didn't crash"). The Swift side has been reviewed carefully by hand
(and one systemic decoding bug — see AgentClient's comment on
`convertFromSnakeCase` — was caught this way) but **still never compiled**;
see the root `README.md` for what to do once you're on a Mac with Xcode, and
for which pieces (Bonjour resolution, background refresh, menu bar) are the
most likely to need a fix on first build.
