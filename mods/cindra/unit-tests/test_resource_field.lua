-- Plain-Lua unit test for the pure resource-field geometry
-- (scripts/resource-field.lua). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_resource_field.lua
--
-- resource-field.lua is pure (no game.* / prototypes.*): it maps a ribbon Y to a
-- per-band node richness. This asserts the band boundaries and the edge-pushing
-- richness gradients (best nodes at the lethal margins) off the game entirely.
-- The factorio-test in tests/test_worldgen.lua asserts the same shape places real
-- entities under the runtime; keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local field = require("scripts.resource-field")

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

-- Defaults: safe_half_width 24, lethal_at 96, wall_at 128.

test("stone lives on the ribbon + hot margin, not on the nightside", function()
  assert_true(field.stone_richness(0) > 0, "stone at the terminator")
  assert_true(field.stone_richness(90) > 0, "stone out to the hot margin")
  assert_eq(0, field.stone_richness(-40), "no stone nightward of the safe band")
  assert_eq(0, field.stone_richness(200), "no stone past the hot lethal edge")
end)

test("stone is richest toward the HOT lethal edge (edge-pushing)", function()
  assert_true(field.stone_richness(90) > field.stone_richness(0),
    "sunward stone richer than central stone")
  assert_true(field.stone_richness(0) > field.stone_richness(-20),
    "richness falls off toward the nightward edge of the stone band")
end)

test("ice lives on the nightside only, richer deeper (colder)", function()
  assert_eq(0, field.ice_richness(0), "no ice in the temperate ribbon")
  assert_eq(0, field.ice_richness(60), "no ice sunward")
  assert_true(field.ice_richness(-60) > 0, "ice on the nightside")
  assert_true(field.ice_richness(-120) > field.ice_richness(-40),
    "ice richer the deeper (colder) it gets")
end)

test("bootstrap rocks scatter only around the terminator", function()
  assert_true(field.rock_zone(0), "rocks at the terminator")
  assert_true(field.rock_zone(24), "rocks to the edge of the safe band")
  assert_true(field.rock_zone(-24), "rocks on the near nightside edge")
  assert_true(not field.rock_zone(40), "no rocks out in the damage margin")
  assert_true(not field.rock_zone(-40), "no rocks deep nightward")
end)

test("bands honour a partial config override (settings-driven tuning)", function()
  local cfg = { safe_half_width = 4 }
  -- Narrower safe band -> rocks only very close to centre.
  assert_true(field.rock_zone(4, cfg))
  assert_true(not field.rock_zone(10, cfg))
  -- Ice now starts just nightward of the narrower band.
  assert_true(field.ice_richness(-10, cfg) > 0, "ice exposed closer in")
end)

-- The native-autoplace band masks (emitted as noise-expression DSL strings) MUST
-- describe the same boundaries as the numeric richness_* fns above: stone on the
-- ribbon+hot margin [-safe, lethal], ice nightward (-safe .. -wall). Pinning the
-- exact string catches
-- any boundary drift. The DEFAULT orientation is vertical (hot on the LEFT), so
-- the sunward-positive perpendicular axis is "(0 - x)" and its negation is "x";
-- scripts/axis.lua proves both orientations of that mapping.

test("stone mask spans the ribbon + hot margin on the perpendicular axis", function()
  assert_eq("((0 - x) >= -24) * ((0 - x) <= 96)", field.stone_mask_expr(), "default stone band")
  -- Honours a config override (settings-driven tuning).
  assert_eq("((0 - x) >= -4) * ((0 - x) <= 50)", field.stone_mask_expr({ safe_half_width = 4, lethal_at = 50 }))
end)

test("ice mask covers the nightside in to the wall", function()
  assert_eq("((0 - x) < -24) * ((0 - x) > -128)", field.ice_mask_expr(), "default ice band")
end)

test("bootstrap-rock autoplace masks to the terminator band AND a finite spawn disk", function()
  local expr = field.rock_probability_expr()
  -- Confined to the safe band on the perpendicular axis (|perp| <= safe_half_width).
  assert_true(expr:find("(0 - x) < 24", 1, true) ~= nil, "capped sunward of the safe band")
  assert_true(expr:find("(0 - x) > -24", 1, true) ~= nil, "capped nightward of the safe band")
  -- FINITE: zero probability beyond a bounded disk around spawn.
  assert_true(expr:find("distance < ", 1, true) ~= nil, "rocks stop beyond a spawn-radius disk (finite)")
end)

test("edge-pushing richness multipliers ramp 1 -> peak/base toward the margins", function()
  -- Stone richest toward the hot edge; the multiplier's ceiling is peak/base.
  local mult = field.stone_richness_mult_expr()
  assert_true(mult:find("lerp%(1, ", 1) ~= nil, "starts at 1x at the near edge")
  assert_true(mult:find("clamp%(", 1) ~= nil, "clamped to the band fraction")
  -- The ice multiplier ramps on the nightward axis ("x" by default: deeper
  -- nightward = colder = richer). Pin the depth term so a boundary or orientation
  -- drift is caught.
  assert_true(field.ice_richness_mult_expr():find("%(x %- 24%)", 1) ~= nil, "ice ramps with nightward depth")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
