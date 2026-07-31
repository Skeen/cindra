-- Plain-Lua unit test for the pure ribbon temperature axis (scripts/ribbon.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_ribbon.lua
--
-- This is the fast, no-Factorio path. scripts/ribbon.lua is deliberately pure
-- (no game.* / prototypes.*), so its whole maths surface is reachable here. The
-- factorio-test in tests/test_ribbon.lua asserts the SAME behaviour under the
-- real runtime; keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local ribbon = require("scripts.ribbon")
local terrain = require("scripts.terrain")

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

-- === Solar output falloff (§ ci-9ht; recalibrated to ci-da2 zones, ci-22v) =====

-- The zone-derived anchors for the default worldgen (ci-wly): full output at the inner
-- edge of the hot DAMAGING rings (hot_inner.lo), ~zero by the middle->cold boundary.
local FULL_AT = terrain.role_band("hot_inner").lo   -- 130 by default
local ZERO_AT = terrain.role_band("middle").lo      -- -60 by default

test("solar anchors are DERIVED from the zone layout, not fixed tiles", function()
  local full, zero, floor = ribbon.solar_anchors()
  assert_eq(FULL_AT, full, "full-output anchor is the hot damaging inner edge")
  assert_eq(ZERO_AT, zero, "zero-output anchor is the middle->cold boundary")
  assert_eq(0.0, floor, "the far-nightward floor is ~nothing")
  -- The anchors must be well clear of the middle: the ci-22v bug was full output
  -- landing at/near spawn. Full only sunward of the middle (the lava side), zero on
  -- the cold side -- derived, so it tracks the live widths.
  assert_true(full > terrain.role_band("middle").hi,
    "full output is sunward of the middle (the lava side), not at spawn")
  assert_true(zero <= 0, "zero output is at/beyond the nightward edge of the middle")
end)

test("recalibrating a zone width moves the solar anchors with it", function()
  -- A wider middle pushes the middle->cold boundary further nightward, so solar tracks
  -- the actual worldgen instead of a stale fixed tile.
  local full, zero = ribbon.solar_anchors({ zone_widths = { middle = 400 } })
  assert_eq(terrain.role_band("middle", { middle = 400 }).lo, zero,
    "the zero anchor follows the widened middle")
  assert_eq(terrain.role_band("hot_inner", { middle = 400 }).lo, full,
    "the full anchor follows the shifted hot zone")
  assert_true(zero < ZERO_AT, "widening the middle moved zero further nightward")
end)

test("solar output is full only on the LAVA side, ~nothing on the ICE side", function()
  assert_eq(1.0, ribbon.sunward_factor(FULL_AT), "at the lava inner edge: full sun")
  assert_eq(1.0, ribbon.sunward_factor(FULL_AT + 100), "deeper into the lava: held at full")
  assert_eq(0.0, ribbon.sunward_factor(ZERO_AT), "at the temperate->ice boundary: ~nothing")
  assert_eq(0.0, ribbon.sunward_factor(ZERO_AT - 100), "far onto the ice: held at the floor")
end)

test("solar output is NOT full at the temperate centre (the ci-22v bug)", function()
  -- The reported bug: output hit 400kW at the centre and stayed flat into the lava.
  -- The centre must now be a modest fraction, well below full.
  local centre = ribbon.sunward_factor(0)
  assert_true(centre > 0.0, "the terminator centre still makes SOME power")
  assert_true(centre < 0.4, "the centre is nowhere near full output (got " .. centre .. ")")
  -- And it must NOT be flat into the lava: a point just sunward of centre is well
  -- below a point deep in the hot margin.
  assert_true(ribbon.sunward_factor(100) < ribbon.sunward_factor(300),
    "output still rises across the hot margin, not flat")
end)

test("solar output rises monotonically sunward across the whole ribbon", function()
  local prev = -1
  for _, y in ipairs({ -200, -100, -50, 0, 50, 100, 200, 300, 350, 450 }) do
    local f = ribbon.sunward_factor(y)
    assert_true(f >= prev, "y=" .. y .. " must not drop below a nightward point")
    prev = f
  end
end)

test("solar falloff makes the lava side dwarf the ice side", function()
  -- The whole point: a sunward panel must out-produce a nightward one, so
  -- placement (build toward the heat) is a real decision.
  assert_true(ribbon.sunward_factor(FULL_AT) > 4 * ribbon.sunward_factor(-50) + 0.1,
    "the lava side dwarfs a nightward point")
  assert_true(ribbon.sunward_factor(0) > ribbon.sunward_factor(-50),
    "the terminator centre still beats a nightward point")
end)

test("solar falloff respects a config override (tunable, still clamped)", function()
  local cfg = { solar_full_at = 48, solar_zero_at = 0, solar_floor = 0.1 }
  assert_eq(1.0, ribbon.sunward_factor(48, cfg), "custom full point saturates")
  assert_eq(0.1, ribbon.sunward_factor(0, cfg), "custom zero point holds the floor")
  assert_eq(0.1, ribbon.sunward_factor(-10, cfg), "below the zero point: floor")
  local mid = ribbon.sunward_factor(24, cfg)
  assert_true(mid > 0.1 and mid < 1.0, "halfway ramps between floor and full")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
