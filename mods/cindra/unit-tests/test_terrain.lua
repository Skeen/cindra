-- Plain-Lua unit test for the ribbon TERRAIN bands (scripts/terrain.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is the pure source of truth for the noise-driven ribbon tile bands:
-- it emits each Cindra tile's `probability_expression` (a noise expression keyed
-- to the perpendicular axis, wiggled by basis_noise so boundaries are organic),
-- classifies which tiles are lethal, and reports the finite map dimension. This
-- proves that pure surface; the factorio-test in tests/test_worldgen.lua proves
-- the bands actually generate in the right places on a live map.

package.path = package.path .. ";./?.lua;./?/init.lua"
local terrain = require("scripts.terrain")
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

local function contains(haystack, needle, msg)
  assert_true(haystack:find(needle, 1, true) ~= nil,
    (msg or "expected substring") .. " '" .. needle .. "' in: " .. haystack)
end

local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128 }

test("the five Cindra tiles are registered, centre -> edge on each side", function()
  local names = terrain.tile_names()
  assert_eq(5, #names, "five ribbon tiles")
  local set = {}
  for _, n in ipairs(names) do set[n] = true end
  for _, n in ipairs({ "cindra-terminator", "cindra-molten-rock", "cindra-lava",
                       "cindra-frost", "cindra-deep-ice" }) do
    assert_true(set[n], "missing tile " .. n)
  end
end)

test("only lava (heat) and deep-ice (cold) are lethal; the margins are safe", function()
  assert_eq("heat", terrain.lethal_kind("cindra-lava"), "lava burns")
  assert_eq("cold", terrain.lethal_kind("cindra-deep-ice"), "deep ice freezes")
  assert_eq(nil, terrain.lethal_kind("cindra-molten-rock"), "molten rock is walkable/safe")
  assert_eq(nil, terrain.lethal_kind("cindra-frost"), "frost is walkable/safe")
  assert_eq(nil, terrain.lethal_kind("cindra-terminator"), "the terminator centre is safe")
  local lethal = terrain.lethal_tiles()
  local n = 0
  for _ in pairs(lethal) do n = n + 1 end
  assert_eq(2, n, "exactly two lethal tiles")
end)

test("the terminator is a constant baseline so it wins the wide safe centre", function()
  assert_eq("1", terrain.probability_expr("cindra-terminator", CFG),
    "the centre tile is the constant fallback (guarantees full coverage)")
end)

test("band expressions are noise-driven (range_select_base + basis_noise), keyed to the axis", function()
  local hot = terrain.probability_expr("cindra-lava", CFG)
  local cold = terrain.probability_expr("cindra-deep-ice", CFG)
  -- Noise-driven bands (organic boundaries), not raw straight thresholds.
  contains(hot, "range_select_base", "lava band is a range selector")
  contains(hot, "basis_noise", "lava boundary is wiggled by smooth noise")
  -- Keyed to the perpendicular axis: hot side reads +perp, cold side reads -perp.
  contains(hot, axis.perp_expr(), "hot band reads the sunward-positive axis")
  contains(cold, axis.perp_neg_expr(), "cold band reads the nightward-positive axis")
end)

test("the world is finite perpendicular via the map-gen (width by default)", function()
  local d = terrain.finite_dimension(CFG)
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  assert_eq(2 * CFG.wall_at, d.value, "the finite dimension is twice the wall distance")
  -- Tracks the config: a narrower wall -> a narrower ribbon.
  assert_eq(200, terrain.finite_dimension({ wall_at = 100 }).value)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
