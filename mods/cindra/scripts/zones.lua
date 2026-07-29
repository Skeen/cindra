-- The per-zone ribbon GRADIENT: the single source of truth for the map's
-- perpendicular band layout (ci-a35 worldgen v2).
--
-- The old ribbon defined its perpendicular extent with a few abstract knobs
-- (safe half-width / lethal-at / wall-at). ci-a35 replaces that with an ORDERED
-- list of named zones, each with its OWN width MOD SETTING. The world's
-- perpendicular (across-ribbon) extent is the SUM of every zone width, so
-- changing any one zone width changes both that band AND the total map width.
--
-- Gradient, HOT edge -> COLD edge (the planet's whole thesis painted on the
-- ground), with the DEFAULT widths (all `(tune)`, all configurable):
--
--   hot-lava 80 [FIRE] | lava 40 [FIRE] | cracks-hot 30 [FIRE] || cracks-warm 20 |
--   cracks-plain 10 | jagged 10 | dirt 10 | SAND 100 (spawn) | aquilo-dust 20
--   (varied) | rough-ice 20 | == ICE CLIFF == | smooth-ice 20 [FREEZE]
--
-- DAMAGE MAP (ci-a35): the three hottest bands (hot-lava, lava, cracks-hot) deal
-- ramping FIRE damage (hottest at hot-lava); ONLY smooth-ice (behind the ice
-- cliff, the deepest cold) deals FREEZE damage. Everything between -- cracks-warm
-- through rough-ice, including the wide SAND spawn band -- is SAFE / walkable.
--
-- The layout is GEOMETRIC-CENTRED on the world origin: the whole band is centred
-- at perpendicular coordinate p = 0, so the map-gen's own symmetric `width`
-- (= the sum) voids everything beyond +/- sum/2 (the void backstop; the engine
-- has no asymmetric void and cannot autoplace out-of-map). The temperate SPAWN
-- sits at the SAND band centre, which -- because the hot side carries more/wider
-- bands than the cold side -- lands OFF the geometric centre; scripts/ribbon.lua
-- reads `ref` (the sand centre) so temperature / solar / building-heat are keyed
-- to the spawn, and scripts/driver.lua sets the force spawn there.
--
-- DELIBERATELY PURE (no game.* / prototypes.*): it reads the width mod settings
-- when `settings` exists (data + control stages) and falls back to the defaults
-- otherwise (plain-Lua unit tests), exactly like scripts/axis.lua. That keeps the
-- geometry deterministic and unit-testable off the game.

local M = {}

-- The ordered gradient. Each zone:
--   name       functional id (no "Ribbon"); the width setting is cindra-zone-<name>-width
--   tile       the base cindra-* tile placed in the band
--   clone_from vanilla tile(s) the tile art is cloned from (a list => a VARIED band
--              with several tile variants for visual variety, e.g. Aquilo dust)
--   default    default width (tiles)
--   min        minimum width (hot-lava is forced > 0 so a hot edge ALWAYS exists)
--   damage     "fire" | "freeze" | nil  (the tile damage kind; nil = safe)
--   intensity  relative damage magnitude within a damage kind (ramps the fire band)
M.SPEC = {
  { name = "hot-lava",     tile = "cindra-hot-lava",     clone_from = "lava-hot",              default = 80,  min = 1, damage = "fire",   intensity = 1.0 },
  { name = "lava",         tile = "cindra-lava-field",   clone_from = "lava",                  default = 40,  min = 0, damage = "fire",   intensity = 0.6 },
  { name = "cracks-hot",   tile = "cindra-cracks-hot",   clone_from = "volcanic-cracks-hot",   default = 30,  min = 0, damage = "fire",   intensity = 0.3 },
  { name = "cracks-warm",  tile = "cindra-cracks-warm",  clone_from = "volcanic-cracks-warm",  default = 20,  min = 0, damage = nil },
  { name = "cracks-plain", tile = "cindra-cracks-plain", clone_from = "volcanic-cracks",       default = 10,  min = 0, damage = nil },
  { name = "jagged",       tile = "cindra-jagged",       clone_from = "volcanic-jagged-ground",default = 10,  min = 0, damage = nil },
  { name = "dirt",         tile = "cindra-dirt",         clone_from = "dry-dirt",              default = 10,  min = 0, damage = nil },
  { name = "sand",         tile = "cindra-sand",         clone_from = "sand-1",                default = 100, min = 0, damage = nil, spawn = true },
  { name = "aquilo-dust",  tile = "cindra-aquilo-dust",  clone_from = { "dust-flat", "dust-lumpy", "dust-patchy" }, default = 20, min = 0, damage = nil },
  { name = "rough-ice",    tile = "cindra-rough-ice",    clone_from = "ice-rough",             default = 20,  min = 0, damage = nil, cliff_after = true },
  { name = "smooth-ice",   tile = "cindra-smooth-ice",   clone_from = "ice-smooth",            default = 20,  min = 0, damage = "freeze", intensity = 1.0 },
}

-- The startup-setting key that tunes a zone's width.
function M.setting_name(name)
  return "cindra-zone-" .. name .. "-width"
end

-- Resolve a zone's width: the mod setting when present (data + control stages),
-- else the spec default (unit tests). Clamped to the spec minimum so hot-lava can
-- never be tuned to zero (a hot edge ALWAYS exists, ci-a35 item 2).
function M.width(spec)
  local w = spec.default
  local s = settings and settings.startup and settings.startup[M.setting_name(spec.name)]
  if s and s.value ~= nil then w = s.value end
  if spec.min and w < spec.min then w = spec.min end
  return w
end

-- The full geometric-centred layout. Returns:
--   total        sum of every zone width (= the finite perpendicular map extent)
--   half         total / 2 (the void backstop distance; map spans p in [-half, half])
--   zones        the SPEC entries decorated with resolved width + perpendicular
--                bounds { lo_p, hi_p, center_p } (hi_p is the HOTTER / higher-p side)
--   hot_edge_p   +half  (outer edge of the hottest band, at the void)
--   cold_edge_p  -half  (outer edge of the coldest band, at the void)
--   ref          perpendicular coordinate of the SAND band centre (the temperate
--                spawn reference every axis curve is keyed to)
--   cliff_p      the rough-ice / smooth-ice boundary (where the ice cliff wall runs)
function M.layout()
  local total = 0
  for _, spec in ipairs(M.SPEC) do total = total + M.width(spec) end
  local half = total / 2

  local zones = {}
  local cursor = half              -- start at the hot edge, walk toward cold
  local ref, cliff_p = 0, nil
  for i, spec in ipairs(M.SPEC) do
    local w = M.width(spec)
    local hi_p, lo_p = cursor, cursor - w
    local z = {
      name = spec.name, tile = spec.tile, clone_from = spec.clone_from,
      width = w, damage = spec.damage, intensity = spec.intensity,
      spawn = spec.spawn, varied = (type(spec.clone_from) == "table"),
      lo_p = lo_p, hi_p = hi_p, center_p = (hi_p + lo_p) / 2,
    }
    zones[i] = z
    if spec.spawn then ref = z.center_p end
    if spec.cliff_after then cliff_p = lo_p end   -- cliff on this band's COLD boundary
    cursor = lo_p
  end

  return {
    total = total, half = half, zones = zones,
    hot_edge_p = half, cold_edge_p = -half,
    ref = ref, cliff_p = cliff_p,
  }
end

-- Geometry the abstract ribbon axis (scripts/ribbon.lua) keys its temperature /
-- solar curves to. `ref` is the temperate spawn (sand centre); `hot_reach` /
-- `cold_reach` are the tile distances from `ref` out to the hot / cold void edge;
-- `hot_damage_start` / `cold_damage_start` are the perpendicular coordinates where
-- the fire / freeze bands begin (so downstream curves line up with the tiles).
function M.geometry()
  local L = M.layout()
  -- Hot damage begins at the cold boundary of the innermost FIRE zone (cracks-hot),
  -- and reaches full at the outer (hottest) fire zone (hot-lava).
  local hot_damage_start, hot_full_at
  local cold_damage_start
  for _, z in ipairs(L.zones) do
    if z.damage == "fire" then
      if not hot_damage_start or z.lo_p < hot_damage_start then hot_damage_start = z.lo_p end
      if not hot_full_at or z.lo_p > hot_full_at then hot_full_at = z.lo_p end
    elseif z.damage == "freeze" then
      cold_damage_start = z.hi_p
    end
  end
  hot_damage_start = hot_damage_start or L.hot_edge_p
  hot_full_at = hot_full_at or L.hot_edge_p
  cold_damage_start = cold_damage_start or L.cold_edge_p
  return {
    total = L.total, half = L.half, ref = L.ref,
    hot_edge_p = L.hot_edge_p, cold_edge_p = L.cold_edge_p,
    hot_reach = L.hot_edge_p - L.ref,
    cold_reach = L.ref - L.cold_edge_p,
    hot_damage_start = hot_damage_start,   -- fire begins (cracks-hot cold edge)
    hot_full_at = hot_full_at,             -- fire full (hot-lava cold edge)
    cold_damage_start = cold_damage_start, -- freeze begins (smooth-ice hot edge)
    cliff_p = L.cliff_p,
  }
end

return M
