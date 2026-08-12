-- Plain-Lua unit test for the ribbon TERRAIN (scripts/terrain.lua; ci-oe83 ONE-field
-- rebuild). Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is the pure source of truth for the SINGLE continuous heightmap: one
-- monotonic value field H over the perpendicular axis, edge-pinned to the lava/ice
-- extremes and clamped through the safe middle, with BOTH the tile art and the damage
-- derived from that value. This proves the pure surface: the value ramp, the field (pinned
-- edges, clamped middle, monotonic single-crossing belts), value->tile + value->damage,
-- the zone geometry, the damage bounds, walkability, the no-pave set, map colours, the
-- probability expressions, and the EMERGENCE / CONTINUITY / SMOOTH properties.
-- tests/test_worldgen + tests/test_heightmap prove it generates on a live surface.

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
local function assert_near(a, b, eps, msg)
  if math.abs(a - b) > (eps or 1e-9) then
    error((msg or "not near") .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")", 2)
  end
end
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

-- === THE ONE FIELD (ci-oe83) ================================================

test("the value ramp is ONE monotonic hot->cold sequence, lava-hot core -> ice-smooth core", function()
  local r = terrain.VALUE_RAMP
  assert_eq("lava-hot", r[1].vanilla, "the hottest ramp tile is the hot-lava ocean core")
  assert_eq("ice-smooth", r[#r].vanilla, "the coldest ramp tile is the smooth-ice ocean core")
  for i = 2, #r do
    assert_true(r[i].lo < r[i - 1].lo, "ramp tile " .. i .. " has a strictly lower value threshold")
  end
  -- The damage thresholds sit ON ramp-tile edges: the first heat tile begins at HOT_DMG,
  -- the first safe cold tile at COLD_DMG.
  local by = {}
  for _, e in ipairs(r) do by[e.vanilla] = e.lo end
  assert_eq(terrain.HOT_DMG, by["volcanic-cracks-hot"], "cracks-hot begins at the heat threshold")
  assert_eq(terrain.COLD_DMG, by["snow-flat"], "snow-flat begins at the cold threshold (safe side)")
end)

-- === THE HOT-SIDE FOLDS BRANCH (ci-72bw) ====================================

test("the hot slope has TWO families spanning the SAME value segment (ci-72bw)", function()
  -- The cracks family is the main line; the folds family is the branch. The branch span is
  -- derived from the cracks members, so both cover exactly the same values.
  local span = terrain.BRANCH_SPAN
  assert_eq(terrain.HOT_DMG, span.hi, "the branch span tops out at the heat threshold")
  assert_eq(0.585, span.lo, "the branch span bottoms out where ash-dark begins")
  local cracks, folds = terrain.family_tiles("cracks"), terrain.family_tiles("folds")
  local function names(set)
    local out = {}
    for n in pairs(set) do out[#out + 1] = n end
    table.sort(out)
    return table.concat(out, ",")
  end
  assert_eq("cindra-volcanic-cracks,cindra-volcanic-cracks-warm,cindra-volcanic-smooth-stone",
    names(cracks), "the cracks family is the ci-wly main line")
  assert_eq("cindra-volcanic-ash-cracks,cindra-volcanic-folds,cindra-volcanic-folds-flat," ..
    "cindra-volcanic-folds-warm,cindra-volcanic-pumice-stones",
    names(folds), "the folds family is the ci-72bw branch")
  -- Family membership is exclusive, and NOTHING outside the branch span is a member.
  for _, v in ipairs({ "lava-hot", "lava", "volcanic-smooth-stone-warm", "volcanic-cracks-hot",
                       "volcanic-ash-dark", "volcanic-ash-flats", "dust-flat", "ice-smooth" }) do
    assert_eq(nil, terrain.tile_branch("cindra-" .. v), "cindra-" .. v .. " is in neither family")
  end
  assert_eq("cracks", terrain.tile_branch("cindra-volcanic-cracks-warm"), "cracks-warm is the cracks family")
  assert_eq("folds", terrain.tile_branch("cindra-volcanic-folds-warm"), "folds-warm is the folds family")
end)

test("the folds ramp is monotonic, pinned to the branch span, ordered warm -> pumice", function()
  local r = terrain.FOLDS_RAMP
  assert_eq(5, #r, "five folds tiles")
  assert_eq("volcanic-folds-warm", r[1].vanilla, "hottest folds tile first")
  assert_eq("volcanic-pumice-stones", r[#r].vanilla, "pumice-stones is the coldest folds tile")
  for i = 2, #r do
    assert_true(r[i].lo < r[i - 1].lo, "folds tile " .. i .. " has a strictly lower value threshold")
  end
  assert_eq(terrain.BRANCH_SPAN.lo, r[#r].lo, "the coldest folds tile bottoms out at the convergence")
  assert_true(r[1].lo < terrain.BRANCH_SPAN.hi, "the hottest folds tile stays below the heat threshold")
end)

test("BOTH families CONVERGE on ash-dark, and neither leaks past the branch span", function()
  local span = terrain.BRANCH_SPAN
  -- Below the span the folds selection returns the SAME tile as the main line (ash-dark
  -- and everything colder): that IS the convergence.
  for _, H in ipairs({ span.lo - 0.001, 0.56, 0.5, 0.44, terrain.COLD_DMG, 0.1, 0.0 }) do
    assert_eq(terrain.value_tile(H), terrain.value_tile(H, "folds"),
      "below the branch span both families paint the same tile (H=" .. H .. ")")
  end
  assert_eq("cindra-volcanic-ash-dark", terrain.value_tile(span.lo - 0.001, "folds"),
    "the folds family thins into ash-dark")
  assert_eq("cindra-volcanic-ash-dark", terrain.value_tile(span.lo - 0.001),
    "the cracks family thins into ash-dark too")
  -- Above the span (the lethal crust + the oceans) both families are the main line as well.
  for _, H in ipairs({ span.hi, 0.76, 0.85, 0.95, 1.0 }) do
    assert_eq(terrain.value_tile(H), terrain.value_tile(H, "folds"),
      "above the branch span both families paint the same tile (H=" .. H .. ")")
  end
  -- INSIDE the span the two families differ everywhere (that is the point of the branch).
  for _, H in ipairs({ 0.69, 0.66, 0.64, 0.60, 0.59 }) do
    local main, folds = terrain.value_tile(H), terrain.value_tile(H, "folds")
    assert_true(main ~= folds, "the families differ inside the span (H=" .. H .. ": " .. main .. ")")
    assert_eq("folds", terrain.tile_branch(folds), folds .. " is a folds tile")
    assert_eq("cracks", terrain.tile_branch(main), main .. " is a cracks tile")
  end
end)

test("folds-warm carries the SAME (zero) heat damage as cracks-warm (ci-72bw)", function()
  local wi, wk = terrain.tile_damage("cindra-volcanic-folds-warm")
  local ci, ck = terrain.tile_damage("cindra-volcanic-cracks-warm")
  assert_eq(ci, wi, "folds-warm has cracks-warm's heat intensity")
  assert_eq(ck, wk, "folds-warm has cracks-warm's damage kind")
  assert_eq(0, wi, "and that is the safe hot-slope value (0)")
  assert_eq(nil, wk, "with no damage kind")
  -- The whole folds family is safe, exactly like the whole cracks family: both live
  -- strictly below HOT_DMG, so the branch cannot smuggle lethal ground into the slope.
  for name in pairs(terrain.family_tiles("folds")) do
    local i, k = terrain.tile_damage(name)
    assert_eq(0, i, name .. " deals no damage")
    assert_eq(nil, k, name .. " has no damage kind")
    assert_eq(false, terrain.is_no_pave(name), name .. " is pavable safe ground")
    assert_eq(true, terrain.is_walkable(name), name .. " is walkable ground")
  end
end)

test("the folds family is confined to the hot slope: never the middle, never the cold side", function()
  for name in pairs(terrain.family_tiles("folds")) do
    local zones = terrain.tile_zones(name)
    assert_true(zones.hot_outer == true, name .. " paints the hot outer slope")
    for _, role in ipairs({ "middle", "cold_outer", "cold_inner", "cold_ocean", "hot_ocean" }) do
      assert_eq(nil, zones[role], name .. " must never paint " .. role)
    end
  end
end)

test("the field is PINNED at the edges: lava extreme sunward, ice extreme nightward", function()
  local _, total = terrain.bands()
  local half = total / 2
  assert_eq(1.0, terrain.field(half), "the sunward edge is pinned to the hot-lava extreme (H=1)")
  assert_eq(0.0, terrain.field(-half), "the nightward edge is pinned to the smooth-ice extreme (H=0)")
  assert_eq(1.0, terrain.field(half + 500), "beyond the sunward edge stays pinned (clamped)")
  assert_eq(0.0, terrain.field(-half - 500), "beyond the nightward edge stays pinned (clamped)")
  assert_eq("cindra-lava-hot", terrain.value_tile(terrain.field(half)), "the sunward edge IS the lava ocean")
  assert_eq("cindra-ice-smooth", terrain.value_tile(terrain.field(-half)), "the nightward edge IS the ice ocean")
end)

test("the field is CLAMPED through the middle: strictly between the ice + lava thresholds", function()
  local mid = terrain.role_band("middle")
  for p = mid.lo, mid.hi do
    local h = terrain.field(p)
    assert_true(h < terrain.HOT_DMG, "middle field at p=" .. p .. " stays below the heat threshold (" .. h .. ")")
    assert_true(h > terrain.COLD_DMG, "middle field at p=" .. p .. " stays above the cold threshold (" .. h .. ")")
  end
  assert_eq(0.5, terrain.field(0), "the ribbon centre is exactly the neutral middle value")
end)

test("the field is MONOTONIC: it rises steadily from the ice edge to the lava edge", function()
  local prev = terrain.field(-400)
  for p = -399, 400 do
    local h = terrain.field(p)
    assert_true(h >= prev - 1e-9, "field never falls as p rises (at p=" .. p .. ")")
    prev = h
  end
  assert_true(terrain.field(200) > terrain.field(0), "hotter sunward")
  assert_true(terrain.field(0) > terrain.field(-200), "colder nightward")
end)

test("value_tile maps a field value to its ramp tile (lava-hot -> ice-smooth)", function()
  assert_eq("cindra-lava-hot", terrain.value_tile(1.0), "peak value is the molten core")
  assert_eq("cindra-lava-hot", terrain.value_tile(0.95), "deep ocean is lava-hot")
  assert_eq("cindra-volcanic-cracks-hot", terrain.value_tile(terrain.HOT_DMG), "the heat threshold value is glowing crust")
  assert_eq("cindra-volcanic-ash-flats", terrain.value_tile(0.5), "the neutral middle is ash flats")
  assert_eq("cindra-snow-flat", terrain.value_tile(terrain.COLD_DMG), "the cold threshold value is snow")
  assert_eq("cindra-ice-smooth", terrain.value_tile(0.0), "the coldest value is the frozen core")
end)

test("value_damage: heat above HOT_DMG, cold below COLD_DMG, SAFE strictly between", function()
  local function kind(h) return (select(2, terrain.value_damage(h))) end
  local function intensity(h) return (select(1, terrain.value_damage(h))) end
  assert_eq(nil, kind(0.5), "the middle value is safe")
  assert_eq(0, intensity(0.5), "the middle value deals no damage")
  assert_eq("heat", kind(terrain.HOT_DMG), "at the heat threshold it is heat")
  assert_eq(0, intensity(terrain.HOT_DMG), "at the heat threshold the intensity is 0 (ramp start)")
  assert_eq("heat", kind(1.0), "the lava extreme is heat")
  assert_eq(1.0, intensity(1.0), "the lava extreme is peak heat (1.0)")
  assert_true(intensity(0.95) < intensity(1.0), "heat intensity ramps up toward the lava extreme")
  assert_eq("cold", kind(terrain.COLD_DMG), "at the cold threshold it is cold")
  assert_eq(0, intensity(terrain.COLD_DMG), "at the cold threshold the intensity is 0 (ramp start)")
  assert_eq("cold", kind(0.0), "the ice extreme is cold")
  assert_eq(1.0, intensity(0.0), "the ice extreme is peak cold (1.0)")
  assert_true(intensity(0.05) < intensity(0.0), "cold intensity ramps up toward the ice extreme")
end)

test("tile_damage: hazard naturals burn/freeze, safe naturals + cover tiles shield (ci-ma18)", function()
  local function kind(name) return (select(2, terrain.tile_damage(name))) end
  local function intensity(name) return (select(1, terrain.tile_damage(name))) end
  -- HEAT naturals: the lava cores + hot crust + glowing cracks all deal heat.
  assert_eq("heat", kind("cindra-lava-hot"), "lava-hot burns")
  assert_eq(1.0, intensity("cindra-lava-hot"), "the lava-hot ocean core is peak heat")
  assert_eq("heat", kind("cindra-lava"), "molten lava burns")
  assert_eq("heat", kind("cindra-volcanic-smooth-stone-warm"), "the warm crust burns")
  assert_eq("heat", kind("cindra-volcanic-cracks-hot"), "glowing cracks-hot burn (the ci-ma18 crack)")
  assert_true(intensity("cindra-volcanic-cracks-hot") > 0, "and the burn is non-zero")
  assert_true(intensity("cindra-lava") > intensity("cindra-volcanic-cracks-hot"),
    "deeper into the hot naturals burns more")
  -- COLD naturals: the ice cores + snow deal cold.
  assert_eq("cold", kind("cindra-ice-smooth"), "smooth ice freezes")
  assert_eq(1.0, intensity("cindra-ice-smooth"), "the smooth-ice ocean core is peak cold")
  assert_eq("cold", kind("cindra-ice-rough"), "rough ice freezes")
  assert_eq("cold", kind("cindra-snow-crests"), "snow-crests freezes")
  assert_true(intensity("cindra-ice-rough") > intensity("cindra-snow-crests"),
    "deeper into the cold naturals freezes more")
  -- SAFE naturals: the whole habitable middle + the safe-band edge tiles deal nothing.
  for _, v in ipairs({ "volcanic-cracks-warm", "volcanic-cracks", "volcanic-ash-flats",
                       "volcanic-ash-dark", "dust-flat", "snow-flat" }) do
    assert_eq(0, intensity("cindra-" .. v), "cindra-" .. v .. " is a safe natural")
    assert_eq(nil, kind("cindra-" .. v), "cindra-" .. v .. " has no damage kind")
  end
  -- SOIL overlay tiles sit in the safe middle and carry no damage of their own.
  assert_eq(0, intensity("cindra-volcanic-soil-dark"), "soil is a safe overlay")
  -- COVER tiles (player paving) + unknown tiles SHIELD: absent from the value ramp.
  for _, name in ipairs({ "concrete", "refined-concrete", "stone-path", "hazard-concrete-left", "not-a-tile" }) do
    assert_eq(0, intensity(name), name .. " shields (deals zero damage)")
    assert_eq(nil, kind(name), name .. " has no damage kind")
  end
end)

test("field_damage is TWO contiguous EDGE BELTS with a safe middle, crossings at +/-130", function()
  -- The heat belt begins exactly at the hot damage boundary and the cold belt at the cold
  -- one; the whole middle between them is safe. No overlap: no p is both heat and cold.
  local db = terrain.damage_bounds()
  assert_eq(130, db.hot_from, "the heat belt inner edge")
  assert_eq(-130, db.cold_from, "the cold belt inner edge")
  assert_eq("heat", terrain.lethal_at(db.hot_from), "the field crosses into heat exactly at hot_from")
  assert_eq(nil, terrain.lethal_at(db.hot_from - 1), "one tile inside is safe")
  assert_eq("cold", terrain.lethal_at(db.cold_from), "the field crosses into cold exactly at cold_from")
  assert_eq(nil, terrain.lethal_at(db.cold_from + 1), "one tile inside is safe")
  -- Contiguity + no gaps: scan the whole axis, damage only in the two outer belts.
  local _, total = terrain.bands()
  local half = total / 2
  for p = -half, half do
    local kind = terrain.lethal_at(p)
    if p >= db.hot_from then assert_eq("heat", kind, "everything from hot_from out is heat (p=" .. p .. ")")
    elseif p <= db.cold_from then assert_eq("cold", kind, "everything from cold_from out is cold (p=" .. p .. ")")
    else assert_eq(nil, kind, "the middle band is safe (p=" .. p .. ")") end
  end
end)

test("EMERGENCE: the oceans come from the pinned edge, not a fixed-width band", function()
  -- Shrink BOTH ocean zones to a sliver. The field still pins to the extremes at the (now
  -- nearer) edges, so the ocean tiles STILL appear at the edge and across a band -- proof
  -- the ocean is field/edge-driven, never a 200-wide stamp.
  local cfg = { hot_ocean = 20, cold_ocean = 20 }
  local _, total = terrain.bands(cfg)
  local half = total / 2
  assert_eq("cindra-lava-hot", terrain.value_tile(terrain.field(half, cfg)), "lava ocean still at the edge")
  assert_eq("cindra-ice-smooth", terrain.value_tile(terrain.field(-half, cfg)), "ice ocean still at the edge")
  local lava_band, ice_band = 0, 0
  for p = -half, half do
    local tile = terrain.value_tile(terrain.field(p, cfg))
    if tile == "cindra-lava-hot" then lava_band = lava_band + 1 end
    if tile == "cindra-ice-smooth" then ice_band = ice_band + 1 end
  end
  assert_true(lava_band > 25, "a lava ocean still emerges as a band (" .. lava_band .. " tiles), not just one edge tile")
  assert_true(ice_band > 25, "an ice ocean still emerges as a band (" .. ice_band .. " tiles)")
end)

test("CONTINUITY: the field never steps -- no stamp cut-off across the ocean edge", function()
  local prev = terrain.field(-400)
  local max_step = 0
  for p = -399, 400 do
    local h = terrain.field(p)
    max_step = math.max(max_step, math.abs(h - prev))
    prev = h
  end
  -- The steepest segment is the belt ramp; assert there is no discontinuous jump anywhere.
  assert_true(max_step < 0.01, "adjacent-tile field step stays smooth everywhere (max=" .. max_step .. ")")
end)

test("SMOOTH: the field gradient is bounded (no cliffs in the value field)", function()
  -- Sample perpendicular through both ocean edges specifically (the ci-oe83 cut-off spot).
  for _, edge in ipairs({ 200, -200 }) do
    for p = edge - 30, edge + 30 do
      local step = math.abs(terrain.field(p + 1) - terrain.field(p))
      assert_true(step < 0.006, "smooth across the ocean boundary at p=" .. p .. " (step=" .. step .. ")")
    end
  end
end)

-- === TILES ==================================================================

test("all clone sources are real vanilla/space-age tile family names", function()
  local names = terrain.tile_names()
  assert_eq(28, #names, "twenty-eight deduped concrete tiles (23 + the 5 folds-family tiles)")
  assert_eq("cindra-lava-hot", names[1], "hottest tile is first (hot -> cold order)")
  -- The folds family registers directly after the tile it branches from, so the tile list
  -- still reads hot -> cold.
  local at = {}
  for i, n in ipairs(names) do at[n] = i end
  assert_true(at["cindra-volcanic-cracks-hot"] < at["cindra-volcanic-folds-warm"],
    "the folds family is registered after the crust it branches below")
  assert_true(at["cindra-volcanic-pumice-stones"] < at["cindra-volcanic-ash-dark"],
    "and before the ash-dark convergence")
end)

test("only the two lava tiles are impassable; smooth-ice is WALKABLE (ci-wly)", function()
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

test("each zone's membership is the value tiles (+ soil) that can paint its band", function()
  local function has(role, vanilla) return terrain.zone_tiles(role)["cindra-" .. vanilla] == true end
  assert_true(has("hot_ocean", "lava-hot"), "the hot ocean paints lava-hot")
  assert_true(has("cold_ocean", "ice-smooth"), "the cold ocean paints ice-smooth")
  for _, v in ipairs({ "volcanic-ash-dark", "volcanic-ash-light", "volcanic-ash-flats",
                       "volcanic-ash-soil", "volcanic-soil-light", "volcanic-soil-dark" }) do
    assert_true(has("middle", v), "middle includes " .. v)
  end
  assert_eq(false, has("middle", "lava-hot"), "the middle never paints the lava core")
  assert_eq(false, has("middle", "ice-smooth"), "the middle never paints the ice core")
end)

-- === GEOMETRY (unchanged from ci-wly) =======================================

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

test("the field tracks the widths: crossings move with the damage bounds", function()
  local cfg = { middle = 400 } -- wider middle -> damage bounds move out with it
  local db = terrain.damage_bounds(cfg)
  assert_eq(270, db.hot_from, "the heat belt inner edge moved out with the wider middle")
  assert_eq("heat", terrain.lethal_at(db.hot_from, cfg), "the field still crosses into heat at hot_from")
  assert_eq(nil, terrain.lethal_at(db.hot_from - 1, cfg), "and is still safe one tile inside")
  assert_eq(0.5, terrain.field(0, cfg), "the centre is still the neutral middle value")
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

-- === MAP-GEN EXPRESSIONS ====================================================

test("a value-ramp tile's probability_expr is a value-band term over the ONE field", function()
  local hot = terrain.probability_expr("cindra-lava-hot")
  contains(hot, "max(0,", "the value-band selector falls off via max(0, ...)")
  contains(hot, axis.perp_expr(), "keyed to the perpendicular axis (the one field)")
  contains(hot, "min(1, max(0,", "the field value is clamped to [0,1]")
  contains(hot, "0.9", "the lava-hot lower value threshold")
  contains(hot, "seed1 = 7", "the boundary wiggle (organic contours)")
  -- Both a hot and a cold tile embed the SAME field expression (one field, not two).
  local cold = terrain.probability_expr("cindra-ice-smooth")
  contains(cold, "- 130", "the shared field references the hot damage boundary")
  contains(cold, "- -130", "the shared field references the cold damage boundary")
  local ok = pcall(function() terrain.probability_expr("not-a-tile") end)
  assert_true(not ok, "an unknown tile errors")
end)

test("hot-slope family tiles carry the low-frequency BRANCH penalty (ci-72bw)", function()
  local folds = terrain.probability_expr("cindra-volcanic-folds-warm")
  local cracks = terrain.probability_expr("cindra-volcanic-cracks-warm")
  for _, e in ipairs({ folds, cracks }) do
    contains(e, "seed1 = 60", "gated by the low-frequency branch-noise field")
    contains(e, "input_scale = " .. string.format("%.6g", 1 / terrain.BRANCH_WAVELENGTH),
      "the branch noise is LOW frequency (wavelength " .. terrain.BRANCH_WAVELENGTH .. ")")
    contains(e, "- 0.8 * max(0,", "pays the branch penalty in the other family's regions")
  end
  -- Opposite signs: the folds family is gated to +branch-noise, cracks to -branch-noise,
  -- so a region reads one family or the other, never a blend of both.
  contains(folds, "0.8 * max(0, -(basis_noise{", "folds paint where the branch noise is positive")
  assert_true(cracks:find("0.8 * max(0, -(basis_noise{", 1, true) == nil,
    "cracks are gated the other way (no negated branch noise)")
  -- CONTAINMENT: the folds family additionally pays a positional gate inward of the hot
  -- slope, so a speckle can never surface it in the middle or on the cold side. The gate
  -- reads the RAW perpendicular (a gate on the WIGGLED one contains nothing in world
  -- space -- the wiggle carries the tile straight back over the line).
  local slope = terrain.role_band(terrain.BRANCH_ROLE)
  local g = terrain.branch_gate_band()
  assert_eq(60, slope.lo, "the slope band starts at the middle's hot edge")
  assert_eq(130, slope.hi, "and ends at the heat damage boundary")
  assert_eq(64, g.lo, "the middle-ward gate line sits just inside the slope")
  assert_eq(134, g.hi, "the hot gate line sits just outside it")
  contains(folds, "- 1 * (max(0, 64 - " .. axis.perp_expr(),
    "gated on the RAW perpendicular (a wiggled gate contains nothing in world space)")
  contains(folds, axis.perp_expr() .. " - 134)", "and closed off on the hot side too")
  assert_true(terrain.BRANCH_GATE > terrain.SPECKLE_H,
    "one tile past a gate line the penalty already swamps the per-tile speckle")
  -- Both gate lines must clear the family's visible (wiggled) contours, so neither ever
  -- cuts a straight edge into the art.
  local folds_lo, folds_hi
  for p = slope.lo, slope.hi do
    local h = terrain.field(p)
    if h >= terrain.BRANCH_SPAN.lo and folds_lo == nil then folds_lo = p end
    if h < terrain.BRANCH_SPAN.hi then folds_hi = p end
  end
  local clearance = terrain.NOISE_AMPLITUDE + 1
  assert_true(folds_lo - g.lo > clearance,
    "the middle-ward gate line (" .. g.lo .. ") clears the folds contour (" .. folds_lo .. ")")
  assert_true(g.hi - folds_hi > clearance,
    "the hot gate line (" .. g.hi .. ") clears the folds/crust contour (" .. folds_hi .. ")")
  assert_true(cracks:find("max(0, 64 - ", 1, true) == nil,
    "the main line keeps its established look: only the additive branch is gated")
  -- Tiles OUTSIDE the branch span carry no branch term at all: the crust above it and the
  -- ash-dark convergence below it are family-agnostic.
  for _, v in ipairs({ "volcanic-cracks-hot", "volcanic-ash-dark", "volcanic-ash-flats", "ice-smooth" }) do
    assert_true(terrain.probability_expr("cindra-" .. v):find("seed1 = 60", 1, true) == nil,
      "cindra-" .. v .. " is outside the branch and carries no branch gate")
  end
end)

test("a middle tile carries a value-band term; soil carries a gated patch term", function()
  local flats = terrain.probability_expr("cindra-volcanic-ash-flats")
  contains(flats, "min(1, max(0,", "the middle value band uses the clamped field")
  local soil = terrain.probability_expr("cindra-volcanic-soil-dark")
  contains(soil, "seed1 = 50", "soil is gated by the low-frequency soil patch field")
end)

test("the world is finite perpendicular via the map-gen = the total width", function()
  local d = terrain.finite_dimension()
  assert_eq("width", d.key, "vertical orientation bounds the X axis (width)")
  assert_eq(800, d.value, "the finite dimension is the total ribbon width (sum of zones)")
  assert_eq(1080, terrain.finite_dimension({ middle = 400 }).value, "tracks the widths")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
