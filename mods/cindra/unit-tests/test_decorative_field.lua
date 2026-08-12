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

package.path = package.path .. ";./?.lua;./?/init.lua"
local field = require("scripts.decorative-field")
local terrain = require("scripts.terrain")

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

-- Defaults: safe_half_width 24, lethal_at 96, wall_at 128; the zone layout puts the
-- icy-ground edge (terrain damage cold_from) at -130. Perpendicular axis is
-- sunward-positive; the hot (rocky/lava) zone is y > safe, the cold (icy) zone is
-- y < cold_from, and everything between is decal-free habitable ground.
local COLD_START = terrain.damage_bounds().cold_from

test("rocks/craters live on the hot half; ice/snow only on the icy ground", function()
  assert_true(field.hot_zone(60), "rocks out on the hot margin")
  assert_true(field.hot_zone(120), "rocks to the lava edge")
  assert_true(not field.hot_zone(0), "no rocks on the temperate terminator")
  assert_true(not field.hot_zone(-60), "no rocks on the cold (icy) half")
  assert_true(field.cold_zone(COLD_START - 1), "ice/snow start at the icy-ground edge")
  assert_true(field.cold_zone(-200), "ice/snow out to the deep-ice ocean")
  assert_true(not field.cold_zone(0), "no ice/snow on the temperate terminator")
  assert_true(not field.cold_zone(60), "no ice/snow on the hot (rocky/lava) half")
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
  local S = 24
  for y = -420, 420 do
    assert_true(not (field.hot_zone(y) and field.cold_zone(y)),
      "hot and cold decal zones overlap at y=" .. y)
    if y > S then
      assert_true(field.hot_zone(y) and not field.cold_zone(y), "expected hot-only at y=" .. y)
    elseif y < COLD_START then
      assert_true(field.cold_zone(y) and not field.hot_zone(y), "expected cold-only at y=" .. y)
    else
      assert_true(not field.hot_zone(y) and not field.cold_zone(y),
        "habitable band must be decal-free at y=" .. y)
    end
  end
end)

test("zone purity holds under a settings-driven config override too", function()
  -- Narrower zones (the widths are startup settings) => the icy-ground edge moves,
  -- and the cold decal gate MUST move with it (one source of truth: terrain).
  local cfg = {
    safe_half_width = 8, lethal_at = 60, wall_at = 100,
    middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
    hot_outer = 30, hot_inner = 30, hot_ocean = 100,
  }
  local start = terrain.damage_bounds(cfg).cold_from
  assert_eq(start, field.cold_start(cfg), "cold gate tracks the moved icy-ground edge")
  assert_true(start ~= COLD_START, "the override really did move the boundary")
  for y = -200, 200 do
    assert_true(not (field.hot_zone(y, cfg) and field.cold_zone(y, cfg)),
      "zones overlap under override at y=" .. y)
    if y > 8 then assert_true(field.hot_zone(y, cfg), "hot zone at y=" .. y) end
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

-- The zone masks (emitted as noise-expression DSL strings) MUST describe the same
-- boundaries as the numeric predicates. Default orientation is vertical (hot on the
-- LEFT), so the sunward-positive perpendicular axis is "(0 - x)".
test("hot mask covers the sunward (rocky/lava) half beyond the safe band", function()
  assert_eq("((0 - x) > 24)", field.hot_mask_expr(), "default hot mask")
  assert_eq("((0 - x) > 8)", field.hot_mask_expr({ safe_half_width = 8 }), "override honoured")
end)

test("cold mask starts at the icy ground, not at the safe band (ci-tizx)", function()
  assert_eq("((0 - x) < " .. COLD_START .. ")", field.cold_mask_expr(), "default cold mask")
  -- The old gate (the ribbon safe band) must be gone: safe_half_width no longer
  -- controls where the frost starts.
  assert_true(field.cold_mask_expr({ safe_half_width = 8 }):find("-8", 1, true) == nil,
    "the safe band no longer gates the cold decals")
  local cfg = { middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
                hot_outer = 30, hot_inner = 30, hot_ocean = 100 }
  assert_eq("((0 - x) < " .. terrain.damage_bounds(cfg).cold_from .. ")",
    field.cold_mask_expr(cfg), "the mask tracks the zone widths")
end)

test("cold decals fade in over the ramp and are thinned by their density (ci-tizx)", function()
  assert_eq("clamp((" .. COLD_START .. " - (0 - x)) / " .. field.COLD_FADE_SPAN .. ", 0, 1)",
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
      assert_true(expr:find("(0 - x) > 24", 1, true) ~= nil, spec.name .. " gated to the hot zone")
    elseif spec.side == "cold" then
      cold_seen = true
      assert_true(expr:find("(0 - x) < " .. COLD_START, 1, true) ~= nil,
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
