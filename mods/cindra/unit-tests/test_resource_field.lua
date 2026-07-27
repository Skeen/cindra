-- Plain-Lua unit test for the pure resource-field geometry
-- (scripts/resource-field.lua). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_resource_field.lua
--
-- resource-field.lua is pure (no game.* / prototypes.*): it maps a ribbon
-- perpendicular coordinate to a per-band node richness. This asserts the v2
-- resource rule -- resources ONLY in the survivable PLAYABLE band, richest at the
-- playable edge, and ZERO out in the lethal terrain (molten rock, lava, the ice
-- wall, the death zone). The factorio-test in tests/test_worldgen.lua asserts the
-- same shape places real entities under the runtime; keep the two in sync.

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

-- Defaults (symmetric): safe 24, hot_lethal_at 96, cold_lethal_at 96.

test("stone lives in the playable sunward band, NOT out in the lethal terrain", function()
  assert_true(field.stone_richness(0) > 0, "stone at the terminator")
  assert_true(field.stone_richness(90) > 0, "stone out to just inside the sunward edge")
  assert_eq(0, field.stone_richness(-40), "no stone nightward of the safe band")
  assert_eq(0, field.stone_richness(96), "no stone AT the lethal edge (molten rock)")
  assert_eq(0, field.stone_richness(120), "no stone in the lava band")
  assert_eq(0, field.stone_richness(200), "no stone beyond the wall")
end)

test("stone is richest toward the HOT playable edge (edge-pushing)", function()
  assert_true(field.stone_richness(90) > field.stone_richness(0),
    "sunward stone richer than central stone")
  assert_true(field.stone_richness(0) > field.stone_richness(-20),
    "richness falls off toward the nightward edge of the stone band")
end)

test("ice lives in the playable nightside band, richer toward the cold edge", function()
  assert_eq(0, field.ice_richness(0), "no ice in the temperate centre")
  assert_eq(0, field.ice_richness(60), "no ice sunward")
  assert_true(field.ice_richness(-60) > 0, "ice in the icy margin")
  assert_true(field.ice_richness(-90) > field.ice_richness(-40),
    "ice richer the deeper (colder) it gets, toward the playable edge")
  assert_eq(0, field.ice_richness(-96), "no ice AT the lethal edge (ice wall)")
  assert_eq(0, field.ice_richness(-120), "no ice out in the ice wall / death zone")
end)

test("volatiles only in the deepest SURVIVABLE icy slice (never the ice wall)", function()
  assert_eq(0, field.volatiles_richness(-40), "not in the shallow icy margin")
  assert_eq(0, field.volatiles_richness(0), "not in the ribbon")
  assert_true(field.volatiles_richness(-90) > 0, "volatiles just inside the cold edge")
  assert_true(field.volatiles_richness(-95) > field.volatiles_richness(-80),
    "the coldest survivable node is the best")
  assert_eq(0, field.volatiles_richness(-96), "no volatiles AT the lethal edge")
  assert_eq(0, field.volatiles_richness(-120), "no volatiles in the ice wall / death zone")
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

test("per-side depths gate each resource by its own side's playable edge", function()
  -- Shallow hot zone (lethal 40), deep cold zone (lethal 130).
  local cfg = { safe_half_width = 20, hot_lethal_at = 40, cold_lethal_at = 130 }
  assert_true(field.stone_richness(35, cfg) > 0, "stone still inside the shallow hot edge")
  assert_eq(0, field.stone_richness(40, cfg), "no stone at the shallow hot lethal edge")
  assert_true(field.ice_richness(-120, cfg) > 0, "ice reaches deep into the long cold margin")
  assert_eq(0, field.ice_richness(-130, cfg), "no ice at the deep cold lethal edge")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
