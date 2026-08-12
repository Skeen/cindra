# PlanetsLib evaluation (spike, ci-810e)

**Recommendation: PARTIALLY ADOPT, and only as an OPTIONAL (`?`) dependency.
Do NOT take a hard dependency, and do NOT migrate the planet prototype or the
starmap onto `PlanetsLib:extend()`.**

Playtest feedback asked "we should make use of PlanetsLib". This is the read of
the library against what Cindra actually is. The short version: the headline
feature (the orbit hierarchy) buys Cindra nothing today, because Cindra orbits
the star directly and has no moons; and the library's price is a large set of
mutations to *vanilla* prototypes, which collides head-on with this mod's
load-bearing invariant (AGENTS.md: "NEVER MUTATE GLOBAL STATE THAT AFFECTS OTHER
PLANETS").

---

## 1. What was evaluated

| | |
|---|---|
| Repo | `https://github.com/danielmartin0/PlanetsLib` |
| `info.json` version | **1.23.5** (`changelog.txt` has an unreleased 1.24.0 section) |
| Commit read | `ba3dd7aa3b8b580713aa5043811b68a0e9187905` (2026-08-09) |
| Factorio target | `base >= 2.1.13`, optional `space-age`/`quality`/`recycler` |
| Authors | thesixthroc, MeteorSwarm |

The whole `lib/`, `prototypes/`, `api.lua` and the four stage entry points
(`data.lua`, `data-updates.lua`, `data-final-fixes.lua`, `control.lua`) were read
directly, not just the README. Where this document and the README disagree, the
source is what is described here.

Upstream states it aims to "never make any breaking API changes" and deprecates
by removing from docs rather than deleting code. That is a real point in its
favour for a long-lived dependency.

---

## 2. Inventory: what Cindra hand-rolls that PlanetsLib would own

| Cindra today | Where | PlanetsLib equivalent | Verdict |
|---|---|---|---|
| `type = "planet"` prototype, `data:extend`-ed | `prototypes/planet.lua` | `PlanetsLib:extend{ ... orbit = { parent, distance, orientation } }` | **No benefit.** See §3. |
| `distance = 5`, `orientation = 0.05` (tuned by ci-lcv, ci-zyc7) | `prototypes/planet.lua` | `orbit.distance` / `orbit.orientation` relative to a parent | **No benefit, real risk.** See §4. |
| `starmap_icon` / `starmap_icon_orientation` (tidal-lock quarter turn) | `prototypes/planet.lua`, `prototypes/space-appearance.lua` | none — PlanetsLib never writes `starmap_icon_orientation` | **Not owned by the library.** |
| Baked globe + orbital backdrop | `prototypes/space-appearance.lua` | `orbit.sprite` (moon orbit rings only; README notes starmap sprite layering "not yet implemented") | **Not applicable** (no moons). |
| `space-connection` `vulcanus-cindra`, hand-pinned route icon | `prototypes/planet.lua`, `space-appearance.route_icons()` | `prototypes/override-final/update-connections.lua` is **entirely commented out** upstream | **Nothing there.** |
| `planet-discovery-cindra` technology | `prototypes/planet.lua` | `technology_icon_planet`, `get_child_technologies`, `excise_*` helpers | Cosmetic/utility only; ours is 30 lines and already tested. |
| 29 vanilla entity clones (`util.table.deepcopy(data.raw...)`) | `prototypes/*.lua` | `create_planet_entity_variant` / `assign_entity_replacement` | **Plausible future fit**, but each variant is bound to its own startup setting and a runtime replacement/migration system. Large behavioural surface for something already working. |
| Mass driver (Cindra's rocket alternative) | `prototypes/mass-driver.lua` | `assign_rocket_part_recipe`, cargo-drop whitelists | Not a match — Cindra deliberately does not use the vanilla silo/rocket-part flow. |
| `entities_require_heating = true` | `prototypes/planet.lua` | PlanetsLib *reads* this and adds an `is-freezing = 1` surface property | Free if installed; nothing for us to do. |
| Surface conditions on recipes (e.g. dropping the Vulcanus pressure gate) | `prototypes/*`, tested in `tests/test_foundry_bootstrap.lua` | `relax_surface_conditions` / `restrict_surface_conditions` / `remove_surface_condition` | **Genuinely nicer than hand-editing condition tables** — the one API worth wanting. |

There is also a community **tier list** (`PlanetsLibTiers`, read via
`PlanetsLib.get_planet_tier`). Note that planet mods do **not** self-register a
tier: the tier data lives in that separate companion mod, maintained by its
authors. There is no action available to us there.

---

## 3. What adopting it BUYS us

Honestly: **less than the feedback assumes.**

The bead's premise was that PlanetsLib handles "cross-mod starmap coexistence so
multiple planet mods don't fight over coordinates". **That is not what it does.**
There is no coordinate deconfliction anywhere in the source — no overlap
detection, no auto-nudging of colliding planets. Two mods that both place a
planet at `distance = 5, orientation = 0.05` still collide, with or without
PlanetsLib.

What the orbit system actually provides is a *parent-relative* coordinate
convention plus reconciliation:

- `lib/orbits.lua :: ensure_all_locations_have_orbits()` retro-fits
  `orbit = { parent = star, distance = <current>, orientation = <current> }` onto
  every planet and space-location that lacks one. It is **position-preserving** —
  it never moves anything.
- `prototypes/override-final/check-unexpected-positions.lua` notices when another
  mod has *moved* a body away from where its orbit implies, and drags that body's
  **children** along with it.
- `PlanetsLib:update()` moves a body and cascades to children and grandchildren.

Every one of those benefits is about **children following a moved parent**.
Cindra's parent is the star (which sits at the origin and is never moved) and
Cindra has **no children** — `DESIGN.md` and `TODO.md` contain no moon, no
satellite, and no secondary orbital location. So the cascade has nothing to
cascade.

Crucially: because `ensure_all_locations_have_orbits()` runs over *all* of
`data.raw.planet`, **Cindra already participates in the orbit graph for free**
for any player who installs PlanetsLib alongside it. Calling `PlanetsLib:extend()`
ourselves would produce a byte-identical `distance`/`orientation`.

The things that would be real wins, ranked:

1. **`relax_surface_conditions` / `restrict_surface_conditions` /
   `remove_surface_condition`** — small, pure, well-scoped helpers that do exactly
   what `prototypes/` already does by hand (e.g. stripping the Vulcanus pressure
   gate off the field-foundry recipe). Low risk, modest payoff.
2. **Compatibility conventions** — being a "PlanetsLib planet" is a soft signal to
   other planet-mod authors; it is where the ecosystem is standardising.
3. **Future-proofing** — *if* Cindra ever gains a moon or an orbital station, the
   orbit hierarchy becomes the right tool. It is not the right tool now.

---

## 4. What it COSTS us

### 4.1 The blocking cost: PlanetsLib mutates vanilla, extensively

AGENTS.md: *"NEVER MUTATE GLOBAL STATE THAT AFFECTS OTHER PLANETS. Hard rule.
This mod adds Cindra; it MUST NOT change Nauvis/Vulcanus/Gleba/Fulgora/Aquilo
gameplay."*

A **hard** dependency on PlanetsLib means installing Cindra forcibly applies all
of the following to a player's game, none of it Cindra-scoped:

| PlanetsLib does | Where | Blast radius |
|---|---|---|
| Rewrites the **vanilla centrifuge** — fluidboxes + recipe-coloured working glow | `prototypes/override/centrifuge.lua` (runs even without Space Age) | Nauvis |
| Sets explicit `weight` on ~100 **vanilla items** | `prototypes/override-final/set-default-weights.lua` | every planet, all rocket logistics |
| Walks the **entire technology tree** and strips prerequisites that point at hidden techs (startup setting, default on) | `prototypes/override-final/science.lua` | every mod's tech tree |
| Mirrors vanilla lab science packs onto the **Biolab** | `prototypes/override-final/science.lua` | Gleba/lategame |
| Adds tooltip machinery to **every recipe** | `prototypes/override-final/enhanced-tooltips.lua` | global UI |
| Rewrites every `AmbientSound::planet` into `planets` | `data-final-fixes.lua` | global |
| Adds an `is-freezing` surface property to every freezing planet, and a `planet-str` to every planet | `data-final-fixes.lua` | global (benign, but global) |
| Registers a control-stage event handler and entity-replacement migrations | `control.lua` | runtime, all surfaces |

Most of this is defensible *library* behaviour — but it is behaviour the **player**
should opt into by installing PlanetsLib, not behaviour Cindra should conscript
them into. Making it a hard dependency would be Cindra changing Vulcanus, which
is precisely the thing the invariant forbids.

An **optional** (`? PlanetsLib`) dependency has none of this problem: the
mutations happen only when the player has already chosen PlanetsLib.

### 4.2 Migration risk to the tuned starmap

Cindra's starmap position is not a default — it is the output of four rounds of
human art direction (`ci-2sr` → `ci-bu4` 3→6 → `ci-lcv` 6→4.5 → `ci-zyc7` 4.5→5;
the bead's `ci-mkfls` reference does not resolve in beads, `ci-zyc7` is the
latest tuning of record in `prototypes/planet.lua`),
plus a bespoke `starmap_icon_orientation = (orientation - 0.25) % 1` quarter-turn
that points the baked fire limb at the star. `PlanetsLib:extend()` **rejects**
`distance` and `orientation` as top-level fields (`lib/planet.lua ::
verify_extend_fields` hard-errors on both), so migrating means re-expressing that
tuning through `orbit`.

For a star-parented body the translation is the identity
(`orbits.get_absolute_polar_position_from_orbit` short-circuits on
`parent.name == "star"` and returns `orbit.distance, orbit.orientation`
unchanged) — so the migration is mechanically safe. But it is a rewrite of the
most human-tuned numbers in the mod for **zero behavioural gain**, and it opens a
failure mode we do not have today:

> If `orbit.parent` ever names a body that is absent (a mod not installed),
> `extend()` does **not** error. It silently parks the planet at
> `SPECIAL_PLACEHOLDERS_FOR_MISSING_PARENT` — `distance = 43168,
> orientation = 0.43168` — i.e. flung off the edge of the starmap.

The existing `tests/test_planet.lua` already pins `distance == 5`, the
`< vulcanus.distance` relation, and the `starmap_icon_orientation` quarter-turn,
so a migration could not land silently broken. `tests/test_planetslib_compat.lua`
(added by this spike) additionally pins that Cindra is never sitting on the
missing-parent placeholder.

### 4.3 No conflict with the vetoed art direction

Checked explicitly, per the bead: PlanetsLib **never writes** `starmap_icon`,
`starmap_icons`, `icon`, or `starmap_icon_orientation` on a planet it did not
create. `prototypes/override-final/starmap.lua` only *reads* those fields, and
only for `sprite_only` decorations (its own `star`) and for moon orbit rings
(`orbit.sprite`). It composites into `utility-sprites.default.starmap_star`, a
layer Cindra does not touch.

So the fire → dark mountains → ice globe and the **no gray/tan sandy terminator
band** veto (`ci-6i1`, `PLAYTEST.md:133`) are **not** at risk from PlanetsLib.
That art is baked by `scripts/gen-planet-maps.py` (whose palette now comes from
`scripts/terrain.lua` via `scripts/terrain_ramp.py`, ci-4qyj) into
`graphics/space/` and consumed by `prototypes/space-appearance.lua` — a pipeline
PlanetsLib has no reach into at all. The art direction is ours either way;
nothing in the library can repaint it.

### 4.4 Third-party dependency surface

PlanetsLib is ~2,300 lines of library Lua plus prototypes and graphics, with its
own transitive optional deps (`PlanetsLibTiers`, `Cosmic-Social-Distancing`) and
an incompatibility (`! MT-lib`). Its `data-final-fixes` contains **hard asserts**
that can refuse to load a game — notably the gas-percentage assert (see §5). A
mod-portal release of Cindra would inherit that failure surface.

---

## 5. Compatibility today (no adoption required)

Cindra is already compatible with PlanetsLib as an installed sibling. Traced
against PlanetsLib 1.23.5's `data-final-fixes`:

- `set_planet_str` fallback is `string.sub(name, 1, 8)`. `"cindra"` is 6 chars →
  lossless, no truncation collision.
- `entities_require_heating = true` → PlanetsLib adds `is-freezing = 1`. Additive,
  matches reality, harmless.
- `ensure_all_locations_have_orbits` gives Cindra `orbit = { parent = star,
  distance = 5, orientation = 0.05 }` — Cindra does not move.
- The gas-percentage assert sums `oxygen`/`nitrogen`/`carbon-dioxide`/`argon` from
  `surface_properties`. Cindra declares none of them → sum 0 → passes.

That last one is the live trap: those surface properties are **defined by
PlanetsLib, not by vanilla**. If Cindra ever gives itself an atmosphere
composition summing over 100, every player running Cindra + PlanetsLib gets a
**hard load failure**, and our own test suite (which does not ship PlanetsLib)
would never see it. `tests/test_planetslib_compat.lua` guards this.

### 5.1 Confirmed in-engine (stage 1, `ci-gg3x`)

The section above was originally traced from source only. It has since been run:
Cindra + PlanetsLib were loaded together in a real Factorio (2.1.9, headless
`cindra-test`), and every prediction held.

| Checked | Result |
|---|---|
| Game loads with both installed (PlanetsLib's `data-final-fixes` asserts are live) | **Loads.** All four PlanetsLib stages run; the full suite is green (424 tests, the 418 canonical ones plus the 6 co-load ones). |
| Cindra moves on the star map | **No.** `distance = 5`, `orientation = 0.05`, unchanged. Vulcanus (10 / 0.1) and Nauvis (15 / 0.275) are unchanged too, so the retrofit is position-preserving system-wide, not just for us. |
| Tidal-lock quarter turn survives | **Yes.** `starmap_icon_orientation = 0.8`. PlanetsLib never writes that field. |
| Orbit retro-fitted onto Cindra | **Yes.** `orbit = { parent = space-location/star, distance = 5, orientation = 0.05 }`, exactly what `PlanetsLib:extend` would have produced. |
| `"unexpectedly found at"` reconciliation fires for Cindra | **No.** The string never appears in the log (detailed logging was forced on for the check). |

The **complete** diff PlanetsLib makes to Cindra's prototype, read back from a
probe mod running after PlanetsLib's `data-final-fixes` and diffed against the
same probe on the plain 4-mod run, is three additive things and nothing else:

* the retro-fitted `orbit` above;
* `surface_properties["is-freezing"] = 1`, derived from `entities_require_heating`;
* `surface_properties["planet-str"]`, autogenerated from the name — added to
  *every* planet, Nauvis and Vulcanus included.

Cindra's discovery technology (prerequisites, effects, cost), the
`vulcanus-cindra` connection and its length, the planet/space-location sets and
every surface property Cindra declares itself came back byte-identical.

**Version caveat.** PlanetsLib **1.23.5** declares `base >= 2.1.13`, and the
Factorio available here is **2.1.9**, so the engine will not enable it as
shipped. Both were therefore run: **1.23.4** (the newest release that loads
unmodified on 2.1.9) and **1.23.5** with only its `base` dependency bound
relaxed locally. The results were identical, which the source explains — the
whole 1.23.4 → 1.23.5 code delta is one loop that rewrites `AmbientSound::planet`
into `planets` (a field Wube dropped in 2.1.13), and Cindra defines no
`ambient-sound` prototypes at all.

`tests/test_planetslib_coload.lua` is that verification kept as a test, so the
next PlanetsLib release is checked by running it rather than by reading a log
(see README, "PlanetsLib co-load"). It registers only when PlanetsLib is
installed; `tests/test_planetslib_compat.lua` guards the same edges from our own
side in every run.

---

## 6. Staged migration plan

Ordered by risk, lowest first. Each stage is a follow-up bead; **stages 3 and 4
need human sign-off** because they change what a player is forced to install.

| Stage | Bead | What | Risk | Gate |
|---|---|---|---|---|
| 0 | *(this spike)* | `tests/test_planetslib_compat.lua` — pin the preconditions PlanetsLib's `data-final-fixes` imposes on Cindra, with **no** dependency on PlanetsLib | none | — |
| 1 | `ci-gg3x` | ~~Verify in-engine that Cindra + PlanetsLib load clean together and Cindra does not move on the starmap~~ **DONE** — clean, see §5.1; kept as `tests/test_planetslib_coload.lua` | low | — |
| 2 | `ci-ndm9` | Adopt `PlanetsLib.relax_surface_conditions` / `remove_surface_condition` behind `mods["PlanetsLib"]`, keeping the hand-rolled path as the default | low | — |
| 3 | `ci-dza6` | ~~Declare `"? PlanetsLib"` in `info.json` (optional dep — load order only, forces nothing on the player)~~ **DONE** — human sign-off granted 2026-08-12; guarded by `unit-tests/test_dependencies.lua` (the text) and `tests/test_planetslib_absent.lua` (the consequence) | medium | **human** |
| 4 | `ci-82ib` | Migrate the planet prototype to `PlanetsLib:extend{ orbit = { parent = star, ... } }` | medium | **human** — only worth doing if Cindra gains a moon/satellite |
| — | — | *Not planned:* hard dependency; entity-variant migration; starmap/orbit-sprite migration | — | — |

---

## 7. Recommendation

**Partially adopt.** Concretely:

- **Do** keep Cindra provably compatible with PlanetsLib as an installed sibling
  (stage 0 landed; stage 1 verified in-engine — clean, §5.1).
- **Do** consider `"? PlanetsLib"` plus the guarded surface-condition helpers
  (stages 2–3) — cheap, reversible, invariant-preserving. The optional dependency
  itself **landed** in stage 3 (`ci-dza6`), with human sign-off.
- **Do not** take a hard dependency. It would make installing Cindra silently
  rewrite the vanilla centrifuge, ~100 vanilla item rocket weights, and every
  mod's technology tree — a direct violation of the mod's load-bearing invariant,
  in exchange for a feature (orbit cascade) that has nothing to cascade.
- **Do not** migrate the planet prototype or the starmap now. The tuned
  `distance = 5` / `orientation = 0.05` / quarter-turn icon rotation would
  translate to an identical result, so the rewrite is pure risk. Revisit if and
  when Cindra gains a moon.

The one-line answer to the feedback: *PlanetsLib is the right library for a
mod with moons and a crowded local system; Cindra is one planet orbiting a star,
so it should stay a good PlanetsLib **citizen** without becoming a PlanetsLib
**dependent**.*
