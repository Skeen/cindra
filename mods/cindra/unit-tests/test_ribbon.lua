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

test("damage ramp is a SMOOTH ease-in (starts slow, ramps up with depth)", function()
  -- safe=24, lethal=96, max=200: midpoint distance 60 -> t = 0.5, dps = 200*0.5^2 = 50.
  assert_eq(50, ribbon.damage_per_second(60), "ease-in: halfway is a QUARTER of peak, not half")
  -- Strictly increasing with depth across the whole margin (both sides), and it
  -- accelerates (later steps add more than earlier ones -> "starts slow").
  local prev, prev_step = 0, -1
  for d = 25, 96 do
    local dps = ribbon.damage_per_second(d)
    assert_true(dps > prev, "fire dps strictly increases with depth at d=" .. d)
    local step = dps - prev
    if d > 30 then assert_true(step >= prev_step - 1e-9, "ramp accelerates (ease-in) at d=" .. d) end
    prev, prev_step = dps, step
  end
  -- Symmetric on the cold side: freeze also strictly increases toward the edge.
  assert_true(ribbon.damage_per_second(-96) > ribbon.damage_per_second(-60), "freeze ramps too")
  assert_true(ribbon.damage_per_second(-60) > ribbon.damage_per_second(-30), "freeze gentle near entry")
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

-- === Solar output falloff (§ ci-9ht) ======================================

test("solar output is full deep sunward, ~nothing nightward", function()
  assert_eq(1.0, ribbon.sunward_factor(96), "at the sunward saturation: full sun")
  assert_eq(1.0, ribbon.sunward_factor(200), "beyond it: held at full")
  assert_eq(0.0, ribbon.sunward_factor(-24), "at the nightward floor: ~nothing")
  assert_eq(0.0, ribbon.sunward_factor(-200), "far nightward: held at the floor")
end)

test("solar output rises monotonically sunward", function()
  local prev = -1
  for _, y in ipairs({ -24, -10, 0, 24, 48, 72, 96 }) do
    local f = ribbon.sunward_factor(y)
    assert_true(f >= prev, "y=" .. y .. " must not drop below a nightward point")
    prev = f
  end
end)

test("solar falloff makes sunward materially beat nightward", function()
  -- The whole point: a sunward panel must out-produce a nightward one, so
  -- placement (build toward the heat) is a real decision.
  assert_true(ribbon.sunward_factor(48) > 4 * ribbon.sunward_factor(-24) + 0.1,
    "mid-sunward output dwarfs the nightward floor")
  assert_true(ribbon.sunward_factor(0) > ribbon.sunward_factor(-12),
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

-- Orientation (v2 item 1): the perp/along accessors are the single place that
-- maps a world position to the ribbon axes, and MUST be correct in BOTH layouts.

test("east-west orientation: perpendicular axis is Y, long axis is X", function()
  local cfg = { orientation = "east-west" }
  local pos = { x = 300, y = -40 }
  assert_eq(-40, ribbon.perp(pos, cfg), "perp reads Y east-west")
  assert_eq(300, ribbon.along(pos, cfg), "along reads X east-west")
  -- Default orientation is east-west when unspecified.
  assert_eq(-40, ribbon.perp(pos), "default orientation reads Y")
end)

test("north-south orientation: perpendicular axis is X, long axis is Y", function()
  local cfg = { orientation = "north-south" }
  local pos = { x = -40, y = 300 }
  assert_eq(-40, ribbon.perp(pos, cfg), "perp reads X north-south")
  assert_eq(300, ribbon.along(pos, cfg), "along reads Y north-south")
end)

test("the SAME perp value gives the SAME axis result in either orientation", function()
  -- A point 40 tiles sunward is identical physics regardless of orientation;
  -- only which world coordinate carries it changes.
  local ew = ribbon.perp({ x = 999, y = 40 }, { orientation = "east-west" })
  local ns = ribbon.perp({ x = 40, y = 999 }, { orientation = "north-south" })
  assert_eq(ew, ns, "both extract perp = 40")
  assert_eq(ribbon.zone(ew), ribbon.zone(ns), "identical zone")
end)

-- Asymmetric per-side depths (v2 item 7: hot-zone / cold-zone depth sliders).

test("per-side lethal/wall overrides make hot and cold zones differ", function()
  -- Shallow hot zone, deep cold zone: y=+50 is already lethal-hot, but the same
  -- distance nightward (-50) is still only a warning.
  local cfg = {
    safe_half_width = 24,
    hot_lethal_at = 40, hot_wall_at = 60,
    cold_lethal_at = 96, cold_wall_at = 200,
  }
  assert_eq("hot_lethal", ribbon.zone(50, cfg), "shallow hot zone: 50 is lethal")
  assert_eq("cold_warn", ribbon.zone(-50, cfg), "deep cold zone: -50 still a warning")
  assert_true(ribbon.past_wall(60, cfg), "sunward wall at 60")
  assert_true(not ribbon.past_wall(-60, cfg), "nightward wall much further out")
  assert_true(ribbon.past_wall(-200, cfg), "nightward wall at 200")
end)

test("temperature saturates at the per-side wall, not the symmetric default", function()
  local cfg = { hot_wall_at = 60, cold_wall_at = 200 }
  assert_eq(ribbon.temperature(60, cfg), ribbon.temperature(500, cfg),
    "sunward saturates at the shallow hot wall")
  assert_true(ribbon.temperature(-60, cfg) > ribbon.temperature(-200, cfg),
    "nightward keeps cooling out to the deep cold wall")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
