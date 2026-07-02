# BenchTop

The tracker for one long computational hunt: does the **SCN5A R104Q** variant
destabilize the channel's NTD core, and does **D84N** rescue it? A SwiftUI app
(iPhone + Mac) that renders the science — in science words, not sysadmin words
— plus the small local-network daemon on the rig that feeds it.

Built to the **Comprehensive Tracker Guide** (`benchtop_tracker_guide.md`);
what the repo implements, mapped to that guide, is in
[`docs/BENCHTOP_SPEC.md`](docs/BENCHTOP_SPEC.md). The visual system and all
five screens: [`docs/design/BenchTop-design.html`](docs/design/BenchTop-design.html).

> **Repo name:** this repository is still named `Brugada`, a placeholder from
> before the idea was decided. Rename it under **Settings → General →
> Repository name** (e.g. to `benchtop`). GitHub keeps redirects from the old
> name, so it won't break the remote your local clone points to.

## Status

- ✅ The Python **agent** (`agent/`) is built and **actually run/tested** — the
  home-is-free cost rule, the weighted campaign %, the alert rules, checkpoint
  → sparkline building, and a genuine mDNS register → browse round trip. 15
  passing tests (`agent/tests/`).
- ✅ The **app** is written against the *exact* JSON the agent emits (verified
  field-by-field) but **has never been compiled** — there's no Swift toolchain
  in this environment. Expect small first-build fixes in Xcode; the sparkline
  drawing, Bonjour discovery, menu bar, and background refresh are the newest
  pieces.
- ⬜ Not yet opened in Xcode, run in a simulator, or put on a device — that's
  the next step, on a Mac with room for Xcode (~40 GB free is safe).

## Repo layout

```
BenchTop/                  SwiftUI app (iOS + macOS), generated via XcodeGen
  project.yml               XcodeGen spec — the source of truth for the Xcode project
  Sources/BenchTop/
    DesignSystem.swift        Colour/type/spacing tokens (asset-catalog colours)
    Models/                   Rig, Campaign (+Stage, LiveResult), Job (+JobMetric), Alert
    Networking/               AgentClient, AgentConfig, AgentDiscovery (Bonjour)
    State/                    BenchTopStore (polling loop + alert notifications)
    Views/                    Home, Campaign detail, Job detail, Funnel (+wall),
                               Alerts, Settings, sparkline, menu bar summary
    Notifications/            Local alerts when a new alert appears
    Platform/                 macOS AppDelegate + iOS background refresh
  Tests/BenchTopTests/       Model-decoding tests (mirror the agent's JSON)

agent/                     Python (FastAPI) daemon that runs on the rig
  benchtop_agent/
    models.py                 Rig / Campaign / Job / Alert schemas
    data.py                   reads rigs/campaigns/jobs; merges nvidia-smi + checkpoints
    compute.py                campaign %, honest per-rig spend, alert derivation
    discovery.py              mDNS/Bonjour advertisement (best-effort, optional dep)
  sample_data/               The R104Q journey (mock) + a real-mode file layout example
  tests/                     pytest suite — 15 tests, incl. a real mDNS round trip

docs/BENCHTOP_SPEC.md            What the repo implements, mapped to the guide
docs/design/BenchTop-design.html The visual system + all five screens
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
   point the app's Settings tab at `localhost:8420` to see the full R104Q
   journey without needing a GPU rig or a second device. The agent advertises
   itself over mDNS, so Settings should also list it under "Found on this
   network".
6. On macOS, closing the window shouldn't quit the app — look for the menu bar
   icon; it shows the active campaign, spend, and temp at a glance.

## Why this shape

- **XcodeGen instead of a hand-committed `.xcodeproj`**: `.xcodeproj` files
  are fragile, mostly-generated XML with unique IDs that are painful to hand
  edit correctly without Xcode itself to validate them — and there was no
  Xcode available to generate or verify one in this session. `project.yml`
  is plain text, diffs cleanly, and Xcode/XcodeGen do the fiddly part.
- **Local network + local daemon, no cloud**: the rig and your phone/Mac are
  on the same LAN; there's no reason to round-trip through a cloud service
  for something like GPU temperature.
- **Checkpoint-line hook**: the rig-side scripts append one JSON line per
  heartbeat (`units_done, metric_value, temp, util`) to a per-job `.jsonl`.
  That single append drives the sparklines — the agent and app never need to
  know what MD or docking *is*.
- **The honesty rules, rendered**: home GPU-hours are free (kWh, never
  dollars); the funnel always draws the **SIMULATION WALL** between what a GPU
  can answer and what only a wet lab can; % is of the computational journey,
  never "% to cure". These aren't cosmetic — they're the point.
- **Local network + local daemon, no cloud**: the rig and your phone/Mac share
  a LAN; there's no reason to round-trip GPU temperature through a cloud.
