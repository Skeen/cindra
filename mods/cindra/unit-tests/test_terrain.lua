-- Plain-Lua unit test for the ribbon TERRAIN (scripts/terrain.lua; ci-wly rebuild).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is the pure source of truth for the THREE-PART, TWO-HEIGHTMAP planet:
-- HOT side (ocean + damaging heightmap inner slope + flat cool outer slope), HABITABLE
-- MIDDLE (ash mix + soil patches), COLD side (mirror). This proves the pure surface: the
-- zone table, band geometry (widths that SUM), the ring orders + bands, the flat-zone
-- membership, the per-tile probability expressions, walkability, the no-pave set, the
-- per-tile damage table, and the positional bounds. tests/test_worldgen.lua proves it
-- actually generates on a map.

package.path = package.path .. ";./?.lua;./?/init.lua"
local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1; print("ok - " .. name)
  else failed = failed + 1; print("not ok - " .. name .. ": " .. tostring(err)) end
end
local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end
local function assert_true(x, msg) if not x then error(msg or "expected true", 2) end end
local function contains(haystack, needle, msg)
  assert_true(haystack:find(needle, 1, true) ~= nil,
    (msg or "expected substring") .. " '" .. needle .. "' in: " .. haystack)
end

local ZONE_ORDER = { "hot_ocean", "hot_inner", "hot_outer", "middle", "cold_outer", "cold_inner", "cold_ocean" }

test("the seven zones are ordered HOT -> MIDDLE -> COLD (ci-wly)", function()
  assert_eq(#ZONE_ORDER, #terrain.ZONES, "seven ribbon zones")
  for i, role in ipairs(ZONE_ORDER) do assert_eq(role, terrain.ZONES[i].role, "zone " .. i .. " is " .. role) end
  local oceans, hot_ocean_wall = 0, false
  for _, z in ipairs(terrain.ZONES) do
    if z.ocean then oceans = oceans + 1 end
    if z.role == "hot_ocean" then hot_ocean_wall = z.wall == true end
  end
  assert_eq(2, oceans, "two oceans (one per side)")
  assert_true(hot_ocean_wall, "the hot-lava ocean is the impassable wall")
end)

test("the hot heightmap descends lava-core -> cracks-warm (the damaging rings, ci-wly)", function()
  local EXPECTED = { "lava-hot", "lava", "volcanic-smooth-stone-warm", "volcanic-cracks-hot", "volcanic-cracks-warm" }
  assert_eq(#EXPECTED, #terrain.HOT_RING_ORDER, "five hot rings")
  for i, v in ipairs(EXPECTED) do assert_eq(v, terrain.HOT_RING_ORDER[i].vanilla, "hot ring " .. i .. " is " .. v) end
  for i = 2, #terrain.HOT_RING_ORDER do
    assert_true(terrain.HOT_RING_ORDER[i].lo < terrain.HOT_RING_ORDER[i - 1].lo, "hot ring " .. i .. " is lower")
  end
end)

test("the cold heightmap descends ice-core -> snow-flat (the damaging + snow rings, ci-wly)", function()
  local EXPECTED = { "ice-smooth", "ice-rough", "snow-patchy", "snow-lumpy", "snow-crests", "snow-flat" }
  assert_eq(#EXPECTED, #terrain.COLD_RING_ORDER, "six cold rings")
  for i, v in ipairs(EXPECTED) do assert_eq(v, terrain.COLD_RING_ORDER[i].vanilla, "cold ring " .. i .. " is " .. v) end
  for i = 2, #terrain.COLD_RING_ORDER do
    assert_true(terrain.COLD_RING_ORDER[i].lo < terrain.COLD_RING_ORDER[i - 1].lo, "cold ring " .. i .. " is lower")
  end
end)

test("each zone's membership is the tiles that can paint its band", function()
  local function has(role, vanilla) return terrain.zone_tiles(role)["cindra-" .. vanilla] == true end
  -- Hot heightmap zones expose the hot ring set.
  for _, role in ipairs({ "hot_ocean", "hot_inner" }) do
    assert_true(has(role, "lava-hot"), role .. " includes the lava core")
    assert_true(has(role, "volcanic-cracks-warm"), role .. " reaches the outer cracks-warm ring")
  end
  -- The flat hot outer slope: cool tiles blending to ash-dark.
  for _, v in ipairs({ "volcanic-cracks-warm", "volcanic-cracks", "volcanic-smooth-stone", "volcanic-ash-dark" }) do
    assert_true(has("hot_outer", v), "hot_outer includes " .. v)
  end
  -- Middle: the ash mix + soil.
  for _, v in ipairs({ "volcanic-ash-dark", "volcanic-ash-light", "volcanic-ash-flats",
                       "volcanic-ash-soil", "volcanic-soil-light", "volcanic-soil-dark" }) do
    assert_true(has("middle", v), "middle includes " .. v)
  end
  -- The flat cold outer slope: dust tiles blending to ash-light.
  for _, v in ipairs({ "volcanic-ash-light", "dust-flat", "dust-crests", "dust-lumpy", "dust-patchy" }) do
    assert_true(has("cold_outer", v), "cold_outer includes " .. v)
  end
  -- Cold heightmap zones expose the cold ring set.
  for _, role in ipairs({ "cold_ocean", "cold_inner" }) do
    assert_true(has(role, "ice-smooth"), role .. " includes the ice core")
    assert_true(has(role, "snow-flat"), role .. " reaches the outer snow-flat ring")
  end
end)

test("all clone sources are real vanilla/space-age tile family names", function()
  local names = terrain.tile_names()
  assert_eq(23, #names, "twenty-three deduped concrete tiles")
  assert_eq("cindra-lava-hot", names[1], "hottest tile is first (hot -> cold order)")
  assert_eq("cindra-ice-smooth", names[#names], "coldest tile (ice ocean) is last")
end)

test("only the two lava tiles are impassable; smooth-ice is now WALKABLE (ci-wly)", function()
  assert_eq(false, terrain.is_walkable("cindra-lava-hot"), "hot lava impassable")
  assert_eq(false, terrain.is_walkable("cindra-lava"), "lava impassable")
  assert_eq(true, terrain.is_walkable("cindra-ice-smooth"), "smooth-ice is walkable now")
  for _, v in ipairs({ "volcanic-cracks-hot", "volcanic-cracks-warm", "volcanic-ash-flats",
                       "dust-flat", "ice-rough", "snow-flat" }) do
    assert_eq(true, terrain.is_walkable("cindra-" .. v), "cindra-" .. v .. " is walkable ground")
  end
  assert_eq(nil, terrain.is_walkable("cindra-not-a-tile"), "unknown tile -> nil")
end)

test("the NO-PAVE hazard set is the hottest + iciest tiles (ci-wly)", function()
  for _, v in ipairs({ "lava-hot", "lava", "volcanic-smooth-stone-warm", "volcanic-cracks-hot",
                       "ice-smooth", "ice-rough" }) do
    assert_true(terrain.is_no_pave("cindra-" .. v), "cindra-" .. v .. " is no-pave")
  end
  for _, v in ipairs({ "volcanic-ash-flats", "volcanic-cracks", "dust-flat", "snow-flat" }) do
    assert_eq(false, terrain.is_no_pave("cindra-" .. v), "cindra-" .. v .. " is pavable ground")
  end
  assert_eq(false, terrain.is_no_pave("cindra-not-a-tile"), "unknown tile -> false")
end)

test("per-tile damage: heat + cold ramps scale with depth, safe tiles are 0 (ci-4jl/ci-wly)", function()
  local function intensity(name) return (select(1, terrain.tile_damage(name))) end
  local function kind(name) return (select(2, terrain.tile_damage(name))) end
  assert_eq(1.0, intensity("cindra-lava-hot"), "hot-lava is the peak heat (1.0)")
  assert_eq("heat", kind("cindra-lava-hot"), "hot-lava is heat")
  assert_true(intensity("cindra-lava-hot") > intensity("cindra-lava"), "hot-lava > lava")
  assert_true(intensity("cindra-lava") > intensity("cindra-volcanic-smooth-stone-warm"), "lava > smooth-stone-warm")
  assert_true(intensity("cindra-volcanic-smooth-stone-warm") > intensity("cindra-volcanic-cracks-hot"),
    "smooth-stone-warm > cracks-hot")
  assert_true(intensity("cindra-volcanic-cracks-hot") > intensity("cindra-volcanic-cracks-warm"), "cracks-hot > warm cracks")
  assert_true(intensity("cindra-volcanic-cracks-warm") > 0, "warm cracks still burn a little")
  assert_eq(1.0, intensity("cindra-ice-smooth"), "smooth-ice is the peak cold (1.0)")
  assert_eq("cold", kind("cindra-ice-smooth"), "smooth-ice is cold")
  assert_true(intensity("cindra-ice-smooth") > intensity("cindra-ice-rough"), "smooth-ice > rough-ice")
  assert_true(intensity("cindra-ice-rough") > intensity("cindra-snow-patchy"), "rough-ice > snow-patchy")
  assert_true(intensity("cindra-snow-patchy") > 0, "the deepest snow ring freezes a little")
  assert_eq(0, intensity("cindra-volcanic-ash-flats"), "the middle ash is safe")
  assert_eq(nil, kind("cindra-volcanic-ash-flats"), "safe tiles have no damage kind")
  assert_eq(0, intensity("cindra-volcanic-cracks"), "the cool volcanic cracks are safe")
  assert_eq(0, intensity("cindra-dust-flat"), "the cool dust is safe")
  assert_eq(0, intensity("cindra-not-a-tile"), "unknown tile -> 0")
end)

test("every tile has a map_color: reds sunward, cyan nightward, dark ash middle", function()
  for _, name in ipairs(terrain.tile_names()) do
    local c = terrain.map_color(name)
    assert_true(c ~= nil, name .. " has a map_color")
    assert_eq(3, #c, name .. " map_color is {r,g,b}")
  end
  assert_true(terrain.map_color("cindra-not-a-tile") == nil, "unknown tiles have no map_color")
  local function dist(a, b) return math.abs(a[1]-b[1]) + math.abs(a[2]-b[2]) + math.abs(a[3]-b[3]) end
  local lava = terrain.map_color("cindra-lava-hot")
  local ice = terrain.map_color("cindra-ice-smooth")
  local center = terrain.map_color("cindra-volcanic-ash-flats")
  assert_true(lava[1] > lava[2] and lava[1] > lava[3], "hot lava reads red/orange")
  assert_true(ice[3] > ice[1], "deep ice reads cold (blue over red)")
  assert_true(dist(lava, center) > 0.5, "the hot edge is distinct from the middle")
  assert_true(dist(ice, center) > 0.4, "the cold edge is distinct from the middle")
end)

test("the total ribbon width is the SUM of the zone widths (default 800, ci-wly)", function()
  local bands, total = terrain.bands()
  local sum = 0
  for _, z in ipairs(terrain.ZONES) do sum = sum + z.width end
  assert_eq(sum, total, "total = sum of zone widths")
  assert_eq(800, total, "default total is 800 (200+70+70+120+70+70+200)")
  assert_eq(#terrain.ZONES, #bands, "one band per zone")
end)

test("the gradient is centred on the origin: the middle straddles spawn", function()
  local bands = terrain.bands()
  local bi
  for i, z in ipairs(terrain.ZONES) do if z.role == "middle" then bi = i end end
  assert_eq(-60, bands[bi].lo, "middle band cold edge")
  assert_eq(60, bands[bi].hi, "middle band hot edge")
  assert_true(bands[bi].lo < 0 and bands[bi].hi > 0, "spawn (p=0) is inside the middle band")
  assert_eq(400, bands[1].hi, "hot-lava ocean reaches the sunward map edge (+total/2)")
  assert_eq(-400, bands[#bands].lo, "ice ocean reaches the nightward map edge (-total/2)")
end)

test("bands are contiguous, ordered high->low perpendicular (no gaps, no overlap)", function()
  local bands = terrain.bands()
  for i = 1, #bands do
    assert_true(bands[i].lo < bands[i].hi, "band " .. i .. " has positive width")
    if i > 1 then assert_eq(bands[i - 1].lo, bands[i].hi, "band " .. i .. " abuts the previous") end
  end
end)

test("changing one zone width changes only that band + the total, never the rest", function()
  local base_bands, base_total = terrain.bands()
  local cfg = { middle = 400 }
  local bands, total = terrain.bands(cfg)
  assert_eq(base_total + 280, total, "total grew by exactly the delta")
  local function width(b) return b.hi - b.lo end
  assert_eq(width(base_bands[1]), width(bands[1]), "hot-ocean keeps its width")
  local bi
  for i, z in ipairs(terrain.ZONES) do if z.role == "middle" then bi = i end end
  assert_eq(400, width(bands[bi]), "the middle band took the new width")
end)

test("damage bounds: heat over the hot ocean+inner, cold over the cold inner+ocean", function()
  local db = terrain.damage_bounds()
  assert_eq(130, db.hot_from, "heat band starts at the cold edge of hot_inner")
  assert_eq(-130, db.cold_from, "cold band starts at the hot edge of cold_inner")
  assert_eq(260, db.hot_from - db.cold_from, "the functional band between the danger bands is 260")
  assert_eq("heat", terrain.lethal_at(300), "the hot ocean burns")
  assert_eq("heat", terrain.lethal_at(150), "the hot inner burns")
  assert_eq("cold", terrain.lethal_at(-300), "the ice ocean freezes")
  assert_eq("cold", terrain.lethal_at(-150), "the cold inner freezes")
  assert_eq(nil, terrain.lethal_at(0), "the middle centre is safe")
  assert_eq(nil, terrain.lethal_at(90), "the hot outer slope is positionally safe")
  assert_eq(nil, terrain.lethal_at(-90), "the cold outer slope is positionally safe")
end)

test("resource_bounds splits stone (hot) from ice (cold) at the middle's cold edge", function()
  local rb = terrain.resource_bounds()
  assert_eq(60, rb.building_half, "the safe middle half-width")
  assert_eq(-60, rb.building_lo, "the stone/ice divider is the middle's cold edge")
  assert_eq(200, rb.hot_edge, "stone reaches the outer walkable hot zone, not the lava ocean")
  assert_eq(-400, rb.cold_edge, "ice reaches the cold ocean edge")
end)

test("the region bands + cliff band cover the right spans", function()
  local hr = terrain.hot_region()
  assert_eq(130, hr.lo, "hot heightmap inner (middle-ward) edge")
  assert_eq(400, hr.hi, "hot heightmap outer (ocean) edge")
  local cr = terrain.cold_region()
  assert_eq(-400, cr.lo, "cold heightmap outer (ocean) edge")
  assert_eq(-130, cr.hi, "cold heightmap inner (middle-ward) edge")
  local cb = terrain.cliff_band()
  assert_eq(60, cb.lo, "the volcanic rocky band cold edge (hot_outer lo)")
  assert_eq(200, cb.hi, "the volcanic rocky band hot edge (hot_inner hi)")
end)

test("ring_tile_at maps a HOT elevation to its ring tile (lava core -> cracks-warm)", function()
  assert_eq("cindra-lava-hot", terrain.ring_tile_at(200), "the peak is the molten core")
  assert_eq("cindra-lava-hot", terrain.ring_tile_at(140), "at the core threshold => lava-hot")
  assert_eq("cindra-lava", terrain.ring_tile_at(110), "just below the core => lava body")
  assert_eq("cindra-volcanic-smooth-stone-warm", terrain.ring_tile_at(50), "warm stone rings the lava")
  assert_eq("cindra-volcanic-cracks-hot", terrain.ring_tile_at(20), "cracks-hot rings the smooth-stone")
  assert_eq("cindra-volcanic-cracks-warm", terrain.ring_tile_at(-100), "far out => cracks-warm, blends to the flat slope")
end)

test("cold_ring_tile_at maps a COLD elevation to its ring tile (ice core -> snow-flat)", function()
  assert_eq("cindra-ice-smooth", terrain.cold_ring_tile_at(200), "the peak is the frozen core")
  assert_eq("cindra-ice-rough", terrain.cold_ring_tile_at(110), "rough ice rings the smooth cap")
  assert_eq("cindra-snow-patchy", terrain.cold_ring_tile_at(80), "snow-patchy is the last damaging ring")
  assert_eq("cindra-snow-flat", terrain.cold_ring_tile_at(-100), "far out => snow-flat, blends to the flat dust slope")
end)

test("the SOLID OCEAN floors guarantee the ocean cores regardless of the heightmap", function()
  local lava_lo = terrain.HOT_RING_ORDER[1].lo
  local ice_lo = terrain.COLD_RING_ORDER[1].lo
  assert_true(terrain.SEA_FILL - terrain.HEIGHT_AMPLITUDE >= lava_lo, "forced sea stays above the lava-core threshold")
  assert_true(terrain.SEA_FILL - terrain.HEIGHT_AMPLITUDE >= ice_lo, "forced sea stays above the ice-core threshold")
  assert_eq("cindra-lava-hot", terrain.ring_tile_at(terrain.SEA_FILL), "the forced sea => lava-hot core")
  assert_eq("cindra-ice-smooth", terrain.cold_ring_tile_at(terrain.SEA_FILL), "the forced sea => ice-smooth core")
  assert_true(terrain.SEA_WALL > 0, "the sea floor falls away outside the ocean so pools form")
end)

test("a hot tile's probability_expr is a sea-anchored heightmap ring term", function()
  local hot = terrain.probability_expr("cindra-lava-hot")
  contains(hot, "max(0,", "the gate + ring selector fall off via max(0, ...)")
  contains(hot, axis.perp_expr(), "keyed to the sunward perpendicular axis")
  contains(hot, "130", "the hot region's inner (middle-ward) edge")
  contains(hot, "400", "the hot region's sunward (ocean) edge")
  contains(hot, "140", "the lava-core elevation threshold")
  contains(hot, "seed1 = 42", "the elevation field is the hot heightmap noise (seed 42)")
  contains(hot, "200", "the solid-ocean anchor (hot ocean inner edge = SEA_FILL)")
  contains(hot, tostring(terrain.SEA_FILL), "the sea floor forces lava-hot across the ocean")
  local ok = pcall(function() terrain.probability_expr("not-a-tile") end)
  assert_true(not ok, "an unknown tile errors")
end)

test("a cold tile's probability_expr is a nightward sea-anchored heightmap ring term", function()
  local cold = terrain.probability_expr("cindra-ice-smooth")
  contains(cold, "seed1 = 43", "the cold elevation field is a distinct heightmap noise (seed 43)")
  contains(cold, axis.perp_neg_expr(), "keyed to the NIGHTWARD perpendicular axis (q = -perp)")
  contains(cold, tostring(terrain.SEA_FILL), "the forced ice-ocean floor")
end)

test("flat-slope + middle tiles carry a flat-band term; soil carries a patch ring term", function()
  local flats = terrain.probability_expr("cindra-volcanic-ash-flats")
  contains(flats, "max(0,", "the middle plateau falls off via max(0, ...)")
  contains(flats, "min(1, max(0,", "the flat-band membership weight uses a clamped fraction")
  -- cracks-warm is BOTH the outermost hot ring AND a hot_outer flat member.
  local warm = terrain.probability_expr("cindra-volcanic-cracks-warm")
  contains(warm, "seed1 = 42", "cracks-warm carries the hot ring term")
  contains(warm, "min(1, max(0,", "cracks-warm also carries its flat-slope weight")
  -- soil tiles carry a soil patch ring term (the low-frequency soil field, seed 50).
  local soil = terrain.probability_expr("cindra-volcanic-soil-dark")
  contains(soil, "seed1 = 50", "soil-dark is gated by the low-frequency soil patch field")
end)

test("the world is finite perpendicular via the map-gen = the total width", function()
  local d = terrain.finite_dimension()
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  assert_eq(800, d.value, "the finite dimension is the total ribbon width (sum of zones)")
  assert_eq(1080, terrain.finite_dimension({ middle = 400 }).value, "tracks the widths")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
