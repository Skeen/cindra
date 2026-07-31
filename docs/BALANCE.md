# Cindra — balance math (deriving the `(tune)` values)

Concrete starting numbers for every `(tune)` value in [`DESIGN.md`](../DESIGN.md)
§7 / §16, **derived, not vibed**. The spine of the derivation (spec §10) is:

> Set the surface solar multiplier by working **backwards from the lava recipe
> energy cost**, so baseline solar funds the lava tax + the downstream chain +
> a margin that beats Vulcanus free-lava net productivity, while keeping the
> ~100× flare a windfall that is unreachable on baseline.

Everything below hangs off one anchor — the electrical cost of a unit of
manufactured lava — and propagates outward to solar, flare, storage, the
heater, and the stone loop. Each result is a **starting** value with a lever and
a sensitivity note; the balance pass (`ci-63d`) tunes against playtest, this doc
gives it a defensible origin instead of a guess.

This is an analysis deliverable (no prototype/runtime change), so it ships
without a test; the arithmetic identities it asserts are reproducible from the
anchors table and can be re-derived by any track that consumes them.

---

## Balance-pass reconciliation (ci-63d, §15-14) — read this first

The balance pass (`ci-63d`) validated the shipped numbers against real end-to-end
throughput (via `tests/test_balance_audit.lua`, all rates derived LIVE from the
prototypes) and corrected the places where the code had moved past this doc's
first-principles derivation. The load-bearing corrections:

- **The lava spine is a DEDICATED manufacturer, not a lava-making foundry.** §1
  below derives "a foundry converts 2.5 MW → 1.333 lava/s → ~94 lava-foundries
  per melt line." That predates the `cindra-lava-manufacturer` (ci-e8a) and the
  ci-4ee spazz fix. The SHIPPED spine is `64 stone → 320 lava` at
  `energy_required = 30`, `crafting_speed 2`, `40 MW` draw = **21.3 lava/s per
  manufacturer**, so **~6 manufacturers feed one melting foundry** — single-digit,
  and exactly the "~100 machines per foundry" absurdity this pass exists to
  prevent. `test_lava` + `test_balance_audit` guard the single-digit ratio LIVE.
  (The §1 `E_lava/8` energy-per-lava identity still holds in spirit; the shipped
  `energy_per_lava` is ~1.875 MJ/lava, guarded by `test_lava`.)
- **Baseline solar is 330 kW, not 60 kW; the flare swing is ~18×, not 100×.** §2
  derives a 60 kW floor (1% of the 6 MW peak = a literal 100× swing). Shipped
  reality (ci-ezk, then this pass): the floor is re-based UP to a real surplus and
  tuned to the additive target **"Vulcanus (240 kW) + 100-200 percentage points of
  Nauvis" = 330 kW** (`+150 pp`, NOT a 2-3× multiple). The 6 MW peak is unchanged,
  so the swing is **~18×**. The `<100%`-catchable rule (§4) is unaffected (sized
  against the 6 MW peak) and still holds. Guarded by `test_solar_magnitude` (the
  +100-200 pp bound is checked live against a real Vulcanus panel) and `test_flare`.
- **Methanol rocket fuel was energy-POSITIVE; cut `-> 10` to `-> 1`.** DESIGN §8.6
  flagged (ci-6vj S6) that `50 methanol → 10 rocket-fuel` yields ~1000 MJ of
  fuel_value for ~104 MJ of electricity — a burn-back profit that breaks the
  "terminal sink, never an energy loop" invariant. This pass cut the yield to
  `-> 1` (~104 MJ in vs 100 MJ out, robustly net-negative like ALICE), guarded by
  a live energy-balance test in `test_plastics` that fails on the old graph.
- **Open item #1 (verify the assumed anchors) is closed.** The molten-recipe
  `energy_required` and the 10/15 stone byproduct are no longer "cited, not
  measured": `test_lava` + `test_balance_audit` read them live from the shipped
  recipes, so the lava→foundry ratio and the stone-negativity proof track reality.

The rest of this doc is the original derivation, kept for its reasoning; where a
number here disagrees with the four points above, the shipped value + its test win.

---

## 0. Anchors (measured / cited, not chosen)

| Anchor | Value | Source |
|---|---|---|
| Foundry electric draw | **2.5 MW** | [Foundry — Factorio Wiki](https://wiki.factorio.com/Foundry); confirmed in `prototypes/lava.lua` |
| Foundry crafting speed | **4×** | Factorio Wiki (Foundry) |
| Foundry built-in productivity | **+50%** (applies to the melt/cast steps; **off** for `cindra-lava`) | Wiki; `lava.lua` sets `allow_productivity=false` on lava |
| Lava recipe | `1 stone → 5 lava`, `energy_required = 15` | `prototypes/lava.lua` (`STONE_IN`/`LAVA_OUT`/`ENERGY_REQUIRED`) |
| Molten-iron-from-lava | `500 lava + 1 calcite → 250 molten iron + 10 stone` | `DESIGN.md` §7; `lava.lua` byproduct note |
| Molten-copper-from-lava | `500 lava + 1 calcite → 250 molten copper + 15 stone` | `DESIGN.md` §7; `lava.lua` |
| Molten → plate casting | `20 molten → 2 plates` (10 molten / plate) | [Foundry — Factorio Wiki](https://wiki.factorio.com/Foundry) |
| Solar panel @ 100% | **60 kW** (Nauvis full day) | [Solar panel — Factorio Wiki](https://wiki.factorio.com/Solar_panel) |
| `solar-power` surface property | percentage of Nauvis (Nauvis 100, Vulcanus 400) | Factorio Wiki / Space Age surface properties |
| Accumulator (vanilla) | **5 MJ** capacity, **300 kW** throughput, 2×2 | Factorio Wiki |
| Cindra day-night cycle | **300 s** (`5 * minute`) | `prototypes/planet.lua` |
| Mass-driver shot | **500 MJ** buffer, **10 MW** charge (~50 s/shot) | `prototypes/mass-driver.lua` |
| Electric heater | draw **40 MW**, heat cap **600 °C** | `prototypes/electric-heater.lua` |

Two anchors are cited from `DESIGN.md`/`lava.lua` rather than the live install
(the Factorio data dir is gitignored and absent in this worktree): the
molten-recipe **energy_required** (assumed ~16 s, per the `lava.lua` comment) and
the **stone byproduct** (10 / 15). Both only affect second-order terms below and
are flagged where used — verify against the real recipes during `ci-63d`.

---

## 1. The anchor — what a unit of lava costs in electricity

`cindra-lava` is crafted in the foundry with productivity **disabled**, so its
cost is pure power:

```
craft_time   = energy_required / crafting_speed = 15 / 4      = 3.75 s
energy/craft = foundry_draw × craft_time = 2.5 MW × 3.75 s    = 9.375 MJ   (per 5 lava)
cost/lava    = 9.375 MJ / 5                                   = 1.875 MJ / lava
```

Generalising over the lever `E_lava` (`= energy_required`, the *only* cost knob,
per the "power is the lever" design):

> **cost/lava = (2.5 MW × E_lava / 4) / 5 = E_lava / 8   MJ/lava**

At the shipped `E_lava = 15` → **1.875 MJ/lava**. This single number drives
everything downstream. Equivalent power form: a foundry dedicated to lava is a
fixed converter of **2.5 MW → 1.333 lava/s**, i.e. **1.875 MW per (lava/s)**.

### Cost of metal (propagating the anchor)

One iron plate needs `20 lava` (500 lava → 250 molten → 25 plates):

```
lava power / plate = 20 × 1.875 MJ                 = 37.5  MJ
melt step / plate  = 2.5 MW × (16 s/4) / 25 plates ≈ 0.4   MJ   (energy_required assumed 16 s)
casting / plate                                    ≈ 0.2   MJ
-------------------------------------------------------------
total                                              ≈ 38    MJ / iron plate
```

**~99 % of the cost of Cindra metal is the lava power tax.** For scale: a Nauvis
electric-furnace plate is ~0.29 MJ, and a Vulcanus foundry plate is ~0.4 MJ
(free lava). **Cindra metal costs ~100× the energy of Vulcanus metal** — the
"ruinous power" identity is real and quantified. The planet is only viable
because the star hands back that 100× (and more) as solar surplus.

### The unit that ties the rooms together: the "melt line"

One foundry melting at full tilt is the natural throughput unit:

```
melt foundry consumes  500 lava / (16 s/4) = 500 lava / 4 s = 125 lava/s
lava supply needed     125 / 1.333 = ~94 lava-foundries
steady power           94 × 2.5 MW + 2.5 MW (melt) ≈ 237 MW  ≈ 234 MW is the lava tax alone
output (with +50%)     250 × 1.5 / 4 s = 93.75 molten iron/s ≈ 37.5 iron plates/s
```

> **1 melt line ≈ 234 MW of lava tax → ~37.5 iron plates/s.** Hold this number;
> the solar multiplier is chosen to make it fundable.

---

## 2. Surface solar multiplier ← lava cost (the backwards derivation)

Design pins two facts and asks us to find the third:

- **Night floor ≈ Nauvis full day** = **60 kW/panel** (`DESIGN.md` §7). Never
  true zero — the dark-weighted curve floors at a dim positive value.
- **Flare peak ≈ 100× baseline**, and must be a **windfall unreachable on
  baseline**.

Choose a **reference flare field** — the panel count that should drive exactly
**one melt line at flare peak**. Picking a *small, satisfying* field (so the
flare feels like a windfall, not a chore) sets the peak:

```
reference field           = 40 panels  (40 × 3×3 = 360 tiles — a small block)
required peak power        = 234 MW  (one melt line)
=> peak per panel          = 234 MW / 40 = 5.85 MW  ≈ 6 MW
=> solar-power property    = 6 MW / 60 kW × 100 = ~10000   (100× Nauvis)
```

> **`solar-power` = 10000** (i.e. ~10000 %-of-Nauvis) — and this *validates the
> `DESIGN.md` §7 "~10000 %" guess from first principles*, because it is the peak
> that makes a 40-panel field drive one melt line at flare.

Now the floor falls straight out of the 100× ratio:

```
floor per panel = 6 MW / 100 = 60 kW  = Nauvis full day  ✔  (matches the pin)
```

**The two design pins are mutually consistent** at `solar-power = 10000` with a
curve floor of **1 % of peak**. The flare ratio is therefore **exactly 100×**,
derived — not asserted.

### What this buys, at floor vs flare

| | per-panel | 40-panel reference field |
|---|---|---|
| **Night floor** (99 % of the cycle) | 60 kW | 2.34 MW → **~1 lava foundry** (survival trickle) |
| **Flare peak** (short spike) | 6 MW | 234 MW → **1 full melt line** (100× the floor) |

This is the whole game in one table: **the floor runs base survival (heaters,
life-support, a science trickle); the flare runs metal.** You do not build a
floor field big enough to smelt at scale (that would be ~4000 panels per melt
line); you **conduct the flare** — run wide melt capacity that only lights up
during the spike. That is "routing the star's surplus."

### Margin vs Vulcanus (the "beats free-lava net productivity" clause)

Vulcanus and Cindra run the *same* foundry melt recipe (+50 % prod, `500 lava →
375 molten iron`), so per-foundry throughput ties. Vulcanus pays **0** for lava;
Cindra pays 234 MW/melt-line. On steady state Vulcanus wins metal-per-tile.

Cindra's edge is the **flare headroom**: the same 40-panel field that funds one
melt line at peak is delivering **100×** its floor power for the duration of the
spike. Add melt capacity + burst storage and Cindra runs **up to ~100 melt lines
during the flare** off that one small field — a burst productivity Vulcanus's
flat 4×-solar can never reach. The `< 100 %`-catchable rule (§4) is what turns
this into skill rather than a free bank: you must have the live melt capacity
*standing by* to use the spike, or dump it.

**Concrete margin target for `ci-63d`:** the night floor should fund the
**non-lava** base (heaters + science + mass-driver upkeep) with the lava/metal
economy riding the flare. Starting split: size the floor field so **≥ 2×** the
survival draw is available at floor (headroom to bootstrap the first melt line's
worth of storage), i.e. a starter base wants ~80–100 baseline panels before its
first flare pays off.

---

## 3. Flare shape & cadence (`ci-9k6`; sporadic timing `ci-2ba`)

The flare is driven by `scripts/flare.lua` on a frozen daylight curve, NOT the
raw day-night cycle, so the schedule is fully controlled in code.

| Value | Start | Derivation / note |
|---|---|---|
| Curve **floor** | **1 % of peak** (60 kW/panel) | forced by 100× ratio + 60 kW pin; **never 0** (design) |
| Curve **peak** | **100 % → 6 MW/panel** | `solar-power = 10000` |
| Flare **event** | **~12 s** (telegraph + ramp + plateau + decay), fixed shape | dark-weighted: short spike |
| Ramp / decay | **fast**, telegraphed | design: telegraph → fast-ramp → plateau → fast-decay |
| **Timing** | **SPORADIC** — random calm in `[CALM_MIN, CALM_MAX]`, **mean = old fixed calm** | ci-2ba: unpredictable *when*, consistent *how big* |

Timing is **sporadic** (ci-2ba): the calm gap before each event is a random draw
whose *mean* equals the old fixed cadence, so the average energy delivery — and
all the sizing math below — is preserved on average; only any single gap is
unpredictable. The event itself is unchanged: telegraphed, fixed
ramp/plateau/decay, ~100× peak. Energy delivered by one flare, per reference
40-panel field (triangle-ish spike, avg ≈ ½ peak):

```
flare energy/event ≈ 234 MW × ~12 s × 0.5 ≈ 1.4 GJ   (per 40-panel field)
```

Because the *magnitude* is consistent, **capacity sizing still matters**; because
the *timing* is random, the player must **react per event** (via the warning
telegraph + the reactive environmental scanner, ci-3o3) rather than pre-schedule
against a clock. `ci-9k6`/`ci-2ba` own the concrete control-points; these are the
targets. Curve *feel* (is the telegraph readable? is the warning window enough to
react?) is a **PLAYTEST** item — it cannot be asserted by `factorio-test`.

---

## 4. Storage sizing & the `< 100 %`-catchable rule (`ci-tii`)

The flare delivers **3.5 GJ in 30 s = ~117 MW** into each reference field. To
bank *all* of it you would need, per 40-panel field, either 117 MW of storage
throughput or 3.5 GJ of capacity — both cost far more than the 40 panels that
produced it. **So `< 100 %` catchable holds by economics, not by a cap**: nobody
builds one accumulator per panel. Concretely, a vanilla accumulator's 300 kW
throughput means catching a 6 MW/panel spike needs **20 accumulators per panel**
— absurd, by design.

The two Cindra tiers split the job (each must be **situational-, not
strictly-better** than a vanilla accumulator, §12):

| Tier | Capacity | Throughput | Footprint | Role | Situational cost |
|---|---|---|---|---|---|
| **Capacitor** (`ci-tii`) | **10 MJ** | **5 MW** | 2×2 | catch flare *spikes* fast; feed mass-driver bursts | tiny capacity — useless as bulk storage |
| **Molten-salt battery** | **200 MJ** | **1 MW** | 3×3 | bulk *plateau* across the night trough | heat-upkeep: freezes (loses charge) below ~100 °C |
| *(vanilla accumulator)* | 5 MJ | 300 kW | 2×2 | balanced baseline | strictly average — the guardrail reference |

**Why these numbers:**

- **Capacitor** trades capacity for throughput (5 MW = ~16× an accumulator) so
  it grabs the spike, but 10 MJ empties in 2 s — it *cannot* store the plateau.
  Sized so one capacitor charges a **500 MJ mass-driver shot** in bursts (bank
  during flare, dump on fire).
- **Molten-salt battery** trades throughput for capacity (200 MJ = 40× an
  accumulator) so it holds the trough, but 1 MW out means it drip-feeds, not
  spikes. **Heat-upkeep** is its situational cost: on the cold nightside it must
  be kept > ~100 °C (heater/heat-pipe) or it bleeds charge — literally "freezes"
  (design §5). This is the "drag a heat umbilical" pressure reused for storage.

**Catchability inequality** the balance pass must preserve:

```
Σ(sink throughput) = capacitors×5MW + salt×1MW + heaters×40MW + live factory draw
                   <  flare delivery = panels × 6 MW        (must stay < 100%)
```

Keep aggregate capacitor throughput **< ~50 %** of flare delivery so that the
majority of each flare must be **used live or dumped** — the surplus that damages
undissipated panels (`ci-9ay`). Sizing the panel-damage threshold and the
dissipator ("fuse") throughput is `ci-9ay`'s job; its input from here is: **the
uncatchable fraction is ≥ 50 % of peak by construction.**

---

## 5. Electric heater power/heat ratio (`ci-f5l`)

Shipped: draw **40 MW**, heat cap **600 °C**. A heating-tower-derived reactor
converts electric input to buffer heat at ~100 %:

```
heat production ≈ electric draw = 40 MW (thermal) per heater, capped at 600 °C
```

- **600 °C** is derived by the design constraint "below a reactor (1000 °C),
  above the steam threshold (100 °C)" — high enough to boil water for the
  water/ice loop and warm the molten-salt battery, low enough to stay a
  situational (not strictly-better) heat source than a nuclear reactor.
- **"Capped heat / uncapped draw"**: the *usable* heat is temperature-capped
  (600 °C), but the building should keep **drawing power even when its heat
  buffer is saturated**, radiating the excess away. That is what makes it a
  **flare sink / safe dissipator**. A fixed `consumption = 40 MW` prototype value
  does *not* achieve "keep drawing when full" on its own — a normal reactor idles
  when its buffer is hot. **Flag for `ci-f5l`:** the "uncapped draw / dissipate
  when full" behaviour needs runtime logic (or a dedicated dissipator entity),
  not just the prototype field. The 40 MW is the per-unit sink *rate*.

**Sink math:** dumping one reference field's 234 MW flare peak takes
`234 / 40 ≈ 6 heaters`. That is the deliberate cost of *wasting* a flare you
can't use — you either build melt capacity to consume it, storage to bank a
slice, or heaters to burn it safely. Six heaters/field is cheap enough to be a
valid safety valve, expensive enough that pure-dissipation is wasteful vs
building real sinks. Good starting point; `ci-63d` tunes.

---

## 6. Stone loop-back — net consumption (`ci-4xj` / balance note in `lava.lua`)

Per 250 molten iron:

```
lava consumed   = 500 → 100 lava-crafts → 100 stone IN
stone returned  = 10 (vanilla byproduct)
net             = 100 − 10 = 90 stone consumed   (net-HEAVILY-consuming)
```

Copper is worse: 15 back on 100 in → 85 net. The design target is **"slightly
net-consuming"** (fresh mining stays a *slow* top-up, not the whole supply). With
the current numbers the loop consumes ~90 % of its stone every cycle — mining is
the whole supply, not a top-up. As `lava.lua` already flags, **both levers are
locked**: the `1:5` ratio is "fixed per spec," and the byproduct lives on a
*shared Vulcanus recipe we must not mutate* (never-mutate-other-planets, §6).

**To hit "slightly net-consuming" (target ~5–15 % net loss) without touching
shared prototypes**, the balance pass has three clean options — recommendation in
priority order:

1. **Cindra-exclusive casting tier** (recommended): a *cloned*
   `cindra-molten-iron` recipe (own recipe, gated to a Cindra building or
   category) that returns **~85–95 stone per 250 molten iron** instead of 10.
   Net loss ~5–15 %. Deep-copy, never mutate — same pattern as the ice crusher.
   This is the design's own suggested escape hatch.
2. **Batch-scale lava while preserving `1:5`** (e.g. `4 stone → 20 lava`): keeps
   the spec ratio, changes nothing about net stone (still 100 in / 10 back per
   melt) — so this **does not fix the loop**; listed only to record that it's a
   non-solution.
3. **A stone-reclaim recipe** on Cindra (slag → stone) fed by a cheap byproduct.
   More moving parts; prefer (1).

> **Deliverable to `ci-4xj`:** to make the loop "slightly net-consuming," a
> Cindra-exclusive molten recipe should return **~90 stone / 250 molten iron**
> (≈10 % net loss). Owner decides the exact figure against playtest.

---

## 7. Ribbon geometry (`ci-9nj` mapgen) — already shipped, recorded for completeness

These landed with §15-1/§15-3 and are settings-tunable; no change proposed, but
the balance pass should hold them against the solar field sizes above (a melt
line's floor field is wide, so the safe ribbon must be wide enough to host solar
+ foundries + storage without forcing everything into the lethal margin).

| Value | Shipped | Note |
|---|---|---|
| Safe half-width | 24 tiles | 48-tile safe band (Y); solar-heavy base competes for it |
| Lethal-at | 96 tiles | damage saturates; best resources here (edge-pushing) |
| Wall-at | 128 tiles | hard backstop |
| Peak dps | 200 | survivable briefly with gear |
| Freeze temp | −30 °C | nightside building-heat threshold |

**Balance observation for `ci-9nj`:** a floor-only melt line wants ~4000 panels
(~36 000 tiles). Across a 48-tile safe band that is ~750 tiles of east-west
ribbon *per melt line* — confirming the design intent that you **ride flares
instead of carpeting the ribbon in floor panels**. If playtest finds the ribbon
too cramped even for flare-riding, the safe half-width (24) is the lever.

---

## 8. Starting-value summary (hand-off table)

Every `(tune)` from `DESIGN.md` §7, with a derived starting number and its lever.

| `(tune)` value | Starting value | Derived from | Track / lever |
|---|---|---|---|
| Lava recipe | `1 stone → 5 lava` | fixed by spec | — |
| **Lava power cost** (`energy_required`) | **15 s → 1.875 MJ/lava** | anchor; `cost = E_lava/8` | `ci-4xj` — the master lever |
| **Surface solar multiplier** (`solar-power`) | **10000** (~100× Nauvis) | §2: 40-panel field = 1 melt line @ peak | `ci-9k6` |
| **Night floor** | **60 kW/panel** (1 % of peak) | 100× ratio + Nauvis-full-day pin | `ci-9k6` |
| **Flare peak / baseline** | **100×** (peak 6 MW/panel) | falls out of §2 | `ci-9k6` |
| Flare event / cadence | ~12 s event, **sporadic** (random calm, mean = old cadence) | dark-weighted (§3), ci-2ba | `ci-9k6`/`ci-2ba` + PLAYTEST |
| **Capacitor** | 10 MJ / 5 MW / 2×2 | §4: spike-catcher, feeds 500 MJ shot | `ci-tii` |
| **Molten-salt battery** | 200 MJ / 1 MW / 3×3, heat-upkeep >100 °C | §4: trough bulk | `ci-tii` |
| Uncatchable fraction | **≥ 50 % of peak** | §4 economics | `ci-9ay` (panel damage) |
| **Electric heater** | 40 MW draw → 40 MW heat, cap 600 °C | §5 | `ci-f5l` (needs runtime "draw-when-full") |
| Heaters to dump 1 flare field | ~6 | §5 | `ci-f5l` |
| **Stone loop-back** | Cindra recipe returns ~90 stone/250 molten (≈10 % net) | §6 | `ci-4xj` |
| Mass-driver shot | 500 MJ / 10 MW charge (~50 s) | already shipped | `ci-r10` (holds) |

### Consumers

- **`ci-4xj` (mechanics/economy):** §1 lava lever, §5 heater ratio, §6 stone
  loop-back recipe. The lava `energy_required` is the master knob — everything in
  §2–§5 rescales linearly with it (`cost/lava = E_lava/8`).
- **`ci-9nj` (mapgen):** §7 ribbon-vs-solar-footprint check; confirm the safe
  band hosts flare-riding melt bases without forcing the lethal margin.
- **`ci-9k6` (solar/flare), `ci-tii` (storage), `ci-9ay` (panel damage),
  `ci-f5l` (heater):** their target numbers are §2–§5.
- **`ci-63d` (balance pass):** owns final tuning; verify the two cited-not-
  measured anchors (molten `energy_required`, stone byproduct) and the
  `< 100 %`-catchable inequality against a live save.

---

## 9. Open items the balance pass must close

1. **Verify the two assumed anchors** against the live install: molten-recipe
   `energy_required` (assumed 16 s) and stone byproduct (10/15). They shift the
   second-order terms in §1 and §6 only, but §6's fix depends on the exact
   byproduct.
2. **Curve feel** (§3) is PLAYTEST — is the sporadic warning telegraph readable
   and the event reactable? (timing is now random, ci-2ba)
3. **Heater "draw-when-full"** (§5) needs runtime logic, not a prototype field —
   file under `ci-f5l` if not already covered.
4. **Master-lever sensitivity** — if `E_lava` moves, re-run §2 (a melt line's
   lava tax scales linearly with `E_lava`). Pick one knob to absorb it: either
   hold `solar-power = 10000` and let the reference field grow to
   `40 × E_lava/15` panels, or hold the 40-panel field and scale
   `solar-power = 10000 × E_lava/15`. Don't move both — that double-counts.
