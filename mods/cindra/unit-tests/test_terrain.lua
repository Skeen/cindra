-- Plain-Lua unit test for the ribbon TERRAIN (scripts/terrain.lua; ci-oe83 rebuild).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is the pure source of truth for the ONE-CONTINUOUS-ELEVATION-FIELD planet
-- (ci-oe83): a single smooth valley (low middle, high edges) whose THREE regions -- HOT
-- rings, ash MIDDLE, COLD rings -- are three applications of that one field, with both
-- oceans EMERGING as the field's extremes. This proves the pure surface: the zone table,
-- band geometry, the ring orders + elevation ramp, the ring/middle membership, the
-- per-tile probability expressions, walkability, the no-pave set, the CONTINUOUS FIELD
-- DAMAGE, the corridor guarantee (lava only emerges beyond the damage onset), continuity
-- of the elevation ramp, and the positional bounds. tests/test_worldgen proves it
-- actually generates on a live surface (including the ci-oe83 flood-fill repro guard).

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
local function assert_near(a, b, msg)
  if math.abs(a - b) > 1e-6 then error((msg or "differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end
local function contains(haystack, needle, msg)
  assert_true(haystack:find(needle, 1, true) ~= nil,
    (msg or "expected substring") .. " '" .. needle .. "' in: " .. haystack)
end

local ZONE_ORDER = { "hot_ocean", "hot_inner", "hot_outer", "middle", "cold_outer", "cold_inner", "cold_ocean" }

test("the seven positional zones are ordered HOT -> MIDDLE -> COLD", function()
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

test("the hot ring order spans ash-dark (low E) -> lava-hot (ocean peak, high E)", function()
  local EXPECTED = { "lava-hot", "lava", "volcanic-smooth-stone-warm", "volcanic-cracks-hot",
    "volcanic-cracks-warm", "volcanic-cracks", "volcanic-smooth-stone", "volcanic-ash-dark" }
  assert_eq(#EXPECTED, #terrain.HOT_RING_ORDER, "eight hot rings")
  for i, v in ipairs(EXPECTED) do assert_eq(v, terrain.HOT_RING_ORDER[i].vanilla, "hot ring " .. i .. " is " .. v) end
  for i = 2, #terrain.HOT_RING_ORDER do
    assert_true(terrain.HOT_RING_ORDER[i].lo < terrain.HOT_RING_ORDER[i - 1].lo, "hot ring " .. i .. " is lower")
  end
end)

test("the cold ring order spans ash-light (low E) -> ice-smooth (ocean peak, high E)", function()
  local EXPECTED = { "ice-smooth", "ice-rough", "snow-patchy", "snow-lumpy", "snow-crests", "snow-flat",
    "dust-patchy", "dust-lumpy", "dust-crests", "dust-flat", "volcanic-ash-light" }
  assert_eq(#EXPECTED, #terrain.COLD_RING_ORDER, "eleven cold rings")
  for i, v in ipairs(EXPECTED) do assert_eq(v, terrain.COLD_RING_ORDER[i].vanilla, "cold ring " .. i .. " is " .. v) end
  for i = 2, #terrain.COLD_RING_ORDER do
    assert_true(terrain.COLD_RING_ORDER[i].lo < terrain.COLD_RING_ORDER[i - 1].lo, "cold ring " .. i .. " is lower")
  end
end)

test("the ocean cores are OPEN-TOP rings (a solid emergent sea, not a forced floor)", function()
  assert_eq(terrain.ring_band_hot["cindra-lava-hot"].hi, 1e9, "lava-hot has no upper elevation bound")
  assert_eq(terrain.ring_band_cold["cindra-ice-smooth"].hi, 1e9, "ice-smooth has no upper elevation bound")
end)

test("each zone's membership is the tiles that can paint its band", function()
  local function has(role, vanilla) return terrain.zone_tiles(role)["cindra-" .. vanilla] == true end
  for _, role in ipairs({ "hot_ocean", "hot_inner", "hot_outer" }) do
    assert_true(has(role, "lava-hot"), role .. " includes the lava core")
    assert_true(has(role, "volcanic-ash-dark"), role .. " reaches the lowest hot ring")
  end
  for _, v in ipairs({ "volcanic-ash-dark", "volcanic-ash-light", "volcanic-ash-flats",
                       "volcanic-ash-soil", "volcanic-soil-light", "volcanic-soil-dark" }) do
    assert_true(has("middle", v), "middle includes " .. v)
  end
  for _, role in ipairs({ "cold_ocean", "cold_inner", "cold_outer" }) do
    assert_true(has(role, "ice-smooth"), role .. " includes the ice core")
    assert_true(has(role, "dust-flat"), role .. " reaches the low cold rings")
  end
end)

test("all clone sources dedupe to 23 concrete tiles, hottest first, ice last", function()
  local names = terrain.tile_names()
  assert_eq(23, #names, "twenty-three deduped concrete tiles")
  assert_eq("cindra-lava-hot", names[1], "hottest tile is first (hot -> cold order)")
  assert_eq("cindra-ice-smooth", names[#names], "coldest tile (ice ocean) is last")
end)

test("only the two lava tiles are impassable; smooth-ice is WALKABLE", function()
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

-- CONTINUOUS FIELD DAMAGE (ci-oe83) -----------------------------------------------
test("field damage: heat + cold intensity ramp with perpendicular DEPTH, safe middle = 0", function()
  local function heat(p) return (select(1, terrain.field_damage(p))) end
  local function kind(p) return (select(2, terrain.field_damage(p))) end
  assert_eq(0, heat(0), "the middle centre is safe")
  assert_eq(nil, kind(0), "safe positions have no damage kind")
  assert_eq(0, heat(90), "the safe hot slope is field-safe")
  assert_eq(0, heat(-90), "the safe cold slope is field-safe")
  assert_eq(0, heat(129), "just inside the hot damage onset -> still safe")
  assert_eq("heat", kind(130), "at the hot damage onset -> heat")
  assert_eq("cold", kind(-130), "at the cold damage onset -> cold")
  assert_true(heat(165) > heat(140), "deeper toward the lava -> stronger (monotonic)")
  assert_true(heat(200) >= heat(165), "monotonic toward the ocean")
  assert_near(1, heat(200), "full heat at the hot ocean inner edge")
  assert_near(1, heat(350), "full heat across the ocean")
  local function cold(p) return (select(1, terrain.field_damage(p))) end
  assert_true(cold(-165) > cold(-140), "deeper toward the ice cap -> stronger")
  assert_near(1, cold(-200), "full cold at the cold ocean inner edge")
end)

test("CORRIDOR GUARANTEE: lava can only EMERGE beyond the damage onset (no non-damaging path)", function()
  -- The elevation field is ramp + noise (bounded by HEIGHT_NOISE_AMPLITUDE). The MOST
  -- inward a lava tile can ever appear is where ramp = (lava threshold - max noise); if
  -- that perpendicular position is already beyond the heat damage onset, then EVERY lava
  -- tile is at a damaging position -- there is no non-damaging walk-to-lava corridor.
  local db = terrain.damage_bounds()
  local A = terrain.HEIGHT_NOISE_AMPLITUDE
  local lava_lo = terrain.HOT_RING_ORDER[2].lo      -- "lava" (the molten body threshold)
  local lavahot_lo = terrain.HOT_RING_ORDER[1].lo   -- "lava-hot" (the impassable core)
  local innermost_lava = terrain.hot_perp_at_elevation(lava_lo - A)
  local innermost_core = terrain.hot_perp_at_elevation(lavahot_lo - A)
  assert_true(innermost_lava > db.hot_from,
    "the most-inward possible lava (" .. innermost_lava .. ") is beyond the heat onset (" .. db.hot_from .. ")")
  assert_true(innermost_core > db.hot_from, "the most-inward possible lava-hot core is beyond the onset too")
  -- And the field really is damaging there.
  assert_true((terrain.field_damage(innermost_lava)) > 0, "the innermost possible lava sits in the damaging field")
end)

test("the elevation ramp is CONTINUOUS across the whole planet (no forced-floor step)", function()
  -- One linear ramp per side: constant slope, no discontinuity anywhere (including the
  -- ocean boundary). Assert the per-tile step is small + constant across the ocean edge.
  local function step(side, p) return terrain.elevation_ramp(p + 1, side) - terrain.elevation_ramp(p, side) end
  local s0 = step("hot", 0)
  for p = -350, 350, 5 do
    assert_true(math.abs(step("hot", p) - s0) < 1e-6, "hot ramp slope is constant at p=" .. p)
  end
  -- Near the emergent ocean boundary specifically: no jump.
  local ocean_p = terrain.hot_perp_at_elevation(terrain.HOT_RING_ORDER[1].lo)
  assert_true(math.abs(step("hot", math.floor(ocean_p)) - s0) < 1e-6, "no step at the ocean boundary")
  assert_true(s0 > 0, "the ramp rises toward the ocean")
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

test("the total ribbon width is the SUM of the zone widths (default 800)", function()
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
  assert_eq(60, hr.lo, "hot region inner (middle-ward) edge")
  assert_eq(400, hr.hi, "hot region outer (ocean) edge")
  local cr = terrain.cold_region()
  assert_eq(-400, cr.lo, "cold region outer (ocean) edge")
  assert_eq(-60, cr.hi, "cold region inner (middle-ward) edge")
  local cb = terrain.cliff_band()
  assert_eq(60, cb.lo, "the volcanic rocky band cold edge (hot_outer lo)")
  assert_eq(200, cb.hi, "the volcanic rocky band hot edge (hot_inner hi)")
end)

test("ring_tile_at maps a HOT elevation to its ring tile (lava core -> ash-dark)", function()
  assert_eq("cindra-lava-hot", terrain.ring_tile_at(100), "the peak is the molten core")
  assert_eq("cindra-lava-hot", terrain.ring_tile_at(68), "at the core threshold => lava-hot")
  assert_eq("cindra-lava", terrain.ring_tile_at(50), "just below the core => lava body")
  assert_eq("cindra-volcanic-smooth-stone-warm", terrain.ring_tile_at(30), "warm stone rings the lava")
  assert_eq("cindra-volcanic-cracks-hot", terrain.ring_tile_at(20), "cracks-hot rings the smooth-stone")
  assert_eq("cindra-volcanic-ash-dark", terrain.ring_tile_at(-5), "low elevation => ash-dark, blends to the middle")
end)

test("cold_ring_tile_at maps a COLD elevation to its ring tile (ice core -> ash-light)", function()
  assert_eq("cindra-ice-smooth", terrain.cold_ring_tile_at(100), "the peak is the frozen core")
  assert_eq("cindra-ice-rough", terrain.cold_ring_tile_at(50), "rough ice rings the smooth cap")
  assert_eq("cindra-snow-patchy", terrain.cold_ring_tile_at(30), "snow rings the ice")
  assert_eq("cindra-volcanic-ash-light", terrain.cold_ring_tile_at(-14), "low elevation => ash-light, blends to the middle")
end)

test("EMERGENCE: the ocean tile's probability_expr is a threshold on the ONE field, no forced floor", function()
  local hot = terrain.probability_expr("cindra-lava-hot")
  contains(hot, axis.perp_expr(), "keyed to the sunward perpendicular axis")
  contains(hot, "seed1 = 42", "driven by the ONE shared elevation noise (seed 42)")
  contains(hot, tostring(terrain.HEIGHT_PEAK), "uses the elevation ramp peak")
  -- The ocean must EMERGE from the field, so there is NO forced sea floor / no per-band
  -- constant floor stamped in: the old model's SEA_FILL/SEA_WALL machinery is gone.
  assert_true(hot:find("SEA_FILL", 1, true) == nil, "no forced sea-floor constant")
  assert_eq(nil, terrain.SEA_FILL, "the forced-floor SEA_FILL knob is removed")
  assert_eq(nil, terrain.GATE_STEEP, "the steep perpendicular gate is removed")
  local ok = pcall(function() terrain.probability_expr("not-a-tile") end)
  assert_true(not ok, "an unknown tile errors")
end)

test("a cold ocean tile's probability_expr reads the nightward axis + the same one field", function()
  local cold = terrain.probability_expr("cindra-ice-smooth")
  contains(cold, "seed1 = 42", "the SAME shared elevation field drives both oceans (one heightmap)")
  contains(cold, axis.perp_neg_expr(), "keyed to the NIGHTWARD perpendicular axis")
end)

test("middle + soil tiles carry the ash-mix + soil-patch terms", function()
  local flats = terrain.probability_expr("cindra-volcanic-ash-flats")
  contains(flats, "seed1 = 42", "the middle mix is arbitrated by the same elevation field")
  local soil = terrain.probability_expr("cindra-volcanic-soil-dark")
  contains(soil, "seed1 = 50", "soil-dark is gated by the low-frequency soil patch field")
  -- ash-dark is BOTH the lowest hot ring AND a middle mix member.
  local ash = terrain.probability_expr("cindra-volcanic-ash-dark")
  contains(ash, "max(", "ash-dark carries multiple placement terms (ring + middle)")
end)

test("the world is finite perpendicular via the map-gen = the total width", function()
  local d = terrain.finite_dimension()
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  assert_eq(800, d.value, "the finite dimension is the total ribbon width (sum of zones)")
  assert_eq(1080, terrain.finite_dimension({ middle = 400 }).value, "tracks the widths")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
