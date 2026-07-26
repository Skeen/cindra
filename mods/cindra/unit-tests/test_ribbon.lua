-- Plain-Lua unit test for the pure ribbon temperature axis (scripts/ribbon.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_ribbon.lua
--
-- This is the fast, no-Factorio path. scripts/ribbon.lua is deliberately pure
-- (no game.* / prototypes.*), so its whole maths surface is reachable here. The
-- factorio-test in tests/test_ribbon.lua asserts the SAME behaviour under the
-- real runtime; keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local ribbon = require("scripts.ribbon")

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

test("safe band is temperate and damage-free", function()
  for _, y in ipairs({ -24, -10, 0, 10, 24 }) do
    assert_eq("safe", ribbon.zone(y), "y=" .. y .. " safe")
    assert_eq(0, (ribbon.damage_per_second(y)), "y=" .. y .. " no damage")
  end
end)

test("temperature rises sunward, falls nightward", function()
  local center = ribbon.temperature(0)
  assert_eq(25, center, "centre is room temperature")
  assert_true(ribbon.temperature(100) > center, "sunward hotter")
  assert_true(ribbon.temperature(-100) < center, "nightward colder")
end)

test("temperature saturates at the wall (no runaway beyond the edge)", function()
  assert_eq(ribbon.temperature(128), ribbon.temperature(500), "sunward saturates")
  assert_eq(ribbon.temperature(-128), ribbon.temperature(-500), "nightward saturates")
end)

test("zones split heat sunward from cold nightward", function()
  assert_eq("hot_warn", ribbon.zone(60))
  assert_eq("cold_warn", ribbon.zone(-60))
  assert_eq("hot_lethal", ribbon.zone(110))
  assert_eq("cold_lethal", ribbon.zone(-110))
end)

test("damage types match the edge", function()
  local _, hot = ribbon.damage_per_second(60)
  local _, cold = ribbon.damage_per_second(-60)
  assert_eq("heat", hot)
  assert_eq("cold", cold)
end)

test("damage ramps 0 -> max then holds", function()
  assert_eq(0, (ribbon.damage_per_second(24)), "edge of safe band")
  local mid = ribbon.damage_per_second(60)
  local lethal = ribbon.damage_per_second(96)
  assert_true(mid > 0 and mid < lethal, "ramps in margin")
  assert_eq(lethal, (ribbon.damage_per_second(1000)), "saturates")
  assert_eq(200, lethal, "peak dps default (§16)")
end)

test("damage ramp is exactly linear at the midpoint", function()
  -- safe=24, lethal=96, max=200: midpoint distance 60 -> t = (60-24)/(96-24) = 0.5
  local mid = ribbon.damage_per_second(60)
  assert_eq(100, mid, "half-way through the margin is half the peak dps")
end)

test("hard-wall backstop bounds the ribbon", function()
  assert_true(not ribbon.past_wall(120), "inside")
  assert_true(ribbon.past_wall(128), "at wall")
  assert_true(ribbon.past_wall(-200), "past wall")
end)

test("partial config override falls back to defaults for unset keys", function()
  local cfg = { safe_half_width = 4 }
  assert_eq("hot_warn", ribbon.zone(10, cfg), "narrower safe band exposes y=10")
  assert_eq("safe", ribbon.zone(0, cfg), "centre still safe")
  -- lethal_at unspecified -> default 96 still applies
  assert_eq("hot_lethal", ribbon.zone(96, cfg))
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
