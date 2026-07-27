-- Cindra mod settings (worldgen v2).
--
-- The ribbon-geometry and worldgen knobs, exposed so the planet can be tuned
-- without editing Lua. These drive scripts/config.lua, which builds the ribbon
-- cfg every runtime system consumes (the pure defaults live in
-- scripts/ribbon.lua). All are (tune) starting points (§16).
--
-- NOTE (§15 v2 item 7): the design prefers map-gen autoplace-control sliders on
-- the new-game world-gen screen. Cindra's resources/terrain are placed by a
-- runtime script (not vanilla autoplace), so wiring those controls to scripted
-- placement is a follow-up; startup mod settings are the working fallback the
-- spec allows.

data:extend({
  -- ORIENTATION: which way the ribbon's LONG axis runs. east-west (default) =>
  -- the hot-cold (perpendicular) axis is Y; north-south => it is X.
  {
    type = "string-setting",
    name = "cindra-ribbon-orientation",
    setting_type = "startup",
    default_value = "east-west",
    allowed_values = { "east-west", "north-south" },
    order = "a-orientation",
  },
  -- PLAYABLE WIDTH: half-width (tiles) of the temperate ribbon around the centre.
  -- Inside this, no environmental damage. Thin <-> thick to taste.
  {
    type = "int-setting",
    name = "cindra-playable-half-width",
    setting_type = "startup",
    default_value = 24,
    minimum_value = 4,
    maximum_value = 128,
    order = "b-playable-width",
  },
  -- HOT-ZONE DEPTH: tiles from the playable edge out to the sunward hard wall.
  -- The inner half is the survivable sand margin; the outer half is the lethal
  -- molten-rock + lava-ocean band.
  {
    type = "int-setting",
    name = "cindra-hot-zone-depth",
    setting_type = "startup",
    default_value = 104,
    minimum_value = 16,
    maximum_value = 512,
    order = "c-hot-depth",
  },
  -- COLD-ZONE DEPTH: tiles from the playable edge out to the nightward hard wall.
  -- Inner half = survivable icy margin; outer half = the lethal ice wall.
  {
    type = "int-setting",
    name = "cindra-cold-zone-depth",
    setting_type = "startup",
    default_value = 104,
    minimum_value = 16,
    maximum_value = 512,
    order = "d-cold-depth",
  },
  -- Peak environmental damage-per-second at the lethal edge. Survivable briefly
  -- with mitigation gear so the playable edge is reachable at a cost.
  {
    type = "double-setting",
    name = "cindra-ribbon-max-dps",
    setting_type = "startup",
    default_value = 200,
    minimum_value = 0,
    maximum_value = 10000,
    order = "e-max-dps",
  },
  -- Axis temperature (°C) at/below which unheated nightside machines freeze
  -- (building-heat). Tuned so the freeze zone begins around the nightward edge of
  -- the playable band; the temperate ribbon never freezes.
  {
    type = "double-setting",
    name = "cindra-nightside-freeze-temp",
    setting_type = "startup",
    default_value = -30,
    minimum_value = -270,
    maximum_value = 25,
    order = "f-freeze-temp",
  },
  -- NOTE: STONE + ICE density are NOT startup settings -- they are Frequency /
  -- Size / Richness SLIDERS on the new-game world-gen screen, driven by the
  -- `cindra-stone` / `cindra-ice` autoplace-controls (prototypes/resources.lua,
  -- wired into planet.lua's map gen; read at runtime by scripts/worldgen.lua).
  -- Orientation + band geometry stay startup settings: autoplace-controls only
  -- expose Frequency/Size/Richness, and there is no engine API for a custom
  -- scalar (tile-width) slider on the world-gen screen (§15 v2 item 7, ci-i4z).
})
