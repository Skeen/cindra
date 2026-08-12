-- Worldgen placement of the lava-heat emitter line(s) (§ freeze, ci-bvk step 3).
--
-- Cindra's planet flag `entities_require_heating = true` freezes EVERY freezable
-- entity on the surface (frost, stopped machines, native pipe/fluid freeze) unless a
-- hot heat source is within reach. This module lines the invisible ambient lava-heat
-- emitters (prototypes/freeze-emitter.lua) along the ribbon so the habitable band
-- stays thawed and only the deep nightside freezes -- the ci-b5i inversion.
--
-- GEOMETRY (all derived from the ribbon, never hardcoded):
--   * The WARM band spans, in perpendicular coordinates, from the safe habitable
--     core's cold edge (the middle zone's nightward edge = the freeze ONSET) sunward
--     to the lava sea edge. Everything nightward of the onset freezes: cold_outer
--     becomes the reachable, buildable-but-FROZEN umbilical zone (drag a heat line
--     out to work it -- ci-f5l heaters matter), then the cold-damage rings, then the
--     deep-ice ocean. The onset is where the ice-side terrain gradient begins, so
--     "see the ice = warmth ends" reads as one clean line (was ci-4kz's ice wall,
--     now the ci-wly cold gradient).
--   * A single emitter row reaches only +/-R (=100) across the ribbon, i.e. a
--     201-tile-wide warm strip. The ci-wly habitable+hot span is ~260 tiles, wider
--     than one row, so scripts/freeze.perp_rows lays down SEVERAL parallel rows at
--     the exact 2R+1 offset (bead step 4's "second interior row"), their boxes
--     abutting with no frozen seam between rows.
--   * Along the ribbon's long axis each row is the global 2R+1 lattice
--     (freeze.lattice_coords): as each chunk generates we place exactly the lattice
--     emitters that fall INSIDE it, so every emitter is created once, seams line up
--     no matter the chunk order, and re-generation is idempotent (dedupe by position).
--
-- Both ribbon ORIENTATIONS are honoured: axis.world() maps each (long, perp) lattice
-- point back to the right (x, y). Scoped to `surface.name == "cindra"`; no other
-- planet is ever touched (the emitters exist only here, and the flag is per-planet).

local axis = require("scripts.axis")
local freeze = require("scripts.freeze")
local terrain = require("scripts.terrain")
local zone_scale = require("scripts.zone-scale")

local M = {}

local function is_cindra(s)
  return s and s.valid and s.name == "cindra"
end

-- Auto-placement toggle. Tests that measure the raw reach/seam against a hand-placed
-- emitter set this false so the worldgen line does not heat their fresh ground; it
-- defaults on for real play (and for the integration test that checks the real line).
local function autoplace_enabled()
  return storage.cindra_freeze_autoplace ~= false
end

-- The perpendicular WARM band [lo, hi] the emitter rows keep thawed, derived from the
-- live ribbon geometry (settings-aware via terrain). lo (onset) = the safe middle's
-- cold edge; hi = the lava sea edge (sunward buildable limit). `cfg` overrides the
-- zone widths for tests. Pure.
--
-- Returned in WORLD tiles, because an emitter's reach is a PHYSICAL radius: when the
-- world-gen-screen sliders (ci-i4z) stretch the habitable band, the band needs more
-- rows to stay thawed, and when they shrink it, fewer. `scales` are the slider
-- multipliers in force (zone_scale.for_surface); omitted = the unscaled geometry, so
-- the default world is unchanged.
function M.warm_band(cfg, scales)
  local onset = terrain.role_band("middle", cfg).lo
  local sunward = terrain.role_band("hot_ocean", cfg).lo
  return zone_scale.to_world(onset, scales, cfg), zone_scale.to_world(sunward, scales, cfg)
end

-- The perpendicular row centres for the warm band (a fixed, small set). Pure.
function M.rows(cfg, scales)
  local lo, hi = M.warm_band(cfg, scales)
  return freeze.perp_rows(lo, hi)
end

-- The exact freeze onset (nightward edge of the warm band), in world tiles. Pure.
function M.onset(cfg, scales)
  return freeze.onset(M.rows(cfg, scales))
end

-- Set a freshly created emitter hot so it warms its radius. A heat-pipe emits while
-- its buffer is hot; the periodic reheat sweep (below) keeps it there.
local function energize(e)
  e.temperature = freeze.EMITTER_TEMPERATURE
end

-- Cadence (ticks) at which emitter heat is re-affirmed. A heat-pipe is NOT
-- self-generating: warming the entities in its radius DRAINS its heat, so left alone
-- it would slowly cool and let the warm band re-freeze. Re-setting the temperature a
-- few times a second keeps every emitter pinned hot. Distinct from every other
-- periodic system (tile-damage 20, flare 23, panel-damage 29); reuses the N (47) the
-- retired scripted building-heat sweep used to own.
M.REHEAT_INTERVAL = 47

-- Re-affirm the heat on every emitter on surface `s` (a no-op off Cindra).
function M.reheat(s)
  if not is_cindra(s) then return end
  for _, e in pairs(s.find_entities_filtered({ name = freeze.EMITTER_NAME })) do
    if e.valid then e.temperature = freeze.EMITTER_TEMPERATURE end
  end
end

-- PURE: the world positions {x, y} of every emitter whose lattice point falls INSIDE
-- `area`, for orientation `orient` and zone `cfg`. `area` is a chunk-shaped tile box
-- { left_top = {x,y}, right_bottom = {x,y} }. No game.* access, so the placement
-- geometry is unit-testable for BOTH orientations off the game (orientation is a
-- startup setting fixed per run, so the engine test only exercises one).
function M.positions_in_area(area, orient, cfg, scales)
  local lt = area.left_top or area[1]
  local rb = area.right_bottom or area[2]

  -- The chunk's perpendicular + long spans (orientation-correct via the axis maps).
  local perps, longs = {}, {}
  for _, X in ipairs({ lt.x, rb.x }) do
    for _, Y in ipairs({ lt.y, rb.y }) do
      perps[#perps + 1] = axis.perp(X, Y, orient)
      longs[#longs + 1] = axis.long(X, Y, orient)
    end
  end
  local plo = math.min(perps[1], perps[2], perps[3], perps[4])
  local phi = math.max(perps[1], perps[2], perps[3], perps[4])
  local llo = math.min(longs[1], longs[2], longs[3], longs[4])
  local lhi = math.max(longs[1], longs[2], longs[3], longs[4])

  local out = {}
  local lattice = freeze.lattice_coords(llo, lhi)
  for _, row in ipairs(M.rows(cfg, scales)) do
    if row >= plo and row <= phi then
      for _, long in ipairs(lattice) do
        local x, y = axis.world(long, row, orient)
        out[#out + 1] = { x = x, y = y }
      end
    end
  end
  return out
end

-- Place (idempotently) every emitter whose lattice position falls inside `area` on
-- surface `s`. `area` is a chunk-shaped tile box (as delivered by on_chunk_generated).
-- Safe to call repeatedly on the same area: an emitter is created only where none
-- already sits (dedupe by exact position), so re-generation never duplicates.
function M.place_in_area(s, area, cfg)
  if not is_cindra(s) then return end
  -- The surface's own geometry sliders (ci-i4z): the line must reach across the band
  -- THIS surface actually generated, not the nominal one.
  local scales = zone_scale.for_surface(s)
  for _, pos in ipairs(M.positions_in_area(area, axis.orientation(), cfg, scales)) do
    if not s.find_entity(freeze.EMITTER_NAME, pos) then
      local e = s.create_entity({ name = freeze.EMITTER_NAME, position = pos, force = "player" })
      if e then
        e.destructible = false
        energize(e)
      end
    end
  end
end

-- Place the whole emitter line across every ALREADY-generated chunk of `s` (mod added
-- to a running save, or a surface that existed before the chunk handler registered).
-- New chunks are handled on_chunk_generated; interior chunks are covered here. Idempotent.
function M.place_all(s, cfg)
  if not is_cindra(s) then return end
  for chunk in s.get_chunks() do
    M.place_in_area(s, {
      left_top = { x = chunk.x * 32, y = chunk.y * 32 },
      right_bottom = { x = chunk.x * 32 + 32, y = chunk.y * 32 + 32 },
    }, cfg)
  end
end

-- on_chunk_generated hook: line the emitters as the ribbon reveals. A no-op off Cindra
-- and while auto-placement is disabled (deterministic reach tests).
function M.on_chunk_generated(event)
  if not autoplace_enabled() then return end
  local s = event.surface
  if not is_cindra(s) then return end
  M.place_in_area(s, event.area)
end

-- Called from the driver's on_init: seed the default toggle and cover existing chunks.
function M.init()
  if storage.cindra_freeze_autoplace == nil then storage.cindra_freeze_autoplace = true end
  if not autoplace_enabled() then return end
  for _, s in pairs(game.surfaces) do
    if is_cindra(s) then M.place_all(s) end
  end
end

return M
