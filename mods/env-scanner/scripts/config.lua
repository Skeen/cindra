-- Shared constants for the environmental scanner. One module so the data stage
-- (prototypes), the runtime (scanner/forecast), and the tests all agree on the
-- same names and numbers.

local readings = require("scripts.readings")

local C = {}

-- === Prototype names =========================================================
C.SCANNER = "environmental-scanner" -- the buildable circuit-hub entity/item/recipe

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
-- dependency on cindra). Contract, for the flare-system owner to implement:
--
--   remote.add_interface("cindra-flare", {
--     forecast = function(surface_index)
--       -- return nil when no flare schedule applies to this surface, else:
--       return { countdown = <ticks:int>, phase = <"calm".."decay">, intensity = <x-baseline:number> }
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
