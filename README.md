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
  Expect small build errors on first open in Xcode.
- ✅ The Python agent (`agent/`) **was actually run** in this session, in both
  mock mode and a simulated "real" mode reading `nvidia-smi`-shaped
  checkpoint files — see `agent/README.md`. It works.
- ⬜ Nothing has been opened in Xcode, built, run in a simulator, or put on a
  device yet. That's the next step, on a Mac with room for Xcode
  (~40GB free is a safe bet).

## Repo layout

```
BenchTop/                  SwiftUI app (iOS + macOS), generated via XcodeGen
  project.yml               XcodeGen spec — the source of truth for the Xcode project
  Sources/BenchTop/          App code, shared between the iOS and macOS targets
    Models/                   GPUStatus, Job, Campaign/FunnelStage
    Networking/               AgentClient (polls the agent), AgentConfig (host/port)
    State/                    BenchTopStore (polling loop, transition detection)
    Views/                    Dashboard, GPU tile, campaign detail, funnel chart, settings
    Notifications/            Local alerts on job done/failed
  Tests/BenchTopTests/       Model-decoding tests

agent/                     Python (FastAPI) daemon that runs on the rig
  benchtop_agent/            App code — see agent/README.md for how to run it
  sample_data/               Mock data + an example of the real-mode file layout

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
