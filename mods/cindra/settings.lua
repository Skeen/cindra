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

-- PER-ZONE TERRAIN WIDTHS (ci-a35). Each visible terrain band (scripts/terrain.lua
-- M.ZONES) has its OWN width, in tiles, from the sunward (hot) edge inward to the
-- nightward (cold) edge. The generated world's perpendicular (across-ribbon) extent
-- is the SUM of every zone width, so changing one width changes both that band AND
-- the total ribbon width. These REPLACE the old single "ribbon width" as the map's
-- perpendicular size (the map-gen `width`/`height`). Functional names, no "Ribbon".
--
-- The hot-lava band (band #1) always generates at the sunward extreme: its floor is
-- 1 tile (terrain.HOT_LAVA_MIN_WIDTH) and its noise expression reaches the map edge.
-- Ordered "f-zone-<nn>" so they group together below the ribbon-axis knobs, hot ->
-- cold. Defaults mirror scripts/terrain.lua M.ZONES; all are (tune) starts (§16).
local ZONE_WIDTH_DEFAULTS = {
  { key = "hot-lava",              default = 8,  min = 1 },
  { key = "lava",                  default = 10, min = 0 },
  { key = "volcanic-cracks-hot",   default = 12, min = 0 },
  { key = "volcanic-cracks-warm",  default = 12, min = 0 },
  { key = "volcanic-cracks-plain", default = 12, min = 0 },
  { key = "jagged",                default = 14, min = 0 },
  { key = "dry-dirt",              default = 14, min = 0 },
  { key = "dirt",                  default = 14, min = 0 },
  { key = "sand",                  default = 48, min = 8 }, -- the temperate spawn centre
  { key = "aquilo-dust",           default = 32, min = 0 },
  { key = "rough-ice",             default = 32, min = 0 },
  { key = "smooth-ice",            default = 32, min = 0 },
}

local zone_settings = {}
for i, z in ipairs(ZONE_WIDTH_DEFAULTS) do
  zone_settings[i] = {
    type = "int-setting",
    name = "cindra-zone-width-" .. z.key,
    setting_type = "startup",
    default_value = z.default,
    minimum_value = z.min,
    maximum_value = 512,
    order = string.format("f-zone-%02d-%s", i, z.key),
  }
end
data:extend(zone_settings)
