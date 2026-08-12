-- Proof: Cindra is a RIBBON in whichever orientation is set -- bounded across the
-- hot-cold axis ONLY, running forever along its long axis, with the FIRE on the
-- sunward side the orientation names (ci-65p).
--
-- The horizontal ribbon shipped broken twice over: the world was boxed in on BOTH
-- axes (a rectangle, not a ribbon) and the fire sat at the BOTTOM instead of the top.
-- Everything here is written through scripts/axis.lua's (long, perp) maps rather than
-- raw x/y, so the SAME assertions run against whichever orientation the startup
-- setting selects: "walk along the ribbon forever", "the far side is void", "the
-- sunward edge burns, the nightward edge freezes". A run configured horizontal proves
-- fire-at-the-top with these exact tests; a vertical run proves fire-at-the-west.
--
-- The pure (long, perp) <-> (x, y) mapping for BOTH orientations lives in
-- unit-tests/test_axis.lua + unit-tests/test_terrain.lua (a run can only exercise the
-- one startup orientation); this proves the live surface obeys it.

local axis = require("scripts.axis")
local terrain = require("scripts.terrain")
local driver = require("scripts.driver")

describe("cindra ribbon orientation: bounded across, endless along (ci-65p)", function()
  local s
  -- Far enough along the ribbon to be outside ANY perpendicular bound: past half the
  -- total ribbon width, so a world wrongly bounded on its long axis is void here.
  local FAR = 1200

  local function surface()
    return game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
  end

  -- Generate the chunks around a world position, then read the tile there.
  local function tile_at(x, y)
    s.request_to_generate_chunks({ x, y }, 1)
    s.force_generate_chunk_requests()
    return s.get_tile(math.floor(x), math.floor(y)).name
  end

  -- The world position of a point at (long, perp) on the ribbon.
  local function at(long, perp)
    local x, y = axis.world(long, perp)
    return x, y
  end

  -- An UNBOUNDED map-gen axis. 0 is how the mod states "infinite"; the engine may
  -- report an effectively-infinite axis as its own huge maximum instead, and neither
  -- is a wall the player can reach (cf. tests/test_worldgen.lua's same hedge).
  local function unbounded(v)
    return v == nil or v == 0 or v > 100000
  end

  before_each(function()
    s = surface()
  end)

  -- 1. A RIBBON, NOT A BOX ---------------------------------------------------------
  it("runs FOREVER along its long axis: the ground is still there 1200 tiles out", function()
    for _, long in ipairs({ FAR, -FAR }) do
      local x, y = at(long, 0)
      local name = tile_at(x, y)
      assert.are_not.equal("out-of-map", name,
        "the ribbon must keep going at long=" .. long .. " (" .. x .. "," .. y .. "), got " .. name)
      assert.is_true(terrain.is_walkable(name),
        "and it must be walkable ground out there, got " .. name)
    end
  end)

  it("is VOID across the hot-cold axis, on BOTH sides, at the ribbon's own width", function()
    local half = terrain.finite_dimension().value / 2
    for _, perp in ipairs({ half + 24, -(half + 24) }) do
      local x, y = at(0, perp)
      assert.are.equal("out-of-map", tile_at(x, y),
        "beyond perp=" .. perp .. " (" .. x .. "," .. y .. ") is the void backstop")
    end
    local x, y = at(0, 0)
    assert.are_not.equal("out-of-map", tile_at(x, y), "the ribbon centre is playable")
  end)

  -- 2. THE FIX: A BOXED-IN WORLD IS RE-OPENED --------------------------------------
  it("re-opens a world boxed in on BOTH axes -- the ci-65p horizontal-ribbon bug", function()
    -- The broken state a player actually met: a surface carrying a bound on the
    -- ribbon's LONG axis as well as its perpendicular one (an orientation flipped on
    -- an existing world, or any map-gen source that arrives with a size). Bounding
    -- only the perpendicular axis left that box in place and walled the ribbon in at
    -- ~400 tiles in every direction.
    local finite = terrain.finite_dimension()
    local long_key = terrain.infinite_dimension_key()
    local mg = s.map_gen_settings
    mg[long_key] = finite.value
    s.map_gen_settings = mg
    local boxed = s.map_gen_settings[long_key]

    -- Run the REAL bounding code (what the runtime does on surface creation / mod
    -- init) before asserting anything, and before generating a single chunk: a chunk
    -- generated while boxed would be void FOREVER, and a failed assertion here must
    -- never leave the shared surface walled in for the tests that follow.
    driver.enforce_finite(s)
    local reopened = s.map_gen_settings

    assert.are.equal(finite.value, boxed, "precondition: the surface really was boxed in")
    assert.is_true(unbounded(reopened[long_key]),
      "the long axis is re-opened to infinite, got " .. tostring(reopened[long_key]))
    assert.are.equal(finite.value, reopened[finite.key],
      "and the perpendicular axis keeps the ribbon width")

    -- Player-observable: the ground is back, far out along the ribbon.
    local x, y = at(FAR + 640, 0)
    assert.are_not.equal("out-of-map", tile_at(x, y),
      "after re-opening, the ribbon runs on at (" .. x .. "," .. y .. ")")
  end)

  it("bounds EXACTLY ONE axis -- a ribbon is never boxed on both", function()
    local mg = s.map_gen_settings
    local bounded = 0
    for _, key in ipairs({ "width", "height" }) do
      if not unbounded(mg[key]) then bounded = bounded + 1 end
    end
    assert.are.equal(1, bounded, "exactly one of width/height bounds the world")
    assert.are.equal(terrain.finite_dimension().value, mg[terrain.finite_dimension().key],
      "and it is the perpendicular axis, at the total ribbon width")
  end)

  -- 3. THE FIRE IS ON THE SUNWARD SIDE ---------------------------------------------
  it("burns you on the SUNWARD edge and freezes you on the NIGHTWARD edge", function()
    -- Read through axis.world, so this says "the top burns" under the horizontal
    -- orientation and "the west burns" under the vertical one. The sign of the
    -- perpendicular coordinate is the whole claim: sunward is hot, nightward is cold.
    local hot = terrain.role_band("hot_ocean")
    local cold = terrain.role_band("cold_ocean")
    local hot_perp = (hot.lo + hot.hi) / 2
    local cold_perp = (cold.lo + cold.hi) / 2

    local hx, hy = at(0, hot_perp)
    local hot_tile = tile_at(hx, hy)
    local hi, hkind = terrain.tile_damage(hot_tile)
    assert.are.equal("heat", hkind,
      "the sunward ocean (" .. hx .. "," .. hy .. ") = " .. hot_tile .. " must BURN")
    assert.is_true(hi > 0.5, "and burn hard out in the lava sea, got " .. hi)

    local cx, cy = at(0, cold_perp)
    local cold_tile = tile_at(cx, cy)
    local ci, ckind = terrain.tile_damage(cold_tile)
    assert.are.equal("cold", ckind,
      "the nightward ocean (" .. cx .. "," .. cy .. ") = " .. cold_tile .. " must FREEZE")
    assert.is_true(ci > 0.5, "and freeze hard out in the ice sea, got " .. ci)

    -- The two edges are on OPPOSITE sides of the map, on the perpendicular axis only.
    if axis.orientation() == axis.HORIZONTAL then
      assert.is_true(hy < 0 and cy > 0, "horizontal: FIRE AT THE TOP, ice at the bottom")
      assert.are.equal(hx, cx, "horizontal: both edges sit on the same long-axis column")
    else
      assert.is_true(hx < 0 and cx > 0, "vertical: fire in the west, ice in the east")
      assert.are.equal(hy, cy, "vertical: both edges sit on the same long-axis row")
    end
  end)

  it("keeps the temperature gradient on the perpendicular axis ONLY", function()
    -- Walking ALONG the ribbon must not change the temperature: same perp, different
    -- long -> the same damage verdict. This is what makes it a ribbon rather than a
    -- diagonal or a bowl.
    local hot_perp = (terrain.role_band("hot_ocean").lo + terrain.role_band("hot_ocean").hi) / 2
    local ax, ay = at(0, hot_perp)
    local bx, by = at(FAR, hot_perp)
    local _, akind = terrain.tile_damage(tile_at(ax, ay))
    local _, bkind = terrain.tile_damage(tile_at(bx, by))
    assert.are.equal(akind, bkind,
      "the sunward edge burns identically 1200 tiles along the ribbon")

    local safe_x, safe_y = at(FAR, 0)
    local i = terrain.tile_damage(tile_at(safe_x, safe_y))
    assert.are.equal(0, i, "and the habitable middle stays safe all the way along")
  end)
end)
