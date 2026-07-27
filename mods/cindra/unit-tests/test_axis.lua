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

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
