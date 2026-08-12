-- Cindra mod settings.
--
-- 🚨 EVERY SETTING HERE MUST HAVE A WORLD EFFECT. A knob a player can move that
-- changes nothing is a lie the mod tells them, and it is worse than no knob at
-- all: they retune it, generate a world, and see the same planet. The guard in
-- tests/test_settings_live.lua enumerates these prototypes LIVE and fails when one
-- has no proven consumer, so a dead knob cannot ship again (ci-7k6).
--
-- WHAT DIED AND WHY (ci-7k6). v1 shipped three geometry sliders --
-- `cindra-ribbon-safe-half-width`, `cindra-ribbon-lethal-at` and
-- `cindra-ribbon-wall-at` -- that described the ORIGINAL three-band ribbon: a safe
-- half-width, a damage ramp saturating at a lethal distance, and a hard wall at the
-- map edge. Every one of those three things is now derived from somewhere else:
--   * the safe band + the lethal edges are wherever the ONE heightmap crosses its
--     damage thresholds (scripts/terrain.lua), which is a function of the per-zone
--     WIDTHS below -- and the damage a player takes is keyed to the TILE they stand
--     on (scripts/tile-damage.lua, ci-ma18), not to a distance from centre;
--   * the "wall" is gone: ci-wly dropped the impassable ice-wall (the hot-lava
--     ocean is the only impassable ground) and the world edge is the map-gen's own
--     finite dimension = the SUM of the zone widths (terrain.map_gen_bounds).
-- So all three read into cfg tables that nothing downstream ever looked at. They
-- are removed rather than re-wired: re-wiring would give the ribbon geometry a
-- SECOND source of truth alongside the zone widths, which is exactly the invariant
-- AGENTS.md forbids. The knob that still shapes the habitable band is
-- `cindra-zone-width-middle` (and its siblings) at the bottom of this file.
--
-- The two survivors both reach the world: ORIENTATION picks which axis carries the
-- gradient (scripts/axis.lua -> worldgen, resource masks, every sweep), and MAX-DPS
-- is the peak damage-per-second scripts/tile-damage.lua inflicts on a full-intensity
-- hazard tile. Both are (tune) starting points (§16).

data:extend({
  -- Ribbon ORIENTATION. Which way the survivable ribbon runs, and therefore which
  -- world axis carries the hot-cold gradient (see scripts/axis.lua):
  --   "vertical"   DEFAULT -- ribbon long axis N-S (bottom-to-top); hot-cold runs
  --                LEFT<->RIGHT with HOT on the LEFT (west). perpendicular = X.
  --   "horizontal" ribbon long axis E-W; hot-cold runs top-bottom with FIRE AT THE
  --                TOP (north, -Y) and ice at the bottom. perpendicular = Y.
  {
    type = "string-setting",
    name = "cindra-ribbon-orientation",
    setting_type = "startup",
    default_value = "vertical",
    allowed_values = { "vertical", "horizontal" },
    order = "a-orientation",
  },
  -- Peak environmental damage-per-second on a FULL-INTENSITY hazard tile (the
  -- hot-lava / smooth-ice ocean cores); shallower hazard tiles scale down from it.
  -- Survivable briefly with mitigation gear so the best edge resources are
  -- reachable at a cost. Read by scripts/tile-damage.lua every sweep.
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
