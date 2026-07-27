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

test("volatiles only in the deep nightside cold-lethal band", function()
  assert_eq(0, field.volatiles_richness(-60), "not in the nightward margin")
  assert_eq(0, field.volatiles_richness(0), "not in the ribbon")
  assert_true(field.volatiles_richness(-110) > 0, "volatiles in the deep cold edge")
  assert_true(field.volatiles_richness(-127) > field.volatiles_richness(-100),
    "the coldest, deepest node is the best")
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
-- ribbon+hot margin [-safe, lethal], ice nightward (-safe .. -wall), volatiles in
-- the deep cold-lethal band (-lethal .. -wall). Pinning the exact string catches
-- any boundary / orientation drift.

test("stone mask spans the ribbon + hot margin on the Y axis", function()
  assert_eq("(y >= -24) * (y <= 96)", field.stone_mask_expr(), "default stone band")
  -- Honours a config override (settings-driven tuning).
  assert_eq("(y >= -4) * (y <= 50)", field.stone_mask_expr({ safe_half_width = 4, lethal_at = 50 }))
end)

test("ice mask covers the nightside in to the wall", function()
  assert_eq("(y < -24) * (y > -128)", field.ice_mask_expr(), "default ice band")
end)

test("volatiles mask covers only the deep cold-lethal band", function()
  assert_eq("(y <= -96) * (y > -128)", field.volatiles_mask_expr(), "default volatiles band")
end)

test("edge-pushing richness multipliers ramp 1 -> peak/base toward the margins", function()
  -- Stone richest toward the hot edge; the multiplier's ceiling is peak/base.
  local mult = field.stone_richness_mult_expr()
  assert_true(mult:find("lerp%(1, ", 1) ~= nil, "starts at 1x at the near edge")
  assert_true(mult:find("clamp%(", 1) ~= nil, "clamped to the band fraction")
  -- Ice / volatiles multipliers reference the negated Y (deeper = colder = richer).
  assert_true(field.ice_richness_mult_expr():find("%-y", 1) ~= nil, "ice ramps with depth")
  assert_true(field.volatiles_richness_mult_expr():find("%-y", 1) ~= nil, "volatiles ramp with depth")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
