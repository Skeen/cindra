-- Cindra mod settings.
--
-- v1 exposes the ribbon-geometry tuning knobs so the temperature axis (§4) can
-- be balanced live without editing Lua. These mirror scripts/ribbon.lua's
-- DEFAULTS; the runtime systems that consume the axis (§15 item 2 onward) read
-- these. All are (tune) starting points (§16).
--
-- ci-a35: the world's PERPENDICULAR (across-ribbon) extent is now defined by
-- PER-ZONE WIDTH settings (one per named band, generated below from
-- scripts/zones.SPEC). The map width = the SUM of every zone width, so tuning any
-- band changes both that band AND the total ribbon width. The safe/lethal/wall
-- knobs below no longer set the map width; they remain the RESOURCE-band geometry
-- (scripts/resource-field.lua) and the temperature-curve saturation.

local zones = require("scripts.zones")

data:extend({
  -- Ribbon ORIENTATION. Which way the survivable ribbon runs, and therefore which
  -- world axis carries the hot-cold gradient (see scripts/axis.lua):
  --   "vertical"   DEFAULT -- ribbon long axis N-S (bottom-to-top); hot-cold runs
  --                LEFT<->RIGHT with HOT on the LEFT (west). perpendicular = X.
  --   "horizontal" ribbon long axis E-W; hot-cold runs top-bottom, hot sunward
  --                (+Y). perpendicular = Y (the legacy layout).
  {
    type = "string-setting",
    name = "cindra-ribbon-orientation",
    setting_type = "startup",
    default_value = "vertical",
    allowed_values = { "vertical", "horizontal" },
    order = "a-orientation",
  },
  -- Half-width (tiles) of the guaranteed-safe temperate band around the ribbon
  -- centre. Inside this, no environmental damage.
  {
    type = "int-setting",
    name = "cindra-ribbon-safe-half-width",
    setting_type = "startup",
    default_value = 24,
    minimum_value = 4,
    maximum_value = 128,
    order = "a-safe-half-width",
  },
  -- Distance (tiles) from centre at which environmental damage reaches its
  -- maximum (the lethal deep edge).
  {
    type = "int-setting",
    name = "cindra-ribbon-lethal-at",
    setting_type = "startup",
    default_value = 96,
    minimum_value = 16,
    maximum_value = 512,
    order = "b-lethal-at",
  },
  -- Distance (tiles) from centre of the hard-wall backstop: the player can never
  -- walk past this into instant death or off the usable map (§15 item 2).
  {
    type = "int-setting",
    name = "cindra-ribbon-wall-at",
    setting_type = "startup",
    default_value = 128,
    minimum_value = 16,
    maximum_value = 512,
    order = "c-wall-at",
  },
  -- Peak environmental damage-per-second at the lethal edge. Survivable briefly
  -- with mitigation gear so the best edge resources are reachable at a cost.
  {
    type = "double-setting",
    name = "cindra-ribbon-max-dps",
    setting_type = "startup",
    default_value = 200,
    minimum_value = 0,
    maximum_value = 10000,
    order = "d-max-dps",
  },
  -- Axis temperature (°C) at/below which unheated nightside machines freeze
  -- (§15-2 building-heat). Tuned so the freeze zone begins around the nightward
  -- edge of the safe band; the temperate ribbon never freezes.
  {
    type = "double-setting",
    name = "cindra-nightside-freeze-temp",
    setting_type = "startup",
    default_value = -30,
    minimum_value = -270,
    maximum_value = 25,
    order = "e-freeze-temp",
  },
})

-- PER-ZONE WIDTH settings (ci-a35): one int-setting per named band, in the
-- hot->cold gradient order. The world's perpendicular extent = the SUM of these,
-- so tuning a band changes both that band's width and the total ribbon width.
-- hot-lava has a minimum of 1 (its spec min) so a hot edge ALWAYS generates.
-- Functional names only (no "Ribbon"); ordered z-* so the zone widths group
-- together, in gradient order, below the axis knobs.
local zone_settings = {}
for i, spec in ipairs(zones.SPEC) do
  zone_settings[#zone_settings + 1] = {
    type = "int-setting",
    name = zones.setting_name(spec.name),
    setting_type = "startup",
    default_value = spec.default,
    minimum_value = spec.min or 0,
    maximum_value = 2000,
    order = string.format("z-zone-%02d-%s", i, spec.name),
  }
end
data:extend(zone_settings)
