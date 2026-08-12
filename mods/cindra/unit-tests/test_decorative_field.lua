-- Plain-Lua unit test for the pure decorative-zone geometry
-- (scripts/decorative-field.lua, ci-6fq). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_decorative_field.lua
--
-- decorative-field.lua is pure (no game.* / prototypes.*): it maps a ribbon
-- perpendicular coordinate to a decorative PLACEMENT ZONE (hot rocks/craters vs cold
-- ice/snow) and emits the autoplace noise-expression strings. This asserts the zone
-- split + purity (no rock in the icy zone, no snow in the lava zone) and that the
-- emitted probability expressions are self-contained (no cross-planet biome inputs).
-- The factorio-test in tests/test_decoratives.lua proves the same shape places real
-- decoratives under the runtime; keep the two in sync.
--
-- ci-tizx adds the cold-side legibility rules: the ice/snow decals start only where
-- the GROUND turns icy (never on the brown habitable band), fade in from there, and
-- are thinned by a per-decal density multiplier so the tiles read through.
--
-- ci-mk5y re-gates the HOT side onto the ci-wly heightmap TILES: the rock/crater decals
-- ride the volcanic slope + crust (a band bounded on BOTH sides, derived from the field's
-- own value crossings) instead of "everything sunward of the ribbon safe band" -- so no rock
-- lies on the molten lava and none is strewn across the brown ash middle.
--
-- ci-10ze thins the cold decals back OUT again once the ground becomes the smooth-ice OCEAN
-- SHEET, so the frozen sea reads as a sea instead of as the most cluttered ground on the
-- planet: full frost on the snow/rough-ice shore, a trace of it offshore, and a ramp between
-- the two (no stamped line). Gated on the smooth-ice TILE contour, not the ocean band edge.

package.path = package.path .. ";./?.lua;./?/init.lua"
local field = require("scripts.decorative-field")
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

local function assert_near(a, b, tol, msg)
  if math.abs(a - b) > tol then
    error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2)
  end
end

-- Defaults: the zone layout puts the icy-ground edge (terrain damage cold_from) at -130 and
-- the volcanic slope + crust between the field's ash and molten contours (~90.5 .. 154.5).
-- Perpendicular axis is sunward-positive; the hot (rock/crater) zone is field.hot_band, the
-- cold (icy) zone is y < cold_from, and everything between is decal-free habitable ground.
local COLD_START = terrain.damage_bounds().cold_from
local HOT = field.hot_band()
-- The axis the masks band on, from the ONE source of truth (scripts/axis.lua): the
-- NOMINAL axis, i.e. the world-gen-screen zone sliders' warp (ci-i4z). A mask written
-- against a raw x/y would silently stop following the sliders.
local PERP = axis.perp_expr()
-- Numbers as the emitters format them (integral values keep no ".0").
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.6g", v)
end

test("rocks/craters live on the volcanic slope; ice/snow only on the icy ground", function()
  assert_true(field.hot_zone(HOT.lo + 1), "rocks from the slope's ash edge")
  assert_true(field.hot_zone(120), "rocks out across the volcanic slope")
  assert_true(field.hot_zone(HOT.hi - 1), "rocks up to the lava contour")
  assert_true(not field.hot_zone(0), "no rocks on the temperate terminator")
  assert_true(not field.hot_zone(-60), "no rocks on the cold (icy) half")
  assert_true(field.cold_zone(COLD_START - 1), "ice/snow start at the icy-ground edge")
  assert_true(field.cold_zone(-200), "ice/snow out to the deep-ice ocean")
  assert_true(not field.cold_zone(0), "no ice/snow on the temperate terminator")
  assert_true(not field.cold_zone(60), "no ice/snow on the hot (rocky/lava) half")
end)

-- ci-mk5y: the hot gate used to be `perp > safe_half_width` (+24) with NO outer bound, which
-- put rocks and craters on the brown ash MIDDLE and straight out over the molten LAVA. The
-- band is now derived from the ONE heightmap field: it starts above the ash convergence and
-- STOPS short of the molten floor, with a margin at each end for the terrain's own contour
-- wiggle + speckle, so neither boundary can be crossed by a decal.
test("NO rock/crater decals on the molten lava, and none on the ash middle (ci-mk5y)", function()
  local span = field.hot_value_span()
  assert_eq(terrain.MOLTEN_FLOOR, span.hi, "the hot span stops at the molten floor")
  assert_eq(terrain.BRANCH_SPAN.lo, span.lo, "and starts at the slope's ash convergence")
  -- The gate lines sit strictly INSIDE the two tile contours, by more than the worst case a
  -- decal can drift: per-tile speckle (0.012 H) + a 2-tile boundary wiggle (<= 0.007 H) + a
  -- tile of placement granularity (<= 0.004 H) = ~0.023 H.
  local DRIFT = 0.023
  assert_true(field.HOT_MARGIN_H > DRIFT, "the gate margin clears the terrain's own noise")
  assert_true(terrain.field(HOT.hi) < span.hi - DRIFT, "the sunward line is clear of the lava")
  assert_true(terrain.field(HOT.lo) > span.lo + DRIFT, "the middle-ward line is clear of the ash")
  -- Nothing sunward of the lava contour, and nothing at/inside the habitable middle.
  local molten_at = terrain.field_crossing(terrain.MOLTEN_FLOOR)
  assert_true(HOT.hi < molten_at, "the band ends before the ground turns molten")
  for _, y in ipairs({ molten_at, molten_at + 20, 200, 300, 400 }) do
    assert_true(not field.hot_zone(y), "no rocks on the molten ground at y=" .. y)
  end
  local mid = terrain.role_band("middle")
  assert_true(HOT.lo > mid.hi, "the band starts beyond the habitable middle")
  for _, y in ipairs({ 0, 24, 30, mid.hi, 72 }) do
    assert_true(not field.hot_zone(y), "no rocks on the habitable band at y=" .. y)
  end
  -- The ground it CAN sit on is volcanic slope / crust only -- no lava, no ash middle, no
  -- cold-side tile.
  local ground = field.hot_ground_tiles()
  assert_true(ground["cindra-volcanic-cracks-warm"], "the safe cracks slope is rock ground")
  assert_true(ground["cindra-volcanic-folds-warm"], "so is the folds family (ci-72bw)")
  assert_true(ground["cindra-volcanic-smooth-stone-warm"], "and the hot crust")
  for _, name in ipairs({ "cindra-lava", "cindra-lava-hot", "cindra-volcanic-ash-dark",
                          "cindra-volcanic-ash-flats", "cindra-snow-flat", "cindra-ice-smooth" }) do
    assert_true(not ground[name], name .. " is NOT ground a rock decal may sit on")
  end
end)

-- ci-tizx: the cold decals used to start at the safe band (-24) and so carpeted the
-- ~100 tiles of BROWN habitable ground (ash + dust) between there and the icy belt.
-- The whole habitable band must now be free of ice/snow decals.
test("NO ice/snow decals anywhere on the brown habitable band (ci-tizx)", function()
  assert_true(not field.cold_zone(-24), "not at the old safe-band gate")
  assert_true(not field.cold_zone(-60), "not on the middle's cold edge")
  assert_true(not field.cold_zone(-100), "not out on the brown dust band")
  assert_true(not field.cold_zone(-129), "not on the last brown tile before the ice")
  assert_true(not field.cold_zone(COLD_START), "boundary is exclusive at the icy edge")
  -- The gate tracks the TERRAIN's own brown->snow boundary, not a hand-typed number.
  assert_eq(COLD_START, field.cold_start(), "cold decals start at the icy-ground edge")
end)

-- Zone purity (mirrors the ci-7w0 stone/ice rule for decoratives): a HOT decal must
-- NEVER be eligible in the cold zone and a COLD decal NEVER in the hot zone, across
-- the WHOLE perpendicular axis, so a boundary drift or off-by-one is caught. The two
-- zones are separated by the whole habitable band and never overlap.
test("hot and cold decal zones NEVER overlap (no rock on ice, no snow in lava)", function()
  for y = -420, 420 do
    assert_true(not (field.hot_zone(y) and field.cold_zone(y)),
      "hot and cold decal zones overlap at y=" .. y)
    if y > HOT.lo and y < HOT.hi then
      assert_true(field.hot_zone(y) and not field.cold_zone(y), "expected hot-only at y=" .. y)
    elseif y < COLD_START then
      assert_true(field.cold_zone(y) and not field.hot_zone(y), "expected cold-only at y=" .. y)
    else
      assert_true(not field.hot_zone(y) and not field.cold_zone(y),
        "decal-free outside both zones at y=" .. y)
    end
  end
end)

test("zone purity holds under a settings-driven config override too", function()
  -- Narrower zones (the widths are startup settings) => BOTH the icy-ground edge and the
  -- volcanic slope's contours move, and both decal gates MUST move with them (one source of
  -- truth: terrain).
  local cfg = {
    safe_half_width = 8, lethal_at = 60, wall_at = 100,
    middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
    hot_outer = 30, hot_inner = 30, hot_ocean = 100,
  }
  local start = terrain.damage_bounds(cfg).cold_from
  local hot = field.hot_band(cfg)
  assert_eq(start, field.cold_start(cfg), "cold gate tracks the moved icy-ground edge")
  assert_true(start ~= COLD_START, "the override really did move the boundary")
  assert_true(hot.lo ~= HOT.lo and hot.hi ~= HOT.hi, "the hot band moved with the widths")
  assert_true(hot.hi < terrain.field_crossing(terrain.MOLTEN_FLOOR, cfg),
    "still short of the (moved) molten contour")
  assert_true(hot.lo > terrain.role_band("middle", cfg).hi,
    "still beyond the (moved) habitable middle")
  for y = -200, 200 do
    assert_true(not (field.hot_zone(y, cfg) and field.cold_zone(y, cfg)),
      "zones overlap under override at y=" .. y)
    if y > hot.lo and y < hot.hi then
      assert_true(field.hot_zone(y, cfg), "hot zone at y=" .. y)
    else
      assert_true(not field.hot_zone(y, cfg), "outside the hot band at y=" .. y)
    end
    if y < start then assert_true(field.cold_zone(y, cfg), "cold zone at y=" .. y) end
    if y >= start and y <= 8 then
      assert_true(not field.cold_zone(y, cfg), "habitable band decal-free at y=" .. y)
    end
  end
end)

-- ci-tizx: the frost fades IN from the icy-ground edge, so there is no stamped line
-- where the decals begin, and it is thickest out by the ice wall.
test("cold decal density fades in from the icy edge to full near the ice wall", function()
  assert_eq(0, field.cold_fade(COLD_START), "zero density right at the edge")
  assert_eq(0, field.cold_fade(0), "zero density on the habitable band")
  assert_eq(0.5, field.cold_fade(COLD_START - field.COLD_FADE_SPAN / 2), "half way in")
  assert_eq(1, field.cold_fade(COLD_START - field.COLD_FADE_SPAN), "full at the span")
  assert_eq(1, field.cold_fade(-400), "still full out at the ice ocean")
  -- Monotonic nightward (no dip in the middle of the ramp).
  local prev = -1
  for y = COLD_START, COLD_START - field.COLD_FADE_SPAN - 20, -1 do
    local f = field.cold_fade(y)
    assert_true(f >= prev, "fade must not decrease at y=" .. y)
    prev = f
  end
end)

-- ci-10ze: the frost fades back OUT once the ground becomes the open smooth-ice sheet, so
-- the ocean reads as an ocean. The gate is the TILE contour of the frozen sea, which is a
-- long way warmward of the cold-ocean BAND edge -- gating on the band would have left the
-- ~12 tiles of sheet inside it carpeted (the ci-mk5y mistake, on the other side).
local SHEET_START = terrain.field_crossing(terrain.FROZEN_CEILING)

test("the ice-ocean gate is the smooth-ice TILE contour, not the ocean band edge (ci-10ze)", function()
  assert_eq(SHEET_START, field.ice_ocean_start(), "the gate is the frozen sea's own contour")
  -- It really is the tile boundary: the ground is the ocean sheet nightward of it and the
  -- rough-ice / snow SHORE warmward, so "thin it on the ocean tiles" is geometry, not hope.
  assert_eq("cindra-ice-smooth", terrain.value_tile(terrain.field(SHEET_START - 1)),
    "the ground nightward of the gate is the smooth-ice sheet")
  assert_eq("cindra-ice-smooth", terrain.value_tile(terrain.field(-400)), "out to the map edge")
  assert_true(terrain.value_tile(terrain.field(SHEET_START)) ~= "cindra-ice-smooth",
    "and the gate line itself is still the shore (boundary belongs to the shore)")
  -- The band edge would have been the wrong gate, by a wide margin.
  local ocean = terrain.role_band("cold_ocean")
  assert_true(SHEET_START > ocean.hi,
    "the sheet begins WARMWARD of the cold-ocean band edge (" .. SHEET_START .. " > " .. ocean.hi .. ")")
  assert_true(SHEET_START - ocean.hi > 10,
    "and by more than a rounding error -- a band-edge gate would leave carpeted ocean")
  -- The whole thinned region lies inside the cold decal zone (it is a thinning, not a
  -- second gate): everything nightward of the sheet edge is still eligible for frost.
  assert_true(field.cold_zone(SHEET_START), "the sheet edge is well inside the icy zone")
end)

test("cold decal density thins from full on the shore to a trace offshore (ci-10ze)", function()
  assert_eq(1, field.ocean_thin(SHEET_START), "full frost right at the shore line")
  assert_eq(1, field.ocean_thin(SHEET_START + 20), "and all the way back up the shore")
  assert_eq(1, field.ocean_thin(0), "the multiplier never touches the rest of the planet")
  assert_near(1 - (1 - field.OCEAN_DENSITY) / 2,
    field.ocean_thin(SHEET_START - field.OCEAN_FADE_SPAN / 2), 1e-9, "half thinned half way out")
  assert_near(field.OCEAN_DENSITY, field.ocean_thin(SHEET_START - field.OCEAN_FADE_SPAN), 1e-9,
    "fully thinned by the end of the span")
  assert_near(field.OCEAN_DENSITY, field.ocean_thin(-400), 1e-9, "and still thin at the map edge")
  -- Monotonic offshore: a ramp, never a step and never a dip.
  local prev = 2
  for y = SHEET_START, -420, -1 do
    local t = field.ocean_thin(y)
    assert_true(t <= prev, "the thinning must not increase offshore at y=" .. y)
    prev = t
  end
  -- Materially thinner, or the ocean still would not read as one.
  assert_true(field.OCEAN_DENSITY > 0, "a trace of frost survives (a bare sheet reads as a hole)")
  assert_true(field.OCEAN_DENSITY <= 0.25, "the open sea keeps at most a quarter of the shore's frost")
  -- And a ramp wide enough to be a gradient rather than a line.
  assert_true(field.OCEAN_FADE_SPAN >= 8, "the drop is spread over enough tiles to read as a fade")
end)

-- The composed positional coverage: none on the brown band (ci-tizx), thickest on the frost
-- shore, a trace on the open sea (ci-10ze). That ordering IS the legibility fix -- the
-- densest ground must be the narrow shore, never the vast sheet.
test("the cold half is thickest on the frost SHORE and sparsest on the open sea (ci-10ze)", function()
  assert_eq(0, field.cold_density(-100), "the brown habitable band still carries nothing")
  assert_eq(0, field.cold_density(COLD_START), "nor the icy edge itself")
  assert_eq(1, field.cold_density(SHEET_START + 5), "the frost shore carries full coverage")
  assert_near(field.OCEAN_DENSITY, field.cold_density(-300), 1e-9, "the open sea carries a trace")
  -- The peak of the whole cold-side profile is on the shore, warmward of the sheet.
  local peak_y, peak = nil, -1
  for y = COLD_START, -420, -1 do
    local d = field.cold_density(y)
    if d > peak then peak, peak_y = d, y end
  end
  assert_eq(1, peak, "the profile does reach full coverage somewhere")
  assert_true(peak_y > SHEET_START, "and it peaks on the SHORE, not out on the ocean sheet")
  assert_true(field.cold_density(-400) < field.cold_density(SHEET_START + 1) / 4,
    "the open sea is a small fraction of the shore's coverage")
end)

test("the ice-ocean thinning tracks the zone widths, like every other gate (ci-10ze)", function()
  local cfg = { middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
                hot_outer = 30, hot_inner = 30, hot_ocean = 100 }
  local start = field.ice_ocean_start(cfg)
  assert_eq(terrain.field_crossing(terrain.FROZEN_CEILING, cfg), start, "the moved sheet contour")
  assert_true(start ~= SHEET_START, "the override really did move the sheet edge")
  assert_eq("cindra-ice-smooth", terrain.value_tile(terrain.field(start - 1, cfg)),
    "still the smooth-ice sheet nightward of the moved gate")
  assert_eq(1, field.ocean_thin(start, cfg), "full frost at the moved shore line")
  assert_near(field.OCEAN_DENSITY, field.ocean_thin(start - field.OCEAN_FADE_SPAN, cfg), 1e-9,
    "thinned offshore of the moved shore line")
  -- The default gate is meaningless under the override (i.e. we did not bake a number in).
  assert_true(field.ocean_thin(SHEET_START, cfg) < 1,
    "the default contour is already offshore under the narrower widths")
end)

-- The zone masks (emitted as noise-expression DSL strings) MUST describe the same
-- boundaries as the numeric predicates. Default orientation is vertical (hot on the
-- LEFT); the emitted masks read the nominal perpendicular axis (PERP above).
test("hot mask is the two-sided volcanic slope band, not the ribbon safe band (ci-mk5y)", function()
  assert_eq("(" .. PERP .. " > 90.5) * (" .. PERP .. " < 154.5)", field.hot_mask_expr(), "default hot mask")
  -- The RIBBON's safe band no longer has anything to do with where rocks go: only the
  -- heightmap geometry (the zone widths) moves the gate.
  assert_eq(field.hot_mask_expr(), field.hot_mask_expr({ safe_half_width = 8 }),
    "the ribbon safe band no longer gates the rock decals")
  local cfg = { middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
                hot_outer = 30, hot_inner = 30, hot_ocean = 100 }
  local b = field.hot_band(cfg)
  assert_eq("(" .. PERP .. " > " .. num(b.lo) .. ") * (" .. PERP .. " < " .. num(b.hi) .. ")",
    field.hot_mask_expr(cfg), "the mask tracks the zone widths")
end)

test("cold mask starts at the icy ground, not at the safe band (ci-tizx)", function()
  assert_eq("(" .. PERP .. " < " .. num(COLD_START) .. ")", field.cold_mask_expr(), "default cold mask")
  -- The old gate (the ribbon safe band) must be gone: safe_half_width no longer
  -- controls where the frost starts.
  assert_true(field.cold_mask_expr({ safe_half_width = 8 }):find("-8", 1, true) == nil,
    "the safe band no longer gates the cold decals")
  local cfg = { middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
                hot_outer = 30, hot_inner = 30, hot_ocean = 100 }
  assert_eq("(" .. PERP .. " < " .. num(terrain.damage_bounds(cfg).cold_from) .. ")",
    field.cold_mask_expr(cfg), "the mask tracks the zone widths")
end)

test("cold decals fade in over the ramp and are thinned by their density (ci-tizx)", function()
  assert_eq("clamp((" .. num(COLD_START) .. " - " .. PERP .. ") / " .. num(field.COLD_FADE_SPAN) .. ", 0, 1)",
    field.cold_fade_expr(), "fade expression")
  for _, spec in ipairs(field.DECORATIVES) do
    local expr = field.probability_expr(spec)
    if spec.side == "cold" then
      -- Materially thinner than the mirrored vanilla density (the bead asks for
      -- ~1/3 to 1/2), and the thinning actually reaches the emitted expression.
      assert_true(spec.density ~= nil and spec.density <= 0.5,
        spec.name .. " keeps at most half the vanilla decal density")
      assert_true(expr:find("* " .. tostring(spec.density), 1, true) ~= nil,
        spec.name .. " multiplies its probability by its density")
      assert_true(expr:find("clamp(", 1, true) ~= nil, spec.name .. " rides the fade ramp")
    else
      -- The hot side is untouched by ci-tizx: no density scaling, no cold fade.
      assert_true(spec.density == nil, spec.name .. " (hot) keeps its native density")
      assert_true(expr:find("clamp(", 1, true) == nil, spec.name .. " (hot) has no cold fade")
    end
  end
end)

-- ci-10ze: the offshore thinning has to reach the EMITTED expression (the map-gen only ever
-- sees the string), on every cold decal and on no hot one.
test("every cold decal's emitted probability carries the ocean thinning (ci-10ze)", function()
  local thin = field.ocean_thin_expr()
  assert_eq("(1 - 0.88 * clamp((-188.333 - (0 - x)) / 24, 0, 1))", thin, "default thinning expression")
  -- It reads the SAME perpendicular axis as every other gate, and the same contour the
  -- numeric mirror uses (a hand-typed number here would drift from the geometry).
  assert_true(thin:find(field.PERP, 1, true) ~= nil, "the thinning reads the perpendicular axis")
  local cfg = { middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
                hot_outer = 30, hot_inner = 30, hot_ocean = 100 }
  assert_true(field.ocean_thin_expr(cfg):find(string.format("%.6g", field.ice_ocean_start(cfg)), 1, true) ~= nil,
    "the emitted contour tracks the zone widths")
  for _, spec in ipairs(field.DECORATIVES) do
    local expr = field.probability_expr(spec)
    if spec.side == "cold" then
      assert_true(expr:find(thin, 1, true) ~= nil, spec.name .. " thins on the ocean sheet")
    else
      assert_true(expr:find(thin, 1, true) == nil, spec.name .. " (hot) has no ocean thinning")
    end
  end
end)

-- The big snow-drift art (a ~6.6 x 4.6 tile decal) covers far more ground per
-- placement than the small ice/snowy decals, so it must be the sparsest of the three
-- -- otherwise it alone re-buries the tiles (ci-tizx).
test("the biggest cold decal is the sparsest", function()
  local by_name = {}
  for _, spec in ipairs(field.DECORATIVES) do by_name[spec.name] = spec end
  local drift = by_name["cindra-snow-drift-decal"]
  assert_true(drift.density < by_name["cindra-ice-decal"].density, "sparser than the ice decal")
  assert_true(drift.density < by_name["cindra-snowy-decal"].density, "sparser than the snowy decal")
end)

-- Every decorative's probability multiplies its base scatter by its side's zone mask,
-- and is SELF-CONTAINED: it references only core noise (random_penalty) and the
-- Cindra-owned peaks field, NEVER a Vulcanus/Aquilo biome input that does not exist
-- on Cindra (which would evaluate negative and place nothing).
test("each decorative's autoplace is zone-gated and self-contained", function()
  local hot_seen, cold_seen = false, false
  for _, spec in ipairs(field.DECORATIVES) do
    local expr = field.probability_expr(spec)
    assert_true(expr:find("random_penalty", 1, true) ~= nil, spec.name .. " uses core random scatter")
    assert_true(expr:find("cindra_decorative_peaks", 1, true) ~= nil, spec.name .. " rides the Cindra peaks field")
    -- No cross-planet biome coupling (the reason we mirror rather than reuse verbatim).
    for _, banned in ipairs({ "vulcanus_", "aquilo_", "moisture", "aux", "gleba_", "fulgora_" }) do
      assert_true(expr:find(banned, 1, true) == nil,
        spec.name .. " must not reference the cross-planet input '" .. banned .. "'")
    end
    if spec.side == "hot" then
      hot_seen = true
      assert_true(expr:find(field.hot_mask_expr(), 1, true) ~= nil,
        spec.name .. " gated to the volcanic slope band (both sides)")
    elseif spec.side == "cold" then
      cold_seen = true
      assert_true(expr:find(PERP .. " < " .. num(COLD_START), 1, true) ~= nil,
        spec.name .. " gated to the icy-ground zone")
    else
      error("decorative " .. spec.name .. " has an unknown side " .. tostring(spec.side))
    end
  end
  assert_true(hot_seen, "at least one hot (rock/crater) decorative")
  assert_true(cold_seen, "at least one cold (ice/snow) decorative")
end)

test("the catalogue covers rocks + craters + pebbles (hot) and ice + snow (cold)", function()
  local names = {}
  for _, n in ipairs(field.decorative_names()) do names[n] = true end
  -- Hot: rock decals + craters + pebbles.
  assert_true(names["cindra-volcanic-rock-medium"], "a rock decal")
  assert_true(names["cindra-volcanic-rock-small"] or names["cindra-volcanic-rock-tiny"], "a pebble decal")
  assert_true(names["cindra-crater-small"] and names["cindra-crater-large"], "craters")
  -- Cold: ice decals + light-snow decals.
  assert_true(names["cindra-ice-decal"], "an ice decal")
  assert_true(names["cindra-snowy-decal"] or names["cindra-snow-drift-decal"], "a light-snow decal")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
