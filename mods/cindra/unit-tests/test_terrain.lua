-- Plain-Lua unit test for the ribbon TERRAIN zones (scripts/terrain.lua; ci-da2).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is the pure source of truth for the noise-driven left->right ribbon
-- gradient: the ordered zone table, each zone's perpendicular band geometry (widths
-- that SUM to the total ribbon width), the tile probability expressions (a noise-
-- wiggled plateau per band), walkability + lethality flags, and the finite map
-- dimension. This proves that pure surface; the factorio-test in
-- tests/test_worldgen.lua proves the zones actually generate on a live map.

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

-- The definitive zone order, HOT (west) -> COLD (east) (ci-da2).
local ORDER = {
  "cindra-hot-lava", "cindra-lava", "cindra-lava-crust", "cindra-volcanic-warm",
  "cindra-basalt", "cindra-scorched-dirt", "cindra-dry-sand", "cindra-terminator",
  "cindra-cold-dust", "cindra-rough-ice", "cindra-deep-ice",
}

test("all eleven Cindra zone tiles are registered, HOT -> COLD in order", function()
  local names = terrain.tile_names()
  assert_eq(#ORDER, #names, "eleven ribbon zone tiles")
  for i, want in ipairs(ORDER) do
    assert_eq(want, names[i], "zone " .. i .. " is " .. want)
  end
end)

test("damage tiles are the three hot (heat) + deep-ice (cold); the middle is safe", function()
  -- Spec: DAMAGE TILES are zones 1+2+3 (hot-lava/lava/lava-crust) + zone 11 (deep-ice).
  assert_eq("heat", terrain.lethal_kind("cindra-hot-lava"), "hot-lava burns")
  assert_eq("heat", terrain.lethal_kind("cindra-lava"), "lava burns")
  assert_eq("heat", terrain.lethal_kind("cindra-lava-crust"), "lava-crust burns")
  assert_eq("cold", terrain.lethal_kind("cindra-deep-ice"), "deep-ice freezes")
  for _, safe in ipairs({ "cindra-volcanic-warm", "cindra-basalt", "cindra-scorched-dirt",
                          "cindra-dry-sand", "cindra-terminator", "cindra-cold-dust",
                          "cindra-rough-ice" }) do
    assert_eq(nil, terrain.lethal_kind(safe), safe .. " is safe")
  end
  local lethal, n = terrain.lethal_tiles(), 0
  for _ in pairs(lethal) do n = n + 1 end
  assert_eq(4, n, "exactly four lethal tiles")
end)

test("only the two hot lava zones are impassable; every other zone is walkable", function()
  -- Spec: NOT WALKABLE = zones 1 + 2 (hot-lava, lava), impassable like Vulcanus lava.
  assert_eq(false, terrain.is_walkable("cindra-hot-lava"), "hot-lava impassable")
  assert_eq(false, terrain.is_walkable("cindra-lava"), "lava impassable")
  for _, walk in ipairs({ "cindra-lava-crust", "cindra-volcanic-warm", "cindra-basalt",
                          "cindra-scorched-dirt", "cindra-dry-sand", "cindra-terminator",
                          "cindra-cold-dust", "cindra-rough-ice", "cindra-deep-ice" }) do
    assert_eq(true, terrain.is_walkable(walk), walk .. " is walkable ground")
  end
end)

test("every zone has a map_color: reds sunward, cyan nightward, neutral building", function()
  local function dist(a, b)
    return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3])
  end
  for _, name in ipairs(ORDER) do
    local c = terrain.map_color(name)
    assert_true(c ~= nil, name .. " has a map_color")
    assert_eq(3, #c, name .. " map_color is {r,g,b}")
  end
  assert_true(terrain.map_color("unknown-tile") == nil, "unknown tiles have no map_color")
  local lava = terrain.map_color("cindra-hot-lava")
  local ice = terrain.map_color("cindra-deep-ice")
  local center = terrain.map_color("cindra-terminator")
  assert_true(lava[1] > lava[2] and lava[1] > lava[3], "hot-lava reads red/orange")
  assert_true(ice[3] > ice[1], "deep-ice reads cold (blue over red)")
  assert_true(dist(lava, center) > 0.6, "the hot edge is distinct from the safe centre")
  assert_true(dist(ice, center) > 0.6, "the cold edge is distinct from the safe centre")
end)

test("the total ribbon width is the SUM of the zone widths (default 900)", function()
  local bands, total = terrain.bands()
  local sum = 0
  for _, z in ipairs(terrain.ZONES) do sum = sum + z.width end
  assert_eq(sum, total, "total = sum of zone widths")
  assert_eq(900, total, "default total is 900 (7x50 + 200 + 2x50 + 250)")
  assert_eq(#terrain.ZONES, #bands, "one band per zone")
end)

test("the gradient is centred on the origin: building band straddles spawn", function()
  local bands = terrain.bands()
  local bi
  for i, z in ipairs(terrain.ZONES) do if z.role == "terminator" then bi = i end end
  assert_eq(-100, bands[bi].lo, "building band cold (west-perp) edge")
  assert_eq(100, bands[bi].hi, "building band hot-perp edge at p=100")
  assert_true(bands[bi].lo < 0 and bands[bi].hi > 0, "spawn (p=0) is inside the building band")
  -- Hot-lava is the outermost (highest p) band; deep-ice the outermost cold.
  assert_eq(450, bands[1].hi, "hot-lava reaches the sunward map edge (p = +total/2)")
  assert_eq(-450, bands[#bands].lo, "deep-ice reaches the nightward map edge (p = -total/2)")
end)

test("bands are contiguous, ordered high->low perpendicular (no gaps, no overlap)", function()
  local bands = terrain.bands()
  for i = 1, #bands do
    assert_true(bands[i].lo < bands[i].hi, "band " .. i .. " has positive width")
    if i > 1 then
      assert_eq(bands[i - 1].lo, bands[i].hi, "band " .. i .. " abuts the previous band exactly")
    end
  end
end)

test("changing one zone width changes only that band + the total, never the rest", function()
  local base_bands, base_total = terrain.bands()
  local cfg = { terminator = 400 } -- widen the building area by 200
  local bands, total = terrain.bands(cfg)
  assert_eq(base_total + 200, total, "total grew by exactly the delta (world width = sum)")
  local function width(b) return b.hi - b.lo end
  assert_eq(width(base_bands[1]), width(bands[1]), "hot-lava keeps its width")
  local bi
  for i, z in ipairs(terrain.ZONES) do if z.role == "terminator" then bi = i end end
  assert_eq(400, width(bands[bi]), "the building band took the new width")
end)

test("resource_bounds splits stone (hot) from ice (cold) at the building's cold edge", function()
  local rb = terrain.resource_bounds()
  assert_eq(100, rb.building_half, "the safe building half-width")
  assert_eq(-100, rb.building_lo, "the stone/ice divider is the building's cold edge")
  assert_eq(350, rb.hot_edge, "stone reaches the outer walkable hot zone (lava-crust), not the impassable lava")
  assert_eq(-450, rb.cold_edge, "ice reaches the cold cap edge")
end)

test("each zone's probability_expr is a noise-wiggled plateau keyed to the axis", function()
  local expr = terrain.probability_expr("cindra-terminator")
  contains(expr, "max(0,", "the plateau falls off via max(0, ...)")
  contains(expr, "basis_noise", "the boundary is wiggled by smooth noise")
  contains(expr, axis.perp_expr(), "keyed to the perpendicular axis")
  contains(expr, "-100", "the band's cold edge appears")
  contains(expr, "100", "the band's hot edge appears")
  local hot = terrain.probability_expr("cindra-hot-lava")
  contains(hot, "400", "hot-lava band inner edge")
  contains(hot, "450", "hot-lava band outer edge")
  local ok = pcall(function() terrain.probability_expr("not-a-tile") end)
  assert_true(not ok, "an unknown tile errors")
end)

test("the world is finite perpendicular via the map-gen = the total width", function()
  local d = terrain.finite_dimension()
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  assert_eq(900, d.value, "the finite dimension is the total ribbon width (sum of zones)")
  assert_eq(1100, terrain.finite_dimension({ terminator = 400 }).value, "tracks the widths")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
