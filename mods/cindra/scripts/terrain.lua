-- Ribbon TERRAIN gradient: which tile paints each point of the hot-cold axis
-- (§4, worldgen tile layers). PURE module (no game.* / prototypes.*): it maps a
-- perpendicular coordinate `p` (sunward-positive, from scripts/axis.lua) to a
-- vanilla tile prototype name, reading the SAME band boundaries as
-- scripts/ribbon.lua so the VISIBLE terrain and the FELT damage share one axis.
--
-- The tiles ARE the gradient. From the hot edge (the deepest sunward tiles, at
-- the LEFT/west in the default vertical orientation) inward toward the temperate
-- ribbon, then out the cold side:
--
--   lava-hot  ->  lava  ->  volcanic-cracks-hot  ->  [sand]  ->  TEMPERATE
--                                                     [snow]  <-
--   <-  ammoniacal-ocean  <-  ice-rough  <-  ice-smooth
--
-- The three HOT tiles (lava-hot, lava, volcanic-cracks-hot) sit exactly in the
-- fire-damage zone (perp beyond the safe half-width), so the visible terrain
-- change lands on the damage boundary; the sand/snow FRINGE is the last strip of
-- the no-damage safe band, a visual blend into the temperate centre. lava /
-- lava-hot / ammoniacal-ocean are vanilla FLUID tiles (impassable, like water):
-- they form the molten / frozen lethal edge just inside the hard-wall void, so
-- the deepest edge reads as a wall you cannot walk into. The walkable
-- volcanic-cracks-hot / ice-smooth / ice-rough carry the survivable damage ramp.
--
-- Boundaries (depth d = |p|), read live from the ribbon config so the terrain
-- follows the same tuning sliders as the damage:
--   d <= safe_half_width - FRINGE     temperate (natural land; returns nil)
--   safe_half_width - FRINGE < d <= safe_half_width   sand / snow fringe
--   safe_half_width < d <= lethal_at  volcanic-cracks-hot / ice-smooth (ramp)
--   lethal_at < d <= edge_mid         lava / ice-rough
--   edge_mid < d < wall_at            lava-hot / ammoniacal-ocean (the wall)
--   d >= wall_at                      void (scripts/worldgen hard wall; nil here)

local ribbon = require("scripts.ribbon")

local M = {}

-- Vanilla tile prototype names, per side, ordered centre -> edge. Centralised so
-- a name fix is a single edit; scripts/worldgen validates each exists before
-- painting (a mistyped / missing tile is skipped, never a crash).
M.TILES = {
  -- Sunward / hot side (Vulcanus tiles).
  hot = {
    fringe = "sand-1",              -- inner transition, still in the safe band
    inner  = "volcanic-cracks-hot", -- walkable ramping-damage margin
    mid    = "lava",                -- molten (impassable)
    outer  = "lava-hot",            -- hottest molten edge (impassable, most lethal)
  },
  -- Nightward / cold side (Aquilo tiles).
  cold = {
    fringe = "snow-flat",           -- inner transition, still in the safe band
    inner  = "ice-smooth",          -- walkable freezing-damage margin
    mid    = "ice-rough",           -- deep ice
    outer  = "ammoniacal-ocean",    -- the frozen "ice wall" (impassable)
  },
}

-- Width (tiles) of the sand/snow fringe at the OUTER edge of the safe band. Kept
-- small so the wide temperate ribbon at spawn stays natural buildable land. (tune)
M.FRINGE = 4

-- Tile prototype name to paint at perpendicular coordinate `p`, or nil to leave
-- the natural (temperate) land. `cfg` is a partial ribbon config (defaults to
-- ribbon.DEFAULTS). Reads the SAME safe/lethal/wall boundaries as the damage.
function M.tile_for(p, cfg)
  cfg = ribbon.resolve(cfg)
  local d = math.abs(p)
  if d >= cfg.wall_at then return nil end -- the hard-wall void owns this
  local side = (p >= 0) and M.TILES.hot or M.TILES.cold
  local fringe_start = cfg.safe_half_width - M.FRINGE
  if d <= fringe_start then
    return nil                            -- temperate: leave natural land
  elseif d <= cfg.safe_half_width then
    return side.fringe                    -- sand / snow (still no damage)
  elseif d <= cfg.lethal_at then
    return side.inner                     -- volcanic-cracks-hot / ice-smooth
  else
    local edge_mid = (cfg.lethal_at + cfg.wall_at) / 2
    if d <= edge_mid then return side.mid else return side.outer end
  end
end

-- Every tile name this module can emit, deduplicated. scripts/worldgen uses this
-- to validate the set once against the running prototypes.
function M.all_tiles()
  local seen, out = {}, {}
  for _, side in pairs(M.TILES) do
    for _, name in pairs(side) do
      if not seen[name] then
        seen[name] = true
        out[#out + 1] = name
      end
    end
  end
  return out
end

return M
