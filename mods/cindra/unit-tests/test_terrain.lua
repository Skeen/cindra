-- Plain-Lua unit test for the ribbon TERRAIN zones (scripts/terrain.lua; ci-da2).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is the pure source of truth for the noise-driven left->right ribbon
-- gradient: the ordered 11-zone table (each zone a MIX of several tiles), each
-- zone's perpendicular band geometry (widths that SUM to the total ribbon width),
-- the per-tile probability expressions (a noise-wiggled plateau + interpolated
-- membership weight + speckle), walkability, the POSITIONAL damage bounds and the
-- finite map dimension. This proves that pure surface; the factorio-test in
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
local ZONE_ORDER = {
  "hot_lava", "lava_mix", "lava_crust", "volcanic_warm", "basalt", "scorched",
  "dry_dirt", "building", "cold_dust", "rough_ice", "deep_ice",
}

test("the eleven zones are ordered HOT -> COLD (ci-da2 definitive spec)", function()
  assert_eq(#ZONE_ORDER, #terrain.ZONES, "eleven ribbon zones")
  for i, role in ipairs(ZONE_ORDER) do
    assert_eq(role, terrain.ZONES[i].role, "zone " .. i .. " is " .. role)
  end
end)

test("each zone mixes its DEFINITIVE tile membership (spec zones 1-11)", function()
  -- Spot-check the spec's per-zone membership. zone_tiles returns cindra-* names.
  local function has(role, vanilla)
    return terrain.zone_tiles(role)["cindra-" .. vanilla] == true
  end
  -- 1 pure hot lava.
  assert_true(has("hot_lava", "lava-hot"), "zone 1 is hot lava")
  -- 2 hot-lava -> lava.
  assert_true(has("lava_mix", "lava-hot") and has("lava_mix", "lava"), "zone 2 mixes hot-lava + lava")
  -- 3 lava + cracks-hot, + some cracks-warm / smooth-stone-warm.
  for _, v in ipairs({ "lava", "volcanic-cracks-hot", "volcanic-cracks-warm", "volcanic-smooth-stone-warm" }) do
    assert_true(has("lava_crust", v), "zone 3 includes " .. v)
  end
  -- 4 cracks-warm -> cracks / smooth-stone / soil-dark.
  for _, v in ipairs({ "volcanic-cracks-warm", "volcanic-cracks", "volcanic-smooth-stone", "volcanic-soil-dark" }) do
    assert_true(has("volcanic_warm", v), "zone 4 includes " .. v)
  end
  -- 5 -> jagged / soil-light / ash-soil.
  for _, v in ipairs({ "volcanic-jagged-ground", "volcanic-soil-light", "volcanic-ash-soil" }) do
    assert_true(has("basalt", v), "zone 5 includes " .. v)
  end
  -- 6 -> grass-4 / dry-dirt / dirt-4..7.
  for _, v in ipairs({ "grass-4", "dry-dirt", "dirt-4", "dirt-5", "dirt-6", "dirt-7" }) do
    assert_true(has("scorched", v), "zone 6 includes " .. v)
  end
  -- 7 dirt -> sand: dirt-1..3, sand-1..3, red-desert-1..3.
  for _, v in ipairs({ "dirt-1", "dirt-2", "dirt-3", "sand-1", "sand-2", "sand-3",
                       "red-desert-1", "red-desert-2", "red-desert-3" }) do
    assert_true(has("dry_dirt", v), "zone 7 includes " .. v)
  end
  -- 8 building: sandy soils.
  for _, v in ipairs({ "sand-1", "sand-2", "sand-3" }) do
    assert_true(has("building", v), "zone 8 building includes " .. v)
  end
  -- 9 sand -> dust.
  for _, v in ipairs({ "dust-crests", "dust-flat", "dust-lumpy", "dust-patchy" }) do
    assert_true(has("cold_dust", v), "zone 9 includes " .. v)
  end
  -- 10 dust -> rough ice.
  assert_true(has("rough_ice", "ice-rough"), "zone 10 reaches rough ice")
  -- 11 smooth deep-ice cap.
  assert_true(has("deep_ice", "ice-smooth"), "zone 11 is the smooth-ice cap")
end)

test("all clone sources are real vanilla/space-age tile family names", function()
  -- The concrete tiles are cindra-<vanilla>; the count is the deduped membership.
  local names = terrain.tile_names()
  assert_eq(32, #names, "thirty-two deduped concrete tiles")
  assert_eq("cindra-lava-hot", names[1], "hottest tile is first (hot -> cold order)")
  assert_eq("cindra-ice-smooth", names[#names], "coldest tile is last")
end)

test("only the two lava tiles are impassable; every other tile is walkable ground", function()
  -- Spec: NOT WALKABLE = zones 1 + 2 (pure lava). Walkability is per TILE: only the
  -- lava tiles are impassable, which makes zones 1+2 the impassable wall.
  assert_eq(false, terrain.is_walkable("cindra-lava-hot"), "hot lava impassable")
  assert_eq(false, terrain.is_walkable("cindra-lava"), "lava impassable")
  for _, v in ipairs({ "volcanic-cracks-hot", "volcanic-cracks-warm", "sand-1",
                       "dust-flat", "ice-rough", "ice-smooth", "grass-4" }) do
    assert_eq(true, terrain.is_walkable("cindra-" .. v), "cindra-" .. v .. " is walkable ground")
  end
  assert_eq(nil, terrain.is_walkable("cindra-not-a-tile"), "unknown tile -> nil")
end)

test("zone-geometry damage bounds: heat over zones 1+2+3, cold over zone 11, middle safe", function()
  -- damage_bounds / lethal_at describe which BAND is heat/cold (worldgen geometry);
  -- ci-4jl moved the RUNTIME damage to per-tile intensity (terrain.tile_damage),
  -- but these positional descriptors remain and the worldgen tests still read them.
  local db = terrain.damage_bounds()
  assert_eq(300, db.hot_from, "heat band starts at the cold edge of zone 3 (lava-crust)")
  assert_eq(-200, db.cold_from, "cold band starts at the hot edge of zone 11 (deep-ice cap)")
  -- Zone centres (perp): 1..3 hot (425/375/325), 11 cold (-325); 4 (275), 10 (-175) safe.
  assert_eq("heat", terrain.lethal_at(425), "zone 1 burns")
  assert_eq("heat", terrain.lethal_at(325), "zone 3 (lava-crust) burns")
  assert_eq("cold", terrain.lethal_at(-325), "zone 11 (deep ice) freezes")
  assert_eq(nil, terrain.lethal_at(275), "zone 4 (volcanic-warm) is safe")
  assert_eq(nil, terrain.lethal_at(-175), "zone 10 (rough ice) is safe")
  assert_eq(nil, terrain.lethal_at(0), "the building centre is safe")
end)

test("per-tile damage: intensity RAMPS by tile, safe tiles are 0 (ci-4jl)", function()
  -- Spec: HEAT ramp hot-lava(max) > lava > cracks-hot > warm crust; COLD ramp
  -- smooth-ice(max) > rough-ice; every other tile is 0. Keyed to the ACTUAL tile
  -- under an entity, so the depth ramp emerges from the noisy zone mixes and a
  -- machine overlapping a lava tile burns (scripts/tile-damage.lua reads this).
  local function intensity(name)
    local i = select(1, terrain.tile_damage(name))
    return i
  end
  local function kind(name)
    return select(2, terrain.tile_damage(name))
  end

  -- HEAT ramp is strictly monotonic and peaks at 1.0.
  assert_eq(1.0, intensity("cindra-lava-hot"), "hot-lava is the peak heat (1.0)")
  assert_eq("heat", kind("cindra-lava-hot"), "hot-lava is heat")
  assert_true(intensity("cindra-lava-hot") > intensity("cindra-lava"), "hot-lava > lava")
  assert_true(intensity("cindra-lava") > intensity("cindra-volcanic-cracks-hot"), "lava > cracks-hot")
  assert_true(intensity("cindra-volcanic-cracks-hot") > intensity("cindra-volcanic-cracks-warm"),
    "cracks-hot > warm crust")
  assert_true(intensity("cindra-volcanic-cracks-warm") > 0, "warm crust still burns a little")
  assert_eq("heat", kind("cindra-volcanic-cracks-warm"), "warm crust is heat")
  -- The warm smooth-stone member matches the warm crust (both are the low rung).
  assert_eq(intensity("cindra-volcanic-cracks-warm"),
    intensity("cindra-volcanic-smooth-stone-warm"), "warm members share the low intensity")

  -- COLD ramp peaks at the smooth-ice cap.
  assert_eq(1.0, intensity("cindra-ice-smooth"), "smooth-ice is the peak cold (1.0)")
  assert_eq("cold", kind("cindra-ice-smooth"), "smooth-ice is cold")
  assert_true(intensity("cindra-ice-smooth") > intensity("cindra-ice-rough"), "smooth-ice > rough-ice")
  assert_true(intensity("cindra-ice-rough") > 0, "rough ice freezes a little")

  -- Safe / unknown tiles deal nothing.
  assert_eq(0, intensity("cindra-sand-1"), "the building sand is safe")
  assert_eq(nil, kind("cindra-sand-1"), "safe tiles have no damage kind")
  assert_eq(0, intensity("cindra-volcanic-cracks"), "the safe volcanic-warm member is safe")
  assert_eq(0, intensity("cindra-not-a-tile"), "unknown tile -> 0")
  assert_eq(nil, kind("cindra-not-a-tile"), "unknown tile -> no kind")
end)

test("every tile has a map_color: reds sunward, cyan nightward, neutral building", function()
  local function dist(a, b)
    return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3])
  end
  for _, name in ipairs(terrain.tile_names()) do
    local c = terrain.map_color(name)
    assert_true(c ~= nil, name .. " has a map_color")
    assert_eq(3, #c, name .. " map_color is {r,g,b}")
  end
  assert_true(terrain.map_color("cindra-not-a-tile") == nil, "unknown tiles have no map_color")
  local lava = terrain.map_color("cindra-lava-hot")
  local ice = terrain.map_color("cindra-ice-smooth")
  local center = terrain.map_color("cindra-sand-1") -- a building-band tile
  assert_true(lava[1] > lava[2] and lava[1] > lava[3], "hot lava reads red/orange")
  assert_true(ice[3] > ice[1], "deep ice reads cold (blue over red)")
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
  for i, z in ipairs(terrain.ZONES) do if z.role == "building" then bi = i end end
  assert_eq(-100, bands[bi].lo, "building band cold edge")
  assert_eq(100, bands[bi].hi, "building band hot edge at p=100")
  assert_true(bands[bi].lo < 0 and bands[bi].hi > 0, "spawn (p=0) is inside the building band")
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
  local cfg = { building = 400 } -- widen the building area by 200
  local bands, total = terrain.bands(cfg)
  assert_eq(base_total + 200, total, "total grew by exactly the delta (world width = sum)")
  local function width(b) return b.hi - b.lo end
  assert_eq(width(base_bands[1]), width(bands[1]), "hot-lava keeps its width")
  local bi
  for i, z in ipairs(terrain.ZONES) do if z.role == "building" then bi = i end end
  assert_eq(400, width(bands[bi]), "the building band took the new width")
end)

test("resource_bounds splits stone (hot) from ice (cold) at the building's cold edge", function()
  local rb = terrain.resource_bounds()
  assert_eq(100, rb.building_half, "the safe building half-width")
  assert_eq(-100, rb.building_lo, "the stone/ice divider is the building's cold edge")
  assert_eq(350, rb.hot_edge, "stone reaches the outer walkable hot zone (lava-crust), not the lava wall")
  assert_eq(-450, rb.cold_edge, "ice reaches the cold cap edge")
end)

test("the volcanic cliff band spans the rocky zones (lava-crust .. scorched)", function()
  local cb = terrain.cliff_band()
  assert_eq(150, cb.lo, "cliff band cold edge = scorched zone lo")
  assert_eq(350, cb.hi, "cliff band hot edge = lava-crust zone hi")
end)

test("a temperate tile's probability_expr is a noise-wiggled plateau + weight + speckle", function()
  local expr = terrain.probability_expr("cindra-sand-1")
  contains(expr, "max(0,", "the plateau falls off via max(0, ...)")
  contains(expr, "basis_noise", "the boundary + speckle are basis_noise")
  contains(expr, axis.perp_expr(), "keyed to the perpendicular axis")
  contains(expr, "min(1, max(0,", "the membership weight uses a clamped fraction")
  -- A tile that mixes into several zones has several max() terms.
  assert_true(expr:find("max(", 1, true) ~= nil, "a multi-zone tile takes the max over its bands")
  local ok = pcall(function() terrain.probability_expr("not-a-tile") end)
  assert_true(not ok, "an unknown tile errors")
end)

test("the HOT RING order is core -> outer, contiguous elevation bands (ci-cwk)", function()
  -- lava is the peak; descend the elevation field out through the rings.
  local order = {}
  for _, r in ipairs(terrain.HOT_RING_ORDER) do order[#order + 1] = r.vanilla end
  assert_eq("lava-hot", order[1], "the molten core is the highest ring")
  assert_eq("lava", order[2], "lava is the pool body")
  assert_eq("volcanic-cracks-hot", order[3], "cracks-hot is the boundary RING around lava")
  assert_eq("volcanic-smooth-stone-warm", order[#order], "warm smooth stone is the outermost ring")
  -- Thresholds strictly descend, so equal-elevation contours nest as concentric rings.
  for i = 2, #terrain.HOT_RING_ORDER do
    assert_true(terrain.HOT_RING_ORDER[i].lo < terrain.HOT_RING_ORDER[i - 1].lo,
      "ring " .. i .. " sits at a lower elevation than the one inside it")
  end
end)

test("ring_tile_at maps an elevation to its ring tile (lava core down to warm crust)", function()
  -- High elevation = the lava core; descending elevation walks outward through the rings.
  assert_eq("cindra-lava-hot", terrain.ring_tile_at(200), "the peak is the molten core")
  assert_eq("cindra-lava-hot", terrain.ring_tile_at(140), "at the core threshold => lava-hot")
  assert_eq("cindra-lava", terrain.ring_tile_at(110), "just below the core => lava body")
  assert_eq("cindra-volcanic-cracks-hot", terrain.ring_tile_at(60), "the boundary RING is cracks-hot")
  assert_eq("cindra-volcanic-cracks-warm", terrain.ring_tile_at(30), "outside the ring => warm cracks")
  assert_eq("cindra-volcanic-smooth-stone-warm", terrain.ring_tile_at(-50), "far out => smooth warm crust")
end)

test("a hot tile's probability_expr is a heightmap ring term (not a flat sub-band)", function()
  -- The hot region [300, 450] is driven by the lava heightmap: a steep hot_gate that
  -- confines the tile to the hot region + a ring selector on the elevation field.
  local hot = terrain.probability_expr("cindra-lava-hot")
  contains(hot, "max(0,", "the gate + ring selector fall off via max(0, ...)")
  contains(hot, axis.perp_expr(), "the gate is keyed to the perpendicular axis")
  contains(hot, "300", "the hot region's temperate (inner) edge")
  contains(hot, "450", "the hot region's sunward (outer) edge")
  contains(hot, "140", "the lava-core elevation threshold")
  contains(hot, "seed1 = 42", "the elevation field is the lava heightmap noise (seed 42)")
  -- lava-hot lives ONLY in the hot region, so it has no perpendicular sub-band edge
  -- at 400 anymore (the old flat-band inner edge); the layout is purely ring-based.
  assert_true(hot:find("400", 1, true) == nil, "no leftover flat sub-band inner edge (400)")
  -- cracks-warm is BOTH a hot-region ring AND a temperate (zone 4) member, so it has a
  -- ring term (heightmap) AND a flat perp-band weight term.
  local warm = terrain.probability_expr("cindra-volcanic-cracks-warm")
  contains(warm, "seed1 = 42", "cracks-warm carries the hot ring term")
  contains(warm, "min(1, max(0,", "cracks-warm also carries its temperate flat-band weight")
end)

test("the world is finite perpendicular via the map-gen = the total width", function()
  local d = terrain.finite_dimension()
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  assert_eq(900, d.value, "the finite dimension is the total ribbon width (sum of zones)")
  assert_eq(1100, terrain.finite_dimension({ building = 400 }).value, "tracks the widths")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
