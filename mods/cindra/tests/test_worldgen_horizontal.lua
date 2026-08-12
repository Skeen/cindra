-- Proof: with `cindra-ribbon-orientation = horizontal`, the REAL generated world is
-- rotated a quarter turn -- tiles, resources and lethal ground all band along the
-- Y axis, and the ribbon runs east-west forever (ci-vjc, ci-65p).
--
-- WHY THIS FILE EXISTS. The horizontal ribbon was proven only in the mapping MATHS
-- (unit-tests/test_axis.lua) and through orientation-agnostic helpers
-- (tests/test_orientation.lua, which reads every position through scripts/axis.lua).
-- Both of those pass just as happily if the axis module is self-consistently WRONG:
-- the whole worldgen/resource/damage suite generates the DEFAULT vertical world, so
-- nothing ever checked that a horizontal run puts real lava at the top of the map.
-- The ci-d7x coverage audit called that gap; this closes it.
--
-- SO EVERYTHING HERE IS WRITTEN IN RAW WORLD COORDINATES -- deliberately. It does not
-- call axis.perp/axis.world, it states where the player finds fire, ice, stone and
-- death in x/y:
--   * FIRE AT THE TOP: a solid lava sea at y <= -200 (north), an ice sea at y >= +200.
--   * NOTHING ACROSS: at y = 0 the ground stays safe and walkable out to x = +/-1500,
--     where the vertical world would have had its lava sea and then its void.
--   * BOUNDED N-S, ENDLESS E-W: out-of-map past y = +/-410, land at x = +/-3000.
--   * RESOURCES BAND ON Y: stone in the warm band y <= 60 spread along the whole
--     long axis, ice on the cold margin y in (60, 120.5).
--   * DAMAGE BANDS ON Y: a character burns in the north belt and freezes in the
--     south belt, at any x -- and takes nothing on the middle line.
-- Every one of these fails on a world generated with the vertical (default) axis,
-- which is exactly what makes them a proof and not a restatement.
--
-- Only registered when the run really is horizontal (control.lua reads the startup
-- setting); `npm run test:integration:horizontal` is the runner that configures it
-- (scripts/cindra-test.sh + mods/cindra-dev-horizontal).

local axis = require("scripts.axis")
local field = require("scripts.resource-field")
local terrain = require("scripts.terrain")
local td = require("scripts.tile-damage")

describe("horizontal (E-W) ribbon: the generated world is rotated a quarter turn (ci-vjc)", function()
  -- The ribbon geometry in RAW Y, from the shipped zone widths (total 800):
  --   hot ocean   y in [-400, -200]   (north / top: FIRE)
  --   hot belt    y in [-200, -130]   (heat-lethal)
  --   safe hot    y in [-130,  -60]
  --   middle      y in [ -60,   60]   (spawn, always safe)
  --   safe cold   y in [  60,  130]
  --   cold belt   y in [ 130,  200]   (cold-lethal)
  --   ice ocean   y in [ 200,  400]   (south / bottom: ICE)
  local HALF = 400
  -- Far out along the LONG axis: more than TWICE the ribbon's own half-width, so
  -- every assertion made out here is also a statement that the world runs on
  -- east-west -- a vertically-generated world is void at x = +/-960. (The "and it
  -- keeps going" claim proper is tests/test_orientation's, which walks to 1840.)
  local FAR = 960

  local s          -- fixed-seed generation surface (tiles + resources)
  local live       -- the REAL "cindra" surface (the damage sweep is gated on the name)
  local ready = false

  before_each(function()
    if ready then return end
    live = game.surfaces["cindra"] or game.planets["cindra"].create_surface()
    local mgs = live.map_gen_settings
    mgs.seed = 2468
    s = game.surfaces["cindra-horizontal-test"] or game.create_surface("cindra-horizontal-test", mgs)
    -- Radius 15 chunks (~480 tiles) covers the full ribbon y in [-400,400]; three
    -- such blocks, centred on spawn and FAR either side, make ONE continuous stretch
    -- x in [-1440, 1440] of fully generated ribbon to read the bands off.
    for _, cx in ipairs({ -FAR, 0, FAR }) do
      s.request_to_generate_chunks({ cx, 0 }, 15)
    end
    s.force_generate_chunk_requests()
    ready = true
  end)

  local function tile(x, y) return s.get_tile(x, y).name end

  -- 0. THE RUN REALLY IS HORIZONTAL ------------------------------------------------
  it("is running the horizontal orientation (the whole file is meaningless otherwise)", function()
    assert.are.equal("horizontal", axis.orientation(),
      "this suite only registers under cindra-ribbon-orientation=horizontal")
  end)

  -- 1. BOUNDED NORTH-SOUTH, ENDLESS EAST-WEST --------------------------------------
  it("bounds the world across Y (800 tiles) and leaves X infinite", function()
    local mg = live.map_gen_settings
    assert.are.equal(800, mg.height, "the ribbon is 800 tiles tall (finite N-S)")
    assert.is_true(mg.width == 0 or mg.width > 100000,
      "and endless east-west; got width=" .. tostring(mg.width))
  end)

  it("VOID above and below the ribbon, GROUND thousands of tiles east and west", function()
    assert.are.equal("out-of-map", tile(0, -(HALF + 10)), "past the northern edge is void")
    assert.are.equal("out-of-map", tile(0, HALF + 10), "past the southern edge is void")
    for _, x in ipairs({ FAR, -FAR, 1400, -1400 }) do
      local n = tile(x, 0)
      assert.are_not.equal("out-of-map", n,
        "the ribbon runs on at x=" .. x .. " (a vertical world is void here), got " .. n)
      assert.is_true(terrain.is_walkable(n), "and it is walkable ground at x=" .. x .. ", got " .. n)
    end
  end)

  -- 2. FIRE AT THE TOP, ICE AT THE BOTTOM ------------------------------------------
  it("generates a SOLID lava sea along the NORTH edge (y <= -200)", function()
    local box = { { -350, -396 }, { 350, -204 } }
    local gaps = 0
    for _, name in ipairs(terrain.tile_names()) do
      if name ~= "cindra-lava-hot" then gaps = gaps + s.count_tiles_filtered({ name = name, area = box }) end
    end
    assert.are.equal(0, gaps, "the northern lava ocean is a SOLID sea (" .. gaps .. " non-lava tiles)")
    assert.is_true(s.count_tiles_filtered({ name = "cindra-lava-hot", area = box }) > 1000,
      "and a large one")
  end)

  it("generates a SOLID smooth-ice sea along the SOUTH edge (y >= 200)", function()
    local box = { { -350, 204 }, { 350, 396 } }
    local gaps = 0
    for _, name in ipairs(terrain.tile_names()) do
      if name ~= "cindra-ice-smooth" then gaps = gaps + s.count_tiles_filtered({ name = name, area = box }) end
    end
    assert.are.equal(0, gaps, "the southern ice ocean is a SOLID sea (" .. gaps .. " non-ice tiles)")
    assert.is_true(s.count_tiles_filtered({ name = "cindra-ice-smooth", area = box }) > 1000,
      "and a large one")
  end)

  it("puts NO ocean east or west: walking the long axis at y=0 never meets lava or ice", function()
    -- The discriminator against a world still generated on the vertical axis: there,
    -- x = -390 is the lava sea and x = +390 the ice sea. Rotated, both are plain
    -- middle-band ground, all the way out.
    for x = -FAR, FAR, 50 do
      local n = tile(x, 0)
      assert.are_not.equal("cindra-lava-hot", n, "no lava on the centre line at x=" .. x)
      assert.are_not.equal("cindra-lava", n, "no lava on the centre line at x=" .. x)
      assert.are_not.equal("cindra-ice-smooth", n, "no ocean ice on the centre line at x=" .. x)
      assert.is_true(terrain.is_walkable(n), "the centre line stays walkable at x=" .. x .. ", got " .. n)
    end
  end)

  it("keeps the SAME bands far along the ribbon: the gradient runs N-S only", function()
    -- Same y, 1500 tiles east: the same ground. A gradient that had leaked onto the
    -- long axis would drift here.
    assert.are.equal("cindra-lava-hot", tile(FAR, -300), "still the lava sea at x=" .. FAR)
    assert.are.equal("cindra-ice-smooth", tile(FAR, 300), "still the ice sea at x=" .. FAR)
    assert.are.equal("cindra-lava-hot", tile(-FAR, -300), "and west of spawn too")
    assert.are.equal("cindra-ice-smooth", tile(-FAR, 300), "and west of spawn too")
  end)

  -- 3. DAMAGE BANDS ON Y -----------------------------------------------------------
  -- Player-observable: a character standing there loses HP from ONE real sweep of the
  -- shipped damage system, on the REAL cindra surface (the sweep is gated on the
  -- surface name), far out along the ribbon so the reading also proves the belts run
  -- east-west with it.
  it("BURNS you in the north belt and FREEZES you in the south belt, at ANY x", function()
    local prev = storage.cindra_driver_enabled
    storage.cindra_driver_enabled = false
    for _, x in ipairs({ 0, FAR }) do
      live.request_to_generate_chunks({ x, 0 }, 8)
      live.force_generate_chunk_requests()
      local function hp_lost(y)
        local c = live.create_entity({ name = "character", position = { x, y }, force = "player" })
        assert.is_not_nil(c, "a character stands at (" .. x .. "," .. y .. ")")
        local before = c.health
        td.sweep(live, 60, 200)
        local lost = before - c.health
        c.destroy()
        return lost
      end
      assert.is_true(hp_lost(-180) > 0, "the NORTH belt is lethal ground at x=" .. x)
      assert.is_true(hp_lost(180) > 0, "the SOUTH belt is lethal ground at x=" .. x)
      assert.are.equal(0, hp_lost(0), "the middle line is safe at x=" .. x)
    end
    storage.cindra_driver_enabled = prev
  end)

  it("the north belt burns and the south belt freezes -- not the same hazard twice", function()
    -- Which hazard each belt is, read off the ground that actually generated there.
    local _, north = terrain.tile_damage(tile(0, -180))
    local _, south = terrain.tile_damage(tile(0, 180))
    assert.are.equal("heat", north, "the NORTHERN belt cooks you (fire is at the top)")
    assert.are.equal("cold", south, "the SOUTHERN belt freezes you")
  end)

  it("leaves a safe, buildable middle band the whole way along the ribbon", function()
    for _, x in ipairs({ -FAR, -400, 0, 400, FAR }) do
      for y = -55, 55, 10 do
        local n = tile(x, y)
        assert.is_true(terrain.is_walkable(n), "middle tile (" .. x .. "," .. y .. ") walkable, got " .. n)
        local intensity = terrain.tile_damage(n)
        assert.are.equal(0, intensity, "middle tile (" .. x .. "," .. y .. ") = " .. n .. " must be harmless")
      end
    end
  end)

  -- 4. RESOURCES BAND ON Y ---------------------------------------------------------
  -- The resource patches are placed by NATIVE autoplace whose band masks are built
  -- from the orientation axis at the data stage -- the exact thing a horizontal run
  -- has never checked. They must lie in Y bands and spread along the whole X axis.
  local function resources(name, y1, y2)
    return s.find_entities_filtered({ name = name, area = { { -FAR, y1 }, { FAR, y2 } } })
  end

  it("bands STONE on the warm side (y <= 60), never on the cold half", function()
    -- stone zone perp [-60, 120.5) -> y in (-120.5, 60].
    assert.is_true(#resources(field.STONE, -118, 60) > 0, "stone patches on the warm band")
    local cold_leak = 0
    for _, e in ipairs(resources(field.STONE, 65, HALF)) do cold_leak = cold_leak + 1 end
    assert.are.equal(0, cold_leak, "no stone south of the divider (found " .. cold_leak .. ")")
    assert.are.equal(0, #resources(field.STONE, -HALF, -131), "no stone in the northern heat belt")
  end)

  it("bands ICE on the cold margin (y in 60..120.5), never on the warm half", function()
    -- ice zone perp (-120.5, -60) -> patch CENTRES at y in (60, 120.5).
    local in_band = 0
    for _, e in ipairs(resources(field.ICE, 55, 130)) do
      if e.position.y > 60 then in_band = in_band + 1 end
    end
    assert.is_true(in_band > 0, "ice patches on the cold margin (found " .. in_band .. ")")
    local warm_leak = 0
    for _, e in ipairs(resources(field.ICE, -HALF, 60)) do
      if e.position.y < 60 then warm_leak = warm_leak + 1 end
    end
    assert.are.equal(0, warm_leak, "no ice centred on the warm half (found " .. warm_leak .. ")")
    assert.are.equal(0, #resources(field.ICE, 131, HALF), "no ice in the southern cold belt")
  end)

  it("lays the resource bands as LONG E-W stripes: wide along X, narrow along Y", function()
    -- The shape of the deposits is the claim: banded on the perpendicular axis means
    -- the ore stretches for kilometres along the ribbon while staying inside a thin
    -- slice of it. Measured over the whole generated stretch (x in [-1440, 1440]) --
    -- the SAME measurement on a vertical world comes out the other way round (narrow
    -- in x, kilometres in y), so the two cannot both pass.
    local minx, maxx, miny, maxy
    local far_out = 0
    for _, name in ipairs({ field.STONE, field.ICE }) do
      for _, e in ipairs(s.find_entities_filtered({ name = name, area = { { -1440, -HALF }, { 1440, HALF } } })) do
        local p = e.position
        minx = math.min(minx or p.x, p.x); maxx = math.max(maxx or p.x, p.x)
        miny = math.min(miny or p.y, p.y); maxy = math.max(maxy or p.y, p.y)
        if math.abs(p.x) > 500 then far_out = far_out + 1 end
      end
    end
    assert.is_not_nil(minx, "the ribbon actually grew stone/ice deposits")
    local x_span, y_span = maxx - minx, maxy - miny
    log("ci-vjc resource extent: x " .. minx .. ".." .. maxx .. " (" .. x_span ..
      "), y " .. miny .. ".." .. maxy .. " (" .. y_span .. ")")
    assert.is_true(far_out > 0, "deposits reach far along the ribbon, not just around spawn")
    assert.is_true(x_span > 1000, "the ore stretches along the E-W long axis, got " .. x_span)
    assert.is_true(y_span < 250,
      "and stays inside a thin N-S slice of the ribbon, got " .. y_span)
    assert.is_true(x_span > 4 * y_span,
      "so the deposits are E-W stripes (x " .. x_span .. " vs y " .. y_span .. ")")
  end)

  it("keeps the hand-minable bootstrap rocks in their Y bands too", function()
    -- Sandy rocks: perp [-55, 60] -> y in [-60, 55]. Ice formations: perp (-130,-60]
    -- -> y in [60, 130). Burned volcanic rocks: perp (60,200] -> y in [-200,-60).
    local function count(names, y1, y2)
      local n = 0
      for _, name in ipairs(names) do
        n = n + s.count_entities_filtered({ name = name, area = { { -FAR, y1 }, { FAR, y2 } } })
      end
      return n
    end
    assert.is_true(count({ field.ROCK }, -59, 54) > 0, "bootstrap rocks in the warm middle")
    assert.are.equal(0, count({ field.ROCK }, 62, 120), "no sandy rocks on the frosty side")
    assert.is_true(count(field.ice_rock_names(), 62, 128) > 0, "ice formations on the cold margin")
    assert.are.equal(0, count(field.ice_rock_names(), -128, 58), "no ice formations on the warm side")
    assert.is_true(count(field.burned_rock_names(), -195, -65) > 0, "burned rocks on the hot slope")
    assert.are.equal(0, count(field.burned_rock_names(), -55, HALF), "none in the middle or cold half")
  end)

  it("keeps every harvestable field OUT of both lethal belts (ci-fb9, rotated)", function()
    for _, name in ipairs({ field.STONE, field.ICE }) do
      assert.are.equal(0, #resources(name, -HALF, -131), name .. " must not sit in the north heat belt")
      assert.are.equal(0, #resources(name, 131, HALF), name .. " must not sit in the south cold belt")
    end
  end)
end)
