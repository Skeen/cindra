-- Proof: Cindra world generation. Two layers:
--   1. SCRIPT layer (scripts/worldgen.lua): the hard-wall backstop makes the map a
--      finite RIBBON, and finite bootstrap rocks scatter around the terminator.
--   2. NATIVE layer (prototypes/resources.lua): stone / ice / volatiles are placed
--      by native Factorio resource autoplace as irregular PATCHES (not a script
--      grid), each CONSTRAINED to its ribbon band, and the map generates NO water.
--
-- The pure band geometry + masks are proven in unit-tests/test_resource_field.lua;
-- this proves the runtime actually voids tiles, scatters rocks, and that native
-- autoplace respects the bands and never floods the map.

local field = require("scripts.resource-field")
local worldgen = require("scripts.worldgen")

-- ---------------------------------------------------------------------------
-- Script layer: hard wall + bootstrap-rock scatter. Driven directly on a paved,
-- isolated strip (driver disabled) so placement is deterministic.
-- ---------------------------------------------------------------------------
describe("cindra worldgen: hard wall + bootstrap rocks (§15-2, §6)", function()
  local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128 }
  -- A tall, narrow work strip far from any other test, covering both lethal edges
  -- and the wall on the Y axis. Wide in X so the sparse rock scatter reliably
  -- lands at least one rock inside the sampled area.
  local X1, X2 = 2000, 2120
  local Y1, Y2 = -140, 140
  local AREA = { left_top = { x = X1, y = Y1 }, right_bottom = { x = X2, y = Y2 } }
  local s

  before_each(function()
    storage.cindra_driver_enabled = false -- no auto-placement; we call worldgen directly
    s = game.surfaces["cindra"]
    if not s then
      s = game.planets["cindra"] and game.planets["cindra"].create_surface()
        or game.create_surface("cindra")
    end
    -- Generate the chunks under the strip, then clear + pave to clean land so
    -- placement is deterministic (nothing pre-placed).
    s.request_to_generate_chunks({ (X1 + X2) / 2, 0 }, 6)
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

  local function count(name, y1, y2)
    return s.count_entities_filtered({ name = name, area = { { X1, y1 }, { X2, y2 } } })
  end

  it("voids tiles at/beyond the wall, keeping the ribbon interior playable", function()
    worldgen.apply_hard_wall(s, AREA, CFG)
    assert.are.equal("out-of-map", s.get_tile(X1 + 5, 135).name, "sunward past the wall is void")
    assert.are.equal("out-of-map", s.get_tile(X1 + 5, -135).name, "nightward past the wall is void")
    assert.are_not.equal("out-of-map", s.get_tile(X1 + 5, 0).name, "the terminator stays playable")
    assert.are_not.equal("out-of-map", s.get_tile(X1 + 5, 100).name, "the lethal margin is still land")
  end)

  it("scatters finite bootstrap rocks around the terminator only", function()
    worldgen.place_bootstrap_rocks(s, AREA, CFG)
    assert.is_true(count(field.ROCK, -24, 24) > 0, "rocks near the terminator")
    assert.are.equal(0, count(field.ROCK, 50, Y2), "no rocks out in the damage margin")
  end)

  it("keeps the richest nodes at the lethal margins (edge-pushing geometry)", function()
    -- The band geometry the native masks read is edge-pushing: the best stone is
    -- hottest, the best ice/volatiles are coldest.
    assert.is_true(field.stone_richness(90, CFG) > field.stone_richness(0, CFG))
    assert.is_true(field.ice_richness(-120, CFG) > field.ice_richness(-40, CFG))
    assert.is_true(field.volatiles_richness(-125, CFG) > field.volatiles_richness(-100, CFG))
  end)
end)

-- ---------------------------------------------------------------------------
-- Native layer: real map-gen. We generate a natural Cindra region (NOT paved) at
-- a FIXED seed so autoplace is deterministic, then prove the patches land in the
-- right bands, nothing floods the wrong band, and NO water generates.
-- ---------------------------------------------------------------------------
describe("cindra worldgen: native resource autoplace + no water (§15-3)", function()
  local s
  -- Region centred on the starting area (0,0). Wide in X so patches are sampled
  -- across many chunks; tall enough to cover every band on the Y axis.
  local RX = 320  -- +/- tiles in X
  local RY = 128  -- +/- tiles in Y (the wall)
  local ready = false

  before_each(function()
    if ready then return end
    -- Generate on a DEDICATED surface cloned from the Cindra planet's map-gen
    -- (same autoplace controls, band masks, and no-water tile set) at a FIXED
    -- seed. Using a private surface keeps this test isolated from the many other
    -- tests that pave/trample the shared "cindra" surface, and the fixed seed
    -- makes native autoplace fully reproducible run-to-run.
    local base = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    local mgs = base.map_gen_settings
    mgs.seed = 2468
    s = game.surfaces["cindra-worldgen-test"] or game.create_surface("cindra-worldgen-test", mgs)
    s.request_to_generate_chunks({ 0, 0 }, 11) -- ~352 tiles radius: covers the region
    s.force_generate_chunk_requests()
    ready = true
  end)

  -- Count resource entities in an X-full band [y1, y2].
  local function count(name, y1, y2)
    return s.count_entities_filtered({ name = name, area = { { -RX, y1 }, { RX, y2 } } })
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
    assert.is_true(count(field.STONE, -RY, 96) > 0, "stone patches in the stone band")
    assert.are.equal(0, count(field.STONE, -RY, -40), "no stone deep nightward of the safe band")
  end)

  it("places ice as patches on the nightside, never sunward of the safe band", function()
    assert.is_true(count(field.ICE, -RY, -30) > 0, "ice patches on the nightside")
    assert.are.equal(0, count(field.ICE, 0, RY), "no ice sunward of the safe band")
  end)

  it("keeps volatiles out of the ribbon and sunward (deep cold-lethal only)", function()
    -- Volatiles' band is a thin deep-nightside slice; presence there is playtest-
    -- verified. Here we prove the hard exclusion: never in the ribbon or sunward.
    assert.are.equal(0, count(field.VOLATILES, -90, RY), "no volatiles above the cold-lethal band")
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
