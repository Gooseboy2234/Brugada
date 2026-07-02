# BenchTop

A SwiftUI app (iPhone + Mac) that watches a local GPU rig run a
generate → dock → MD-triage → prune drug-discovery pipeline, plus the small
local-network daemon it talks to. Full concept: [`docs/BENCHTOP_SPEC.md`](docs/BENCHTOP_SPEC.md).

> **Repo name:** this repository is still named `Brugada`, a placeholder from
> before the actual idea was decided. There's no API to rename a GitHub repo
> from here — rename it yourself under the repo's **Settings → General →
> Repository name** (e.g. to `benchtop`). GitHub keeps redirects from the old
> name automatically, so this won't break the remote your local clone points
> to.

## Status

This is a **scaffold, built and validated without a Mac** (this session runs
on Linux, with no Xcode/Swift toolchain available). What that means
concretely:

- ✅ Swift models, views, networking, and state layer are written and
  believed correct, but **never compiled** — there's no Swift toolchain here.
  Expect small build errors on first open in Xcode. The Bonjour discovery
  client (`AgentDiscovery.swift`), the macOS menu bar extra, and iOS
  background refresh are the newest and least-battle-tested pieces — flagged
  in-file with why.
- ✅ The Python agent (`agent/`) **was actually run** in this session — mock
  mode, a simulated "real" mode reading `nvidia-smi`-shaped checkpoint
  files, the `/api/stats` budget/cost computation, and a genuine mDNS
  register → independently browse round trip (not just "didn't throw"; see
  `agent/README.md` and `agent/tests/`). It works, and has 19 passing tests.
- ⬜ Nothing has been opened in Xcode, built, run in a simulator, or put on a
  device yet. That's the next step, on a Mac with room for Xcode
  (~40GB free is a safe bet).

## Repo layout

```
BenchTop/                  SwiftUI app (iOS + macOS), generated via XcodeGen
  project.yml               XcodeGen spec — the source of truth for the Xcode project
  Sources/BenchTop/          App code, shared between the iOS and macOS targets
    Models/                   GPUStatus, Job, Campaign/FunnelStage, Stats
    Networking/               AgentClient (polls the agent), AgentConfig (host/port),
                               AgentDiscovery (Bonjour/mDNS pick list)
    State/                    BenchTopStore (polling loop, transition + budget alerts)
    Views/                    Dashboard, stats summary, GPU tile, campaign detail,
                               funnel chart, settings, macOS menu bar summary
    Notifications/            Local alerts on job done/failed/budget crossed
    Platform/                 macOS AppDelegate (stay running with no window open),
                               iOS background refresh (BGTaskScheduler)
  Tests/BenchTopTests/       Model-decoding tests

agent/                     Python (FastAPI) daemon that runs on the rig
  benchtop_agent/            App code — see agent/README.md for how to run it
    stats.py                   GPU-hours / cost / budget / per-unit totals (pure function)
    discovery.py                mDNS/Bonjour advertisement (best-effort, optional dep)
  sample_data/               Mock data + an example of the real-mode file layout
  tests/                     pytest suite — 19 tests, all passing, incl. a real mDNS round trip

docs/BENCHTOP_SPEC.md      The product spec/concept this was scaffolded from
```

## When you're on a Mac: first build

1. Install Xcode (App Store) and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
   (`brew install xcodegen`). XcodeGen generates the `.xcodeproj` from
   `project.yml` — that file is committed, the generated project is not
   (see `.gitignore`), so it's regenerated fresh each time and never goes
   stale relative to the file list.
2. From `BenchTop/`, run:
   ```bash
   xcodegen generate
   open BenchTop.xcodeproj
   ```
3. Pick the `BenchTop-macOS` scheme and hit Run first — fastest feedback loop,
   no simulator/device needed. Fix whatever Xcode complains about (there will
   likely be a few small things — this was never compiled).
4. Then try `BenchTop-iOS` in the Simulator, and finally on your iPhone (you'll
   need to set a development team under **Signing & Capabilities** for a
   device build).
5. Start the agent (see `agent/README.md`) in mock mode on the same Mac and
   point the app's Settings sheet at `localhost:8420` to see it come alive
   without needing the actual GPU rig or an iPhone/Mac on the same network.
   The agent advertises itself over mDNS by default, so Settings should also
   list it under "Found on this network" — that's the Bonjour discovery path
   and worth checking specifically since it's the least-tested piece.
6. On macOS, closing the window shouldn't quit the app — look for the new
   menu bar icon; clicking it should show the same GPU/job summary. If the
   app does quit on window close, `MacAppDelegate` isn't wired up correctly.

## Why this shape

- **XcodeGen instead of a hand-committed `.xcodeproj`**: `.xcodeproj` files
  are fragile, mostly-generated XML with unique IDs that are painful to hand
  edit correctly without Xcode itself to validate them — and there was no
  Xcode available to generate or verify one in this session. `project.yml`
  is plain text, diffs cleanly, and Xcode/XcodeGen do the fiddly part.
- **Local network + local daemon, no cloud**: the rig and your phone/Mac are
  on the same LAN; there's no reason to round-trip through a cloud service
  for something like GPU temperature.
- **Checkpoint-line hook**: the pipeline scripts just append one JSON line
  per checkpoint to a per-job file. Any job type shows up in the app
  automatically — the agent and app never need to know what docking or MD
  simulation *is*.
- **No watchOS target**: the spec itself calls this out as a separate,
  multi-weekend later step (new platform, new UI, pairing) rather than part
  of the v0 weekend build — pulling it in now would be scope creep, not
  completeness.
- **No CORS middleware on the agent**: it was in an earlier version and got
  removed — CORS is a browser concept (preflight checks enforced by
  browsers), and native `URLSession`/`NWConnection` clients never trigger it.
  It was dead code.
