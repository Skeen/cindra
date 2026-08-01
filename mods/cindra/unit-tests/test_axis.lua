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

test("horizontal (legacy): the perpendicular axis is Y, sunward = +Y", function()
  assert_eq(40, axis.perp(0, 40, "horizontal"), "+Y is sunward-positive")
  assert_eq(-40, axis.perp(0, -40, "horizontal"), "-Y is nightward-negative")
  assert_eq(0, axis.perp(999, 0, "horizontal"), "the long (E-W) axis does not change temperature")
end)

test("perp_expr emits the sunward-positive axis for the noise DSL", function()
  assert_eq("(0 - x)", axis.perp_expr("vertical"), "vertical bands on -x (hot left)")
  assert_eq("y", axis.perp_expr("horizontal"), "horizontal bands on y")
  assert_eq("(0 - x)", axis.perp_expr(), "default resolves to vertical")
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
  -- +y, so y = 40. A lattice point at long = 201 sits on the respective long axis.
  local vx, vy = axis.world(201, 40, "vertical")
  assert_eq(-40, vx, "vertical: sunward row is at -x"); assert_eq(201, vy, "vertical: lattice on y")
  local hx, hy = axis.world(201, 40, "horizontal")
  assert_eq(201, hx, "horizontal: lattice on x"); assert_eq(40, hy, "horizontal: sunward row is at +y")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
