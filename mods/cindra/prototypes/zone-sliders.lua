-- The ribbon's WORLD-GEN-SCREEN sliders (ci-i4z): playable width + hot/cold zone depth.
--
-- ci-i8a put Cindra's stone + ice DENSITY on the new-game map-gen screen (real
-- Frequency / Size / Richness sliders, via autoplace-controls). This finishes the job
-- for the ribbon GEOMETRY: the width of the habitable band you build in, and how deep
-- the hot and cold zones run. Those were startup mod settings only -- the wrong place
-- for a world-shaping choice, and invisible when you start a new game.
--
-- WHY IT IS AN AUTOPLACE CONTROL. The engine has no custom scalar slider for the
-- map-gen screen; an autoplace-control is the only player-facing map-gen knob a mod can
-- add. A "terrain"-category control shows Frequency + Size dropdowns (richness is
-- resource-only), and every control publishes its dropdown values to the noise system
-- as the constants `control:<name>:frequency` / `:size`. So the ribbon geometry rides
-- on SIZE: a bigger Size = a wider band, which is the reading a player already has.
-- (Frequency is not wired to anything: there is nothing on a fixed ribbon band for a
-- "how often" multiplier to mean.) `can_be_disabled = false` keeps the "None" option
-- off the dropdown -- a zone of width zero is not a world.
--
-- THE THREE-STEP RESOLUTION (why there are two expressions per slider).
--   1. `cindra_ribbon_scale_<key>` is a GLOBAL named expression pinned to 1. Any
--      surface that is not Cindra resolves the warp through these, so the warp is the
--      IDENTITY off-planet: no Cindra map-gen expression ever asks a foreign surface
--      for a control it does not have (the never-touch-another-planet invariant), and
--      a Cindra surface with default sliders generates exactly the ci-oe83 world.
--   2. `cindra_ribbon_slider_<key>` READS the map-gen screen value.
--   3. The Cindra planet's `property_expression_names` overrides (1) with (2) -- the
--      documented resolution order is local names, then the surface's
--      property_expression_names, then global prototype names -- so the sliders are
--      live on Cindra and only on Cindra.
--
-- `cindra_perp` / `cindra_perp_neg` are the warped NOMINAL axis every band mask in the
-- mod reads (scripts/axis.lua returns their names). One warp, whole world.

local zone_scale = require("scripts.zone-scale")

local controls, expressions = {}, {}

for _, s in ipairs(zone_scale.SLIDERS) do
  controls[#controls + 1] = {
    type = "autoplace-control",
    name = s.control,
    category = "terrain",
    -- Terrain controls never show a richness slider; the width rides on Size.
    richness = false,
    -- No "None": disabling a ribbon zone would generate a world with no such band.
    can_be_disabled = false,
    order = s.order,
  }
  -- (1) the identity default, for every surface that is not Cindra.
  expressions[#expressions + 1] = {
    type = "noise-expression",
    name = s.var,
    expression = "1",
  }
  -- (2) the Cindra-only reader: the map-gen screen's Size dropdown for this control.
  -- Clamping lives in the warp (scripts/zone-scale.lua), the one place the runtime and
  -- the map-gen share, so this expression stays a plain read.
  expressions[#expressions + 1] = {
    type = "noise-expression",
    name = zone_scale.reader_name(s.key),
    expression = 'var("control:' .. s.control .. ':' .. zone_scale.SLIDER_PROPERTY .. '")',
  }
end

-- The warped NOMINAL perpendicular axis: the single coordinate every ribbon band is
-- read against (scripts/axis.lua perp_expr / perp_neg_expr return these names).
expressions[#expressions + 1] = {
  type = "noise-expression",
  name = zone_scale.PERP_EXPR,
  expression = zone_scale.perp_expr(),
}
expressions[#expressions + 1] = {
  type = "noise-expression",
  name = zone_scale.PERP_NEG_EXPR,
  expression = "(0 - " .. zone_scale.PERP_EXPR .. ")",
}

data:extend(controls)
data:extend(expressions)

-- What prototypes/planet.lua folds into the Cindra map-gen settings: the controls to
-- SHOW on the map-gen screen, and the per-slider overrides that make them live.
local M = {}

function M.autoplace_controls()
  local out = {}
  for _, s in ipairs(zone_scale.SLIDERS) do out[s.control] = {} end
  return out
end

function M.property_expression_names()
  local out = {}
  for _, s in ipairs(zone_scale.SLIDERS) do out[s.var] = zone_scale.reader_name(s.key) end
  return out
end

return M
