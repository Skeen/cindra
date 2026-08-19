-- Native-freeze engine constants + emitter-line geometry (§ freeze, ci-bvk).
--
-- The SINGLE SOURCE OF TRUTH for the numbers behind Cindra's native freeze: the
-- engine's heat-emitter reach, the tight emitter spacing, and the deterministic
-- lattice the emitter line snaps to. Every part of the native-freeze mechanic
-- (the planet flag, the worldgen emitter placement, the ice-line alignment) reads
-- these; nothing re-derives the clamp. Kept DELIBERATELY PURE (no game.* /
-- prototypes.* access) so the geometry is fast, deterministic, and unit-testable
-- off the game (unit-tests/test_freeze.lua), exactly like scripts/ribbon.lua.
--
-- === EXACT CONSTANTS, MEASURED (ci-bvk step 1, re-measured against the SHIPPING
-- emitter) ===
-- The ci-b5i spike left the clamp APPROXIMATE ("~100-101"). CRUCIAL CORRECTION:
-- `heating_radius` is a HeatPipe/Reactor prototype field, NOT a HeatInterface one
-- (base changelog: "Added heating_radius to ReactorPrototype and HeatPipePrototype").
-- A heat-INTERFACE silently IGNORES heating_radius (it only warms its own tile), so
-- the shipping emitter is a 1x1 HEAT-PIPE (prototypes/freeze-emitter.lua) -- the one
-- entity that is both a single tile (exact reach) AND honours heating_radius. These
-- values were then MEASURED to the tile, headless in factorio-test, against that real
-- heat-pipe emitter on the Cindra `entities_require_heating` surface (the
-- tests/test_freeze.lua guard re-asserts them):
--
--   * REACH is a Chebyshev SQUARE, INCLUSIVE, of exactly 101 tiles for a
--     heating_radius = 100 heat-pipe. A freezable entity is THAWED iff |dx| <= 101
--     AND |dy| <= 101 from the emitter, and FROZEN at 102. Measured last-thawed tile
--     101, first-frozen 102, identical on +x, +y and the (101,101) diagonal corner
--     -- a square, not a disc. (Reach = heating_radius + 1: the extra tile is the
--     pipe's own half-tile footprint, measured, not assumed.)
--   * SEAM measured exact: two such emitters leave ZERO frozen tiles between them at
--     spacing 203 (= 2R+1) and open a one-tile frozen gap at 204 (= 2R+2). The 2R+1
--     spacing is a tight bound (contiguous, gap-free AND overlap-free), not padded.

local M = {}

-- The INVISIBLE, worldgen-placed ambient heat source that represents the LAVA's
-- own warmth radiating off the fire edge (prototypes/freeze-emitter.lua clones a
-- vanilla HEAT-PIPE into it; scripts/freeze-emitters.lua lines them along the ribbon
-- and holds them hot). It is NOT a player-built structure.
M.EMITTER_NAME = "cindra-lava-heat"

-- The temperature the emitter's heat is HELD at (re-affirmed periodically, since a
-- heat-pipe is not self-generating). REACH is a pure DISTANCE mechanic, independent
-- of how hot the source is, so this only needs to sit safely above the freeze point.
-- 1000 C: hot, the vanilla heat ceiling, no significance beyond "emitting".
M.EMITTER_TEMPERATURE = 1000

-- The emitter prototype's heating_radius (the HeatPipe field). 100 yields the
-- measured inclusive reach of 101 (reach = radius + 1, see above).
M.EMITTER_HEATING_RADIUS = 100

-- The exact MEASURED inclusive Chebyshev reach (tiles): a heating_radius-100 heat-pipe
-- thaws out to 101 and freezes at 102. This -- not the prototype radius -- is what the
-- lattice geometry is built from.
M.FREEZE_REACH = M.EMITTER_HEATING_RADIUS + 1 -- = 101, measured

-- Contiguous, gap-free AND overlap-free spacing along the emitter line. With an
-- INCLUSIVE reach R, emitter A covers [-R, R] and emitter B at 2R+1 covers
-- [R+1, 3R+1]: they ABUT exactly, no gap, no overlap (measured: no frozen tile at
-- 2R+1, a frozen gap at 2R+2). Derived from the pinned reach -- never hardcoded.
M.EMITTER_SPACING = 2 * M.FREEZE_REACH + 1 -- = 203

-- Chebyshev INCLUSIVE coverage predicate: is a point (dx, dy) tiles from an
-- emitter's centre thawed by that emitter? The load-bearing shape: because it is
-- a square (both axes independently bounded), a straight LINE of emitters yields
-- a STRAIGHT freeze front (no scallop) as long as the spacing keeps the boxes
-- abutting along the line. Pure.
function M.covers(dx, dy)
  return math.abs(dx) <= M.FREEZE_REACH and math.abs(dy) <= M.FREEZE_REACH
end

-- Deterministic emitter long-axis coordinates covering [lo, hi] with no gap,
-- SNAPPED to a fixed global lattice (integer multiples of EMITTER_SPACING). The
-- fixed lattice is what makes placement idempotent and seam-aligned no matter
-- which chunk (or in which order) the map-gen produces first: an emitter's world
-- coordinate is always exactly k * EMITTER_SPACING, so re-generating a chunk asks
-- for the SAME positions and a placement pass can dedupe by position. Returns the
-- ascending list of long-axis coordinates whose +/-R boxes together cover all of
-- [lo, hi]. Pure.
function M.line_coords(lo, hi)
  local S = M.EMITTER_SPACING
  local R = M.FREEZE_REACH
  -- Lattice index k places an emitter at k*S covering [k*S - R, k*S + R]. Its box
  -- overlaps [lo, hi] iff k*S + R >= lo and k*S - R <= hi.
  local first = math.ceil((lo - R) / S)
  local last = math.floor((hi + R) / S)
  local out = {}
  for k = first, last do
    out[#out + 1] = k * S
  end
  return out
end

-- The global-lattice points (multiples of EMITTER_SPACING) CONTAINED in [lo, hi].
-- This is the placement primitive along the ribbon's long axis: as each chunk
-- generates, place exactly the lattice emitters whose coordinate falls inside that
-- chunk, so every emitter is created once (when its own chunk generates) and the
-- fixed global lattice makes the set identical regardless of chunk order (idempotent
-- + seam-aligned). Contrast line_coords, which returns the (possibly wider) set of
-- lattice boxes that COVER [lo, hi] -- that answers "which emitters warm this range",
-- not "which emitters live in this chunk". Pure.
function M.lattice_coords(lo, hi)
  local S = M.EMITTER_SPACING
  local out = {}
  for k = math.ceil(lo / S), math.floor(hi / S) do
    out[#out + 1] = k * S
  end
  return out
end

-- The perpendicular ROW centres that keep the warm band [lo, hi] thawed, given a
-- single emitter row only reaches +/-R across the ribbon. One row (2R+1 = 201 tiles
-- wide) cannot span a band wider than 201, so a wide ribbon needs SEVERAL parallel
-- rows offset by EMITTER_SPACING (the same tight, abutting 2R+1 step the along-axis
-- lattice uses -- so the rows' boxes meet edge-to-edge with no frozen seam between
-- them, exactly as line_coords proves along the long axis). The first (nightward)
-- row is anchored so its cold edge sits EXACTLY on `lo`: that makes `lo` the precise
-- freeze ONSET the ice-side terrain gradient aligns to. Rows then step sunward until
-- one covers `hi`. Returns the ascending list of perpendicular row centres. Pure.
--
--   e.g. warm band [-60, 200] (the ci-wly habitable+hot span): rows { 40, 241 }.
--   Row 40 covers perp [-60, 140]; row 241 covers [141, 341]; they abut at 140/141
--   with no frozen seam, and together thaw everything from the onset (-60) sunward.
function M.perp_rows(lo, hi)
  local R, S = M.FREEZE_REACH, M.EMITTER_SPACING
  local rows = {}
  local c = lo + R -- first row: its nightward edge (c - R) lands exactly on lo
  rows[#rows + 1] = c
  while c + R < hi do
    c = c + S
    rows[#rows + 1] = c
  end
  return rows
end

-- ===========================================================================
-- HEAT COVERAGE (ci-de55): "would the engine thaw something standing here?"
-- ===========================================================================
--
-- The native freeze needs no such question -- the engine answers it per entity.
-- The SCRIPT freeze (scripts/script-freeze.lua) does, because the entity types it
-- covers are exactly the ones the engine refuses to freeze, so it will not answer
-- for them. This is the single source of truth for that answer, kept here beside
-- the reach constants it is derived from rather than re-derived at the call site.
--
-- THE RULE, MEASURED IN-ENGINE (ci-de55, on the Cindra surface, against BOTH a
-- 1x1 heat-pipe of radius 100 and a 3x3 reactor of radius 1 -- one huge and one
-- tiny, so the shape is pinned rather than fitted):
--
--   A heat source heats the TILES its own footprint occupies, GROWN OUTWARD BY
--   `heating_radius` tiles. An entity is thawed iff its own footprint tiles
--   OVERLAP that region.
--
--   * emitter (footprint 1 tile, radius 100): a 3x3 machine at Chebyshev centre
--     distance 101 thawed, 102 froze. Grown region spans 100 tiles each way from
--     the emitter's tile; the machine's nearest tile is 100 away at distance 101
--     (overlap) and 101 away at distance 102 (no overlap). Matches.
--   * electric heater (footprint 3x3, radius 1): a 3x3 machine at centre distance
--     3 thawed, 4 froze -- i.e. touching thaws, one tile of clear ground freezes.
--     Grown region reaches 1 tile past the heater's 3x3; the machine's nearest
--     tile lands inside it at 3 and outside at 4. Matches.
--
-- Everything is INTEGER TILE arithmetic, which is what makes the boundary exact:
-- the two entities' bounding boxes touch precisely at the knife edge in world
-- coordinates, and tile indices decide it without a float comparison. The claim
-- that this reproduces the engine is not left as a comment -- tests/test_script_freeze
-- puts a natively-freezable machine beside every script-frozen building along a
-- line crossing the boundary and asserts they agree tile for tile.
--
-- The only prototype types that honour `heating_radius` (base changelog: "Added
-- heating_radius to ReactorPrototype and HeatPipePrototype"). Enumerated live in
-- ci-de55 against the loaded registry: exactly six prototypes carry a non-zero
-- radius, and every one is a heat-pipe or a reactor.
M.HEAT_SOURCE_TYPES = { "heat-pipe", "reactor" }

-- Half-open integer TILE box {x0, y0, x1, y1} covering `box` (a bounding box in
-- world coordinates, i.e. entity.selection_box). Pure.
function M.tile_box(box)
  local lt = box.left_top or box[1]
  local rb = box.right_bottom or box[2]
  return {
    x0 = math.floor(lt.x or lt[1]), y0 = math.floor(lt.y or lt[2]),
    x1 = math.ceil(rb.x or rb[1]), y1 = math.ceil(rb.y or rb[2]),
  }
end

-- The tile region a source with `radius` keeps thawed: its own tiles grown by
-- `radius` outward. Pure.
function M.heated_region(tiles, radius)
  return {
    x0 = tiles.x0 - radius, y0 = tiles.y0 - radius,
    x1 = tiles.x1 + radius, y1 = tiles.y1 + radius,
  }
end

-- Do two half-open integer tile boxes share a tile? Pure.
function M.tiles_overlap(a, b)
  return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

-- Bucket size (tiles) of the coverage index below. Chosen at the emitter's own
-- scale: one cell is about one emitter reach, so a region lands in a handful of
-- cells and a cell holds a handful of regions. It is a PERFORMANCE knob only --
-- every cell size gives the same answers (unit-tested), so it can be retuned
-- without re-earning the geometry.
M.COVERAGE_CELL = 128

local function cell_range(region, cell)
  return math.floor(region.x0 / cell), math.floor((region.x1 - 1) / cell),
    math.floor(region.y0 / cell), math.floor((region.y1 - 1) / cell)
end

-- Index a list of heated REGIONS (each a tile box) into a coarse spatial hash, so
-- asking "is this building thawed?" costs a hash lookup plus a couple of box
-- tests instead of a scan over every heat source on the surface.
--
-- WHY IT MATTERS. A played-in Cindra has hundreds of worldgen lava-heat emitters
-- and can have thousands of solar panels; the naive nested loop is
-- sources x buildings per sweep, which is exactly the "correct but tanks UPS on a
-- large save" regression the ci-de55 ruling calls out. Pure, so the cost model is
-- unit-testable off the game.
function M.coverage_index(regions, cell)
  cell = cell or M.COVERAGE_CELL
  local buckets = {}
  for _, r in ipairs(regions) do
    local cx0, cx1, cy0, cy1 = cell_range(r, cell)
    for cx = cx0, cx1 do
      for cy = cy0, cy1 do
        local key = cx .. ":" .. cy
        local b = buckets[key]
        if not b then b = {}; buckets[key] = b end
        b[#b + 1] = r
      end
    end
  end
  return { cell = cell, buckets = buckets }
end

-- Is the tile box `tiles` inside any indexed heated region? Pure.
function M.covered_by_index(index, tiles)
  local cell = index.cell
  local cx0, cx1, cy0, cy1 = cell_range(tiles, cell)
  for cx = cx0, cx1 do
    for cy = cy0, cy1 do
      local b = index.buckets[cx .. ":" .. cy]
      if b then
        for _, r in ipairs(b) do
          if M.tiles_overlap(tiles, r) then return true end
        end
      end
    end
  end
  return false
end

-- The exact freeze ONSET (nightward edge of the warm band) for a set of perp rows:
-- the cold edge of the nightward-most (first) row. The ice-side terrain gradient is
-- aligned to this so "warmth ends = ice starts" reads as one clean line. Pure.
function M.onset(rows)
  return rows[1] - M.FREEZE_REACH
end

return M
