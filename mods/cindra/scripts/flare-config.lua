-- Shared tuning constants for the Cindra flare power system (§15 items 7-9;
-- DESIGN.md §5, §7 tuning table). Integrated from the proven flare-poc
-- (mods/flare-poc, ci-zg3): the flare cycle (§15-7), the disposal-deficit
-- panel-damage rule (§15-8), and the two-tier storage + dissipator sink web
-- (§15-9) all share these numbers, so the data stage (prototypes) and the
-- runtime (flare / panels / sinks) agree and the tests read them instead of
-- hard-coding.
--
-- Every value is a (tune) starting point (§16); §15-14 (ci-63d) does the real
-- balance pass against the lava recipe's energy cost. This module is PURE (no
-- game.* / prototypes.*), so it loads in both the data and control stages and
-- in the plain-Lua unit tests.

local C = {}

-- The planet surface every flare handler is gated on. This is the real Cindra
-- surface (the flare-poc used a "flare-poc" scratch surface); every runtime
-- sweep re-checks `surface.name == C.SURFACE`, so nothing here ever touches
-- Nauvis or another planet (the never-mutate-other-planets invariant).
C.SURFACE = "cindra"

-- === Solar / flare magnitudes (§7 "HIGH-INTENSITY SOLAR VIA DAYLIGHT CURVE") ==
-- Fixed high surface solar multiplier (~10000% of Nauvis). NEVER changed at
-- runtime: the flare swing comes from the daylight cycle, NOT from moving this
-- number (that would be the "artificial overdrive" the spec forbids). The planet
-- prototype's `solar-power` surface property is set to match (100x Nauvis), and
-- flare.apply re-affirms this multiplier on the surface as it drives the curve.
C.SOLAR_MULT = 100
-- Each panel's Nauvis-full-day output (W), before the surface multiplier. This
-- is the VANILLA solar panel's own `production` (60 kW): Cindra reuses the plain
-- vanilla panel (ci-8al), so the damage model's per-panel output must match the
-- real prototype it now degrades. Anchoring here also keeps the reduced-band
-- variants (production = this * factor) strictly BELOW the full band, so a
-- nightward band never out-produces the sunward vanilla panel.
C.PANEL_NOMINAL_W = 60e3 -- 60 kW (vanilla solar-panel)
-- Intensity is measured in "Nauvis full-day equivalents" = sf * SOLAR_MULT.
-- Baseline (the never-fully-dark night floor) is one Nauvis full day; the flare
-- peak is SOLAR_MULT of them, i.e. ~100x baseline.
C.BASELINE_INTENSITY = 1.0
C.PEAK_INTENSITY = C.SOLAR_MULT -- 100x baseline

-- Daylight curve endpoints. flare.daytime_for reads the surface's OWN
-- dusk/evening at runtime (so it adapts to whatever the planet has); these are
-- only the pure fallbacks for the unit tests. The engine's solar factor ramps
-- 1 -> 0 linearly across [dusk, evening], so daytime_for inverts that.
C.DUSK = 0.0
C.EVENING = 0.5
C.SF_PEAK = 1.0
C.SF_FLOOR = C.BASELINE_INTENSITY / C.SOLAR_MULT

-- === Flare schedule (ticks) ==================================================
-- SPORADIC timing (ci-2ba, overrides the old fixed cadence in DESIGN §10): the
-- WHEN of a flare is unpredictable - the calm stretch between events is a random
-- draw in [CALM_MIN_TICKS, CALM_MAX_TICKS], so you cannot forecast the next flare
-- by clock. What stays FIXED is the flare EVENT itself: it is always telegraphed
-- (a WARNING window that lets the player react and circuit-automate per event),
-- always the same telegraph -> fast ramp -> plateau -> fast decay shape, and
-- always ~100x peak. So capacity SIZING still matters (magnitude is consistent);
-- only the timing, plus the reaction window, is the sporadic hazard/windfall.
--
-- These are the flare-poc's compressed durations (a ~12 s event) so the tests
-- stay fast; real play scales the whole schedule up ~10-30x (events minutes
-- apart) once the sky-telegraph visuals exist. (tune) -- final cadence is §15-14.
C.WARNING_TICKS = 180  -- telegraph: alarm + countdown, power still at baseline
C.RAMP_TICKS = 120     -- fast ramp baseline -> peak
C.PLATEAU_TICKS = 300  -- sustained peak
C.DECAY_TICKS = 120    -- fast ramp peak -> baseline
-- One flare EVENT (fixed length): telegraph through decay. The random calm sits
-- BEFORE it, so there is no fixed period any more (that was the old model).
C.EVENT_TICKS = C.WARNING_TICKS + C.RAMP_TICKS + C.PLATEAU_TICKS + C.DECAY_TICKS

-- Random calm band between flares (ticks). This is the real-play cadence
-- (ci-1c7): the gap between consecutive flares is a random draw in [5min, 10min],
-- so the average is ~7.5 min and no single gap is ever shorter than 5 min nor
-- longer than 10 min. Bounded so timing is neither clustered-to-death (a real gap
-- always separates events: MIN > 0) nor starved (MAX caps the drought); only any
-- single gap is unpredictable (sporadic, not a metronome). At 60 ticks/s,
-- 5 min = 18000 ticks and 10 min = 36000 ticks. The event itself
-- (WARNING..DECAY) is short relative to this, so the interval between consecutive
-- flare telegraphs is ~[5min, 10min]. (tune) -- final balance is §15-14 (ci-63d).
C.CALM_MIN_TICKS = 5 * 60 * 60  -- 18000 ticks = 5 minutes
C.CALM_MAX_TICKS = 10 * 60 * 60 -- 36000 ticks = 10 minutes

-- === Panel damage (§15-8 "disposal-deficit rule") ============================
-- Cindra uses the plain VANILLA solar panel (ci-8al): the flare behaviour comes
-- from the SURFACE (high solar multiplier + daylight-curve flares), which already
-- applies to vanilla panels, so a bespoke panel tier is redundant. Every flare
-- system (damage sweep, sunward morph) reads C.PANEL and so targets the vanilla
-- panel on Cindra; the gating is per-surface, so vanilla panels off-world are
-- never touched.
C.PANEL = "solar-panel"
-- Reduced sunward-band variants (§ ci-9ht) are Cindra clones of the vanilla panel
-- with a smaller fixed output. They carry this prefix (e.g. cindra-solar-band-b75)
-- so they are unmistakably Cindra prototypes and never collide with the vanilla
-- panel; the full band (1.0) is the vanilla panel itself, not a clone.
C.PANEL_BAND_PREFIX = "cindra-solar-band"
-- Vanilla solar-panel max_health (the panels the disposal-deficit rule degrades).
C.PANEL_MAX_HEALTH = 200
-- Damage budget per sweep scales with the disposal DEFICIT (MW with nowhere to
-- go), never with panel count (mirrors the induction-damage kernel).
C.HP_PER_MW_DEFICIT = 4.0
-- Recovery when disposal is sufficient: over-budget panels ran "hot" but recover
-- if you add disposal, so degradation is reversible.
C.RECOVERY_HP_PER_SWEEP = 6.0
-- Grid-saturation alarm threshold (Cindra's proven "a full battery is the alarm",
-- ci-snq). A storage buffer stops counting as available disposal once its REAL
-- fill (entity.energy / electric_buffer_size) reaches this fraction: at/near cap
-- it can no longer absorb the surge, so the deficit -- and the panel damage --
-- fires reliably instead of waiting for the buffer to peg bit-exact full. 0.9
-- matches Cindra's induction SATURATION_THRESHOLD.
C.STORAGE_SATURATION_THRESHOLD = 0.9

-- === Tick cadences ===========================================================
-- on_nth_tick(N) is REPLACE-not-add: every periodic system needs a DISTINCT N.
-- The worldgen track already owns 20 (edge-damage) and 47 (building-heat), so
-- the flare driver and the panel-damage sweep take fresh primes.
C.FLARE_INTERVAL = 23        -- advance the flare (daytime + multiplier) + upkeep
C.PANEL_DAMAGE_INTERVAL = 29 -- the panel damage / recovery sweep

-- === Sinks (§15-9 storage + dissipator) ======================================
-- Dissipator: infinite safe waste, rate-limited per building. The disposal floor
-- AND the sacrificial fuse; its rated draw is counted BEFORE any panel is
-- damaged (electric-energy-interface, pure consumer).
C.DISSIPATOR = "cindra-dissipator"
C.DISSIPATOR_DRAW_W = 20e6 -- 20 MW per building

-- Capacitor: TINY, very high rate (ci-wcu). A minute buffer with a huge flow ->
-- catches the sharp leading edge of a flare but stores almost nothing.
-- Situational-not-strictly-better vs a vanilla accumulator (§12 guardrail): a
-- far worse reservoir (1/10th the buffer) traded for a much higher flow. It is a
-- spike catcher, not bulk storage.
C.CAPACITOR = "cindra-capacitor"
C.CAPACITOR_BUFFER_J = 0.5e6 -- 0.5 MJ (1/10th a vanilla accumulator's 5 MJ)
C.CAPACITOR_FLOW_W = 50e6    -- 50 MW  (charge AND discharge; >> accumulator 300 kW)
-- Self-discharge: like the battery, the capacitor bleeds a fraction of its
-- capacity per flare-driver tick when idle, but MUCH more gently (ci-411) -- a
-- slight trickle, not the battery's punishing drain. Reuses the same upkeep
-- mechanism (scripts/sinks.lua) at a far lower rate. Sized so a full 0.5 MJ
-- capacitor bleeds empty in ~15-20 min unpowered: full-drain takes 1/FRACTION
-- flare ticks = (1/FRACTION) * FLARE_INTERVAL / 60 seconds. At 0.00037 that is
-- ~2703 ticks -> ~1036 s (~17.3 min), i.e. ~0.48 kW self-discharge -- roughly an
-- order of magnitude gentler than the battery's ~5.5 kW.
C.CAPACITOR_UPKEEP_FRACTION = 0.00037

-- Molten-salt battery: large-ish, SLOW, CHEAP, LEAKY (ci-wcu). A moderate buffer
-- with a trickle flow -> soaks a sustained plateau across an array but can never
-- catch the spike alone. Situational-not-strictly-better (§12): its buffer AND
-- its flow are BOTH below a vanilla accumulator's, so on raw specs it is strictly
-- worse; its upside is a CHEAP recipe (no chemical batteries) and its downside a
-- heat-upkeep self-discharge (scripts/sinks.lua) that fully drains it in ~5-10
-- min when unpowered -- a mild sink here, awkward off-world.
C.BATTERY = "cindra-molten-salt-battery"
C.BATTERY_BUFFER_J = 2.5e6 -- 2.5 MJ (large-ish; half a vanilla accumulator)
C.BATTERY_FLOW_W = 150e3   -- 150 kW (inflow AND discharge; < accumulator 300 kW: slow)
-- Heat upkeep: fraction of the battery's *capacity* lost per flare-driver tick
-- when idle. Sized so a full battery bleeds its whole 2.5 MJ in ~5-10 min
-- unpowered: drain/tick = capacity * FRACTION, so full-drain takes 1/FRACTION
-- flare ticks = (1/FRACTION) * FLARE_INTERVAL / 60 seconds. At 0.00085 that is
-- ~1176 ticks -> ~451 s (~7.5 min), squarely inside the 5-10 min window.
C.BATTERY_UPKEEP_FRACTION = 0.00085

-- Test-only measurement rig: an accumulator with flow far above the flare peak,
-- so it absorbs a panel's full output WITHOUT throttling. Reading its energy
-- delta over a window measures real, unthrottled engine solar output (used to
-- prove the ~100x peak against the engine, not just the canonical model). Only
-- registered when factorio-test is loaded (see prototypes/storage.lua).
C.MEASURE_SINK = "cindra-measurement-sink"
C.MEASURE_FLOW_W = 500e6
C.MEASURE_BUFFER_J = 5e9

-- Baseline factory consumption on the grid (W). Baseline solar runs the factory
-- between flares (storage is NOT life-support); default equals one panel's
-- baseline so a lone-panel grid is net-neutral at rest.
--
-- NOTE (integration simplification, from the PoC): consumption is a per-grid
-- SCALAR the damage rule reads to size the deficit; a full build would read live
-- consumers per electric network. TODO(ci-63d/follow-up): sum real network draw
-- so the panel-damage deficit tracks actual load instead of this default.
C.DEFAULT_CONSUMPTION_W = C.PANEL_NOMINAL_W

return C
