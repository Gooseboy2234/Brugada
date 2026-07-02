# BenchTop — what this repo implements

BenchTop turns *"is my GPU still doing something useful, and how far is my
cure project?"* into a glance — in science words, not sysadmin words — for one
specific hunt: does the **SCN5A R104Q** variant destabilize the channel's NTD
core, and does **D84N** rescue it?

This document maps the build to the source of truth, the **Comprehensive
Tracker Guide** (`benchtop_tracker_guide.md`). Where they differ, the guide
wins.

## The three questions, in priority order

1. **Is the science moving?** — which hypothesis is being tested, how far along.
2. **Is the money safe?** — burn rate, projected total, credit remaining.
3. **Is the machine healthy?** — GPU temp/util/VRAM — *last*, because when
   things are fine it's the least interesting.

Every screen and every rig card is ordered this way on purpose.

## Data model — Rig → Campaign → Job → Checkpoint

Mirrored on both sides (`agent/benchtop_agent/models.py` ↔
`BenchTop/Sources/BenchTop/Models`):

- **Rig** — one machine (home 4060 Ti, or a cloud/Modal sandbox). Carries GPU
  model, VRAM, live temp/util/power, `$/hr`, `is_cloud`, uptime. **The honesty
  rule lives here:** cloud rigs show real dollars; home rigs show `$0.00 ·
  home = free` plus kWh. The app never pretends home GPU-hours cost money.
- **Campaign** — one scientific question. Carries the one-sentence
  **hypothesis**, the cure-journey **funnel**, a **live result** (the number
  you actually care about, per system), a **so-what** verdict slot, and a
  weighted **% of the computational journey** (never "% to cure").
- **Job** — one concrete run. Carries tag, kind (md/fep/docking/folding),
  status, units done vs target, ns/day + ETA (with its confidence window),
  `$` spent, and **the one metric that matters for its type** with a
  sparkline (MD → salt-bridge distance, FEP → ΔΔG, docking → best score,
  folding → pLDDT), plus resource sparklines and a log tail.
- **Checkpoint** — the rig-side heartbeat (`{units_done, metric_value, temp,
  util}` appended to `checkpoints/<job_id>.jsonl`). It drives the sparklines.
  That single append is the whole integration contract.

## Screens

- **Home** — one card per rig: active campaign + % + ETA (science), the honest
  spend line (money), temp/util/vram + alert count (machine).
- **Campaign** — hypothesis, a "you are here" journey strip, the **live
  result** with per-system sparklines (core RMSF: WT / R104Q / rescued), the
  job list, and the **so-what** verdict.
- **Job** — status + honest ETA ("based on last 20 min"), the **metric that
  matters** with a big value + sparkline, resource sparklines, and a
  collapsible log tail.
- **Funnel** — the whole cure journey as one pipeline, with the
  **SIMULATION WALL**: a hard, always-drawn line between what a GPU can tell
  you (above) and what only a wet lab can (below). Tap any stage for its
  honest caveat. This is the honesty contract, rendered.
- **Alerts** — rare and meaningful only: a failure with its real error, a
  budget nearing its cap, a batch completing. Normal is silent.

## The three "for scientists, not sysadmin" things

1. **ETA is first-class and honest** — from measured ns/day, with its
   confidence window, never a spinner.
2. **Every run shows its scientific heartbeat** — the salt bridge, the ΔΔG —
   not just GPU%.
3. **The funnel refuses to lie** — the wall is always drawn; % is of the
   computational journey; every stage carries its caveat.

## Transport & privacy

Local network only. The rig-side agent serves JSON over the LAN and advertises
itself via mDNS/Bonjour; the app polls it (pull-to-refresh). No cloud, no
account. See `agent/README.md`.

## Status

The **agent** is built and tested (`agent/tests/`, run in CI-less mock mode
here — home-is-free cost, the weighted campaign %, the alert rules, checkpoint
sparklines, and a real mDNS round trip). The **app** is written against the
exact JSON the agent emits (verified field-by-field) but **has never been
compiled** — there is no Swift toolchain in the build environment. See the
root `README.md` for first-build steps on a Mac. The visual system and all
five screens are in `docs/design/BenchTop-design.html`.
