-- Position-scaled solar output (§ ci-9ht "solar output scales with sunward
-- position"). Solar panels only REALLY work on the sunny (sunward) part of the
-- ribbon; a panel's output scales with how far SUNWARD it sits and drops toward
-- ~nothing nightward, so panel PLACEMENT is a real decision.
--
-- WHY DISCRETE BANDS (not a per-tick scripted drain): Factorio's solar output is
-- per-SURFACE (surface solar multiplier + the daylight curve), not per-position.
-- The cheapest ENGINE-NATIVE way to make output position-dependent is to give a
-- panel a fixed `production` that already encodes its band, then let the engine's
-- own daylight/flare curve multiply it. So we clone the base panel into a few
-- reduced-output VARIANTS and, when a panel is placed, morph it to the variant
-- matching its Y (scripts/panels.lua reconcile). No per-tick power scripting, no
-- companion consumer entity, and the flare composition is automatic: each variant
-- is a real solar panel whose output already swings with the flare, so
-- real output = band_factor * (baseline..peak). The falloff SHAPE is the pure
-- ribbon curve (ribbon.sunward_factor); this module only SNAPS it to bands.
--
-- PURE MODULE (no game.* / prototypes.*): it loads in the data stage (to generate
-- the variant prototypes, prototypes/flare.lua), the control stage (to pick a
-- panel's variant + size its output for the damage model, scripts/panels.lua),
-- and the plain-Lua unit tests. The band list is the ONE source both stages read,
-- so the prototypes and the runtime can never drift.

local C = require("scripts.flare-config")
local ribbon = require("scripts.ribbon")

local M = {}

-- Output bands as a fraction of the panel's nominal output, sunward (1.0) ->
-- nightward (~0). The TOP band (1.0) IS the base panel prototype (C.PANEL, the
-- craftable item); the rest are reduced-output variants generated in
-- prototypes/flare.lua. More bands = smoother gradient at the cost of more
-- prototypes; five reads as clear "zones". (tune) -- balance pass is §15-14.
M.BANDS = { 1.0, 0.75, 0.5, 0.25, 0.05 }

-- Prototype name for a band factor. The full band is the base panel (so a
-- sunward placement needs no morph); every reduced band gets a "-bNN" suffix,
-- e.g. 0.25 -> "cindra-solar-panel-b25".
function M.name_for_band(factor)
  if factor >= 1.0 then return C.PANEL end
  return string.format("%s-b%02d", C.PANEL, math.floor(factor * 100 + 0.5))
end

-- All panel prototype names (base + variants) -- what find_entities_filtered must
-- match so the damage/potential sweeps see every band, not just the base.
function M.all_names()
  local names = {}
  for _, f in ipairs(M.BANDS) do names[#names + 1] = M.name_for_band(f) end
  return names
end

-- Snap the continuous sunward fraction at `y` to the nearest output band. A fixed
-- Y always snaps to the same band (a placed panel never moves), so a morphed
-- panel is stable -- it never flaps between bands.
function M.band_factor(y, cfg)
  local f = ribbon.sunward_factor(y, cfg)
  local best, best_d = M.BANDS[1], math.huge
  for _, b in ipairs(M.BANDS) do
    local d = math.abs(b - f)
    if d < best_d then best, best_d = b, d end
  end
  return best
end

-- The panel prototype name a panel at coordinate `y` should be (its band).
function M.variant_for_y(y, cfg)
  return M.name_for_band(M.band_factor(y, cfg))
end

-- Nominal output (W, before the flare/daylight multiplier) for a panel prototype
-- NAME. The damage model reads this so a panel's disposal burden matches the
-- real output it actually dumps on the grid: a nightward b05 produces ~nothing,
-- so it creates ~no surplus and takes ~no disposal-deficit damage. Unknown names
-- fall back to full nominal (a safe over-estimate).
function M.nominal_w(name)
  for _, f in ipairs(M.BANDS) do
    if M.name_for_band(f) == name then return C.PANEL_NOMINAL_W * f end
  end
  return C.PANEL_NOMINAL_W
end

return M
