-- Proof: Cindra world generation (scripts/worldgen.lua, v2) paints the themed
-- terrain gradient, voids the ribbon to a finite width (hard-wall backstop), and
-- places each resource ONLY in the survivable playable band -- in BOTH ribbon
-- orientations. §15 v2 items 2, 5, 6.
--
-- The pure band geometry is proven in unit-tests/{test_terrain,test_resource_
-- field}.lua; this proves the runtime layer actually paints the right tiles and
-- creates the right entities in the right places. We drive the worldgen functions
-- DIRECTLY with an explicit cfg (driver disabled) so placement is deterministic
-- and independent of mod settings.

local terrain = require("scripts.terrain")
local field = require("scripts.resource-field")
local worldgen = require("scripts.worldgen")

-- Symmetric geometry: safe 24, lethal 96, wall 128 (hot_ocean_at 112).
local function cfg_for(orientation)
  return {
    orientation = orientation,
    safe_half_width = 24,
    hot_lethal_at = 96, hot_wall_at = 128,
    cold_lethal_at = 96, cold_wall_at = 128,
  }
end

-- A far-away, isolated work strip so tests never collide with each other.
local X1, X2 = 2000, 2120
local PERP1, PERP2 = -140, 140

local function make_surface()
  local s = game.surfaces["cindra"]
  if not s then
    s = game.planets["cindra"] and game.planets["cindra"].create_surface()
      or game.create_surface("cindra")
  end
  return s
end

-- Generate + clear a rectangular work box, addressed by (along, perp) so the same
-- helper works in both orientations. Returns the {left_top, right_bottom} area in
-- world coords.
local function prepare(s, orientation, pave)
  local area
  if orientation == "north-south" then
    -- Long axis = Y (along), perpendicular = X. Put the strip so X spans the perp.
    area = { left_top = { x = PERP1, y = X1 }, right_bottom = { x = PERP2, y = X2 } }
  else
    area = { left_top = { x = X1, y = PERP1 }, right_bottom = { x = X2, y = PERP2 } }
  end
  local lt, rb = area.left_top, area.right_bottom
  local cx, cy = (lt.x + rb.x) / 2, (lt.y + rb.y) / 2
  s.request_to_generate_chunks({ cx, cy }, 6)
  s.force_generate_chunk_requests()
  for _, e in pairs(s.find_entities_filtered({ area = { { lt.x, lt.y }, { rb.x, rb.y } } })) do
    if e.type ~= "character" then e.destroy() end
  end
  if pave then
    local tiles = {}
    for x = lt.x, rb.x - 1 do
      for y = lt.y, rb.y - 1 do
        tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
      end
    end
    s.set_tiles(tiles)
  end
  return area
end

describe("cindra worldgen v2: terrain gradient + wall + playable resources", function()
  local s
  before_each(function()
    storage.cindra_driver_enabled = false
    s = make_surface()
  end)
  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  -- A tile probe at a given (along-fixed, perp) point for the orientation.
  local function tile_at(orientation, along, perp)
    if orientation == "north-south" then
      return s.get_tile(perp, along).name
    end
    return s.get_tile(along, perp).name
  end

  for _, orientation in ipairs({ "east-west", "north-south" }) do
    it("paints the hot->cold gradient tiles and voids past the wall (" .. orientation .. ")", function()
      local cfg = cfg_for(orientation)
      local area = prepare(s, orientation, false)
      worldgen.paint_terrain(s, area, cfg)
      local along = X1 + 5
      assert.are.equal(terrain.TILE.temperate, tile_at(orientation, along, 0), "temperate centre")
      assert.are.equal(terrain.TILE.sand, tile_at(orientation, along, 50), "sunward sand margin")
      assert.are.equal(terrain.TILE.molten_rock, tile_at(orientation, along, 100), "molten rock")
      assert.are.equal(terrain.TILE.lava_ocean, tile_at(orientation, along, 120), "lava ocean")
      assert.are.equal(terrain.TILE.icy, tile_at(orientation, along, -50), "nightward icy margin")
      assert.are.equal(terrain.TILE.ice_wall, tile_at(orientation, along, -110), "ice wall")
      assert.are.equal("out-of-map", tile_at(orientation, along, 135), "sunward past the wall is void")
      assert.are.equal("out-of-map", tile_at(orientation, along, -135), "nightward past the wall is void")
    end)
  end

  -- Resource placement: count entities whose PERPENDICULAR coordinate lies in a
  -- band. We pave the strip so placement is deterministic and tile-agnostic.
  local function count_perp(orientation, name, p1, p2)
    local box
    if orientation == "north-south" then
      box = { { p1, X1 }, { p2, X2 } }
    else
      box = { { X1, p1 }, { X2, p2 } }
    end
    return s.count_entities_filtered({ name = name, area = box })
  end

  for _, orientation in ipairs({ "east-west", "north-south" }) do
    it("places each resource only in its playable band (" .. orientation .. ")", function()
      local cfg = cfg_for(orientation)
      local area = prepare(s, orientation, true)
      worldgen.place_resources(s, area, cfg)

      -- Stone on the ribbon + sunward sand, never nightward or in the lethal bands.
      assert.is_true(count_perp(orientation, field.STONE, 0, 90) > 0, "stone in the playable sunward band")
      assert.are.equal(0, count_perp(orientation, field.STONE, -140, -40), "no stone deep nightward")
      assert.are.equal(0, count_perp(orientation, field.STONE, 96, 140), "no stone in molten rock / lava")

      -- Ice on the nightside icy margin, never sunward, never in the ice wall.
      assert.is_true(count_perp(orientation, field.ICE, -95, -30) > 0, "ice in the playable nightside band")
      assert.are.equal(0, count_perp(orientation, field.ICE, 0, 140), "no ice sunward")
      assert.are.equal(0, count_perp(orientation, field.ICE, -140, -96), "no ice in the ice wall / death zone")

      -- Volatiles only in the deep survivable icy slice, never in the ice wall.
      assert.is_true(count_perp(orientation, field.VOLATILES, -95, -73) > 0, "volatiles at the cold playable edge")
      assert.are.equal(0, count_perp(orientation, field.VOLATILES, -140, -96), "no volatiles in the ice wall")
      assert.are.equal(0, count_perp(orientation, field.VOLATILES, -50, 140), "no volatiles shallow / sunward")

      -- Bootstrap rocks scatter only around the terminator.
      assert.is_true(count_perp(orientation, field.ROCK, -24, 24) > 0, "rocks near the terminator")
      assert.are.equal(0, count_perp(orientation, field.ROCK, 50, 140), "no rocks out in the damage margin")
    end)
  end

  it("puts the richest nodes at the playable edges (edge-pushing)", function()
    local cfg = cfg_for("east-west")
    -- Best stone hottest, best ice/volatiles coldest (all inside the playable band).
    assert.is_true(field.stone_richness(90, cfg) > field.stone_richness(0, cfg))
    assert.is_true(field.ice_richness(-90, cfg) > field.ice_richness(-40, cfg))
    assert.is_true(field.volatiles_richness(-94, cfg) > field.volatiles_richness(-80, cfg))
  end)

  it("exposes stone + ice density as world-gen SLIDERS (autoplace-controls wired into map gen)", function()
    -- The controls exist as `resource`-category autoplace-controls (so the
    -- world-gen screen renders Frequency/Size/Richness sliders)...
    for _, name in ipairs({ "cindra-stone", "cindra-ice" }) do
      local ctrl = prototypes.autoplace_control[name]
      assert.is_not_nil(ctrl, name .. " autoplace-control must exist")
    end
    -- ...and Cindra's map gen LISTS them, so they actually show on the screen and
    -- the runtime can read the chosen values.
    local ac = s.map_gen_settings.autoplace_controls
    assert.is_not_nil(ac["cindra-stone"], "Cindra map gen exposes the stone slider")
    assert.is_not_nil(ac["cindra-ice"], "Cindra map gen exposes the ice slider")
  end)

  it("worldgen reads the stone/ice sliders off the surface map gen at runtime", function()
    -- The runtime consults control_scale on the surface's map_gen_settings; an
    -- unset slider is the neutral baseline (the scaling math itself is unit-tested
    -- in unit-tests/test_worldgen_density.lua).
    local ch, amt = worldgen.control_scale(s.map_gen_settings, "cindra-stone")
    assert.are.equal(1, ch, "unset stone slider -> neutral chance")
    assert.are.equal(1, amt, "unset stone slider -> neutral amount")
    local ich, iamt = worldgen.control_scale(s.map_gen_settings, "cindra-ice")
    assert.are.equal(1, ich); assert.are.equal(1, iamt)
    -- A cranked control (crafted table) yields >baseline multipliers the placer uses.
    local hi = { autoplace_controls = { ["cindra-stone"] = { frequency = 4, size = 2, richness = 3 } } }
    local hch, hamt = worldgen.control_scale(hi, "cindra-stone")
    assert.is_true(hch > 1 and hamt > 1, "cranked sliders drive denser/richer placement")
  end)

  it("bootstrap rocks drop a little finite COAL; Cindra has NO coal patch/autoplace (mayor add)", function()
    -- The finite, hand-gathered rock yields coal alongside stone + metal -- the
    -- ONLY coal on the planet (seeds the foundry bootstrap, nitro ci-arw).
    local rock = prototypes.entity[field.ROCK]
    local yields = {}
    for _, p in pairs(rock.mineable_properties.products) do yields[p.name] = true end
    assert.is_true(yields["coal"], "bootstrap rock drops coal")
    assert.is_true(yields["stone"], "and stone")
    assert.is_true(yields["tungsten-ore"], "and the landing metal")

    -- No renewable coal: the worldgen resource-field defines no coal band, and
    -- Cindra's map gen enables no coal autoplace control.
    assert.is_nil(field.COAL, "resource-field places no coal patch")
    local ac = s.map_gen_settings.autoplace_controls or {}
    assert.is_nil(ac["coal"], "Cindra map gen has no coal autoplace control")
    assert.are.equal(0, s.count_entities_filtered({ name = "coal", area = { { X1, PERP1 }, { X2, PERP2 } } }),
      "no vanilla coal resource is placed on Cindra")
  end)
end)
