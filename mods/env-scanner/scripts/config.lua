-- Shared constants for the environmental scanner. One module so the data stage
-- (prototypes), the runtime (scanner/forecast), and the tests all agree on the
-- same names and numbers.

local readings = require("scripts.readings")

local C = {}

-- === Prototype names =========================================================
C.SCANNER = "environmental-scanner" -- the buildable circuit-hub entity/item/recipe

-- Runtime animation overlays (ci-0e8). A constant-combinator renders through a
-- STATIC Sprite4Way (the `sprites` field has no frame_count), so the buildable
-- body cannot frame-animate from the prototype. The building instead keeps a
-- static first-frame `sprites` (used by the ghost/blueprint/factoriopedia
-- previews) and the runtime draws these AnimationPrototypes on top of each
-- placed scanner via rendering.draw_animation, so it genuinely animates
-- in-world without regressing previews or changing the entity type. See
-- prototypes/scanner.lua and scripts/scanner.lua.
C.BODY_ANIM = "environmental-scanner-body-animation" -- animated building body
C.GLOW_ANIM = "environmental-scanner-glow-animation" -- animated emissive glow

-- Playback speed of the overlay animations, in frames advanced per tick. 0.25
-- => a full 20-frame loop every 80 ticks (~1.3 s): a gentle idle flicker, not a
-- strobe. Passed to rendering.draw_animation (the runtime param, not the
-- prototype field, drives runtime-drawn playback).
C.ANIM_SPEED = 0.25

-- === Runtime cadence =========================================================
-- The scanner refreshes its signals every UPDATE_INTERVAL ticks. Fine enough to
-- track a flare ramp, coarse enough to be cheap. on_nth_tick is REPLACE-not-add,
-- so this N must be unique within the mod (it is the only periodic handler).
C.UPDATE_INTERVAL = 15

-- Nominal day length (ticks) used to scale the TICK_OF_DAY signal. See
-- readings.DEFAULT_DAY_TICKS -- documented as an approximation in README.md.
C.DAY_TICKS = readings.DEFAULT_DAY_TICKS

-- === Cross-mod flare contract ================================================
-- Optional integration with Cindra's flare system (ci-9k6). The scanner emits
-- flare-forecast signals ONLY when a mod registers this remote interface; when
-- absent, that signal set is simply inactive (graceful degradation, no hard
-- dependency on cindra).
--
-- REACTIVE early-warning contract (ci-2ba): Cindra's flares are SPORADIC (no
-- fixed schedule to read off a clock), so the provider returns nil during calm
-- and only reports a forecast once a flare has entered its telegraph or is
-- active. That is what makes this scanner genuinely valuable - it is an
-- early-warning device, not a schedule display. Contract for the flare owner:
--
--   remote.add_interface("cindra-flare", {
--     forecast = function(surface_index)
--       -- nil during calm (no imminent/active flare) OR a non-cindra surface;
--       -- else, once a sporadic flare is telegraphing/active:
--       return { countdown = <ticks:int>, phase = <"warning".."decay">, intensity = <x-baseline:number> }
--     end,
--   })
C.FLARE_INTERFACE = "cindra-flare"
C.FLARE_METHOD = "forecast"

-- === Signal emission order ===================================================
-- Deterministic order the runtime writes slots in, so output (and tests) are
-- stable. Generic signals first, then the optional flare-forecast block.
local S = readings.SIGNALS
C.SIGNAL_ORDER = {
  S.DAYTIME, S.DAYLIGHT, S.SOLAR, S.TICK_OF_DAY,
  S.FLARE_COUNTDOWN, S.FLARE_PHASE, S.FLARE_INTENSITY,
}

return C
