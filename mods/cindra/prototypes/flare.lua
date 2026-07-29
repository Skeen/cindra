-- Cindra sunward-band solar variants (§15-7 solar + flare, § ci-9ht sunward
-- scaling; DESIGN.md §5). Integrated from the proven flare-poc (ci-zg3).
--
-- Cindra uses the PLAIN VANILLA solar panel (ci-8al): there is no bespoke Cindra
-- panel tier. The flare behaviour is entirely a property of the SURFACE (a fixed
-- high solar multiplier + the daylight-curve flare, prototypes/planet.lua +
-- scripts/flare.lua), which the engine already applies to any solar panel on
-- Cindra. So on Cindra a vanilla panel swings from a 400 kW baseline between
-- flares to a ~6 MW peak (ci-ezk), and the disposal-deficit rule (§15-8) degrades
-- those same vanilla panels when their surplus has nowhere to go -- all without a
-- custom entity.
--
-- The ONE thing that still needs new prototypes is sunward output scaling
-- (§ ci-9ht): a panel's output should fall off nightward. Factorio's solar output
-- is per-SURFACE, not per-position, so the engine-native way to make output
-- position-dependent is to give a panel a fixed `production` that already encodes
-- its band and let the engine's daylight/flare curve multiply it. We therefore
-- clone the vanilla panel into a few reduced-output VARIANTS; scripts/panels.lua
-- morphs a placed vanilla panel to the variant matching its sunward Y. The FULL
-- band (1.0) is the vanilla panel itself, so a sunward placement never morphs.
--
-- We add ONLY new prototypes and DEEP-COPY the shared vanilla solar-panel before
-- touching the copy, so no other planet's solar behaviour changes (the
-- never-mutate-other-planets invariant).

local util = require("util")
local C = require("scripts.flare-config")
local panel_solar = require("scripts.panel-solar")

local function watts(w) return string.format("%dW", math.floor(w)) end

local vanilla = data.raw["solar-panel"]["solar-panel"]

-- Position-scaled output variants (§ ci-9ht). Each reduced band is a deep-copy of
-- the VANILLA solar panel with a smaller fixed `production`; scripts/panels.lua
-- morphs a placed panel to the variant matching its sunward Y. Variants have NO
-- item/recipe of their own -- the player only ever crafts/holds the vanilla panel
-- (C.PANEL), which morphs in place -- so mining any variant returns the vanilla
-- item and a blueprint / pipette maps back to it. The engine's daylight/flare
-- curve multiplies each variant's production natively, so position scaling
-- composes with the flare for free (no per-tick power scripting). Only new
-- prototypes are added; the shared vanilla solar panel is untouched (deep-copied),
-- so the never-mutate-other-planets invariant holds.
local variants = {}
for _, factor in ipairs(panel_solar.BANDS) do
  if factor < 1.0 then
    local v = util.table.deepcopy(vanilla)
    v.name = panel_solar.name_for_band(factor)
    v.production = watts(C.PANEL_NOMINAL_W * factor)
    v.minable = { mining_time = vanilla.minable.mining_time, result = C.PANEL }
    v.placeable_by = { item = C.PANEL, count = 1 }
    v.next_upgrade = nil
    -- Present as "the same panel" in-game: identical name/description as the
    -- vanilla panel, so a band is a silent output difference, not a different
    -- building to the player.
    v.localised_name = { "entity-name." .. C.PANEL }
    v.localised_description = { "entity-description." .. C.PANEL }
    variants[#variants + 1] = v
  end
end

data:extend(variants)
