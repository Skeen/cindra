-- Cindra mod settings.
--
-- v1 exposes the ribbon-geometry tuning knobs so the temperature axis (§4) can
-- be balanced live without editing Lua. These mirror scripts/ribbon.lua's
-- DEFAULTS; the runtime systems that consume the axis (§15 item 2 onward) read
-- these. All are (tune) starting points (§16).

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
  -- (The old `cindra-nightside-freeze-temp` slider is gone: the nightside now
  -- freezes NATIVELY (§ freeze, ci-bvk) via entities_require_heating + the lava-heat
  -- emitter line, whose onset is DERIVED from the ribbon zone widths below -- not a
  -- separate temperature threshold. See scripts/freeze-emitters.lua.)
})

-- Per-zone WIDTH settings for the left->right worldgen gradient (ci-da2 / ci-a35).
--
-- Each zone of the ribbon tile gradient (scripts/terrain.lua) has its OWN width in
-- tiles. Changing one setting changes ONLY that band's width; the TOTAL ribbon
-- width is DERIVED = the SUM of all zone widths (never a standalone setting). The
-- list, defaults and order are the single source of truth in terrain.ZONES, looped
-- here so the settings and the geometry can never drift. Minimum 1 tile so EVERY
-- band -- including the sunward hot-lava layer -- always generates (ci-a35).
local terrain = require("scripts.terrain")
local zone_width_settings = {}
for i, z in ipairs(terrain.ZONES) do
  zone_width_settings[#zone_width_settings + 1] = {
    type = "int-setting",
    name = z.setting,
    setting_type = "startup",
    default_value = z.width,
    minimum_value = 1,
    maximum_value = 2000,
    -- Grouped after the axis knobs, ordered hot -> cold to match the gradient.
    order = string.format("z-zone-width-%02d-%s", i, z.role),
  }
end
data:extend(zone_width_settings)
