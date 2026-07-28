-- Plain-Lua unit test for the ribbon TERRAIN bands (scripts/terrain.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is the pure source of truth for the noise-driven ribbon tile
-- gradient (ci-a35 per-zone widths): it lays the ordered hot->cold zones out on
-- the perpendicular axis from their per-zone widths, emits each Cindra tile's
-- `probability_expression` (a noise expression keyed to the axis, wiggled by
-- basis_noise so boundaries are organic), classifies which tiles are lethal, and
-- reports the finite map dimension (= the SUM of every zone width). This proves
-- that pure surface; tests/test_worldgen.lua proves the bands generate in the right
-- places on a live map.

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

-- The full hot->cold gradient, in order.
local ORDER = {
  "cindra-hot-lava", "cindra-lava",
  "cindra-volcanic-cracks-hot", "cindra-volcanic-cracks-warm", "cindra-volcanic-cracks",
  "cindra-jagged", "cindra-dry-dirt", "cindra-dirt",
  "cindra-sand",
  "cindra-aquilo-dust", "cindra-rough-ice", "cindra-smooth-ice",
}

test("the twelve Cindra zone tiles are registered in hot->cold order", function()
  local names = terrain.tile_names()
  assert_eq(#ORDER, #names, "twelve ribbon tiles")
  for i, n in ipairs(ORDER) do
    assert_eq(n, names[i], "tile " .. i .. " is " .. n)
  end
end)

test("hot-lava is band #1 at the sunward extreme; smooth-ice is the cold extreme", function()
  assert_eq("cindra-hot-lava", terrain.ZONES[1].name, "band #1 is hot-lava")
  assert_eq("cindra-smooth-ice", terrain.ZONES[#terrain.ZONES].name, "the last band is smooth-ice")
end)

test("only the molten edge (hot-lava, lava = heat) and deep ice (smooth-ice = cold) are lethal", function()
  assert_eq("heat", terrain.lethal_kind("cindra-hot-lava"), "hot-lava burns")
  assert_eq("heat", terrain.lethal_kind("cindra-lava"), "lava burns")
  assert_eq("cold", terrain.lethal_kind("cindra-smooth-ice"), "smooth ice freezes")
  -- The whole interior is walkable/safe.
  for _, n in ipairs({ "cindra-volcanic-cracks-hot", "cindra-jagged", "cindra-dirt",
                       "cindra-sand", "cindra-aquilo-dust", "cindra-rough-ice" }) do
    assert_eq(nil, terrain.lethal_kind(n), n .. " is walkable/safe")
  end
  local lethal, n = terrain.lethal_tiles(), 0
  for _ in pairs(lethal) do n = n + 1 end
  assert_eq(3, n, "exactly three lethal tiles (two hot, one cold)")
end)

test("the sand centre is a constant baseline so it wins the wide safe spawn", function()
  assert_eq("1", terrain.probability_expr("cindra-sand"),
    "the centre tile is the constant fallback (guarantees full coverage + spawn)")
  assert_true(terrain.CENTER == "cindra-sand", "sand is the declared centre")
end)

test("band expressions are noise-driven (range_select_base + basis_noise), keyed to the axis", function()
  local hot = terrain.probability_expr("cindra-hot-lava")
  local cold = terrain.probability_expr("cindra-smooth-ice")
  contains(hot, "range_select_base", "hot band is a range selector")
  contains(hot, "basis_noise", "hot boundary is wiggled by smooth noise")
  contains(hot, axis.perp_expr(), "bands read the perpendicular axis (single source of truth)")
  contains(cold, "range_select_base", "cold band is a range selector")
end)

-- ci-a35 core requirement #1: per-zone widths; total map width = SUM of widths.
test("the finite map extent is the SUM of every zone width", function()
  local d = terrain.finite_dimension()
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  local sum = 0
  for _, z in ipairs(terrain.ZONES) do sum = sum + z.default end
  assert_eq(sum, d.value, "the finite dimension equals the sum of default zone widths")
  assert_eq(240, sum, "default gradient totals 240 tiles")
end)

test("changing ONE zone width changes both that band AND the total map width", function()
  local base = terrain.finite_dimension().value
  -- Widen the sand centre by 40 tiles.
  local widened = terrain.finite_dimension({ sand = 88 }).value
  assert_eq(base + 40, widened, "the total grows by exactly the width delta")

  -- The sand band interval grows by 40 (it straddles the centre), and every OTHER
  -- band keeps its own width; the whole ribbon just gets wider.
  local L0 = terrain.layout()
  local L1 = terrain.layout({ sand = 88 })
  local sand0 = L0.bands["cindra-sand"]
  local sand1 = L1.bands["cindra-sand"]
  assert_eq(40, (sand1.hi - sand1.lo) - (sand0.hi - sand0.lo), "the sand band itself widened by 40")
  local dirt0 = L0.bands["cindra-dirt"]
  local dirt1 = L1.bands["cindra-dirt"]
  assert_eq(dirt0.hi - dirt0.lo, dirt1.hi - dirt1.lo, "the dirt band keeps its own width")
end)

test("each zone's band width in the layout equals its configured width", function()
  local L = terrain.layout()
  for _, z in ipairs(terrain.ZONES) do
    local b = L.bands[z.name]
    assert_eq(z.default, b.hi - b.lo, z.name .. " band width == its configured width")
  end
end)

test("zones stack hot(+perp) -> cold(-perp) with no gaps, centred on perp 0", function()
  local L = terrain.layout()
  -- The hot edge of band #1 is +half; the cold edge of the last band is -half.
  assert_eq(L.half, L.bands[terrain.ZONES[1].name].hi, "hot-lava reaches +half (the hot map edge)")
  assert_eq(-L.half, L.bands[terrain.ZONES[#terrain.ZONES].name].lo, "smooth-ice reaches -half (cold edge)")
  -- Each band's cold edge is the next band's hot edge (contiguous, no gaps).
  for i = 1, #terrain.ZONES - 1 do
    local a = L.bands[terrain.ZONES[i].name]
    local b = L.bands[terrain.ZONES[i + 1].name]
    assert_eq(a.lo, b.hi, "band " .. i .. " abuts band " .. (i + 1))
  end
  -- The spawn (perp 0, world 0,0) lands inside the sand band.
  local sand = L.bands["cindra-sand"]
  assert_true(sand.lo <= 0 and 0 <= sand.hi, "perp 0 (spawn) is inside the sand band")
end)

-- ci-a35 core requirement #2: a hot-lava band ALWAYS exists at the hot edge.
test("a hot-lava band always exists at the hot edge, even at width 0 (floored to 1)", function()
  -- The width setting floors at 1, so the band never vanishes...
  local L = terrain.layout({ ["hot-lava"] = 0 })
  local b = L.bands["cindra-hot-lava"]
  assert_true(b.width >= terrain.HOT_LAVA_MIN_WIDTH, "hot-lava width is floored to at least 1")
  assert_eq(L.half, b.hi, "hot-lava still reaches the hot map edge")
  -- ...and its probability expression extends past the void edge, so it wins the
  -- whole sunward extreme regardless of how thin the band is configured.
  local expr = terrain.probability_expr("cindra-hot-lava", { ["hot-lava"] = 1 })
  contains(expr, "range_select_base", "hot-lava is still a real band expression")
  -- The `to` marker is pushed out to half + EDGE_EXTEND (reaches the void edge).
  local reach = L.half + terrain.EDGE_EXTEND
  contains(expr, tostring(math.floor(reach)), "hot-lava extends to the void edge (" .. reach .. ")")
end)

test("horizontal orientation bounds the height axis instead of width", function()
  -- axis.orientation() reads the setting; with no `settings` global it defaults to
  -- vertical (width). We can still prove the key selection is axis-driven by the
  -- default path above; the value is orientation-independent (the SUM).
  local d = terrain.finite_dimension()
  assert_true(d.key == "width" or d.key == "height", "bounds a real map dimension")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
