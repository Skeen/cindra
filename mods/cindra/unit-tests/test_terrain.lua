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

test("every tile has a map_color; the danger edges are distinct from the safe centre (ci-4h7)", function()
  -- The danger zone must read on the map view (ci-4h7). Each Cindra tile carries a
  -- {r,g,b} map_color, and the lethal edges are visually distinct from the safe
  -- terminator centre so the safe<->damaging boundary is legible on the map.
  local center = terrain.map_color("cindra-terminator")
  assert_true(center ~= nil, "the safe centre has a map_color")
  for _, t in ipairs({ "cindra-terminator", "cindra-molten-rock", "cindra-lava",
                       "cindra-frost", "cindra-deep-ice" }) do
    local c = terrain.map_color(t)
    assert_true(c ~= nil, t .. " has a map_color")
    assert_eq(3, #c, t .. " map_color is {r,g,b}")
  end
  assert_true(terrain.map_color("unknown-tile") == nil, "unknown tiles have no map_color")

  -- Manhattan distance in RGB: the two lethal edges must clearly differ from the
  -- neutral centre (not a near-identical muddy brown, the vanilla-clone problem).
  local function dist(a, b)
    return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3])
  end
  local lava, ice = terrain.map_color("cindra-lava"), terrain.map_color("cindra-deep-ice")
  assert_true(dist(lava, center) > 0.6, "the lethal lava edge is a distinct colour from the safe centre")
  assert_true(dist(ice, center) > 0.6, "the lethal deep-ice edge is a distinct colour from the safe centre")

  -- The hot danger band reddens toward its lethal edge (deep red margin -> hot
  -- orange lava): red channel dominates and the edge is brighter/hotter than the
  -- margin. The cold band brightens toward its lethal edge (blue channel dominant).
  local margin = terrain.map_color("cindra-molten-rock")
  assert_true(lava[1] > lava[2] and lava[1] > lava[3], "lava reads red/orange (red channel dominates)")
  assert_true(margin[1] > margin[2] and margin[1] > margin[3], "the hot margin reads red")
  assert_true(lava[1] >= margin[1], "the lethal lava edge is at least as hot/bright as the hot margin")
  assert_true(ice[3] > ice[1], "deep-ice reads cold (blue channel over red)")
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
