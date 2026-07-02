# BenchTop — Comprehensive Tracker Guide (iOS + macOS)
### What a live tracker would show for *this* journey: SCN5A R104Q → computed cure hypothesis

*Companion to `gpu_tracker_app_concept.md`. That doc was the architecture pitch; this one is the
screen-by-screen content spec, mapped to the real R104Q project so you can see exactly what each view
would display at each stage of the work.*

---

## 0. The one-sentence purpose

> **BenchTop turns "is my $2/hr GPU still doing something useful, and how far is my cure project?" into
> a glance — in science words, not sysadmin words.**

It answers three questions, in this priority order:
1. **Is the science moving?** (which hypothesis is being tested right now, how far along)
2. **Is the money safe?** (burn rate, projected total, credit remaining)
3. **Is the machine healthy?** (GPU temp, util, VRAM, thermals) — last, because it's the least interesting when things are fine.

---

## 1. The data model (what the app actually tracks)

Three nested objects. Everything on every screen is a view into these.

```
Rig                     ← one physical machine (your 4060 Ti box, or a Modal sandbox)
 └─ Campaign            ← one scientific question ("Does R104Q destabilize the NTD?")
     └─ Job             ← one concrete run (WT 100 ns MD, seed 1)
         └─ Checkpoint  ← periodic heartbeat (ns done, current metric value, temp)
```

- A **Rig** has: name, GPU model, VRAM, current temp/util/power, $/hr rate, uptime.
- A **Campaign** has: the hypothesis in one sentence, a funnel stage, % complete, list of jobs, a
  "so-what" verdict slot (filled when done).
- A **Job** has: tag, status (queued/running/done/failed), ns or ligands done vs target, ns/day,
  ETA, $ spent so far, the ONE metric that matters for this job type, and a spark-line of that metric.
- A **Checkpoint** is what the rig-side daemon emits every N seconds → drives the live spark-lines.

The daemon on the rig writes a `campaign.json` next to each run; the app just renders it. No cloud,
no account — LAN WebSocket + optional push relay for alerts when you're away.

---

## 2. Screen-by-screen — what it shows for the R104Q journey

### 2.1 HOME (the glance)
The screen you check 20× a day. One card per rig.

```
┌─────────────────────────────────────────────┐
│  🖥  Home Rig — RTX 4060 Ti 16 GB            │
│                                               │
│  ▶ R104Q · MD replicates          72% ▓▓▓▓▓░  │
│    seed 2 of 3 · WT+R104Q+rescued             │
│    ETA 3h 41m · 611 ns/day · 61 °C            │
│                                               │
│  This week: ████████░░  $0.00 (home = free)   │
│  ⚠ 0 alerts                                   │
└─────────────────────────────────────────────┘
```

What each line means for you:
- **`▶ R104Q · MD replicates`** — the CAMPAIGN, not the job. You care "which question," not "which .py".
- **`72%`** — averaged across the 9 replicate jobs (3 systems × 3 seeds), weighted by ns done.
- **`611 ns/day`** — your card's real measured throughput (Modal L4 hit 770–783; the 4060 Ti will be a
  bit lower — the app learns YOUR number after the first job and stops guessing).
- **`$0.00`** — home rig is electricity-only; the app shows kWh instead of dollars for local rigs, and
  real dollars only for cloud (Modal) rigs. This is the honesty feature: it never pretends home GPU-hours cost Modal money.

### 2.2 CAMPAIGN DETAIL (the "what's the story" view)
Tap the card. This is where the science lives.

```
  R104Q · MD replicates
  ───────────────────────────────────────────
  HYPOTHESIS
  "R104Q destabilizes the NTD core; D84N rescues it."

  FUNNEL          ● built → ● flagship → ◐ replicates → ○ FEP → ○ wet-lab
                                          you are here

  LIVE RESULT (updates as frames land)
     core RMSF (res 55–85), Å
     WT      ▁▁▂▂▂  3.9  (n=1 so far this batch)
     R104Q   ▃▄▅▅▅  5.4  ← +37% vs WT
     rescued ▁▁▁▁▁  3.1  ← most rigid

  JOBS (9)
     WT   seed1 ✅  seed2 ▶ 72%  seed3 ⏸ queued
     R104Q seed1 ✅  seed2 ▶ 68%  seed3 ⏸ queued
     resc seed1 ✅  seed2 ▶ 74%  seed3 ⏸ queued

  SO-WHAT  (fills in when batch completes)
     "±error bars pending — need all 3 seeds."
```

The point: **the number you actually care about (core RMSF gap) is on the campaign screen, live, with
error bars appearing as replicates finish.** Not buried in a log file you SSH in to `tail`.

### 2.3 JOB DETAIL (the "is this one run OK" view)
For when something looks off and you want to look closer.

```
  WT · MD · seed 2
  ───────────────────────────────────────────
  status ▶ running       48.2 / 100 ns
  ETA 3h 41m             611 ns/day
  GPU 61 °C · 94% util · 11.2/16 GB VRAM · 168 W

  THE METRIC THAT MATTERS (this job = MD)
     R104–D84 min distance, Å        [spark-line, live]
     ▂▂▃▂▂▄▅▃▂▂  current 3.1 Å · 58% occupancy <4 Å

  RESOURCES     temp ▁▁▂▂▂▃▃  util ▇▇▇▇▇▇▇
  LOG TAIL      [last 5 lines, collapsible]
```

Job-type-aware "metric that matters":
- **MD job** → salt-bridge distance + occupancy live.
- **FEP job** → ΔΔG running estimate + convergence (does the free-energy curve flatten?).
- **Docking job** → best score so far + #ligands screened + ligands/sec.
- **Folding job** → pLDDT of best model so far.

This is the "speaks science" promise: each run shows its OWN scientifically meaningful heartbeat, not
just a generic progress bar.

### 2.4 FUNNEL VIEW (the "how close to the finish line" view)
The whole cure journey as one pipeline. This is the view you screenshot to explain the project to someone.

```
  THE R104Q FUNNEL

  ✅ 1  Structure & mechanism        8VYJ · R104–D84 3.79 Å salt bridge
  ✅ 2  Variant scoring              ESM −3.57 · AM 0.869 · REVEL 0.967
  ✅ 3  Static models WT/mut/rescue   built + minimized
  ✅ 4  Flagship MD (n=1)            core RMSF 3.98→5.46→3.09 ✓ mechanism
  ◐ 5  MD replicates (n=3)          ← error bars, THE current gap
  ○ 6  FEP ΔΔG_fold                 thermodynamic number on hypothesis
  ○ 7  Chaperone re-rank (DiffDock)  size-bias-free mexiletine test
  ○ 8  ─────── SIMULATION WALL ───────
  ○ 9  Wet-lab: patch-clamp / trafficking / dom-neg vs haploinsufficiency
  ○ 10 Clinical (ICD already protects — this is the real safeguard today)
```

The **SIMULATION WALL** line is deliberate and honest: it draws a hard visual boundary between "things a
GPU can tell you" (stages 1–7) and "things only a wet-lab can" (9–10). The app never lets the funnel
*look* like a GPU can finish the cure. That's the honesty contract, rendered.

### 2.5 ALERTS (the "tap me when I need to care" view)
Push notifications, tuned to be rare and meaningful:
- ✅ **"WT seed 2 done — 100 ns in 3h 55m"** (job complete)
- 🎉 **"MD replicate batch complete — core RMSF gap +37% ± 4% holds"** (campaign milestone)
- ⚠️ **"R104Q seed 3 threw: CUDA OOM at 8 ns"** (job failed — with the actual error)
- 🔥 **"GPU 87 °C for 10 min — throttling likely"** (thermal)
- 💸 **"Modal spend hit $25 — approaching your $30 cap"** (budget, cloud rigs only)

Rule: **an alert either means "good news you were waiting for" or "something needs your hand." Never
"FYI the GPU is at 94% util" — that's normal, and normal is silent.**

---

## 3. The three things that make it "for scientists," not a sysadmin dashboard

1. **ETA is first-class and honest.** Computed from measured ns/day (or ligands/sec), not a spinner.
   And it degrades gracefully: "ETA 3h 41m (based on last 20 min)" — it tells you how confident it is.
2. **Every run shows its scientific heartbeat**, not just CPU%/GPU%. The MD run shows the salt bridge;
   the docking run shows the best hit. You see the *science* converging, live.
3. **The funnel refuses to lie.** The simulation wall is always drawn. % complete is % of the
   *computational* journey, never labeled "% to cure." Hover any stage → the honest caveat for that stage.

---

## 4. What it would look like RIGHT NOW for your project

If BenchTop existed today and you opened it this second:

- **Home:** one rig (Modal, now idle — flagship MD finished). Home 4060 Ti not yet connected.
- **Campaign "R104Q · flagship MD":** funnel at stage 4 ✅, SO-WHAT filled:
  *"R104Q +37% core RMSF; D84N rescues below WT. n=1 — replicates needed."*
- **Next-up banner:** "Stage 5 — MD replicates. Est 9 jobs × ~4 h on your 4060 Ti ≈ 1.5 days wall.
  Home rig = free. Tap to generate run bundle." ← the app would hand you the exact next action.
- **Budget:** Modal ~$25 spent / $30 cap · $5 left · flag: "downstream is CPU/free."

---

## 5. Build path (unchanged from concept doc, recapped)

- **v0 (a weekend):** rig-side Python daemon (`nvidia-smi` + reads each run's `campaign.json`) → serves
  JSON over LAN WebSocket. SwiftUI app: Home + Job Detail only. Pull-to-refresh. No push yet.
- **v1:** Campaign + Funnel views, job-type-aware metric cards, local push via APNs relay.
- **v2:** multi-rig, historical charts, the "generate next run bundle" button (deep-links to your
  staged `gpu_bundles.tar.gz`), Modal cost integration.

The daemon is the whole trick: if every run writes a small `campaign.json` heartbeat (tag, hypothesis,
ns done, current metric, temp), the app is "just" a renderer — which is why v0 is a weekend, not a month.
