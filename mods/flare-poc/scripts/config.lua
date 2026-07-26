-- Shared tuning constants for the flare PoC (planet_design.md sec.10/12/16).
--
-- One module so the data stage (prototypes) and the runtime (flare/panels/sinks)
-- agree on the same numbers, and so tests can read them instead of hard-coding.
-- Every value here is a PoC starting point (marked (tune) in the spec); the
-- README documents how to scale them to real-time cadence.

local C = {}

-- The scratch surface the whole PoC lives on. Every runtime handler is gated on
-- `surface.name == C.SURFACE`, so the mod is inert on nauvis and every real
-- planet (the never-mutate-other-planets rule, AGENTS.md).
C.SURFACE = "flare-poc"

-- === Solar / flare magnitudes (sec.10 "HIGH-INTENSITY SOLAR VIA DAYLIGHT CURVE")
-- Fixed high surface solar multiplier (spec: ~10000% of Nauvis). Never changed
-- at runtime: the flare swing comes from the daylight cycle, NOT from moving
-- this number (that would be the "artificial overdrive" the spec forbids).
C.SOLAR_MULT = 100
-- Each flare panel's Nauvis-full-day output (W), before the surface multiplier.
C.PANEL_NOMINAL_W = 100e3 -- 100 kW
-- Intensity is measured in "Nauvis full-day equivalents" = sf * SOLAR_MULT.
-- Baseline (the never-fully-dark night floor) is one Nauvis full day; the flare
-- peak is SOLAR_MULT of them, i.e. ~100x baseline.
C.BASELINE_INTENSITY = 1.0
C.PEAK_INTENSITY = C.SOLAR_MULT -- 100x baseline

-- Daylight curve set on the surface so the engine's own solar factor is exactly
-- sf(daytime) = 1 - daytime/EVENING for daytime in [0, EVENING]. With dusk = 0
-- the sun begins dimming from noon; we keep daytime inside [0, DAYTIME_FLOOR] so
-- solar output never reaches true night (the non-zero floor).
C.DUSK = 0.0
C.EVENING = 0.5
C.MORNING = 0.75 -- past our range; only the dusk->evening ramp is ever used
C.DAWN = 1.0
-- Actual engine solar factor at the two ends: peak = noon, floor = the dim
-- baseline where sf = BASELINE_INTENSITY / SOLAR_MULT (= 0.01 -> 1x after mult).
C.SF_PEAK = 1.0
C.SF_FLOOR = C.BASELINE_INTENSITY / C.SOLAR_MULT

-- === Flare schedule (ticks) ==================================================
-- Compressed for fast tests; scale up for real play (see README). Telegraphed
-- and regular so capture/dump capacity can be engineered (spec: NOT random).
C.CALM_TICKS = 600     -- quiet stretch on baseline solar (safe, no damage risk)
C.WARNING_TICKS = 180  -- telegraph: alarm + countdown, power still at baseline
C.RAMP_TICKS = 120     -- fast ramp baseline -> peak
C.PLATEAU_TICKS = 300  -- sustained peak
C.DECAY_TICKS = 120    -- fast ramp peak -> baseline
C.PERIOD_TICKS = C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS
  + C.PLATEAU_TICKS + C.DECAY_TICKS

-- === Panel damage (sec.10 "Panel damage mechanic") ===========================
C.PANEL = "flare-solar-panel"
C.PANEL_MAX_HEALTH = 200
-- Damage budget per sweep scales with the disposal DEFICIT (MW with nowhere to
-- go), never with panel count (mirrors the induction-damage kernel).
C.HP_PER_MW_DEFICIT = 4.0
-- Recovery when disposal is sufficient: over-budget panels ran "hot" but recover
-- if you add disposal. Regen per safe sweep, so degradation is reversible.
C.RECOVERY_HP_PER_SWEEP = 6.0
-- Degrade-before-death: a panel can lose at most this much health per sweep, so
-- a panel always runs "hot" (reduced efficiency) for several sweeps before it
-- can die. Deaths only happen under a SUSTAINED deficit (spec: "die if sustained").
C.MAX_HP_LOSS_PER_SWEEP = 20.0
-- How often the damage/recovery sweep runs.
C.DAMAGE_INTERVAL = 20
-- Cadence of the flare-driver tick (distinct N from DAMAGE_INTERVAL, since
-- on_nth_tick is replace-not-add per N).
C.FLARE_INTERVAL = 21

-- === Sinks (sec.10 "disposal problem", sec.12 items 5-6) =====================
-- Dissipator: infinite safe waste, but rate-limited per building. The floor and
-- the sacrificial fuse; its rated draw is counted BEFORE any panel is damaged.
C.DISSIPATOR = "flare-dissipator"
C.DISSIPATOR_DRAW_W = 20e6 -- 20 MW per building
-- Capacitor: fast, small. Catches the sharp leading edge of the flare.
C.CAPACITOR = "flare-capacitor"
C.CAPACITOR_BUFFER_J = 5e6  -- 5 MJ
C.CAPACITOR_FLOW_W = 5e6    -- 5 MW
-- Molten-salt battery: bulk, slow. Soaks the sustained plateau. Must stay hot or
-- it self-discharges (heat upkeep), modelled as a slow scripted drain.
C.BATTERY = "flare-molten-salt-battery"
C.BATTERY_BUFFER_J = 200e6 -- 200 MJ
C.BATTERY_FLOW_W = 2e6     -- 2 MW
-- Heat upkeep: fraction of the battery's *capacity* lost per driver tick when
-- idle-cold. Small, but present, so the battery is itself a mild power sink and
-- thrives here / is awkward elsewhere (spec sec.12 item 6).
C.BATTERY_UPKEEP_FRACTION = 0.0005

-- Test-only measurement rig: an accumulator with flow far above the flare peak,
-- so it absorbs a panel's full output WITHOUT throttling. Reading its energy
-- delta over a window measures real, unthrottled engine solar output (used to
-- prove the ~100x peak against the engine, not just the canonical model).
C.MEASURE_SINK = "flare-measurement-sink"
C.MEASURE_FLOW_W = 500e6
C.MEASURE_BUFFER_J = 5e9

-- Baseline factory consumption on the grid (W). Baseline solar runs the factory
-- between flares (spec: storage is NOT life-support); default equals one panel's
-- baseline so a lone panel grid is net-neutral at rest.
C.DEFAULT_CONSUMPTION_W = C.PANEL_NOMINAL_W

return C
