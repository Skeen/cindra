-- Plain-Lua unit test for the PURE ambient thermal grade (scripts/damage-feedback.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_feedback.lua
--
-- The grade is what the player SEES washed over the screen as they walk the ribbon:
-- nothing in the temperate middle, a warm orange that deepens as they push sunward,
-- a cool blue that deepens as they push nightward. This asserts that shape off the
-- game; tests/test_feedback.lua drives a LIVE player and asserts the real render
-- object matches.
--
-- These are the properties the ci-nw0 feedback asked for, stated as things a player
-- could notice: neutral where it is safe, continuous (no snap), subtle near the band
-- and deeper toward each extreme, never an opaque overlay, and driven by POSITION
-- rather than by taking damage.

package.path = package.path .. ";./?.lua;./?/init.lua"
_G.settings = { startup = {} }
local grade = require("scripts.damage-feedback")
local terrain = require("scripts.terrain")
local ribbon = require("scripts.ribbon")

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1; print("ok - " .. name)
  else failed = failed + 1; print("not ok - " .. name .. ": " .. tostring(err)) end
end
local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end
local function assert_true(v, msg)
  if not v then error(msg or "expected true", 2) end
end
local function which(p) return (select(1, grade.grade_at(p))) end
local function depth(p) return (select(2, grade.grade_at(p))) end
local function alpha(p) return grade.alpha_for(depth(p)) end

local A = grade.anchors()
local MID_HOT, MID_COLD = A.warm_from, A.cool_from   -- temperate band edges (+/-60 by default)
local HOT_SAT, COLD_SAT = A.warm_sat, A.cool_sat     -- ocean inner edges (+/-200 by default)
local HALF = A.half                                  -- map edge (+/-400 by default)

test("the temperate band reads NEUTRAL: no wash at all across the whole middle", function()
  for p = MID_COLD, MID_HOT, 5 do
    assert_eq(nil, which(p), "no hue at p=" .. p)
    assert_eq(0, alpha(p), "no wash at p=" .. p)
  end
  assert_eq(nil, which(0), "spawn is neutral")
  assert_eq(0, alpha(MID_HOT), "exactly zero at the hot edge of the band")
  assert_eq(0, alpha(MID_COLD), "exactly zero at the cold edge of the band")
end)

test("push sunward and the screen warms CONTINUOUSLY, deepening the whole way", function()
  local prev = 0
  for p = MID_HOT + 1, HOT_SAT, 10 do
    assert_eq("warm", which(p), "warm hue at p=" .. p)
    assert_true(alpha(p) > prev, "wash deepens at p=" .. p)
    prev = alpha(p)
  end
end)

test("push nightward and the screen cools CONTINUOUSLY, deepening the whole way", function()
  local prev = 0
  for p = MID_COLD - 1, COLD_SAT, -10 do
    assert_eq("cool", which(p), "cool hue at p=" .. p)
    assert_true(alpha(p) > prev, "wash deepens at p=" .. p)
    prev = alpha(p)
  end
end)

test("it does NOT snap on: leaving the band is a whisper, not a step", function()
  -- One tile out of the temperate band must be barely visible: a small fraction of
  -- the deepest wash. The old binary overlay jumped straight to 0.18 alpha here.
  local edge_out = alpha(MID_HOT + 1)
  assert_true(edge_out > 0, "the wash has started")
  assert_true(edge_out < 0.02 * grade.MAX_ALPHA, "and is a whisper: " .. edge_out)
  assert_true(alpha(MID_COLD - 1) < 0.02 * grade.MAX_ALPHA, "same on the cold side")
  -- No discontinuity anywhere along the axis: successive tiles differ by a hair.
  for p = -HALF, HALF - 1, 1 do
    local step = math.abs(alpha(p + 1) - alpha(p))
    assert_true(step < 0.01, "no jump between p=" .. p .. " and p=" .. (p + 1))
  end
end)

test("it is a HUE WASH, never an opaque overlay", function()
  local worst = 0
  for p = -HALF, HALF, 1 do
    if alpha(p) > worst then worst = alpha(p) end
  end
  assert_true(worst <= 0.25, "the deepest wash stays subtle: " .. worst)
  assert_true(worst > 0.1, "but the extremes are clearly felt: " .. worst)
end)

test("warm side reads ORANGE, cold side reads BLUE", function()
  local hot = grade.tint_at(HOT_SAT)
  assert_true(hot.r > hot.g and hot.g > hot.b, "sunward wash is orange (r > g > b)")
  local cold = grade.tint_at(COLD_SAT)
  assert_true(cold.b > cold.g and cold.g > cold.r, "nightward wash is blue (b > g > r)")
  assert_eq(nil, grade.tint_at(0), "and nothing is drawn at spawn")
end)

test("the wash keeps deepening past ribbon's DEFAULT saturation, out to the real map edge", function()
  -- ribbon's default `saturate_at` (128 tiles) is far inside today's 800-tile ribbon.
  -- If the grade evaluated the temperature curve over it instead of handing in the
  -- real half-width, the curve would saturate before the player even reached the burn
  -- belt and the whole outer ribbon would read the same flat colour. The player must
  -- instead keep seeing it deepen all the way out.
  local default_edge = ribbon.DEFAULTS.saturate_at
  assert_true(default_edge < HOT_SAT, "the default saturation really is inside the ribbon")
  assert_true(alpha(HOT_SAT) > alpha(default_edge), "still deepening beyond it")
  assert_true(alpha(COLD_SAT) > alpha(-default_edge), "same nightward")
end)

test("POSITION drives it, not damage: safe ground outside the band is already tinted", function()
  -- The whole point of ci-nw0. Between the temperate band and the burn belt the
  -- environment deals ZERO damage -- and the player must still see the ribbon warming
  -- around them. The old model showed nothing at all until damage started.
  local db = terrain.damage_bounds()
  local p = (MID_HOT + db.hot_from) / 2
  local dmg = select(1, terrain.field_damage(p))
  assert_eq(0, dmg, "this stretch is genuinely undamaging")
  assert_eq("warm", which(p), "yet the screen already reads warm there")
  assert_true(alpha(p) > 0, "with a visible wash")

  local pc = (MID_COLD + db.cold_from) / 2
  assert_eq(0, (select(1, terrain.field_damage(pc))), "cold side stretch is undamaging too")
  assert_eq("cool", which(pc), "yet the screen already reads cool there")
end)

test("full depth is reached at the ocean, and simply holds inside it", function()
  assert_eq(1, depth(HOT_SAT), "full warm depth at the lava ocean edge")
  assert_eq(1, depth(COLD_SAT), "full cool depth at the ice ocean edge")
  assert_eq(grade.MAX_ALPHA, alpha(HOT_SAT), "capped at MAX_ALPHA")
  assert_eq(alpha(HOT_SAT), alpha(HALF), "and holds across the ocean, never exceeding it")
  assert_eq(alpha(COLD_SAT), alpha(-HALF), "same nightward")
end)

test("the two sides are mirror images of each other", function()
  for _, p in ipairs({ 70, 100, 150, 199, 300 }) do
    local dh = depth(p)
    local dc = depth(-p)
    assert_true(math.abs(dh - dc) < 1e-9, "depth is symmetric at |p|=" .. p)
  end
end)

test("the neutral band tracks the LIVE zone widths, not a hard-coded number", function()
  -- Halve the middle band and the wash must start correspondingly closer to spawn --
  -- the player's safe, untinted pocket shrinks with the geometry.
  local narrow = { middle = 40 }
  local a = grade.anchors(narrow)
  assert_true(a.warm_from < MID_HOT, "the neutral pocket got smaller")
  assert_eq(nil, (select(1, grade.grade_at(a.warm_from, narrow))), "still neutral at its edge")
  assert_eq("warm", (select(1, grade.grade_at(a.warm_from + 5, narrow))), "warm just outside it")
  -- A position that was neutral under the default layout is now tinted.
  local p = (a.warm_from + MID_HOT) / 2
  assert_eq(nil, which(p), "neutral under the default widths")
  assert_eq("warm", (select(1, grade.grade_at(p, narrow))), "tinted under the narrow middle")
end)

-- ci-i4z: the grade's anchors are ZONE edges, so a WORLD position must be warped onto the
-- nominal axis by the world-gen-screen geometry sliders before it is graded. Otherwise the
-- wash would sit at a fixed tile count while the ground it explains has moved -- warm air
-- over the habitable band, neutral out on the lethal slope.
test("the grade follows the world-gen-screen geometry sliders (ci-i4z)", function()
  local zone_scale = require("scripts.zone-scale")
  local orient = "vertical" -- perp = -x, so a sunward (hot) position is at negative x
  local sliders = zone_scale.default_scales()
  sliders.middle = 3 -- a habitable band three times as wide

  -- A spot just sunward of the default temperate band: warm at default sliders...
  local p = MID_HOT + 20
  local x = -p
  assert_eq("warm", (select(1, grade.grade_at_world(x, 0, orient, zone_scale.default_scales()))),
    "warm on the default world")
  -- ...and NEUTRAL once the habitable band has been widened past it, because that ground is
  -- now the temperate middle a player builds on.
  assert_eq(nil, (select(1, grade.grade_at_world(x, 0, orient, sliders))),
    "neutral once the habitable band reaches out there")
  -- The landing spot is neutral either way.
  for _, sc in ipairs({ zone_scale.default_scales(), sliders }) do
    assert_eq(nil, (select(1, grade.grade_at_world(0, 0, orient, sc))), "spawn is never washed")
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
