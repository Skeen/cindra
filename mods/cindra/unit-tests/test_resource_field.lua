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

-- Default bounds. terrain.resource_bounds: building_half 100, building_lo -100 (the
-- stone/ice divider), hot_edge 350 (walkable hot = lava-crust), cold_edge -450 (cap
-- edge). But HARVESTABLE FIELDS are clamped to the DAMAGE-FREE band (ci-fb9): heat
-- damage starts at perp 300 (zones 1-3), cold at -200 (zone 11), so stone lives on
-- [-100, 300) and ice on (-200, -100) -- both strictly OUT of the damage zones.

test("stone lives on the building ribbon + SAFE hot margin, not on the cold cap", function()
  assert_true(field.stone_richness(0) > 0, "stone at the terminator centre")
  assert_true(field.stone_richness(290) > 0, "stone out to the SAFE hot margin (below the heat band)")
  assert_eq(0, field.stone_richness(-200), "no stone on the cold cap")
  assert_eq(0, field.stone_richness(300), "no stone AT the heat damage boundary (ci-fb9)")
  assert_eq(0, field.stone_richness(340), "no stone in the heat damage zone / lava-crust (ci-fb9)")
  assert_eq(0, field.stone_richness(400), "no stone past the hot walkable margin (into the lava)")
end)

test("stone is richest toward the HOT (safe) edge (edge-pushing)", function()
  assert_true(field.stone_richness(290) > field.stone_richness(0),
    "sunward stone richer than central stone")
  assert_true(field.stone_richness(0) > field.stone_richness(-90),
    "richness falls off toward the cold edge of the stone band")
end)

test("ice lives on the SAFE cold margin only, richer deeper (colder)", function()
  assert_eq(0, field.ice_richness(0), "no ice in the temperate ribbon")
  assert_eq(0, field.ice_richness(200), "no ice on the hot side")
  assert_true(field.ice_richness(-150) > 0, "ice on the SAFE cold margin")
  assert_eq(0, field.ice_richness(-200), "no ice AT the cold damage boundary (ci-fb9)")
  assert_eq(0, field.ice_richness(-400), "no ice in the cold damage zone / deep-ice cap (ci-fb9)")
  assert_true(field.ice_richness(-190) > field.ice_richness(-110),
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

-- Damage-zone exclusion (ci-fb9): NO harvestable field (stone / ice) may generate
-- in a DAMAGE ZONE -- a resource on a lethal tile is visible-but-unreachable. Scan
-- the WHOLE perpendicular axis and assert stone/ice richness + zone are ZERO for
-- every lethal position, keyed off the SAME terrain.damage_bounds the tile damage
-- uses. Volcanic rocks (the hazard-reward exception) are intentionally NOT checked
-- here -- they are meant to live in the hot region.
test("stone + ice NEVER generate in a damage zone (heat 1-3 or cold 11)", function()
  local db = terrain.damage_bounds()
  local rb = terrain.resource_bounds()
  local saw_heat, saw_cold = false, false
  for p = rb.cold_edge - 20, rb.hot_edge + 20 do
    local lethal = terrain.lethal_at(p)
    if lethal == "heat" then
      saw_heat = true
      assert_eq(0, field.stone_richness(p), "stone in the HEAT damage zone at p=" .. p)
      assert_eq(0, field.ice_richness(p), "ice in the HEAT damage zone at p=" .. p)
      assert_true(not field.stone_zone(p), "stone_zone true in the HEAT damage zone at p=" .. p)
      assert_true(not field.ice_zone(p), "ice_zone true in the HEAT damage zone at p=" .. p)
    elseif lethal == "cold" then
      saw_cold = true
      assert_eq(0, field.stone_richness(p), "stone in the COLD damage zone at p=" .. p)
      assert_eq(0, field.ice_richness(p), "ice in the COLD damage zone at p=" .. p)
      assert_true(not field.stone_zone(p), "stone_zone true in the COLD damage zone at p=" .. p)
      assert_true(not field.ice_zone(p), "ice_zone true in the COLD damage zone at p=" .. p)
    end
  end
  assert_true(saw_heat, "scan covered the heat damage zone")
  assert_true(saw_cold, "scan covered the cold damage zone")
  -- The field bands stop STRICTLY short of the damage boundaries.
  assert_true(field.stone_richness(db.hot_from - 1) > 0, "stone reaches right up to (but not into) the heat band")
  assert_true(field.ice_richness(db.cold_from + 1) > 0, "ice reaches right up to (but not into) the cold band")
end)

test("damage-zone exclusion holds under a per-zone-width config override too", function()
  -- Shrink the heat crust + widen the ice cap: the damage boundaries move, and the
  -- field bands must track them (still zero resource on any lethal tile).
  local cfg = { lava_crust = 120, deep_ice = 400 }
  local rb = terrain.resource_bounds(cfg)
  for p = rb.cold_edge - 20, rb.hot_edge + 20 do
    if terrain.lethal_at(p, cfg) then
      assert_eq(0, field.stone_richness(p, cfg), "stone on a lethal tile under override at p=" .. p)
      assert_eq(0, field.ice_richness(p, cfg), "ice on a lethal tile under override at p=" .. p)
    end
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

test("stone mask spans the building ribbon + SAFE hot margin, short of the heat band", function()
  -- Hot edge clamped to the heat-damage boundary (perp 300), EXCLUSIVE (ci-fb9).
  assert_eq("((0 - x) >= -100) * ((0 - x) < 300)", field.stone_mask_expr(), "default stone band")
end)

test("ice mask covers the SAFE cold margin, short of the cold-lethal cap", function()
  -- Cold edge clamped to the cold-damage boundary (perp -200), EXCLUSIVE (ci-fb9).
  assert_eq("((0 - x) < -100) * ((0 - x) > -200)", field.ice_mask_expr(), "default ice band")
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
test("burned volcanic rocks live in the hot region only (ci-da2 zone bounds)", function()
  -- Re-banded to the zone geometry: perp in (building_half=100, hot_edge=350].
  assert_true(field.burned_rock_zone(150), "burned rocks in the volcanic band")
  assert_true(field.burned_rock_zone(340), "burned rocks out toward the lava (walkable) edge")
  assert_true(field.burned_rock_zone(101), "just sunward of the building band")
  assert_true(not field.burned_rock_zone(0), "NO burned rocks at the temperate building centre")
  assert_true(not field.burned_rock_zone(100), "NO burned rocks in the building band (boundary)")
  assert_true(not field.burned_rock_zone(-200), "NO burned rocks in the cold/ice zone")
  assert_true(not field.burned_rock_zone(400), "NO burned rocks in the impassable lava wall (past hot_edge)")
end)

test("burned-rock zone honours a per-zone-width config override", function()
  -- Widen the building band: its hot edge (building_half) moves out, so the burned
  -- rocks start further sunward and never inside the wider building band.
  local cfg = { building = 400 }
  local rb = terrain.resource_bounds(cfg)
  assert_true(field.burned_rock_zone(rb.building_half + 10, cfg), "just sunward of the wider building band")
  assert_true(not field.burned_rock_zone(rb.building_half - 10, cfg), "not inside the wider building band")
  assert_true(not field.burned_rock_zone(-10, cfg), "never in the cold zone")
  assert_true(not field.burned_rock_zone(rb.hot_edge + 10, cfg), "never past the walkable hot edge (into the lava wall)")
end)

test("burned-rock autoplace masks to the hot region and clusters toward the lava", function()
  local expr = field.burned_rock_probability_expr()
  local rb = terrain.resource_bounds()
  -- Confined to the hot margin on the perpendicular axis: sunward of the building
  -- band, in to the walkable hot edge (default hot = negative x, perp = "(0 - x)").
  assert_true(expr:find("(0 - x) > " .. rb.building_half, 1, true) ~= nil, "starts sunward of the building band")
  assert_true(expr:find("(0 - x) <= " .. rb.hot_edge, 1, true) ~= nil, "capped at the walkable hot edge")
  -- Clusters toward the lava: a clamped ramp from MIN to MAX probability.
  assert_true(expr:find("lerp(0.003, 0.02,", 1, true) ~= nil, "ramps MIN -> MAX toward the lava")
  assert_true(expr:find("clamp(", 1, true) ~= nil, "ramp fraction is clamped to the band")
  -- Never keyed off the cold axis, so it can never bleed into the ice zone.
  assert_true(expr:find("> -", 1, true) == nil, "no nightward (cold) bound (hot region only)")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
