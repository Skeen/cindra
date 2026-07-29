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

package.path = package.path .. ";./?.lua;./?/init.lua"
local field = require("scripts.decorative-field")

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

-- Defaults: safe_half_width 24, lethal_at 96, wall_at 128. Perpendicular axis is
-- sunward-positive; the hot (rocky/lava) zone is y > safe, the cold (icy) zone is
-- y < -safe, and |y| <= safe is the decal-free temperate terminator.

test("rocks/craters live on the hot half; ice/snow on the cold half", function()
  assert_true(field.hot_zone(60), "rocks out on the hot margin")
  assert_true(field.hot_zone(120), "rocks to the lava edge")
  assert_true(not field.hot_zone(0), "no rocks on the temperate terminator")
  assert_true(not field.hot_zone(-60), "no rocks on the cold (icy) half")
  assert_true(field.cold_zone(-60), "ice/snow on the cold half")
  assert_true(field.cold_zone(-120), "ice/snow to the deep-ice edge")
  assert_true(not field.cold_zone(0), "no ice/snow on the temperate terminator")
  assert_true(not field.cold_zone(60), "no ice/snow on the hot (rocky/lava) half")
end)

-- Zone purity (mirrors the ci-7w0 stone/ice rule for decoratives): a HOT decal must
-- NEVER be eligible in the cold zone and a COLD decal NEVER in the hot zone, across
-- the WHOLE perpendicular axis, so a boundary drift or off-by-one is caught. The two
-- zones share the safe-band divider and never overlap.
test("hot and cold decal zones NEVER overlap (no rock on ice, no snow in lava)", function()
  local S, W = 24, 128
  for y = -W - 20, W + 20 do
    assert_true(not (field.hot_zone(y) and field.cold_zone(y)),
      "hot and cold decal zones overlap at y=" .. y)
    if y > S then
      assert_true(field.hot_zone(y) and not field.cold_zone(y), "expected hot-only at y=" .. y)
    elseif y < -S then
      assert_true(field.cold_zone(y) and not field.hot_zone(y), "expected cold-only at y=" .. y)
    else
      assert_true(not field.hot_zone(y) and not field.cold_zone(y),
        "temperate band must be decal-free at y=" .. y)
    end
  end
end)

test("zone purity holds under a settings-driven config override too", function()
  local cfg = { safe_half_width = 8, lethal_at = 60, wall_at = 100 }
  for y = -120, 120 do
    assert_true(not (field.hot_zone(y, cfg) and field.cold_zone(y, cfg)),
      "zones overlap under override at y=" .. y)
    if y > 8 then assert_true(field.hot_zone(y, cfg), "hot zone at y=" .. y) end
    if y < -8 then assert_true(field.cold_zone(y, cfg), "cold zone at y=" .. y) end
  end
end)

-- The zone masks (emitted as noise-expression DSL strings) MUST describe the same
-- boundaries as the numeric predicates. Default orientation is vertical (hot on the
-- LEFT), so the sunward-positive perpendicular axis is "(0 - x)".
test("hot mask covers the sunward (rocky/lava) half beyond the safe band", function()
  assert_eq("((0 - x) > 24)", field.hot_mask_expr(), "default hot mask")
  assert_eq("((0 - x) > 8)", field.hot_mask_expr({ safe_half_width = 8 }), "override honoured")
end)

test("cold mask covers the nightward (icy) half beyond the safe band", function()
  assert_eq("((0 - x) < -24)", field.cold_mask_expr(), "default cold mask")
  assert_eq("((0 - x) < -8)", field.cold_mask_expr({ safe_half_width = 8 }), "override honoured")
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
      assert_true(expr:find("(0 - x) < -24", 1, true) ~= nil, spec.name .. " gated to the cold zone")
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
