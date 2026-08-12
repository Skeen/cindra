-- Plain-Lua unit test for the WORLD-GEN-SCREEN zone sliders (scripts/zone-scale.lua,
-- ci-i4z). Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_zone_scale.lua
--
-- The sliders stretch the ribbon by WARPING the perpendicular coordinate every band is
-- read against: world tiles in, nominal tiles out. This proves the warp's load-bearing
-- properties, all of which a player can feel:
--
--   * default sliders = today's world, exactly (the warp is the identity).
--   * the habitable band you build in really is N times wider at Size N, measured in
--     world tiles between the band's own edges.
--   * the hot / cold zone depths do the same, INDEPENDENTLY of each other and of the
--     middle -- one slider never shoves another band around.
--   * SPAWN never moves: the middle band stays centred on the ribbon centre.
--   * the MAP never changes size: the oceans absorb what the bands take, and never
--     shrink below a full chunk of impassable wall, so the void backstop is where it
--     always was and you can never walk off the edge.
--   * the warp is strictly monotonic and exactly invertible (so "which band am I in"
--     and "where is that band on the ground" agree).
--   * THE EMITTED NOISE EXPRESSION IS THE SAME FUNCTION as the runtime warp: the
--     emitted string is evaluated here (its syntax is a subset of Lua) and compared
--     against the numeric path point for point. A map-gen that painted the tiles in
--     one place while the runtime believed they were somewhere else is the whole risk
--     of this feature, and this is the guard against it.

package.path = package.path .. ";./?.lua;./?/init.lua"
local zone_scale = require("scripts.zone-scale")
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

-- The nominal geometry under test (the shipped defaults).
local function nominal_band(role) return terrain.role_band(role) end
local _, TOTAL = terrain.bands()
local HALF = TOTAL / 2
local CENTRE = zone_scale.centre()
local MID = nominal_band("middle")
local DMG = terrain.damage_bounds()

local function scales(t)
  local out = zone_scale.default_scales()
  for k, v in pairs(t or {}) do out[k] = v end
  return out
end

-- The WORLD width of a nominal band [lo, hi] under a set of sliders.
local function world_width(band, sc)
  return zone_scale.to_world(band.hi, sc) - zone_scale.to_world(band.lo, sc)
end

-- === the wiring is not duplicated ==========================================

test("the axis emitters and the warp agree on the named expressions (no drift)", function()
  assert_eq(zone_scale.PERP_EXPR, axis.perp_expr(), "every band mask reads the warped axis")
  assert_eq("(0 - " .. zone_scale.PERP_EXPR .. ")", "(0 - cindra_perp)", "the negated axis name")
  assert_eq(zone_scale.PERP_NEG_EXPR, axis.perp_neg_expr(), "and its nightward twin")
  -- The RAW axis is still available (the warp itself is built on it).
  assert_eq("(0 - x)", axis.raw_perp_expr("vertical"), "vertical raw axis")
  assert_eq("(0 - y)", axis.raw_perp_expr("horizontal"), "horizontal raw axis (fire at the top, ci-65p)")
end)

test("every ribbon zone is either scaled by a slider or an absorbing ocean", function()
  local scaled, absorbing = 0, 0
  for _, z in ipairs(terrain.ZONES) do
    if z.scale then
      scaled = scaled + 1
      assert_true(zone_scale.default_scales()[z.scale] ~= nil, z.role .. " claims a real slider")
    else
      absorbing = absorbing + 1
      assert_true(z.ocean == true, z.role .. " may only absorb if it is an OCEAN (a pinned wall)")
    end
  end
  assert_eq(5, scaled, "the five inhabitable bands are slider-scaled")
  assert_eq(2, absorbing, "only the two oceans absorb")
end)

-- === identity at the defaults ==============================================

test("default sliders leave the world EXACTLY as it is (the warp is the identity)", function()
  for p = -HALF, HALF, 7.5 do
    assert_near(p, zone_scale.to_nominal(p), 1e-9, "nominal(" .. p .. ")")
    assert_near(p, zone_scale.to_world(p), 1e-9, "world(" .. p .. ")")
  end
  assert_near(120, world_width(MID), 1e-9, "the habitable band is its nominal 120 tiles wide")
end)

test("an absent / disabled / absurd control never collapses a band", function()
  assert_eq(1, zone_scale.scales_from_controls(nil).middle, "no controls at all -> default")
  assert_eq(1, zone_scale.scales_from_controls({}).hot, "control absent -> default")
  local read = zone_scale.scales_from_controls({
    ["cindra-habitable-band"] = { frequency = 6, size = 2, richness = 1 },
  })
  assert_eq(2, read.middle, "the SIZE dropdown is what drives the width")
  assert_eq(1, read.hot, "an unset slider stays at 1 (frequency is not wired to anything)")
  -- A 0 ("None") or a scripted absurdity is clamped, never obeyed.
  local none = world_width(MID, scales({ middle = 0 }))
  assert_true(none > 0, "a zero slider still leaves a habitable band (" .. none .. " tiles)")
  assert_near(world_width(MID, scales({ middle = zone_scale.MIN_SCALE })), none, 1e-9,
    "a 0 reads as the minimum size")
  assert_near(world_width(MID, scales({ middle = 999 })), world_width(MID, scales({ middle = zone_scale.MAX_SCALE })),
    1e-9, "an absurd slider reads as the maximum size")
end)

-- === the sliders do what they say ==========================================

test("the HABITABLE BAND slider really widens the band you build in", function()
  for _, s in ipairs({ 0.5, 2, 3 }) do
    local sc = scales({ middle = s })
    assert_near(120 * s, world_width(MID, sc), 1e-6,
      "Size " .. s .. " gives a " .. (120 * s) .. "-tile habitable band")
  end
  -- ...and the lethal ground moves out with it: the heat belt starts further away.
  local wide = zone_scale.to_world(DMG.hot_from, scales({ middle = 2 }))
  assert_true(wide > DMG.hot_from + 50,
    "at Size 2 the heat belt starts much further out (" .. wide .. " vs " .. DMG.hot_from .. ")")
end)

test("the HOT / COLD sliders deepen their own zones only", function()
  local hot_zones = { nominal_band("hot_outer"), nominal_band("hot_inner") }
  local cold_zones = { nominal_band("cold_outer"), nominal_band("cold_inner") }
  local sc = scales({ hot = 2 })
  for _, b in ipairs(hot_zones) do
    assert_near(2 * (b.hi - b.lo), world_width(b, sc), 1e-6, "a hot band doubles at Size 2")
  end
  -- The cold side is budgeted independently: its bands, and the habitable band, are
  -- untouched by the hot slider.
  for _, b in ipairs(cold_zones) do
    assert_near(b.hi - b.lo, world_width(b, sc), 1e-6, "the cold bands are untouched")
  end
  assert_near(120, world_width(MID, sc), 1e-6, "the habitable band is untouched")
  -- And symmetrically for the cold slider.
  local cs = scales({ cold = 2 })
  for _, b in ipairs(cold_zones) do
    assert_near(2 * (b.hi - b.lo), world_width(b, cs), 1e-6, "a cold band doubles at Size 2")
  end
  for _, b in ipairs(hot_zones) do
    assert_near(b.hi - b.lo, world_width(b, cs), 1e-6, "the hot bands are untouched")
  end
end)

test("asking for more than the ribbon holds degrades gracefully, never breaks", function()
  -- The ribbon is a fixed width, so at the top of the dropdown the bands cannot ALL
  -- have what they asked for. They then shrink together (one shared factor), the ocean
  -- sits on its floor, and every band still exists -- no zone is ever lost.
  local sc = scales({ hot = 6 })
  local asked, got = 2 * 70 * 6, 0
  for _, role in ipairs({ "hot_outer", "hot_inner" }) do
    local w = world_width(nominal_band(role), sc)
    assert_true(w > 70, role .. " is still deeper than nominal (" .. w .. ")")
    got = got + w
  end
  assert_true(got < asked, "but not the full ask, which does not fit (" .. got .. " < " .. asked .. ")")
  assert_true(got > 2 * 70 * 2, "it fits as much as it can (" .. got .. ")")
  assert_near(zone_scale.MIN_WALL, world_width(nominal_band("hot_ocean"), sc), 1e-6,
    "the ocean has given everything it can and sits on its floor")
  -- The habitable band pays too (both share the sunward budget), but survives.
  assert_true(world_width(MID, sc) > 0, "there is still a habitable band")
end)

test("SPAWN is always safe, buildable ground with room either side", function()
  local combos = {
    {}, { middle = 3 }, { hot = 3 }, { cold = 3 }, { hot = 6, cold = 0.5 },
    { middle = 6, hot = 6, cold = 6 }, { middle = 1 / 6, hot = 6, cold = 1 / 6 },
    { middle = 1 / 6, hot = 1 / 6, cold = 1 / 6 },
  }
  local PAD = 16 -- a landing-pad's worth of ground, either side of the origin
  for _, c in ipairs(combos) do
    local sc = scales(c)
    assert_near(CENTRE, zone_scale.to_nominal(CENTRE, sc), 1e-9, "the centre is the warp's anchor")
    -- Habitable band either side of spawn...
    assert_true(zone_scale.to_world(MID.hi, sc) > CENTRE, "habitable ground sunward of spawn")
    assert_true(zone_scale.to_world(MID.lo, sc) < CENTRE, "habitable ground nightward of spawn")
    -- ...and the LETHAL ground (where the field crosses a damage threshold) stays a
    -- landing pad away, so a fresh drop never lands in the burn or the frost.
    local hot_belt = zone_scale.to_world(DMG.hot_from, sc) - CENTRE
    local cold_belt = CENTRE - zone_scale.to_world(DMG.cold_from, sc)
    assert_true(hot_belt > PAD, "the heat belt is clear of the pad (" .. hot_belt .. " tiles)")
    assert_true(cold_belt > PAD, "the cold belt is clear of the pad (" .. cold_belt .. " tiles)")
  end
end)

test("a symmetric setting keeps the habitable band centred on spawn", function()
  -- With the two sides asking for the same thing they get the same thing: the band you
  -- land in is symmetric. (An EXTREME one-sided slider squeezes that side's half of the
  -- band more than the other's -- the sides are budgeted independently, which is what
  -- keeps one slider from shoving the other side's bands around. Spawn stays safe
  -- either way, proven above.)
  for _, c in ipairs({ {}, { middle = 2 }, { middle = 0.5 }, { hot = 2, cold = 2 } }) do
    local sc = scales(c)
    local hot_edge = zone_scale.to_world(MID.hi, sc) - CENTRE
    local cold_edge = CENTRE - zone_scale.to_world(MID.lo, sc)
    assert_near(hot_edge, cold_edge, 1e-6, "the habitable band is centred on spawn")
  end
end)

-- === the map itself never changes ==========================================

test("the ribbon's total width -- and the void backstop -- never moves", function()
  local combos = {
    {}, { middle = 6 }, { hot = 6 }, { cold = 6 }, { middle = 6, hot = 6, cold = 6 },
    { middle = 1 / 6, hot = 1 / 6, cold = 1 / 6 }, { middle = 4, hot = 0.5, cold = 2 },
  }
  for _, c in ipairs(combos) do
    local sc = scales(c)
    assert_near(HALF, zone_scale.to_world(HALF, sc), 1e-6, "the sunward map edge is pinned")
    assert_near(-HALF, zone_scale.to_world(-HALF, sc), 1e-6, "the nightward map edge is pinned")
    assert_near(HALF, zone_scale.to_nominal(HALF, sc), 1e-6, "and maps back to the nominal edge")
    assert_near(-HALF, zone_scale.to_nominal(-HALF, sc), 1e-6, "both ways")
  end
  assert_eq(TOTAL, terrain.finite_dimension().value,
    "so the finite map dimension stays the SUM of the nominal zone widths")
end)

test("both OCEAN walls survive every slider setting (at least a full chunk wide)", function()
  local combos = {
    {}, { middle = 6 }, { hot = 6 }, { cold = 6 }, { middle = 6, hot = 6, cold = 6 },
  }
  for _, c in ipairs(combos) do
    local sc = scales(c)
    for _, role in ipairs({ "hot_ocean", "cold_ocean" }) do
      local w = world_width(nominal_band(role), sc)
      assert_true(w >= zone_scale.MIN_WALL - 1e-6,
        role .. " keeps a real wall (" .. w .. " >= " .. zone_scale.MIN_WALL .. " tiles)")
    end
  end
  -- The oceans GIVE the width back when the bands shrink.
  local narrow = world_width(nominal_band("hot_ocean"), scales({ middle = 1 / 6, hot = 1 / 6 }))
  assert_true(narrow > 200, "a narrow ribbon is surrounded by MORE ocean (" .. narrow .. " tiles)")
end)

-- === the warp is a warp ====================================================

test("the warp is strictly monotonic (bands never fold or swap order)", function()
  for _, c in ipairs({ {}, { middle = 4 }, { hot = 6, cold = 1 / 6 }, { middle = 6, hot = 6, cold = 6 } }) do
    local sc = scales(c)
    local prev = zone_scale.to_nominal(-HALF - 20, sc)
    for p = -HALF, HALF, 2.5 do
      local q = zone_scale.to_nominal(p, sc)
      assert_true(q >= prev - 1e-12, "nominal must never go backwards at p=" .. p)
      prev = q
    end
  end
end)

test("world <-> nominal round-trips exactly (both directions, every combo)", function()
  for _, c in ipairs({ {}, { middle = 2 }, { hot = 3 }, { cold = 0.5 }, { middle = 6, hot = 2, cold = 4 } }) do
    local sc = scales(c)
    for q = -HALF, HALF, 12.5 do
      assert_near(q, zone_scale.to_nominal(zone_scale.to_world(q, sc), sc), 1e-6,
        "nominal -> world -> nominal at " .. q)
    end
    for p = -HALF, HALF, 12.5 do
      assert_near(p, zone_scale.to_world(zone_scale.to_nominal(p, sc), sc), 1e-6,
        "world -> nominal -> world at " .. p)
    end
  end
end)

test("beyond the map edge the warp saturates at the pinned ocean extreme", function()
  local sc = scales({ middle = 2 })
  assert_near(HALF, zone_scale.to_nominal(HALF + 500, sc), 1e-6, "sunward of the edge is still the lava extreme")
  assert_near(-HALF, zone_scale.to_nominal(-HALF - 500, sc), 1e-6, "nightward of the edge is still the ice extreme")
end)

test("nominal_perp honours the ribbon orientation", function()
  local sc = scales({ middle = 2 })
  -- vertical: perp = -x (hot to the west). horizontal: perp = -y (hot at the top, ci-65p).
  assert_near(zone_scale.to_nominal(-40, sc), zone_scale.nominal_perp(40, 0, "vertical", sc), 1e-9,
    "vertical reads -x")
  assert_near(zone_scale.to_nominal(40, sc), zone_scale.nominal_perp(0, -40, "horizontal", sc), 1e-9,
    "horizontal reads -y")
end)

-- === THE MAP-GEN AND THE RUNTIME ARE THE SAME FUNCTION =====================

-- The emitted noise expression uses only arithmetic and min/max, which is also valid
-- Lua, so it can be evaluated here against the numeric warp. `x` is the world
-- coordinate (vertical orientation: perp = -x) and the slider variables stand in for
-- the map-gen screen values the engine resolves them to.
local function eval_expr(expr, x, sc)
  local env = { min = math.min, max = math.max, x = x, y = 0 }
  for _, s in ipairs(zone_scale.SLIDERS) do env[s.var] = sc[s.key] end
  local chunk = assert(load("return " .. expr, "warp", "t", env))
  return chunk()
end

test("the emitted map-gen expression IS the runtime warp, point for point", function()
  local expr = zone_scale.perp_expr(nil, "vertical")
  assert_true(expr:find("cindra_ribbon_scale_middle", 1, true) ~= nil,
    "the expression reads the slider variables (so the map-gen screen can move it)")
  assert_true(expr:find("(0 - x)", 1, true) ~= nil, "over the raw world axis")
  for _, c in ipairs({ {}, { middle = 2 }, { hot = 3 }, { cold = 0.5 },
                       { middle = 6, hot = 6, cold = 6 }, { middle = 0, hot = 999 } }) do
    local sc = scales(c)
    for p = -HALF, HALF, 6.25 do
      local expected = zone_scale.to_nominal(p, sc)
      local got = eval_expr(expr, -p, sc) -- vertical: p = -x
      assert_near(expected, got, 1e-6,
        "map-gen and runtime must agree at p=" .. p .. " for sliders " ..
        sc.middle .. "/" .. sc.hot .. "/" .. sc.cold)
    end
  end
end)

test("the emitted expression is the IDENTITY when the sliders resolve to 1", function()
  -- This is what makes the warp safe everywhere it is not wanted: on any surface that
  -- is not Cindra the scale variables resolve to their global default of 1, so the
  -- expression collapses to the raw axis and no foreign world is touched.
  local expr = zone_scale.perp_expr(nil, "vertical")
  for p = -HALF, HALF, 5 do
    assert_near(p, eval_expr(expr, -p, zone_scale.default_scales()), 1e-9, "identity at p=" .. p)
  end
end)

print(string.format("\n1..%d # passed %d, failed %d", passed + failed, passed, failed))
if failed > 0 then os.exit(1) end
