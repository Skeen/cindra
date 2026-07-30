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
-- edge). HARVESTABLE FIELDS are clamped to stop short of the LETHAL damage zone
-- (ci-fb9): the positional damage_bounds put the heat cap at perp 77 (zones 1-3) and
-- the cold cap / ICE WALL at -51 (zone 11). ci-4iw pulls the field edge a further
-- FIELD_DAMAGE_MARGIN (9.5) into the safe side so noise-BLED lethal tiles near the
-- boundary stay field-free. So stone lives on [-25, 67.5) and ice on (-41.5, -25) --
-- reaching INTO the survivable edge margin (zone 4 / zone 10, the "reachable at a
-- cost" edge-push) but never onto the bled lethal cap/wall. (ci-qqt thin ribbon.)

test("stone lives on the building ribbon + SAFE hot margin, not on the cold cap", function()
  assert_true(field.stone_richness(0) > 0, "stone at the terminator centre")
  assert_true(field.stone_richness(60) > 0, "stone out into the survivable hot margin (edge-push, below the cap)")
  assert_eq(0, field.stone_richness(-51), "no stone on the cold cap")
  assert_eq(0, field.stone_richness(67.5), "no stone AT the field's hot edge (a margin short of the heat cap, ci-4iw)")
  assert_eq(0, field.stone_richness(77), "no stone in the LETHAL heat zone / lava-crust (perp >= 77)")
  assert_eq(0, field.stone_richness(100), "no stone deep in the heat damage zone")
  assert_eq(0, field.stone_richness(180), "no stone past the hot walkable margin (into the lava)")
end)

test("stone is richest toward the HOT (safe) edge (edge-pushing)", function()
  assert_true(field.stone_richness(60) > field.stone_richness(0),
    "sunward stone richer than central stone")
  assert_true(field.stone_richness(0) > field.stone_richness(-20),
    "richness falls off toward the cold edge of the stone band")
end)

test("ice lives on the SAFE cold margin only, richer deeper (colder)", function()
  assert_eq(0, field.ice_richness(0), "no ice in the temperate ribbon")
  assert_eq(0, field.ice_richness(60), "no ice on the hot side")
  assert_true(field.ice_richness(-38) > 0, "ice out into the survivable cold margin (edge-push, rough-ice side)")
  assert_eq(0, field.ice_richness(-41.5), "no ice AT the field's cold edge (a margin short of the cold cap, ci-4iw)")
  assert_eq(0, field.ice_richness(-51), "no ice in the LETHAL cold zone / deep-ice cap (perp <= -51)")
  assert_eq(0, field.ice_richness(-150), "no ice deep in the cold damage zone")
  assert_true(field.ice_richness(-38) > field.ice_richness(-28),
    "ice richer the deeper (colder) it gets")
end)

test("sandy bootstrap rocks scatter the WARM part of the building band, fading before ice (ci-18n)", function()
  assert_true(field.rock_zone(0), "rocks at the terminator")
  assert_true(field.rock_zone(25), "rocks to the hot edge of the building band")
  -- ci-18n: the cold edge is pulled a MARGIN warm of the building band's cold edge
  -- (building_lo -25 + ROCK_COLD_MARGIN 5 = -20), so the rocks fade out before the
  -- frosty cold zones. Rocks reach the pulled-in cold edge but not the divider itself.
  assert_true(field.rock_zone(-20), "rocks to the pulled-in (warm) cold edge")
  assert_true(not field.rock_zone(-25), "NO rocks at the building band's cold edge (fades before ice)")
  assert_true(not field.rock_zone(-23), "NO rocks in the cold margin next to the frost")
  assert_true(not field.rock_zone(60), "no rocks out in the hot margin")
  assert_true(not field.rock_zone(-100), "no rocks out on the cold cap")
end)

-- Ice-rocks (ci-18n): the cold-side counterpart, in the SAFE cold/ice band -- cold of
-- the stone/ice divider (building_lo -25) but WARM of the lethal deep-ice damage
-- zone (damage cold_from -51), so they are gatherable with no cold damage.
test("ice-rocks scatter the SAFE cold/ice band, never on the lethal deep-ice cap (ci-18n)", function()
  local d = terrain.damage_bounds()
  assert_true(field.ice_rock_zone(-25), "ice-rocks at the cold edge of the building band (the divider)")
  assert_true(field.ice_rock_zone(-40), "ice-rocks out on the safe cold cap (rough ice)")
  assert_true(field.ice_rock_zone(-50), "ice-rocks right up to the lethal deep-ice edge")
  assert_true(not field.ice_rock_zone(d.cold_from), "NO ice-rocks in the lethal deep-ice zone (boundary)")
  assert_true(not field.ice_rock_zone(-100), "NO ice-rocks deep in the lethal deep-ice cap")
  assert_true(not field.ice_rock_zone(-10), "NO ice-rocks in the warm/temperate building band")
  assert_true(not field.ice_rock_zone(50), "NO ice-rocks on the hot side")
  -- The two rock scatters are mutually exclusive across the divider: sandy warm-side,
  -- icy cold-side, so no point ever grows both a sandy and an icy rock.
  for p = -300, 200 do
    assert_true(not (field.rock_zone(p) and field.ice_rock_zone(p)),
      "sandy and ice rock bands overlap at p=" .. p)
  end
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

-- Lethal-zone exclusion (ci-fb9) + keep-back margin (ci-4iw): NO harvestable field
-- (stone / ice) may generate in the LETHAL damage zone -- a resource on the
-- unreachable cap/wall is visible-but-unreachable. The exclusion reads the SAME
-- positional terrain.damage_bounds the tile gradient uses, and additionally keeps a
-- FIELD_DAMAGE_MARGIN back so a noise-bled lethal tile just warm of the boundary is
-- field-free too (the ci-4iw leak: ci-fb9 clamped with no margin, so ice landed on
-- smooth-ice bled across the boundary). Scan the WHOLE axis and assert zero field for
-- every lethal position AND the whole margin band. Volcanic rocks (the hazard-reward
-- exception) are intentionally NOT checked -- they live in the hot region on purpose.
test("stone + ice NEVER generate in the lethal zone NOR its bled margin (ci-fb9, ci-4iw)", function()
  local db = terrain.damage_bounds()
  local m = field.FIELD_DAMAGE_MARGIN
  local rb = terrain.resource_bounds()
  local saw_heat, saw_cold = false, false
  for p = rb.cold_edge - 20, rb.hot_edge + 20 do
    local lethal = terrain.lethal_at(p)
    -- Excluded band: the lethal zone PLUS the keep-back margin (p >= hot_from - m on
    -- the heat side, p <= cold_from + m on the cold side).
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
  -- The field bands reach right up to (but a full MARGIN short of) the lethal boundary,
  -- i.e. INTO the survivable edge margin -- the edge-push reward is preserved.
  assert_true(field.stone_richness(db.hot_from - m - 1) > 0,
    "stone reaches the survivable hot margin (a margin short of the heat cap)")
  assert_true(field.ice_richness(db.cold_from + m + 1) > 0,
    "ice reaches the survivable cold margin (a margin short of the cold cap)")
  -- ...and there really is a keep-back GAP between the field edge and the lethal cap.
  assert_eq(0, field.stone_richness(db.hot_from - 1), "no stone in the keep-back gap (heat)")
  assert_eq(0, field.ice_richness(db.cold_from + 1), "no ice in the keep-back gap (cold)")
end)

test("lethal-zone exclusion + margin holds under a per-zone-width config override too", function()
  -- Shrink the heat crust + widen the ice cap: the damage boundaries move, and the
  -- field bands (with the margin) must track them (still zero resource in the lethal
  -- zone or its bled margin).
  local cfg = { lava_crust = 120, deep_ice = 400 }
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
  -- building=400 -> building_half 200, building_lo -200, damage cold_from -226.
  local cfg = { building = 400 }
  assert_true(field.rock_zone(180, cfg), "rocks reach further with a wider building band")
  assert_true(not field.rock_zone(220, cfg), "but not past the wider building edge")
  -- The sandy cold edge tracks the (moved) divider + margin (-200 + 5 = -195).
  assert_true(field.rock_zone(-195, cfg), "sandy cold edge tracks the moved divider + margin")
  assert_true(not field.rock_zone(-200, cfg), "sandy rocks still fade before the (moved) ice divider")
  -- Ice-rocks (finite, exempt) track the moved divider and the positional lethal
  -- deep-ice edge (cold_from -226); they are allowed on the rough-ice cold band.
  assert_true(field.ice_rock_zone(-200, cfg), "ice-rocks start at the moved divider")
  assert_true(field.ice_rock_zone(-225, cfg), "ice-rocks up to the moved lethal deep-ice edge")
  assert_true(not field.ice_rock_zone(-226, cfg), "ice-rocks never in the moved lethal zone")
  -- Ice FIELDS track the moved lethal cap (cold_from -226) minus the margin: cold
  -- edge -226 + 9.5 = -216.5, so ice sits on the (moved) survivable cold margin
  -- (-216.5, -200) but stops a margin short of the deep-ice cap.
  assert_true(field.ice_richness(-210, cfg) > 0, "ice on the (moved, further-out) survivable cold margin")
  assert_eq(0, field.ice_richness(-220, cfg), "no ice in the keep-back margin off the (moved) cold cap (ci-4iw)")
end)

-- The native-autoplace band masks (emitted as noise-expression DSL strings) MUST
-- describe the same boundaries as the numeric richness_* fns above. The DEFAULT
-- orientation is vertical (hot on the LEFT), so the sunward-positive perpendicular
-- axis is "(0 - x)"; scripts/axis.lua proves both orientations of that mapping.

test("stone mask spans the building ribbon + survivable hot margin, short of the heat cap", function()
  -- Hot edge = heat cap boundary (perp 77) minus the keep-back margin (9.5) = 67.5,
  -- EXCLUSIVE (ci-fb9, ci-4iw): reaches the survivable edge, off the bled lethal cap.
  assert_eq("((0 - x) >= -25) * ((0 - x) < 67.5)", field.stone_mask_expr(), "default stone band")
end)

test("ice mask covers the survivable cold margin, short of the cold cap", function()
  -- Cold edge = cold cap boundary (perp -51) plus the keep-back margin (9.5) = -41.5,
  -- EXCLUSIVE (ci-fb9, ci-4iw): reaches the survivable edge, off the bled smooth-ice.
  assert_eq("((0 - x) < -25) * ((0 - x) > -41.5)", field.ice_mask_expr(), "default ice band")
end)

test("sandy-rock autoplace masks to the WARM building band across the WHOLE ribbon (ci-18n)", function()
  local expr = field.rock_probability_expr()
  assert_true(expr:find("(0 - x) <= 25", 1, true) ~= nil, "capped at the hot edge of the building band")
  -- Cold edge pulled warm of the divider (building_lo -25 + margin 5 = -20).
  assert_true(expr:find("(0 - x) >= -20", 1, true) ~= nil, "cold edge pulled warm of the ice divider")
  assert_true(expr:find("(0 - x) >= -25", 1, true) == nil, "no longer reaches the building band's cold edge")
  -- BAND-WIDE, not a spawn disk (ci-9bb): NO `distance` cutoff.
  assert_true(expr:find("distance", 1, true) == nil, "no spawn-radius cutoff (rocks span the whole ribbon)")
end)

test("ice-rock autoplace masks to the safe cold band, never the lethal deep-ice cap (ci-18n)", function()
  local expr = field.ice_rock_probability_expr()
  local d = terrain.damage_bounds()
  assert_true(expr:find("(0 - x) <= -25", 1, true) ~= nil, "starts at the cold edge of the building band (divider)")
  assert_true(expr:find("(0 - x) > " .. d.cold_from, 1, true) ~= nil, "capped warm of the lethal deep-ice zone")
  -- BAND-WIDE like the sandy rock: no spawn-radius cutoff.
  assert_true(expr:find("distance", 1, true) == nil, "no spawn-radius cutoff (ice-rocks span the whole cold cap)")
end)

test("edge-pushing richness multipliers ramp 1 -> peak/base toward the margins", function()
  local mult = field.stone_richness_mult_expr()
  assert_true(mult:find("lerp%(1, ", 1) ~= nil, "starts at 1x at the near edge")
  assert_true(mult:find("clamp%(", 1) ~= nil, "clamped to the band fraction")
  -- The ice multiplier ramps with cold-cap depth (distance past the divider).
  assert_true(field.ice_richness_mult_expr():find("%(-25 %- ", 1) ~= nil, "ice ramps with cold-cap depth")
end)

-- Burned volcanic rocks (ci-qy0): confined to the VOLCANIC-TILE region proper
-- (terrain.cliff_band: lava_crust .. scorched). ci-18n tightens the inner edge to
-- the volcanic band's cold edge, dropping the dry_dirt zone so the rocks stop
-- spilling onto non-volcanic tiles. NEVER in the temperate/building band, the
-- dry_dirt zone, or the cold/ice zone.
test("burned volcanic rocks live in the volcanic-tile region only (ci-18n tighten)", function()
  local v = terrain.cliff_band() -- default lo=38 (scorched cold edge), hi=127 (lava-crust edge)
  assert_true(field.burned_rock_zone(100), "burned rocks in the volcanic band")
  assert_true(field.burned_rock_zone(120), "burned rocks out toward the lava (walkable) edge")
  assert_true(field.burned_rock_zone(v.lo + 1), "just sunward of the volcanic band's cold edge")
  assert_true(not field.burned_rock_zone(v.lo), "NO burned rocks at the volcanic band boundary")
  assert_true(not field.burned_rock_zone(30), "NO burned rocks in the dry_dirt zone (non-volcanic, ci-18n)")
  assert_true(not field.burned_rock_zone(20), "NO burned rocks in the building band (boundary)")
  assert_true(not field.burned_rock_zone(0), "NO burned rocks at the temperate building centre")
  assert_true(not field.burned_rock_zone(-100), "NO burned rocks in the cold/ice zone")
  assert_true(not field.burned_rock_zone(150), "NO burned rocks in the impassable lava wall (past the volcanic edge)")
end)

test("burned-rock zone honours a per-zone-width config override", function()
  -- Widen the building band: the volcanic band shifts sunward with it, so the burned
  -- rocks start further sunward and never inside the wider building band or dry_dirt.
  local cfg = { building = 400 }
  local v = terrain.cliff_band(cfg)
  assert_true(field.burned_rock_zone(v.lo + 10, cfg), "just sunward of the (moved) volcanic band edge")
  assert_true(not field.burned_rock_zone(v.lo - 10, cfg), "not inside the dry_dirt/building zones below the volcanic band")
  assert_true(not field.burned_rock_zone(-10, cfg), "never in the cold zone")
  assert_true(not field.burned_rock_zone(v.hi + 10, cfg), "never past the walkable hot edge (into the lava wall)")
end)

test("burned-rock autoplace masks to the volcanic band and clusters toward the lava", function()
  local expr = field.burned_rock_probability_expr()
  local v = terrain.cliff_band()
  -- Confined to the volcanic band on the perpendicular axis: from its cold edge in to
  -- the walkable hot edge (default hot = negative x, perp = "(0 - x)"). ci-18n.
  assert_true(expr:find("(0 - x) > " .. v.lo, 1, true) ~= nil, "starts at the volcanic band's cold edge")
  assert_true(expr:find("(0 - x) <= " .. v.hi, 1, true) ~= nil, "capped at the walkable hot (lava-crust) edge")
  -- Clusters toward the lava: a clamped ramp from MIN to MAX probability.
  assert_true(expr:find("lerp(0.003, 0.02,", 1, true) ~= nil, "ramps MIN -> MAX toward the lava")
  assert_true(expr:find("clamp(", 1, true) ~= nil, "ramp fraction is clamped to the band")
  -- Never keyed off the cold axis, so it can never bleed into the ice zone.
  assert_true(expr:find("> -", 1, true) == nil, "no nightward (cold) bound (hot region only)")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
