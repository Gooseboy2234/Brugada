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
- v0: agent (Python/FastAPI) + SwiftUI app talking to it over the LAN using
  manually entered host/port. A genuine weekend build.
- Later: Bonjour/mDNS auto-discovery of the agent on the LAN, richer funnel
  charts, a watchOS complication, push notifications proper (still local-only,
  no external push service needed since the agent and app share a network).

## Why this matters

The app's job is to make the *dent being made* visible and legible over
months: total ns simulated, molecules screened, shortlist size, cost — the
emotional payoff of running a rig continuously for a long-horizon goal.

## Status

This repository currently holds the **scaffold only**: data models, a talking
skeleton for the SwiftUI app (Dashboard / Campaign detail / Funnel / Settings
views with no real data wired up beyond the agent's sample/mock mode), and the
Python agent with mock and real (`nvidia-smi`-backed) data sources. Nothing
here has been built or run on an actual Mac/iPhone yet — see the root
`README.md` for what to do once you're on a Mac with Xcode.
