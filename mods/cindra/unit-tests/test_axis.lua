-- Plain-Lua unit test for the ribbon ORIENTATION mapping (scripts/axis.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_axis.lua
--
-- axis.lua is the one place that turns a world (x, y) into the ribbon's
-- sunward-positive perpendicular coordinate. It reads only the final startup
-- setting and falls back to the default off-game, so its whole mapping is
-- reachable here without Factorio. The factorio-test in tests/test_worldgen.lua
-- asserts the SAME orientation drives real placement; keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local axis = require("scripts.axis")

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok - " .. name)
  else
    failed = failed + 1
    print("not ok - " .. name .. ": " .. tostring(err))
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

test("default orientation is vertical (ribbon N-S, hot on the LEFT)", function()
  assert_eq("vertical", axis.DEFAULT, "the default is vertical")
  assert_eq("vertical", axis.orientation(), "no setting off-game -> default vertical")
end)

test("vertical: the perpendicular axis is X, sunward-positive toward the LEFT", function()
  -- p = -x: the west (left, -X) is HOT (p > 0), the east (right, +X) is COLD.
  assert_eq(40, axis.perp(-40, 0, "vertical"), "left/west is sunward-positive")
  assert_eq(-40, axis.perp(40, 0, "vertical"), "right/east is nightward-negative")
  assert_eq(0, axis.perp(0, 999, "vertical"), "the long (N-S) axis does not change temperature")
end)

test("horizontal: the perpendicular axis is Y, FIRE AT THE TOP (sunward = -Y)", function()
  -- ci-65p: the horizontal ribbon put the fire at the BOTTOM. It belongs at the top,
  -- matching the vertical ribbon's hot-side convention (hot toward the screen edge
  -- the player reads first). p = -y: north (up, -Y) is HOT, south (down, +Y) is COLD.
  assert_eq(40, axis.perp(0, -40, "horizontal"), "the TOP (-Y / north) is sunward-positive")
  assert_eq(-40, axis.perp(0, 40, "horizontal"), "the BOTTOM (+Y / south) is nightward-negative")
  assert_eq(0, axis.perp(999, 0, "horizontal"), "the long (E-W) axis does not change temperature")
end)

test("both orientations put the fire on the SAME screen side convention", function()
  -- The hot end of the gradient is at negative world coordinate on the perpendicular
  -- axis in BOTH orientations: -x (left) vertically, -y (top) horizontally. A player
  -- walking toward the fire walks toward the top-left origin either way.
  for _, case in ipairs({ { "vertical", -300, 0 }, { "horizontal", 0, -300 } }) do
    local orient, x, y = case[1], case[2], case[3]
    assert_true(axis.perp(x, y, orient) > 0, orient .. ": the negative perpendicular side is HOT")
    assert_true(axis.perp(-x, -y, orient) < 0, orient .. ": the opposite side is COLD")
  end
end)

test("raw_perp_expr emits the sunward-positive WORLD axis for the noise DSL", function()
  assert_eq("(0 - x)", axis.raw_perp_expr("vertical"), "vertical bands on -x (hot left)")
  assert_eq("(0 - y)", axis.raw_perp_expr("horizontal"), "horizontal bands on -y (hot top)")
  assert_eq("(0 - x)", axis.raw_perp_expr(), "default resolves to vertical")
end)

test("raw_perp_neg_expr is exactly -raw_perp_expr for both orientations", function()
  -- The cold-side band masks read "how deep nightward am I". Emitted separately to
  -- keep the expression clean, so it MUST stay the negation of the sunward axis.
  assert_eq("x", axis.raw_perp_neg_expr("vertical"), "vertical nightward is +x (east)")
  assert_eq("y", axis.raw_perp_neg_expr("horizontal"), "horizontal nightward is +y (south, the bottom)")
end)

test("perp_expr is the NOMINAL axis every band mask reads (the zone-slider warp)", function()
  -- The masks must not read the raw world axis: the world-gen-screen zone sliders
  -- (ci-i4z) stretch the world, and the named warp expression is what maps a world
  -- position back onto the nominal zone table every band constant is written in.
  -- One name, so a band cannot opt out of the sliders by accident.
  assert_eq("cindra_perp", axis.perp_expr(), "the sunward nominal axis")
  assert_eq("cindra_perp_neg", axis.perp_neg_expr(), "the nightward nominal axis")
  assert_true(axis.perp_expr() ~= axis.raw_perp_expr(), "and it is NOT the raw axis")
end)

test("long() is the ribbon's OTHER axis (the emitter lattice steps along it)", function()
  assert_eq(999, axis.long(0, 999, "vertical"), "vertical long axis is Y")
  assert_eq(999, axis.long(999, 0, "horizontal"), "horizontal long axis is X")
end)

test("world() is the exact inverse of (long, perp) for BOTH orientations", function()
  -- The emitter placer turns (long = lattice, perp = row) back into (x, y); it must
  -- round-trip perp()/long() so an emitter lands on the intended tile.
  for _, orient in ipairs({ "vertical", "horizontal" }) do
    for _, pt in ipairs({ { 7, -13 }, { -201, 40 }, { 0, 0 }, { 33, 241 } }) do
      local x, y = pt[1], pt[2]
      local wx, wy = axis.world(axis.long(x, y, orient), axis.perp(x, y, orient), orient)
      assert_eq(x, wx, orient .. ": world() recovers x")
      assert_eq(y, wy, orient .. ": world() recovers y")
    end
  end
end)

test("world() places a row-40 emitter on the HOT side for both orientations", function()
  -- perp = 40 is sunward (hot). Vertical: hot is -x, so x = -40. Horizontal: hot is
  -- -y (the TOP), so y = -40. A lattice point at long = 201 sits on the respective
  -- long axis.
  local vx, vy = axis.world(201, 40, "vertical")
  assert_eq(-40, vx, "vertical: sunward row is at -x"); assert_eq(201, vy, "vertical: lattice on y")
  local hx, hy = axis.world(201, 40, "horizontal")
  assert_eq(201, hx, "horizontal: lattice on x"); assert_eq(-40, hy, "horizontal: sunward row is at -y (top)")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
