-- Plain-Lua unit test for the pure resource-field geometry
-- (scripts/resource-field.lua; rebanded to the ci-da2 zones). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_resource_field.lua
--
-- resource-field.lua is pure (no game.* / prototypes.*): it maps a perpendicular
-- coordinate to a per-band node richness, reading the zone geometry from
-- scripts/terrain.lua. This asserts the band boundaries and the edge-pushing
-- richness gradients (best nodes at the lethal margins) off the game entirely. The
-- factorio-test in tests/test_worldgen.lua asserts the same shape places real
-- entities under the runtime; keep the two in sync.

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

-- Default bounds (from terrain.resource_bounds): building_half 100, building_lo
-- -100 (the stone/ice divider), hot_edge 350 (outer walkable hot = lava-crust),
-- cold_edge -450 (the cold cap edge).

test("stone lives on the building ribbon + hot margin, not on the cold cap", function()
  assert_true(field.stone_richness(0) > 0, "stone at the terminator centre")
  assert_true(field.stone_richness(340) > 0, "stone out to the hot (lava-crust) margin")
  assert_eq(0, field.stone_richness(-200), "no stone on the cold cap")
  assert_eq(0, field.stone_richness(400), "no stone past the hot walkable margin (into the lava)")
end)

test("stone is richest toward the HOT edge (edge-pushing)", function()
  assert_true(field.stone_richness(340) > field.stone_richness(0),
    "sunward stone richer than central stone")
  assert_true(field.stone_richness(0) > field.stone_richness(-90),
    "richness falls off toward the cold edge of the stone band")
end)

test("ice lives on the cold cap only, richer deeper (colder)", function()
  assert_eq(0, field.ice_richness(0), "no ice in the temperate ribbon")
  assert_eq(0, field.ice_richness(200), "no ice on the hot side")
  assert_true(field.ice_richness(-200) > 0, "ice on the cold cap")
  assert_true(field.ice_richness(-400) > field.ice_richness(-150),
    "ice richer the deeper (colder) it gets")
end)

test("bootstrap rocks scatter only across the building band", function()
  assert_true(field.rock_zone(0), "rocks at the terminator")
  assert_true(field.rock_zone(100), "rocks to the hot edge of the building band")
  assert_true(field.rock_zone(-100), "rocks to the cold edge of the building band")
  assert_true(not field.rock_zone(200), "no rocks out in the hot margin")
  assert_true(not field.rock_zone(-200), "no rocks out on the cold cap")
end)

-- Zone purity (ci-7w0): the mutually-exclusive placement rule proven off the game.
-- STONE must NEVER be placeable in the cold zone; ICE must NEVER be placeable in the
-- hot/temperate zone. Prove it across the WHOLE perpendicular axis so a boundary
-- drift or off-by-one in either mask is caught.
test("stone is NEVER placeable on the cold cap; ice NEVER in the hot/temperate zone", function()
  local rb = terrain.resource_bounds()
  for p = rb.cold_edge - 20, rb.building_half + 300 do
    -- Cold zone is p < building_lo. Stone must be absent there.
    if p < rb.building_lo then
      assert_eq(0, field.stone_richness(p), "stone leaked into the cold zone at p=" .. p)
      assert_true(not field.stone_zone(p), "stone_zone true in the cold zone at p=" .. p)
    end
    -- Hot + temperate zone is p >= building_lo. Ice must be absent there.
    if p >= rb.building_lo then
      assert_eq(0, field.ice_richness(p), "ice leaked into the hot/temperate zone at p=" .. p)
      assert_true(not field.ice_zone(p), "ice_zone true in the hot/temperate zone at p=" .. p)
    end
    -- The two placement zones NEVER overlap.
    assert_true(not (field.stone_zone(p) and field.ice_zone(p)),
      "stone and ice zones overlap at p=" .. p)
  end
end)

test("zone purity holds under a per-zone-width config override too", function()
  -- Widen the building area: the divider moves, but the guarantee holds.
  local cfg = { building = 400 }
  local rb = terrain.resource_bounds(cfg)
  for p = rb.cold_edge - 10, rb.hot_edge + 200 do
    if p < rb.building_lo then assert_eq(0, field.stone_richness(p, cfg), "stone in cold zone at p=" .. p) end
    if p >= rb.building_lo then assert_eq(0, field.ice_richness(p, cfg), "ice in hot/temperate zone at p=" .. p) end
    assert_true(not (field.stone_zone(p, cfg) and field.ice_zone(p, cfg)),
      "zones overlap under override at p=" .. p)
  end
end)

test("bands honour a per-zone-width override (settings-driven tuning)", function()
  -- A wider building band -> rocks scatter across a wider centre; the divider moves.
  local cfg = { building = 400 }
  assert_true(field.rock_zone(180, cfg), "rocks reach further with a wider building band")
  assert_true(not field.rock_zone(220, cfg), "but not past the wider building edge")
  assert_true(field.ice_richness(-250, cfg) > 0, "ice still on the (further-out) cold cap")
end)

-- The native-autoplace band masks (emitted as noise-expression DSL strings) MUST
-- describe the same boundaries as the numeric richness_* fns above. The DEFAULT
-- orientation is vertical (hot on the LEFT), so the sunward-positive perpendicular
-- axis is "(0 - x)"; scripts/axis.lua proves both orientations of that mapping.

test("stone mask spans the building ribbon + hot margin on the perpendicular axis", function()
  assert_eq("((0 - x) >= -100) * ((0 - x) <= 350)", field.stone_mask_expr(), "default stone band")
end)

test("ice mask covers the cold cap east of the divider", function()
  assert_eq("((0 - x) < -100) * ((0 - x) >= -450)", field.ice_mask_expr(), "default ice band")
end)

test("bootstrap-rock autoplace masks to the building band across the WHOLE ribbon", function()
  local expr = field.rock_probability_expr()
  assert_true(expr:find("(0 - x) < 100", 1, true) ~= nil, "capped at the hot edge of the building band")
  assert_true(expr:find("(0 - x) > -100", 1, true) ~= nil, "capped at the cold edge of the building band")
  -- BAND-WIDE, not a spawn disk (ci-9bb): NO `distance` cutoff.
  assert_true(expr:find("distance", 1, true) == nil, "no spawn-radius cutoff (rocks span the whole ribbon)")
end)

test("edge-pushing richness multipliers ramp 1 -> peak/base toward the margins", function()
  local mult = field.stone_richness_mult_expr()
  assert_true(mult:find("lerp%(1, ", 1) ~= nil, "starts at 1x at the near edge")
  assert_true(mult:find("clamp%(", 1) ~= nil, "clamped to the band fraction")
  -- The ice multiplier ramps with cold-cap depth (distance past the divider).
  assert_true(field.ice_richness_mult_expr():find("%(-100 %- ", 1) ~= nil, "ice ramps with cold-cap depth")
end)

-- Burned volcanic rocks (ci-qy0): confined to the HOT region (sunward of the safe
-- band, in to the wall), NEVER in the temperate/building band or the cold/ice zone.
test("burned volcanic rocks live in the hot region only", function()
  -- Defaults: safe_half_width 24, lethal_at 96, wall_at 128.
  assert_true(field.burned_rock_zone(30), "burned rocks just sunward of the safe band")
  assert_true(field.burned_rock_zone(90), "burned rocks out toward the lava edge")
  assert_true(field.burned_rock_zone(120), "burned rocks in the lava band, in to the wall")
  assert_true(not field.burned_rock_zone(0), "NO burned rocks at the temperate terminator")
  assert_true(not field.burned_rock_zone(24), "NO burned rocks in the safe/building band (boundary)")
  assert_true(not field.burned_rock_zone(-30), "NO burned rocks in the cold/ice zone")
  assert_true(not field.burned_rock_zone(-120), "NO burned rocks deep nightward")
  assert_true(not field.burned_rock_zone(140), "NO burned rocks past the wall")
end)

test("burned-rock zone honours a settings-driven config override", function()
  local cfg = { safe_half_width = 8, lethal_at = 60, wall_at = 100 }
  assert_true(field.burned_rock_zone(10, cfg), "just sunward of the narrower safe band")
  assert_true(not field.burned_rock_zone(8, cfg), "not inside the narrower safe band")
  assert_true(not field.burned_rock_zone(-10, cfg), "never in the cold zone")
  assert_true(not field.burned_rock_zone(110, cfg), "never past the narrower wall")
end)

test("burned-rock autoplace masks to the hot region and clusters toward the lava", function()
  local expr = field.burned_rock_probability_expr()
  -- Confined to the hot region on the perpendicular axis: sunward of the safe band,
  -- in to the wall (default hot = negative x, perp = "(0 - x)").
  assert_true(expr:find("(0 - x) > 24", 1, true) ~= nil, "starts sunward of the safe band")
  assert_true(expr:find("(0 - x) < 128", 1, true) ~= nil, "capped at the wall")
  -- Clusters toward the lava: a clamped ramp from MIN to MAX probability.
  assert_true(expr:find("lerp(0.003, 0.02,", 1, true) ~= nil, "ramps MIN -> MAX toward the lava")
  assert_true(expr:find("clamp(", 1, true) ~= nil, "ramp fraction is clamped to the band")
  -- Never keyed off the cold axis, so it can never bleed into the ice zone.
  assert_true(expr:find("> -", 1, true) == nil, "no nightward (cold) bound (hot region only)")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
