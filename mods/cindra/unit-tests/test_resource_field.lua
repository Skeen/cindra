-- Plain-Lua unit test for the pure resource-field geometry
-- (scripts/resource-field.lua; rebanded to the ci-wly 3-part heightmap zones). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_resource_field.lua
--
-- resource-field.lua is pure (no game.* / prototypes.*): it maps a perpendicular
-- coordinate to a per-band node richness, reading the zone geometry from
-- scripts/terrain.lua. This asserts the band boundaries and the edge-pushing richness
-- gradients (best nodes at the lethal margins) off the game entirely. The
-- factorio-test in tests/test_worldgen.lua asserts the same shape places real entities
-- under the runtime; keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local field = require("scripts.resource-field")
local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

-- The perpendicular axis the masks band on, read from the ONE source of truth
-- (scripts/axis.lua) rather than spelled out: it is the NOMINAL axis, i.e. the
-- world-gen-screen zone sliders' warp (ci-i4z), so a mask written against a raw x/y
-- would silently stop following the sliders.
local PERP = axis.perp_expr()
-- Numbers as the emitters format them (integral values keep no ".0").
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.6g", v)
end

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

-- Default bounds (ci-wly). terrain.resource_bounds: building_half 60, building_lo -60
-- (the stone/ice divider), hot_edge 190 (the walkable hot zone edge), cold_edge -390
-- (the ice ocean edge). HARVESTABLE FIELDS are clamped to stop short of the LETHAL
-- damage zone (ci-fb9): the positional damage_bounds put the heat band at perp 130
-- (hot_ocean+hot_inner) and the cold band at -130 (cold_inner+cold_ocean). ci-4iw pulls
-- the field edge a further FIELD_DAMAGE_MARGIN (9.5) into the safe side, so stone lives
-- on [-60, 120.5) and ice on (-120.5, -60) -- reaching INTO the survivable edge margin
-- (the outer slope, "reachable at a cost") while stopping visibly short of the lethal
-- ground. Keeping ore off an individual BLED lethal tile is the tile restriction's job,
-- not this margin's (ci-bgpm, asserted further down).
local M = 9.5 -- FIELD_DAMAGE_MARGIN (NOISE_AMPLITUDE 2 + SPECKLE_AMPLITUDE 1.5 + 6)
local HOT_FIELD_EDGE = 130 - M  -- 120.5
local COLD_FIELD_EDGE = -130 + M -- -120.5

test("stone lives on the middle + SAFE hot margin, not on the cold side", function()
  assert_true(field.stone_richness(0) > 0, "stone at the terminator centre")
  assert_true(field.stone_richness(90) > 0, "stone out into the survivable hot margin (edge-push, below the cap)")
  assert_eq(0, field.stone_richness(-90), "no stone on the cold side")
  assert_eq(0, field.stone_richness(HOT_FIELD_EDGE), "no stone AT the field's hot edge (a margin short of the heat cap, ci-4iw)")
  assert_eq(0, field.stone_richness(130), "no stone in the LETHAL heat zone (perp >= 130)")
  assert_eq(0, field.stone_richness(200), "no stone deep in the heat damage zone")
  assert_eq(0, field.stone_richness(300), "no stone in the lava ocean")
end)

test("stone is richest toward the HOT (safe) edge (edge-pushing)", function()
  assert_true(field.stone_richness(90) > field.stone_richness(0),
    "sunward stone richer than central stone")
  assert_true(field.stone_richness(0) > field.stone_richness(-40),
    "richness falls off toward the cold edge of the stone band")
end)

test("ice lives on the SAFE cold margin only, richer deeper (colder)", function()
  assert_eq(0, field.ice_richness(0), "no ice in the middle")
  assert_eq(0, field.ice_richness(90), "no ice on the hot side")
  assert_true(field.ice_richness(-100) > 0, "ice out into the survivable cold margin (edge-push)")
  assert_eq(0, field.ice_richness(COLD_FIELD_EDGE), "no ice AT the field's cold edge (a margin short of the cold cap, ci-4iw)")
  assert_eq(0, field.ice_richness(-130), "no ice in the LETHAL cold zone (perp <= -130)")
  assert_eq(0, field.ice_richness(-300), "no ice deep in the cold damage zone")
  assert_true(field.ice_richness(-100) > field.ice_richness(-70),
    "ice richer the deeper (colder) it gets")
end)

test("sandy bootstrap rocks scatter the WARM part of the middle, fading before ice (ci-18n)", function()
  assert_true(field.rock_zone(0), "rocks at the terminator")
  assert_true(field.rock_zone(60), "rocks to the hot edge of the middle")
  -- ci-18n: the cold edge is pulled a MARGIN warm of the middle's cold edge
  -- (building_lo -60 + ROCK_COLD_MARGIN 5 = -55), so the rocks fade before the frost.
  assert_true(field.rock_zone(-55), "rocks to the pulled-in (warm) cold edge")
  assert_true(not field.rock_zone(-60), "NO rocks at the middle's cold edge (fades before ice)")
  assert_true(not field.rock_zone(-58), "NO rocks in the cold margin next to the frost")
  assert_true(not field.rock_zone(90), "no rocks out in the hot margin")
  assert_true(not field.rock_zone(-200), "no rocks out on the cold side")
end)

-- Ice-rocks (ci-18n): the cold-side counterpart, in the SAFE cold/ice band -- cold of
-- the stone/ice divider (building_lo -60) but WARM of the lethal cold damage zone
-- (damage cold_from -130), so they are gatherable with no cold damage.
test("ice-rocks scatter the SAFE cold/ice band, never on the lethal cold zone (ci-18n)", function()
  local d = terrain.damage_bounds()
  assert_true(field.ice_rock_zone(-60), "ice-rocks at the cold edge of the middle (the divider)")
  assert_true(field.ice_rock_zone(-100), "ice-rocks out on the safe cold slope")
  assert_true(field.ice_rock_zone(-129), "ice-rocks right up to the lethal cold edge")
  assert_true(not field.ice_rock_zone(d.cold_from), "NO ice-rocks in the lethal cold zone (boundary)")
  assert_true(not field.ice_rock_zone(-200), "NO ice-rocks deep in the lethal cold side")
  assert_true(not field.ice_rock_zone(-40), "NO ice-rocks in the warm/temperate middle")
  assert_true(not field.ice_rock_zone(90), "NO ice-rocks on the hot side")
  -- The two rock scatters are mutually exclusive across the divider.
  for p = -400, 300 do
    assert_true(not (field.rock_zone(p) and field.ice_rock_zone(p)),
      "sandy and ice rock bands overlap at p=" .. p)
  end
end)

-- Zone purity (ci-7w0): STONE never placeable in the cold zone; ICE never in the
-- hot/temperate zone. Proven across the WHOLE perpendicular axis.
test("stone is NEVER placeable on the cold side; ice NEVER in the hot/temperate zone", function()
  local rb = terrain.resource_bounds()
  for p = rb.cold_edge - 20, rb.building_half + 300 do
    if p < rb.building_lo then
      assert_eq(0, field.stone_richness(p), "stone leaked into the cold zone at p=" .. p)
      assert_true(not field.stone_zone(p), "stone_zone true in the cold zone at p=" .. p)
    end
    if p >= rb.building_lo then
      assert_eq(0, field.ice_richness(p), "ice leaked into the hot/temperate zone at p=" .. p)
      assert_true(not field.ice_zone(p), "ice_zone true in the hot/temperate zone at p=" .. p)
    end
    assert_true(not (field.stone_zone(p) and field.ice_zone(p)),
      "stone and ice zones overlap at p=" .. p)
  end
end)

-- Lethal-zone exclusion (ci-fb9) + keep-back margin (ci-4iw): NO harvestable field may
-- generate in the LETHAL damage zone. Scan the WHOLE axis and assert zero field for
-- every lethal position AND the whole margin band.
test("stone + ice NEVER generate in the lethal zone NOR its bled margin (ci-fb9, ci-4iw)", function()
  local db = terrain.damage_bounds()
  local m = field.FIELD_DAMAGE_MARGIN
  local rb = terrain.resource_bounds()
  local saw_heat, saw_cold = false, false
  for p = rb.cold_edge - 20, rb.hot_edge + 20 do
    local lethal = terrain.lethal_at(p)
    if lethal == "heat" or p >= db.hot_from - m then
      saw_heat = true
      assert_eq(0, field.stone_richness(p), "stone in the heat exclusion band at p=" .. p)
      assert_eq(0, field.ice_richness(p), "ice in the heat exclusion band at p=" .. p)
      assert_true(not field.stone_zone(p), "stone_zone true in the heat exclusion band at p=" .. p)
    elseif lethal == "cold" or p <= db.cold_from + m then
      saw_cold = true
      assert_eq(0, field.stone_richness(p), "stone in the cold exclusion band at p=" .. p)
      assert_eq(0, field.ice_richness(p), "ice in the cold exclusion band at p=" .. p)
      assert_true(not field.ice_zone(p), "ice_zone true in the cold exclusion band at p=" .. p)
    end
  end
  assert_true(saw_heat, "scan covered the heat lethal+margin band")
  assert_true(saw_cold, "scan covered the cold lethal+margin band")
  assert_true(field.stone_richness(db.hot_from - m - 1) > 0,
    "stone reaches the survivable hot margin (a margin short of the heat cap)")
  assert_true(field.ice_richness(db.cold_from + m + 1) > 0,
    "ice reaches the survivable cold margin (a margin short of the cold cap)")
  assert_eq(0, field.stone_richness(db.hot_from - 1), "no stone in the keep-back gap (heat)")
  assert_eq(0, field.ice_richness(db.cold_from + 1), "no ice in the keep-back gap (cold)")
end)

test("lethal-zone exclusion + margin holds under a per-zone-width config override too", function()
  -- Shrink the hot inner + widen the cold ocean: the damage boundaries move, and the
  -- field bands (with the margin) must track them.
  local cfg = { hot_inner = 120, cold_ocean = 400 }
  local db = terrain.damage_bounds(cfg)
  local m = field.FIELD_DAMAGE_MARGIN
  local rb = terrain.resource_bounds(cfg)
  for p = rb.cold_edge - 20, rb.hot_edge + 20 do
    if p >= db.hot_from - m or p <= db.cold_from + m then
      assert_eq(0, field.stone_richness(p, cfg), "stone in the lethal+margin band under override at p=" .. p)
      assert_eq(0, field.ice_richness(p, cfg), "ice in the lethal+margin band under override at p=" .. p)
    end
  end
end)

test("zone purity holds under a per-zone-width config override too", function()
  -- Widen the middle: the divider moves, but the guarantee holds.
  local cfg = { middle = 400 }
  local rb = terrain.resource_bounds(cfg)
  for p = rb.cold_edge - 10, rb.hot_edge + 200 do
    if p < rb.building_lo then assert_eq(0, field.stone_richness(p, cfg), "stone in cold zone at p=" .. p) end
    if p >= rb.building_lo then assert_eq(0, field.ice_richness(p, cfg), "ice in hot/temperate zone at p=" .. p) end
    assert_true(not (field.stone_zone(p, cfg) and field.ice_zone(p, cfg)),
      "zones overlap under override at p=" .. p)
  end
end)

test("bands honour a per-zone-width override (settings-driven tuning)", function()
  -- A wider middle -> rocks scatter across a wider centre; the divider moves.
  -- middle=400 -> building_half 200, building_lo -200, damage cold_from -270.
  local cfg = { middle = 400 }
  local db = terrain.damage_bounds(cfg)
  assert_true(field.rock_zone(180, cfg), "rocks reach further with a wider middle")
  assert_true(not field.rock_zone(220, cfg), "but not past the wider middle edge")
  assert_true(field.rock_zone(-195, cfg), "sandy cold edge tracks the moved divider + margin")
  assert_true(not field.rock_zone(-200, cfg), "sandy rocks still fade before the (moved) ice divider")
  -- Ice-rocks (finite, exempt) track the moved divider and the positional lethal cold edge.
  assert_true(field.ice_rock_zone(-200, cfg), "ice-rocks start at the moved divider")
  assert_true(field.ice_rock_zone(db.cold_from + 1, cfg), "ice-rocks up to the moved lethal cold edge")
  assert_true(not field.ice_rock_zone(db.cold_from, cfg), "ice-rocks never in the moved lethal zone")
  -- Ice FIELDS track the moved lethal cap minus the margin.
  local m = field.FIELD_DAMAGE_MARGIN
  assert_true(field.ice_richness(db.cold_from + m + 5, cfg) > 0, "ice on the (moved) survivable cold margin")
  assert_eq(0, field.ice_richness(db.cold_from + 1, cfg), "no ice in the keep-back margin off the (moved) cold cap (ci-4iw)")
end)

-- ci-bgpm: the positional margin above is a COSMETIC keep-back; what actually keeps ore
-- off lethal ground is the TILE restriction, because the tile family is chosen from the
-- noisy heightmap value and a lethal tile surfaces ~20 tiles inside the nominal safe side
-- (measured in-engine) -- far past any margin the band can afford. The pure geometry of
-- that gate is here; the proof that no ore tile lands on damaging ground on a real
-- (slider-maxed) surface is tests/test_worldgen_field_ground.lua.

test("a FIELD may generate ONLY on ground that deals no damage (ci-bgpm)", function()
  local allowed = field.field_tile_restriction()
  assert_true(#allowed > 0, "the fields must have somewhere to generate")
  for _, name in ipairs(allowed) do
    local intensity = terrain.tile_damage(name)
    assert_true(intensity <= 0, name .. " damages the player, so ore there is unmineable")
  end
end)

test("the field restriction BARS every damaging tile and no other (ci-bgpm)", function()
  local allowed = {}
  for _, name in ipairs(field.field_tile_restriction()) do allowed[name] = true end
  for _, name in ipairs(terrain.tile_names()) do
    local intensity = terrain.tile_damage(name)
    if intensity > 0 then
      assert_true(not allowed[name], name .. " burns/freezes you but may still carry ore")
    else
      -- No safe tile is barred: the fix must cost the bands NO width (the edge-push
      -- reward lives at the very edge of the band).
      assert_true(allowed[name], name .. " is safe ground but is barred from carrying ore")
    end
  end
end)

test("the field restriction tracks the value ramp, never a hand-written tile list", function()
  -- It IS terrain's own damage-free set, so retuning the ramp (or adding a tile) moves it.
  local a, b = field.field_tile_restriction(), terrain.tiles_by_damage(nil)
  assert_eq(#b, #a, "the field restriction must be terrain's damage-free tile set")
  local set = {}
  for _, n in ipairs(a) do set[n] = true end
  for _, n in ipairs(b) do assert_true(set[n], n .. " missing from the field restriction") end
  -- ...and it is disjoint from the ground the GLOWING volcanic rocks stand on (ci-w87):
  -- the rocks are the deliberate hazard-reward, the fields are never a hazard.
  for _, n in ipairs(field.burned_rock_tile_restriction(field.BURNED_ROCK_HOT)) do
    assert_true(not set[n], n .. " burns, so a field must not be allowed on it")
  end
end)

-- The native-autoplace band masks (emitted as noise-expression DSL strings) MUST
-- describe the same boundaries as the numeric richness_* fns, on the nominal
-- perpendicular axis (PERP above).

test("stone mask spans the middle + survivable hot margin, short of the heat cap", function()
  assert_eq("(" .. PERP .. " >= -60) * (" .. PERP .. " < 120.5)", field.stone_mask_expr(),
    "default stone band")
end)

test("ice mask covers the survivable cold margin, short of the cold cap", function()
  assert_eq("(" .. PERP .. " < -60) * (" .. PERP .. " > -120.5)", field.ice_mask_expr(),
    "default ice band")
end)

test("sandy-rock autoplace masks to the WARM middle across the WHOLE ribbon (ci-18n)", function()
  local expr = field.rock_probability_expr()
  assert_true(expr:find(PERP .. " <= 60", 1, true) ~= nil, "capped at the hot edge of the middle")
  assert_true(expr:find(PERP .. " >= -55", 1, true) ~= nil, "cold edge pulled warm of the ice divider")
  assert_true(expr:find(PERP .. " >= -60", 1, true) == nil, "no longer reaches the middle's cold edge")
  assert_true(expr:find("distance", 1, true) == nil, "no spawn-radius cutoff (rocks span the whole ribbon)")
end)

test("ice-rock autoplace masks to the safe cold band, never the lethal cold zone (ci-18n)", function()
  local expr = field.ice_rock_probability_expr()
  local d = terrain.damage_bounds()
  assert_true(expr:find(PERP .. " <= -60", 1, true) ~= nil, "starts at the cold edge of the middle (divider)")
  assert_true(expr:find(PERP .. " > " .. num(d.cold_from), 1, true) ~= nil,
    "capped warm of the lethal cold zone")
  assert_true(expr:find("distance", 1, true) == nil, "no spawn-radius cutoff (ice-rocks span the whole cold cap)")
end)

test("edge-pushing richness multipliers ramp 1 -> peak/base toward the margins", function()
  local mult = field.stone_richness_mult_expr()
  assert_true(mult:find("lerp%(1, ", 1) ~= nil, "starts at 1x at the near edge")
  assert_true(mult:find("clamp%(", 1) ~= nil, "clamped to the band fraction")
  assert_true(field.ice_richness_mult_expr():find("%(-60 %- ", 1) ~= nil, "ice ramps with cold depth")
end)

-- Burned volcanic rocks (ci-qy0): confined to the VOLCANIC-TILE region proper
-- (terrain.cliff_band: hot_inner + hot_outer). NEVER in the middle or the cold side.
test("burned volcanic rocks live in the volcanic-tile region only (ci-18n tighten)", function()
  local v = terrain.cliff_band() -- default lo=60 (middle edge), hi=190 (lava ocean edge)
  assert_true(field.burned_rock_zone(100), "burned rocks in the volcanic band")
  assert_true(field.burned_rock_zone(150), "burned rocks out toward the lava edge")
  assert_true(field.burned_rock_zone(v.lo + 1), "just sunward of the volcanic band's cold edge")
  assert_true(not field.burned_rock_zone(v.lo), "NO burned rocks at the volcanic band boundary")
  assert_true(not field.burned_rock_zone(40), "NO burned rocks in the middle (non-volcanic)")
  assert_true(not field.burned_rock_zone(0), "NO burned rocks at the temperate middle centre")
  assert_true(not field.burned_rock_zone(-100), "NO burned rocks on the cold/ice side")
  assert_true(not field.burned_rock_zone(250), "NO burned rocks in the lava ocean (past the volcanic edge)")
end)

test("burned-rock zone honours a per-zone-width config override", function()
  local cfg = { middle = 400 }
  local v = terrain.cliff_band(cfg)
  assert_true(field.burned_rock_zone(v.lo + 10, cfg), "just sunward of the (moved) volcanic band edge")
  assert_true(not field.burned_rock_zone(v.lo - 10, cfg), "not inside the middle below the volcanic band")
  assert_true(not field.burned_rock_zone(-10, cfg), "never in the cold zone")
  assert_true(not field.burned_rock_zone(v.hi + 10, cfg), "never past the walkable hot edge (into the lava ocean)")
end)

test("burned-rock autoplace masks to the volcanic band and clusters toward the lava", function()
  local expr = field.burned_rock_probability_expr()
  local v = terrain.cliff_band()
  assert_true(expr:find(PERP .. " > " .. num(v.lo), 1, true) ~= nil, "starts at the volcanic band's cold edge")
  assert_true(expr:find(PERP .. " <= " .. num(v.hi), 1, true) ~= nil, "capped at the walkable hot edge")
  assert_true(expr:find("lerp(0.003, 0.02,", 1, true) ~= nil, "ramps MIN -> MAX toward the lava")
  assert_true(expr:find("clamp(", 1, true) ~= nil, "ramp fraction is clamped to the band")
  assert_true(expr:find("> -", 1, true) == nil, "no nightward (cold) bound (hot region only)")
end)

-- ---------------------------------------------------------------------------
-- ci-w87: the volcanic band splits at the LAVA EDGE, so the rock you see tells you
-- whether the ground under it burns. The pure geometry of that split is here; the
-- proof that the right MODEL generates on each side is tests/test_worldgen.lua.
-- ---------------------------------------------------------------------------

test("the lava edge IS the heat-damage boundary (one shared line, ci-w87)", function()
  assert_eq(terrain.damage_bounds().hot_from, field.lava_edge(),
    "the model boundary must be the same line the ground starts burning at")
  local cfg = { hot_inner = 30 }
  assert_eq(terrain.damage_bounds(cfg).hot_from, field.lava_edge(cfg),
    "it tracks a moved zone geometry, never a hardcoded position")
end)

-- The model is chosen by the TILE, not by the coordinate, precisely because the two
-- disagree near the boundary: the bands are painted with a boundary wiggle plus a
-- per-tile speckle in FIELD units, and on the gentle hot slope that speckle is worth
-- several tiles -- glowing crust really does appear well warmward of lava_edge. A
-- position gate would therefore stand plain rocks on burning ground.
test("a GLOWING model may stand ONLY on ground that burns (ci-w87)", function()
  local hot = field.burned_rock_tile_restriction(field.BURNED_ROCK_HOT)
  assert_true(#hot > 0, "the hot models have somewhere to stand")
  for _, name in ipairs(hot) do
    local intensity, kind = terrain.tile_damage(name)
    assert_eq("heat", kind, name .. " is not burning ground")
    assert_true(intensity > 0, name .. " does no damage, so a glowing rock there lies")
  end
end)

test("a PLAIN model may stand ONLY on ground that does not burn (ci-w87)", function()
  local cool = field.burned_rock_tile_restriction(field.BURNED_ROCK)
  assert_true(#cool > 0, "the cool models have somewhere to stand")
  for _, name in ipairs(cool) do
    local intensity = terrain.tile_damage(name)
    assert_true(intensity <= 0, name .. " damages the player, so a plain rock there lies")
  end
end)

test("the two volcanic restrictions PARTITION the tiles: no gap, no overlap (ci-w87)", function()
  local hot_set = {}
  for _, n in ipairs(field.burned_rock_tile_restriction(field.BURNED_ROCK_HOT)) do hot_set[n] = true end
  local cool_set = {}
  for _, n in ipairs(field.burned_rock_tile_restriction(field.BURNED_ROCK)) do cool_set[n] = true end
  for _, name in ipairs(terrain.tile_names()) do
    local _, kind = terrain.tile_damage(name)
    local intensity = terrain.tile_damage(name)
    assert_true(not (hot_set[name] and cool_set[name]), name .. " qualifies for both models")
    -- Every tile a volcanic rock could land on takes exactly one model. Cold-damaging
    -- ground is the one exclusion, and no volcanic rock reaches it (the band mask).
    if not (intensity > 0 and kind == "cold") then
      assert_true(hot_set[name] or cool_set[name], name .. " would carry no volcanic model")
    end
  end
end)

test("each volcanic PROTOTYPE gets the restriction its model needs (ci-w87)", function()
  for _, name in ipairs(field.burned_rock_names()) do
    local tiles = field.burned_rock_tile_restriction(name)
    assert_true(#tiles > 0, name .. " must have somewhere to stand")
    for _, t in ipairs(tiles) do
      local intensity, kind = terrain.tile_damage(t)
      local burns = intensity > 0 and kind == "heat"
      assert_eq(field.is_hot_burned_rock(name), burns,
        name .. " allowed on " .. t .. ", which is the wrong ground for its model")
    end
  end
end)

test("splitting the volcanic family does NOT change the band or its density (ci-w87)", function()
  -- All four models share the one band expression; only tile_restriction differs, so
  -- the hot region carries exactly the rock it carried before the split.
  local expr = field.burned_rock_probability_expr()
  local v = terrain.cliff_band()
  assert_true(expr:find(PERP .. " > " .. num(v.lo), 1, true) ~= nil, "still the volcanic band")
  assert_true(expr:find("lerp(0.003, 0.02,", 1, true) ~= nil, "still the full density ramp")
  assert_true(expr:find(tostring(field.lava_edge()), 1, true) == nil,
    "the lava edge must NOT appear as a position gate -- the tile decides the model")
end)

-- ci-pxlz: the hand-gathered bootstrap rocks (sandy + ice) may stand only on ground that
-- does no damage. These pin the GATE ITSELF -- that the tile list really is damage-free,
-- really is all of the damage-free ground, and really is terrain's own set rather than a
-- hand-maintained copy. What the gate DOES to a generated world is asserted behaviourally
-- in tests/test_worldgen_rock_ground.
test("a bootstrap rock may stand ONLY on ground that does no damage (ci-pxlz)", function()
  local tiles = field.bootstrap_rock_tile_restriction()
  assert_true(#tiles > 0, "the bootstrap rocks have somewhere to stand")
  for _, name in ipairs(tiles) do
    local intensity, kind = terrain.tile_damage(name)
    assert_true(intensity <= 0,
      name .. " deals " .. tostring(kind) .. " damage, so a rock you walk out to mine there hurts")
  end
end)

test("NO safe tile is barred to the bootstrap rocks -- the bands keep their reach (ci-pxlz)", function()
  -- The other half of the gate, and the one that stops "fix the damage by shrinking the
  -- scatter": every damage-free Cindra tile must still qualify, so the restriction can
  -- only ever remove the bled lethal ground and never trims the band itself.
  local allowed = {}
  for _, n in ipairs(field.bootstrap_rock_tile_restriction()) do allowed[n] = true end
  for _, name in ipairs(terrain.tile_names()) do
    local intensity = terrain.tile_damage(name)
    if intensity <= 0 then
      assert_true(allowed[name], name .. " is safe ground but carries no bootstrap rock")
    else
      assert_true(not allowed[name], name .. " damages the player but is allowed anyway")
    end
  end
end)

test("the bootstrap gate is terrain's OWN damage-free set, not a copy (ci-pxlz)", function()
  -- If the two ever drift, a retuned value ramp would move the damage belts and leave the
  -- rock gate behind -- which is exactly how ci-18n's positional promise went stale.
  local from_terrain = terrain.tiles_by_damage(nil)
  local from_field = field.bootstrap_rock_tile_restriction()
  assert_eq(#from_terrain, #from_field, "the gate must track terrain's damage-free set")
  local set = {}
  for _, n in ipairs(from_terrain) do set[n] = true end
  for _, n in ipairs(from_field) do
    assert_true(set[n], n .. " is allowed a rock but is not in terrain's damage-free set")
  end
  -- ...and it is the SAME rule the plain volcanic boulders already stand on, so the two
  -- cannot disagree about what "safe ground" means.
  assert_eq(#from_terrain, #field.burned_rock_tile_restriction(field.BURNED_ROCK),
    "the plain volcanic rocks and the bootstrap rocks must share one notion of safe ground")
end)

test("the ROCK_COLD_MARGIN fade is NOT what keeps rocks off lethal ground (ci-pxlz)", function()
  -- ci-18n sized the margin against the noise amplitudes and read it as a damage
  -- guarantee. It never was one: the speckle is a FIELD-unit tie-break, so the tile bleed
  -- is many times the amplitude sum. Pin the margin as the cosmetic fade it is, so nobody
  -- re-derives a safety promise from it.
  assert_true(field.ROCK_COLD_MARGIN < terrain.NOISE_AMPLITUDE + terrain.SPECKLE_AMPLITUDE + 20,
    "the margin is a fade, not a bleed budget -- it cannot cover the real tile bleed")
  local d = terrain.damage_bounds()
  local b = terrain.resource_bounds()
  -- The ice-rock band still runs right up to the nominal cold-damage boundary: the fix is
  -- a tile gate, NOT a retreat, so the band must not have been pulled inland.
  assert_true(field.ice_rock_zone(d.cold_from + 1), "the ice-rock band still reaches the icy edge")
  assert_true(not field.ice_rock_zone(d.cold_from), "...and still stops at the lethal cap")
  assert_true(field.ice_rock_zone(b.building_lo), "...and still starts at the stone/ice divider")
end)

-- ci-w87: the cold rocks come in two iceberg sizes now. Adding a size must change what
-- the player SEES, not how buried the ground is -- the ci-tizx legibility budget.
test("the ice-rock sizes SPLIT one scatter, they do not add a second (ci-w87)", function()
  local total = 0
  for _, name in ipairs(field.ice_rock_names()) do
    local share = field.ICE_ROCK_SHARE[name]
    assert_true(share and share > 0, name .. " must declare a positive share of the scatter")
    total = total + share
  end
  assert_true(math.abs(total - 1) < 1e-9,
    "the size shares must sum to 1 (got " .. total .. "); more rock art must not mean more rocks")
end)

test("each ice-rock size autoplaces in the SAME safe cold band, at its share (ci-w87)", function()
  local d = terrain.damage_bounds()
  local whole = field.ice_rock_probability_expr()
  for _, name in ipairs(field.ice_rock_names()) do
    local expr = field.ice_rock_probability_expr(nil, name)
    assert_true(expr:find(PERP .. " <= -60", 1, true) ~= nil, name .. " starts at the divider")
    assert_true(expr:find(PERP .. " > " .. num(d.cold_from), 1, true) ~= nil,
      name .. " stays warm of the lethal cold zone")
    -- Same band as the un-split expression: only the trailing probability differs.
    local band = expr:match("^(.-)%s%*%s[%d%.]+$")
    assert_true(band ~= nil and whole:find(band, 1, true) == 1,
      name .. " must share the whole band's mask; got " .. expr)
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
