-- Proof: Cindra world generation (scripts/worldgen.lua) makes the map a finite
-- RIBBON (hard-wall backstop) and places each resource in its axis band with the
-- best nodes at the lethal margins. §15 items 2-3.
--
-- The pure band geometry is proven in unit-tests/test_resource_field.lua; this
-- proves the runtime layer actually voids tiles and creates the right entities in
-- the right places. We drive the worldgen functions DIRECTLY on a paved, isolated
-- strip (driver disabled) so placement is deterministic and free of water noise.

local field = require("scripts.resource-field")
local worldgen = require("scripts.worldgen")

describe("cindra worldgen: hard wall + resources (§15-2,3)", function()
  local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128 }
  -- A tall, narrow work strip far from any other test, covering both lethal edges
  -- and the wall on the Y axis.
  -- Wide enough in X that the sparse (per-band, deterministic) scatter reliably
  -- lands at least one node of each band inside the sampled area.
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
    -- placement is deterministic (no water to skip, nothing pre-placed).
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

  it("places stone on the ribbon, not on the nightside", function()
    worldgen.place_resources(s, AREA, CFG)
    assert.is_true(count(field.STONE, 0, 90) > 0, "stone on the ribbon + hot margin")
    assert.are.equal(0, count(field.STONE, Y1, -40), "no stone deep nightward")
  end)

  it("places ice on the nightside, not sunward", function()
    worldgen.place_resources(s, AREA, CFG)
    assert.is_true(count(field.ICE, Y1, -40) > 0, "ice on the nightside")
    assert.are.equal(0, count(field.ICE, 0, Y2), "no ice sunward of the safe band")
  end)

  it("places volatiles only in the deep-nightside cold edge", function()
    worldgen.place_resources(s, AREA, CFG)
    assert.is_true(count(field.VOLATILES, Y1, -100) > 0, "volatiles deep in the cold edge")
    assert.are.equal(0, count(field.VOLATILES, -90, Y2), "no volatiles above the cold-lethal band")
  end)

  it("scatters finite bootstrap rocks around the terminator only", function()
    worldgen.place_resources(s, AREA, CFG)
    assert.is_true(count(field.ROCK, -24, 24) > 0, "rocks near the terminator")
    assert.are.equal(0, count(field.ROCK, 50, Y2), "no rocks out in the damage margin")
  end)

  it("puts the richest nodes at the lethal margins (edge-pushing)", function()
    -- The runtime richness follows the pure field, so the best stone is hottest,
    -- the best ice/volatiles are coldest.
    assert.is_true(field.stone_richness(90, CFG) > field.stone_richness(0, CFG))
    assert.is_true(field.ice_richness(-120, CFG) > field.ice_richness(-40, CFG))
    assert.is_true(field.volatiles_richness(-125, CFG) > field.volatiles_richness(-100, CFG))
  end)
end)
