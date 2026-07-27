-- Proof: Cindra world generation on the DEFAULT (vertical, hot-left) orientation.
-- The ribbon runs N-S (long Y); the hot-cold gradient runs LEFT<->RIGHT (X) with
-- HOT on the LEFT (west), so the perpendicular coordinate is -x (scripts/axis.lua,
-- unit-proven in unit-tests/test_axis.lua). Three layers:
--   1. SCRIPT layer (scripts/worldgen.lua): the hard-wall backstop makes the map a
--      finite RIBBON on the X axis; the TERRAIN gradient paints molten tiles on
--      the hot (left) edge and ice on the cold (right) edge so the VISIBLE ground
--      IS the temperature axis and lines up with the fire/freeze damage; finite
--      bootstrap rocks scatter around the terminator.
--   2. NATIVE layer (prototypes/resources.lua): stone / ice / volatiles autoplace
--      as irregular PATCHES, each CONSTRAINED to its ribbon band ON THE X AXIS,
--      and the map generates NO water.
--
-- The pure band geometry + tile bands are proven in unit-tests/test_resource_field
-- and unit-tests/test_terrain; this proves the runtime voids, paints, scatters,
-- damages, and bands correctly on a live surface.

local field = require("scripts.resource-field")
local worldgen = require("scripts.worldgen")
local edge = require("scripts.edge-damage")

-- ---------------------------------------------------------------------------
-- Script layer: hard wall + terrain gradient + bootstrap-rock scatter. Driven
-- directly on a paved, isolated strip (driver disabled) so placement is
-- deterministic. The strip CROSSES the wall on X and is parked far away on the
-- long (Y) axis so it never meets another test.
-- ---------------------------------------------------------------------------
describe("cindra worldgen: ribbon geometry on the default vertical axis (§4, §15-2)", function()
  local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128 } -- edge_mid = 112
  -- The strip CROSSES the wall on the perpendicular (X) axis and runs tall on the
  -- long (Y) axis, parked far from any other test. Tall in Y so the sparse, clumped
  -- rock scatter lands plenty of rocks inside the sampled band (to judge the pattern).
  local X1, X2 = -140, 140
  local Y1, Y2 = 2000, 2360
  local AREA = { left_top = { x = X1, y = Y1 }, right_bottom = { x = X2, y = Y2 } }
  local YM = (Y1 + Y2) / 2 -- a sample row well inside the strip
  local s

  before_each(function()
    storage.cindra_driver_enabled = false -- no auto-placement; we call worldgen directly
    s = game.surfaces["cindra"]
    if not s then
      s = game.planets["cindra"] and game.planets["cindra"].create_surface()
        or game.create_surface("cindra")
    end
    -- Generate the chunks under the strip (centred on it), then clear + pave to
    -- clean land so placement is deterministic (nothing pre-placed).
    s.request_to_generate_chunks({ 0, YM }, 8)
    s.force_generate_chunk_requests()
    local box = { { X1, Y1 }, { X2, Y2 } }
    for _, e in pairs(s.find_entities_filtered({ area = box })) do
      if e.type ~= "character" then e.destroy() end
    end
    local tiles = {}
    for x = X1, X2 - 1 do
      for y = Y1, Y2 - 1 do
        tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
      end
    end
    s.set_tiles(tiles)
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  -- Count entities in a perpendicular (X) band spanning the whole strip.
  local function count(name, x1, x2)
    return s.count_entities_filtered({ name = name, area = { { x1, Y1 }, { x2, Y2 } } })
  end

  it("voids tiles at/beyond the wall on the X axis, keeping the ribbon interior playable", function()
    worldgen.apply_hard_wall(s, AREA, CFG)
    assert.are.equal("out-of-map", s.get_tile(-135, YM).name, "sunward (west) past the wall is void")
    assert.are.equal("out-of-map", s.get_tile(135, YM).name, "nightward (east) past the wall is void")
    assert.are_not.equal("out-of-map", s.get_tile(0, YM).name, "the terminator stays playable")
    assert.are_not.equal("out-of-map", s.get_tile(-100, YM).name, "the hot lethal margin is still land")
  end)

  it("paints the hot tiles hot-lava -> lava -> volcanic-cracks-hot from the LEFT (west)", function()
    worldgen.apply_hard_wall(s, AREA, CFG)
    worldgen.paint_terrain(s, AREA, CFG)
    -- Hot side is the LEFT (negative x). From the edge inward the design calls for
    -- hot-lava, then lava, then volcanic-cracks-hot.
    assert.are.equal("lava-hot", s.get_tile(-120, YM).name, "hottest tile at the far-left edge")
    assert.are.equal("lava", s.get_tile(-100, YM).name, "molten lava next")
    assert.are.equal("volcanic-cracks-hot", s.get_tile(-60, YM).name, "then the walkable hot margin")
    -- Order really is left-to-right hot-lava, lava, cracks (decreasing depth).
    assert.is_true(-120 < -100 and -100 < -60, "and they lie in that order from the left")
    -- Cold side mirrors it on the right (east): icy inward, ice wall at the edge.
    assert.are.equal("ice-smooth", s.get_tile(60, YM).name, "walkable cold margin")
    assert.are.equal("ammoniacal-ocean", s.get_tile(120, YM).name, "the frozen ice wall at the far right")
    -- The wide safe band at spawn stays natural land (here, the paved slab).
    assert.are.equal("refined-concrete", s.get_tile(0, YM).name, "the temperate ribbon is untouched")
  end)

  it("aligns the fire-damage zone to the hot tiles: standing on them scales with depth", function()
    worldgen.apply_hard_wall(s, AREA, CFG)
    worldgen.paint_terrain(s, AREA, CFG)
    -- All three hot tiles sit in the fire-damage zone; damage scales with depth
    -- (hot-lava, deepest/leftmost, is the most lethal).
    local d_cracks = edge.damage_for(60, edge.DAMAGE_INTERVAL, CFG)   -- volcanic-cracks-hot @ perp 60
    local d_lava = edge.damage_for(100, edge.DAMAGE_INTERVAL, CFG)    -- lava @ perp 100
    local d_hotlava = edge.damage_for(120, edge.DAMAGE_INTERVAL, CFG) -- hot-lava @ perp 120
    assert.is_true(d_cracks > 0, "volcanic-cracks-hot cooks the player")
    assert.is_true(d_lava >= d_cracks, "lava is at least as lethal (deeper)")
    assert.is_true(d_hotlava >= d_lava, "hot-lava is the most lethal edge")
    -- A character actually standing on the walkable hot tile takes HEAT damage:
    -- the visible terrain IS the damage zone.
    local ch = s.create_entity({ name = "character", position = { -60, YM }, force = "player" })
    assert.is_not_nil(ch, "a character can stand on the walkable volcanic-cracks-hot margin")
    local before = ch.health
    edge.sweep(s, edge.DAMAGE_INTERVAL, CFG)
    assert.is_true(ch.health < before, "the visible hot terrain deals fire damage")
    ch.destroy()
  end)

  it("scatters finite bootstrap rocks around the terminator (safe band) only", function()
    worldgen.place_bootstrap_rocks(s, AREA, CFG)
    assert.is_true(count(field.ROCK, -24, 24) > 0, "rocks in the terminator band")
    assert.are.equal(0, count(field.ROCK, 50, X2), "no rocks out in the cold (east) margin")
    assert.are.equal(0, count(field.ROCK, X1, -50), "no rocks out in the hot (west) margin")
  end)

  it("places rocks OFF a fixed lattice (natural scatter, no visible grid)", function()
    -- Regression for ci-fs4: the old placement dropped every rock at (k*STEP+0.5)
    -- on BOTH axes, so every rock sat exactly on a grid node -- a visible lattice.
    -- Natural scatter jitters each rock across its cell, so rocks land off-grid.
    worldgen.place_bootstrap_rocks(s, AREA, CFG)
    -- The rock band is the terminator on the PERPENDICULAR (X) axis, spanning the
    -- full length of the strip on the long (Y) axis.
    local rocks = s.find_entities_filtered({ name = field.ROCK, area = { { -30, Y1 }, { 30, Y2 } } })
    assert.is_true(#rocks >= 8, "enough rocks to judge the pattern")
    -- Distance from a coord to the nearest OLD lattice node (k*STEP + 0.5). The old
    -- gridded code made this exactly 0 for every rock on both axes; jitter makes it
    -- span the cell, so the MEAN displacement is large (~JITTER/2).
    local function lattice_dist(coord)
      local r = (coord - 0.5) % worldgen.STEP
      if r < 0 then r = r + worldgen.STEP end
      return math.min(r, worldgen.STEP - r)
    end
    local sum, n = 0, 0
    for _, rk in ipairs(rocks) do
      sum = sum + lattice_dist(rk.position.x) + lattice_dist(rk.position.y)
      n = n + 2
    end
    -- Old code => mean 0 (fails). Jittered scatter => mean well off the grid.
    assert.is_true(sum / n > 0.75,
      "rocks are displaced off the lattice on average, not snapped to a grid")
  end)

  it("keeps the richest nodes at the lethal margins (edge-pushing geometry)", function()
    -- Pure band geometry (perpendicular coordinate): best stone hottest, best
    -- ice/volatiles coldest. Orientation-independent (reads perp, not x/y).
    assert.is_true(field.stone_richness(90, CFG) > field.stone_richness(0, CFG))
    assert.is_true(field.ice_richness(-120, CFG) > field.ice_richness(-40, CFG))
    assert.is_true(field.volatiles_richness(-125, CFG) > field.volatiles_richness(-100, CFG))
  end)
end)

-- ---------------------------------------------------------------------------
-- Native layer: real map-gen. We generate a natural Cindra region (NOT paved) at
-- a FIXED seed so autoplace is deterministic, then prove the patches land in the
-- right bands ON THE X AXIS, nothing floods the wrong band, and NO water
-- generates. This runs on a PRIVATE surface (not named "cindra"), so the runtime
-- worldgen handlers (void/paint/rocks) never touch it -- pure native autoplace.
-- ---------------------------------------------------------------------------
describe("cindra worldgen: native resource autoplace + no water on the X axis (§15-3)", function()
  local s
  -- Region: wide on the perpendicular (X) axis to cover every band in to the
  -- wall; tall on the long (Y) axis so patches are sampled across many chunks.
  local RX = 128 -- +/- tiles in X (the wall / ribbon width)
  local RY = 320 -- +/- tiles in Y (the long axis)
  local ready = false

  before_each(function()
    if ready then return end
    -- Generate on a DEDICATED surface cloned from the Cindra planet's map-gen
    -- (same autoplace controls, band masks, and no-water tile set) at a FIXED
    -- seed, so native autoplace is fully reproducible run-to-run and isolated
    -- from the many tests that pave/trample the shared "cindra" surface.
    local base = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    local mgs = base.map_gen_settings
    mgs.seed = 2468
    s = game.surfaces["cindra-worldgen-test"] or game.create_surface("cindra-worldgen-test", mgs)
    s.request_to_generate_chunks({ 0, 0 }, 11) -- ~352 tiles radius: covers the region
    s.force_generate_chunk_requests()
    ready = true
  end)

  -- Count a resource in a perpendicular (X) band spanning the full long axis.
  local function count(name, x1, x2)
    return s.count_entities_filtered({ name = name, area = { { x1, -RY }, { x2, RY } } })
  end

  it("exposes real map-gen sliders via autoplace-controls (Frequency/Size/Richness)", function()
    for _, n in ipairs({ "cindra-stone", "cindra-ice", "cindra-volatiles" }) do
      local ctrl = prototypes.autoplace_control[n]
      assert.is_not_nil(ctrl, n .. " autoplace-control exists")
      assert.are.equal("resource", ctrl.category, n .. " is a resource control")
    end
    -- And each resource actually carries a native autoplace specification.
    assert.is_not_nil(prototypes.entity["cindra-stone"].autoplace_specification,
      "stone has a native autoplace spec")
  end)

  it("places stone as patches on the ribbon + hot margin, never deep nightward", function()
    -- Stone band: perp in [-safe, lethal] -> x in [-96, 24] (hot is -x).
    assert.is_true(count(field.STONE, -96, 24) > 0, "stone patches in the stone band")
    assert.are.equal(0, count(field.STONE, 40, RX), "no stone deep nightward (east) of the safe band")
  end)

  it("places ice as patches on the nightside, never sunward of the safe band", function()
    -- Ice band: perp < -safe -> x > 24 (the nightward/east side).
    assert.is_true(count(field.ICE, 30, RX) > 0, "ice patches on the nightside (east)")
    assert.are.equal(0, count(field.ICE, -RX, 0), "no ice sunward (west) of the safe band")
  end)

  it("keeps volatiles out of the ribbon and sunward (deep cold-lethal only)", function()
    -- Volatiles' band is a thin deep-nightside slice (perp <= -lethal -> x >= 96);
    -- presence there is playtest-verified. Here we prove the hard exclusion.
    assert.are.equal(0, count(field.VOLATILES, -RX, 90), "no volatiles above the cold-lethal band")
  end)

  it("generates NO water and NO starting lake at all", function()
    local water = s.count_tiles_filtered({ name = "water", area = { { -RX, -RY }, { RX, RY } } })
    local deep = s.count_tiles_filtered({ name = "deepwater", area = { { -RX, -RY }, { RX, RY } } })
    assert.are.equal(0, water, "no water tiles anywhere")
    assert.are.equal(0, deep, "no deepwater tiles anywhere")
  end)
end)

-- ---------------------------------------------------------------------------
-- Bootstrap-rock yields (§6): finite hand-mined rocks are the ONLY landing-tier
-- metal (Cindra has no ore/coal patches), so they must drop enough to smelt the
-- first plates: stone + iron ore + copper ore + coal.
-- ---------------------------------------------------------------------------
describe("cindra bootstrap rock: yields iron + copper + coal + stone (§6)", function()
  it("drops the from-nothing starter kit when hand-mined", function()
    local proto = prototypes.entity["cindra-bootstrap-rock"]
    assert.is_not_nil(proto, "the bootstrap rock exists")
    local yielded = {}
    for _, p in ipairs(proto.mineable_properties.products) do
      yielded[p.name] = true
    end
    for _, needed in ipairs({ "stone", "iron-ore", "copper-ore", "coal" }) do
      assert.is_true(yielded[needed] == true, "bootstrap rock yields " .. needed)
    end
  end)
end)
