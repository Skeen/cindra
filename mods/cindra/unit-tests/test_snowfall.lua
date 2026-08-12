-- Plain-Lua unit test for the PURE part of the icy-side snowfall
-- (scripts/snowfall.lua, ci-mk5y). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_snowfall.lua
--
-- The pure surface is the WHERE (which perpendicular positions it snows at) and the HOW IT
-- MOVES (a flake falls, drifts, and wraps back to the top of the field). Both are plain
-- number logic with no game.* access, so they are proven here; that the effect is actually
-- VISIBLE on the ice and invisible everywhere else is proven against a live player in
-- tests/test_snowfall.lua. Keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local snowfall = require("scripts.snowfall")
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
local function assert_true(x, msg) if not x then error(msg or "expected true", 2) end end

-- A deterministic stand-in for math.random: cycles a fixed sequence in [0,1), so the flake
-- construction / wrap logic is exercised without leaning on the RNG.
local function seq(values)
  local i = 0
  return function()
    i = i % #values + 1
    return values[i]
  end
end

local START = terrain.damage_bounds().cold_from -- the icy-ground edge: -130 by default

-- WHERE IT SNOWS ---------------------------------------------------------------------
test("snow falls on the icy side only -- never on the habitable band or the hot side", function()
  assert_eq(START, snowfall.snow_start(), "snow starts at the icy-ground edge")
  assert_true(snowfall.falls_at(START - 1), "it snows on the first snowy ground")
  assert_true(snowfall.falls_at(-200), "it snows out on the deep ice")
  assert_true(snowfall.falls_at(-400), "it snows over the ice ocean")
  assert_true(not snowfall.falls_at(START), "the boundary is exclusive")
  assert_true(not snowfall.falls_at(-100), "no snow on the brown dust band")
  assert_true(not snowfall.falls_at(0), "no snow on the terminator (landing spawn)")
  assert_true(not snowfall.falls_at(60), "no snow on the volcanic slope")
  assert_true(not snowfall.falls_at(300), "no snow over the lava ocean")
end)

-- The falling snow and the LYING snow (the ice/snow decals) must agree: one boundary, read
-- from the terrain, so the effect can never drift away from the ground it belongs to.
test("falling snow starts exactly where the ice/snow decals do", function()
  assert_eq(field.cold_start(), snowfall.snow_start(), "same boundary as the cold decals")
  local cfg = { middle = 40, cold_outer = 30, cold_inner = 30, cold_ocean = 100,
                hot_outer = 30, hot_inner = 30, hot_ocean = 100 }
  assert_eq(field.cold_start(cfg), snowfall.snow_start(cfg), "still agree under an override")
  assert_true(snowfall.snow_start(cfg) ~= START, "the override really did move the boundary")
  assert_true(snowfall.falls_at(snowfall.snow_start(cfg) - 1, cfg), "and the gate moved with it")
  -- The narrower world moves the icy ground WARMWARD, so ground that is bare brown band by
  -- default snows under the override -- the gate tracks the terrain, not a hard-coded line.
  assert_true(not snowfall.falls_at(-100), "bare brown band at the default widths")
  assert_true(snowfall.falls_at(-100, cfg), "icy ground (and snowing) under the override")
end)

-- HOW IT MOVES ----------------------------------------------------------------------
test("a fresh flake sits inside the field with a sane look and a downward speed", function()
  local rand = seq({ 0.0, 0.5, 1.0, 0.25, 0.75 })
  for _ = 1, 50 do
    local f = snowfall.new_flake(rand)
    assert_true(math.abs(f.dx) <= snowfall.SPAN_X / 2, "flake starts inside the field width")
    assert_true(math.abs(f.dy) <= snowfall.SPAN_Y / 2, "flake starts inside the field height")
    assert_true(f.scale >= snowfall.SCALE_MIN and f.scale <= snowfall.SCALE_MAX, "sane scale")
    assert_true(f.alpha >= snowfall.ALPHA_MIN and f.alpha <= snowfall.ALPHA_MAX, "sane alpha")
    assert_true(f.speed > 0, "it falls (positive downward speed)")
    assert_true(math.abs(f.drift) <= snowfall.DRIFT, "the wind stays gentle")
  end
end)

test("a flake FALLS every update and wraps back to the top of the field", function()
  local rand = seq({ 0.5 })
  local f = { dx = 0, dy = -snowfall.SPAN_Y / 2, scale = 0.5, alpha = 0.5,
              speed = snowfall.FALL_SPEED, drift = 0 }
  local top = f.dy
  local prev = f.dy
  local wraps = 0
  -- Drive the flake for well over a full traversal of the field.
  local steps = math.ceil(snowfall.SPAN_Y / snowfall.FALL_SPEED) + 10
  for _ = 1, steps do
    snowfall.step(f, rand)
    if f.dy > prev then
      -- fell
      assert_true(f.dy - prev <= snowfall.FALL_SPEED + 1e-9, "falls at its own speed, no jumps")
    else
      -- wrapped: back to the top of the field, never below it
      wraps = wraps + 1
      assert_true(math.abs(f.dy - top) < 1e-9, "a wrapped flake restarts at the top")
    end
    assert_true(f.dy <= snowfall.SPAN_Y / 2 + 1e-9, "a flake never falls out of the field")
    prev = f.dy
  end
  assert_true(wraps >= 1, "the field recycles its flakes (it never empties)")
end)

test("lateral drift wraps inside the field width (the field never blows away)", function()
  local rand = seq({ 0.5 })
  for _, drift in ipairs({ snowfall.DRIFT, -snowfall.DRIFT }) do
    local f = { dx = 0, dy = 0, scale = 0.5, alpha = 0.5, speed = 0.0001, drift = drift }
    for _ = 1, 4000 do
      snowfall.step(f, rand)
      assert_true(math.abs(f.dx) <= snowfall.SPAN_X / 2 + 1e-9,
        "flake stays within the field width (dx=" .. f.dx .. ")")
    end
  end
end)

-- The update cadence must not collide with another periodic system: on_nth_tick is
-- REPLACE-not-add, so a shared N would silently unhook one of them.
test("the snowfall tick is its own distinct N", function()
  local tile_damage = require("scripts.tile-damage")
  local freeze_emitters = require("scripts.freeze-emitters")
  local flare_config = require("scripts.flare-config")
  local diode_config = require("scripts.diode-config")
  local taken = {
    tile_damage.DAMAGE_INTERVAL, freeze_emitters.REHEAT_INTERVAL,
    flare_config.FLARE_INTERVAL, flare_config.PANEL_DAMAGE_INTERVAL,
    diode_config.TICK_INTERVAL,
  }
  assert_true(snowfall.UPDATE_INTERVAL > 0, "it has a cadence")
  for _, n in ipairs(taken) do
    assert_true(snowfall.UPDATE_INTERVAL ~= n, "snowfall must not share nth-tick " .. tostring(n))
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
