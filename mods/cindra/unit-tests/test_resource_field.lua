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
-- the field edge a further FIELD_DAMAGE_MARGIN into the safe side; ci-poed widened that
-- margin to the fjord/meander displacement bound (MAX_DISPLACEMENT 14 + SPECKLE 1.5 + 6 =
-- 21.5), so stone lives on [-60, 108.5) and ice on (-108.5, -60) -- reaching INTO the
-- survivable edge margin ("reachable at a cost") but never onto a bled lethal fjord tile.
local M = field.FIELD_DAMAGE_MARGIN -- MAX_DISPLACEMENT 14 + SPECKLE_AMPLITUDE 1.5 + 6 = 21.5
local HOT_FIELD_EDGE = 130 - M  -- 108.5
local COLD_FIELD_EDGE = -130 + M -- -108.5

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

-- ci-poed: the keep-back margin must budget the FULL fjord/meander displacement, so a
-- resource can never land on a bled lethal tip (a lava-crust or ice fjord finger).
test("the keep-back margin budgets the full displacement bleed (ci-poed)", function()
  assert_true(field.FIELD_DAMAGE_MARGIN >= terrain.MAX_DISPLACEMENT,
    "the margin (" .. field.FIELD_DAMAGE_MARGIN .. ") covers the fjord/meander bleed (" ..
    terrain.MAX_DISPLACEMENT .. ")")
  assert_eq(terrain.MAX_DISPLACEMENT + terrain.SPECKLE_AMPLITUDE + 6, field.FIELD_DAMAGE_MARGIN,
    "the margin is the displacement bound + the speckle + a safety pad")
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

-- The native-autoplace band masks (emitted as noise-expression DSL strings) MUST
-- describe the same boundaries as the numeric richness_* fns. Default orientation is
-- vertical (hot on the LEFT), so the sunward-positive perpendicular axis is "(0 - x)".

test("stone mask spans the middle + survivable hot margin, short of the heat cap", function()
  local hot = tostring(130 - M) -- the field's hot edge (margin short of the heat cap)
  assert_eq("((0 - x) >= -60) * ((0 - x) < " .. hot .. ")", field.stone_mask_expr(), "default stone band")
end)

test("ice mask covers the survivable cold margin, short of the cold cap", function()
  local cold = tostring(-130 + M) -- the field's cold edge (margin short of the cold cap)
  assert_eq("((0 - x) < -60) * ((0 - x) > " .. cold .. ")", field.ice_mask_expr(), "default ice band")
end)

test("sandy-rock autoplace masks to the WARM middle across the WHOLE ribbon (ci-18n)", function()
  local expr = field.rock_probability_expr()
  assert_true(expr:find("(0 - x) <= 60", 1, true) ~= nil, "capped at the hot edge of the middle")
  assert_true(expr:find("(0 - x) >= -55", 1, true) ~= nil, "cold edge pulled warm of the ice divider")
  assert_true(expr:find("(0 - x) >= -60", 1, true) == nil, "no longer reaches the middle's cold edge")
  assert_true(expr:find("distance", 1, true) == nil, "no spawn-radius cutoff (rocks span the whole ribbon)")
end)

test("ice-rock autoplace masks to the safe cold band, never the lethal cold zone (ci-18n)", function()
  local expr = field.ice_rock_probability_expr()
  local d = terrain.damage_bounds()
  assert_true(expr:find("(0 - x) <= -60", 1, true) ~= nil, "starts at the cold edge of the middle (divider)")
  assert_true(expr:find("(0 - x) > " .. d.cold_from, 1, true) ~= nil, "capped warm of the lethal cold zone")
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
  assert_true(expr:find("(0 - x) > " .. v.lo, 1, true) ~= nil, "starts at the volcanic band's cold edge")
  assert_true(expr:find("(0 - x) <= " .. v.hi, 1, true) ~= nil, "capped at the walkable hot edge")
  assert_true(expr:find("lerp(0.003, 0.02,", 1, true) ~= nil, "ramps MIN -> MAX toward the lava")
  assert_true(expr:find("clamp(", 1, true) ~= nil, "ramp fraction is clamped to the band")
  assert_true(expr:find("> -", 1, true) == nil, "no nightward (cold) bound (hot region only)")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
