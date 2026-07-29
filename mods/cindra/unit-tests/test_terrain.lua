-- Plain-Lua unit test for the ribbon TERRAIN bands (scripts/terrain.lua), the
-- per-zone gradient (ci-a35). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua turns the pure zone layout (scripts/zones.lua) into each Cindra
-- tile's `probability_expression` (a noise expression keyed to the perpendicular
-- axis, wiggled by basis_noise so boundaries are organic), classifies which tiles
-- are lethal (and how hard), and reports the finite map dimension (= the SUM of
-- every zone width). The factorio-test in tests/test_worldgen.lua proves the bands
-- actually generate in the right places on a live map.

package.path = package.path .. ";./?.lua;./?/init.lua"
local terrain = require("scripts.terrain")
local zones = require("scripts.zones")
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

test("every zone tile is registered, in hot->cold order (varied aquilo has variants)", function()
  local names = terrain.tile_names()
  local set = {}
  for _, n in ipairs(names) do set[n] = true end
  for _, n in ipairs({
    "cindra-hot-lava", "cindra-lava-field", "cindra-cracks-hot", "cindra-cracks-warm",
    "cindra-cracks-plain", "cindra-jagged", "cindra-dirt", "cindra-sand",
    "cindra-aquilo-dust-1", "cindra-aquilo-dust-2", "cindra-aquilo-dust-3",
    "cindra-rough-ice", "cindra-smooth-ice",
  }) do
    assert_true(set[n], "missing tile " .. n)
  end
  -- the old worldgen-v1 tiles are gone (snow-flat frost clone dropped, ci-a35).
  assert_true(not set["cindra-frost"], "the snow-flat frost clone is dropped")
  assert_true(not set["cindra-terminator"], "the old terminator tile is gone")
end)

test("only the three fire bands (heat) and smooth-ice (cold) are lethal", function()
  assert_eq("heat", terrain.lethal_kind("cindra-hot-lava"), "hot lava burns")
  assert_eq("heat", terrain.lethal_kind("cindra-lava-field"), "lava burns")
  assert_eq("heat", terrain.lethal_kind("cindra-cracks-hot"), "scorched cracks burn")
  assert_eq("cold", terrain.lethal_kind("cindra-smooth-ice"), "smooth ice freezes")
  for _, safe in ipairs({ "cindra-cracks-warm", "cindra-cracks-plain", "cindra-jagged",
                          "cindra-dirt", "cindra-sand", "cindra-aquilo-dust-1", "cindra-rough-ice" }) do
    assert_eq(nil, terrain.lethal_kind(safe), safe .. " is safe / walkable")
  end
  local lethal = terrain.lethal_tiles()
  local n = 0
  for _ in pairs(lethal) do n = n + 1 end
  assert_eq(4, n, "exactly four lethal tiles (3 fire + smooth ice)")
end)

test("fire damage RAMPS hottest at hot-lava; freeze is full; safe is zero", function()
  assert_eq(1.0, terrain.fire_intensity("cindra-hot-lava"), "hot lava is the hottest")
  assert_true(terrain.fire_intensity("cindra-lava-field") < terrain.fire_intensity("cindra-hot-lava"),
    "lava bites less than hot lava")
  assert_true(terrain.fire_intensity("cindra-cracks-hot") < terrain.fire_intensity("cindra-lava-field"),
    "scorched cracks bite least of the fire bands")
  assert_true(terrain.fire_intensity("cindra-cracks-hot") > 0, "but still bite")
  assert_eq(1.0, terrain.fire_intensity("cindra-smooth-ice"), "smooth ice freezes at full")
  assert_eq(0, terrain.fire_intensity("cindra-sand"), "sand does no damage")
end)

test("band expressions are noise-driven (tent + basis_noise), keyed to the axis", function()
  local hot = terrain.probability_expr("cindra-hot-lava")
  contains(hot, "min(", "a band is a tent (min of two edge distances)")
  contains(hot, "basis_noise", "the boundary is wiggled by smooth noise")
  contains(hot, axis.perp_expr(), "the band reads the perpendicular axis")
end)

test("the world is finite perpendicular via the map-gen: width = SUM of zone widths", function()
  local d = terrain.finite_dimension()
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  local total = 0
  for _, spec in ipairs(zones.SPEC) do total = total + spec.default end
  assert_eq(total, d.value, "the finite dimension is the sum of every zone width")
  assert_eq(360, d.value, "default sum: 80+40+30+20+10+10+10+100+20+20+20 = 360")
end)

test("hot-lava is pinned to the hot edge and always present (min width > 0)", function()
  local L = zones.layout()
  local hot = L.zones[1]
  assert_eq("hot-lava", hot.name, "hot lava is the first (hottest) band")
  assert_eq(L.hot_edge_p, hot.hi_p, "hot lava reaches the hot void edge")
  assert_true(hot.width >= 1, "hot lava is always at least 1 tile wide")
end)

test("the sand band is the spawn reference and the ice cliff sits rough/smooth", function()
  local L = zones.layout()
  -- the sand centre defines ref (temperate spawn).
  assert_eq(L.ref, (function()
    for _, z in ipairs(L.zones) do if z.name == "sand" then return z.center_p end end
  end)(), "ref is the sand-band centre")
  -- the cliff is on the rough-ice / smooth-ice boundary.
  local rough, smooth
  for _, z in ipairs(L.zones) do
    if z.name == "rough-ice" then rough = z elseif z.name == "smooth-ice" then smooth = z end
  end
  assert_eq(rough.lo_p, L.cliff_p, "cliff on the cold boundary of rough-ice")
  assert_eq(smooth.hi_p, L.cliff_p, "cliff on the hot boundary of smooth-ice")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
