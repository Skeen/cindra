-- Plain-Lua unit test for the pure ribbon temperature axis (scripts/ribbon.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_ribbon.lua
--
-- This is the fast, no-Factorio path. scripts/ribbon.lua is deliberately pure
-- (no game.* / prototypes.*), so its whole maths surface is reachable here. The
-- factorio-test in tests/test_ribbon.lua asserts the SAME behaviour under the
-- real runtime; keep the two in sync.
--
-- ci-a35: the temperate reference is the SAND-band centre (`ref`), with asymmetric
-- reaches to the hot / cold void edge, all derived from the per-zone gradient
-- (scripts/zones.lua). Player-facing environmental damage is now TILE damage
-- (scripts/tile-damage.lua), so ribbon no longer exposes an abstract zone()/dps
-- ramp; it maps a perpendicular coordinate to a temperature and a solar fraction.

package.path = package.path .. ";./?.lua;./?/init.lua"
local ribbon = require("scripts.ribbon")
local zones = require("scripts.zones")

local GEO = zones.geometry()
local REF = GEO.ref

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

test("the sand spawn reference is room temperature", function()
  assert_eq(25, ribbon.temperature(REF), "the sand-band centre is temperate")
end)

test("temperature rises sunward, falls nightward of the spawn", function()
  local center = ribbon.temperature(REF)
  assert_true(ribbon.temperature(REF + 60) > center, "sunward hotter")
  assert_true(ribbon.temperature(REF - 60) < center, "nightward colder")
end)

test("temperature saturates at each void edge (no runaway beyond)", function()
  assert_eq(ribbon.temperature(GEO.hot_edge_p), ribbon.temperature(GEO.hot_edge_p + 500),
    "sunward saturates at the hot edge")
  assert_eq(ribbon.temperature(GEO.cold_edge_p), ribbon.temperature(GEO.cold_edge_p - 500),
    "nightward saturates at the cold edge")
  assert_eq(1500, ribbon.temperature(GEO.hot_edge_p), "hot edge = temp_hot_max")
  assert_eq(-270, ribbon.temperature(GEO.cold_edge_p), "cold edge = temp_cold_min")
end)

test("temperature is monotonic across the whole axis", function()
  local prev = math.huge
  for p = math.floor(GEO.hot_edge_p), math.ceil(GEO.cold_edge_p), -5 do
    local t = ribbon.temperature(p)
    assert_true(t <= prev + 1e-9, "temperature falls monotonically from hot to cold at p=" .. p)
    prev = t
  end
end)

test("config override pins the reference and reaches (tunable)", function()
  local cfg = { ref = 0, hot_reach = 100, cold_reach = 100 }
  assert_eq(25, ribbon.temperature(0, cfg), "custom reference is temperate")
  assert_eq(ribbon.temperature(50, cfg), ribbon.temperature(50, cfg), "deterministic")
  assert_true(ribbon.temperature(-50, cfg) < 25, "nightward of the custom ref is colder")
end)

-- === Solar output falloff (§ ci-9ht) ======================================

test("solar output is full deep sunward, ~nothing deep nightward", function()
  assert_eq(1.0, ribbon.sunward_factor(GEO.hot_damage_start), "at the fire margin: full sun")
  assert_eq(1.0, ribbon.sunward_factor(GEO.hot_edge_p), "beyond it: held at full")
  assert_eq(0.0, ribbon.sunward_factor(GEO.cold_damage_start), "at the freeze boundary: floor")
  assert_eq(0.0, ribbon.sunward_factor(GEO.cold_edge_p), "far nightward: held at the floor")
end)

test("solar output rises monotonically sunward", function()
  local prev = -1
  for p = math.floor(GEO.cold_damage_start), math.ceil(GEO.hot_damage_start), 5 do
    local f = ribbon.sunward_factor(p)
    assert_true(f >= prev - 1e-9, "solar must not drop going sunward at p=" .. p)
    prev = f
  end
end)

test("solar falloff makes sunward materially beat nightward", function()
  -- The whole point: a sunward panel must out-produce a nightward one, so
  -- placement (build toward the heat) is a real decision.
  local sunward = ribbon.sunward_factor(REF + (GEO.hot_reach * 0.5))
  local nightward = ribbon.sunward_factor(REF - (GEO.cold_reach * 0.5))
  assert_true(sunward > nightward + 0.2, "mid-sunward output dwarfs the nightward point")
end)

test("solar falloff respects a config override (tunable, still clamped)", function()
  local cfg = { solar_full = 48, solar_zero = 0, solar_floor = 0.1 }
  assert_eq(1.0, ribbon.sunward_factor(48, cfg), "custom full point saturates")
  assert_eq(0.1, ribbon.sunward_factor(0, cfg), "custom zero point holds the floor")
  assert_eq(0.1, ribbon.sunward_factor(-10, cfg), "below the zero point: floor")
  local mid = ribbon.sunward_factor(24, cfg)
  assert_true(mid > 0.1 and mid < 1.0, "halfway ramps between floor and full")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
