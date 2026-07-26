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
-- Each panel's Nauvis-full-day output (W), before the surface multiplier.
C.PANEL_NOMINAL_W = 100e3 -- 100 kW
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
-- Telegraphed and regular so capture/dump capacity can be engineered against a
-- known magnitude and cadence (spec: the flare is NOT random). These are the
-- flare-poc's compressed values (one flare every 22 s) so the tests stay fast;
-- real play scales the whole schedule up ~10-30x (a flare every few minutes)
-- once the sky-telegraph visuals exist. (tune) -- final cadence is §15-14.
C.CALM_TICKS = 600     -- quiet stretch on baseline solar (safe, no damage risk)
C.WARNING_TICKS = 180  -- telegraph: alarm + countdown, power still at baseline
C.RAMP_TICKS = 120     -- fast ramp baseline -> peak
C.PLATEAU_TICKS = 300  -- sustained peak
C.DECAY_TICKS = 120    -- fast ramp peak -> baseline
C.PERIOD_TICKS = C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS
  + C.PLATEAU_TICKS + C.DECAY_TICKS

-- === Panel damage (§15-8 "disposal-deficit rule") ============================
C.PANEL = "cindra-solar-panel"
C.PANEL_MAX_HEALTH = 200
-- Damage budget per sweep scales with the disposal DEFICIT (MW with nowhere to
-- go), never with panel count (mirrors the induction-damage kernel).
C.HP_PER_MW_DEFICIT = 4.0
-- Recovery when disposal is sufficient: over-budget panels ran "hot" but recover
-- if you add disposal, so degradation is reversible.
C.RECOVERY_HP_PER_SWEEP = 6.0

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

-- Capacitor: fast, SMALL. Huge flow, tiny buffer -> catches the sharp leading
-- edge of a flare but stores almost nothing. Situational-not-strictly-better vs
-- a vanilla accumulator (§12 guardrail): worse reservoir (smaller buffer),
-- better spike response (higher flow). It is a spike catcher, not bulk storage.
C.CAPACITOR = "cindra-capacitor"
C.CAPACITOR_BUFFER_J = 2e6  -- 2 MJ  (< vanilla accumulator's 5 MJ)
C.CAPACITOR_FLOW_W = 5e6    -- 5 MW  (>> vanilla accumulator's 300 kW)

-- Molten-salt battery: bulk, SLOW. Huge buffer, trickle flow -> soaks the
-- sustained plateau across an array but can never catch the spike alone.
-- Situational-not-strictly-better (§12): 40x the buffer of a vanilla
-- accumulator but an INTRINSICALLY lower throughput (so it is a reserve, not a
-- responsive buffer), PLUS a heat-upkeep self-discharge when left idle-cold
-- (scripts/sinks.lua) that makes it a mild sink here and awkward off-world.
C.BATTERY = "cindra-molten-salt-battery"
C.BATTERY_BUFFER_J = 200e6 -- 200 MJ (bulk: 40x a vanilla accumulator)
C.BATTERY_FLOW_W = 250e3   -- 250 kW (< vanilla accumulator's 300 kW: slow)
-- Heat upkeep: fraction of the battery's *capacity* lost per flare-driver tick
-- when idle. Small but present, so the battery is itself a mild power sink and
-- thrives on Cindra / is awkward elsewhere.
C.BATTERY_UPKEEP_FRACTION = 0.0005

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
