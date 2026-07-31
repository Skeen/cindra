-- Plain-Lua unit test for the PURE feedback decision (scripts/damage-feedback.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_feedback.lua
--
-- overlay_for maps a perpendicular coordinate to which heat/cold tint (if any) the
-- player should see, and intensity_for maps it to a 0..1 danger used for the tint
-- alpha. Both read the SAME terrain.lethal_at bands the tile-damage sweep uses, so
-- the tint lines up exactly with the damage it explains. The live show/hide of the
-- screen tint is proven in tests/test_feedback.lua; this asserts the decision off
-- the game.

package.path = package.path .. ";./?.lua;./?/init.lua"
_G.settings = { startup = {} }
local feedback = require("scripts.damage-feedback")

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1; print("ok - " .. name)
  else failed = failed + 1; print("not ok - " .. name .. ": " .. tostring(err)) end
end
local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end
local function assert_near(a, b, msg)
  if math.abs(a - b) > 1e-6 then error((msg or "differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end
local function assert_true(v, msg)
  if not v then error(msg or "expected true", 2) end
end

-- A compact, symmetric ribbon keyed by the ci-wly ZONE ROLES (the cfg terrain.widths
-- reads). Heat zones = hot_ocean + hot_inner; cold zones = cold_inner + cold_ocean.
-- With these widths (total 44, half 22):
--   heat lethal band: p >= hot_from = 14   (hot_inner cold edge)
--   cold lethal band: p <= cold_from = -14 (cold_inner hot edge)
--   safe:            -14 < p < 14
local CFG = {
  hot_ocean = 4, hot_inner = 4, hot_outer = 4,
  middle = 20,
  cold_outer = 4, cold_inner = 4, cold_ocean = 4,
}

test("no tint in the safe ribbon", function()
  assert_eq(nil, feedback.overlay_for(0, CFG))
  assert_eq(nil, feedback.overlay_for(13, CFG), "just inside the hot edge -> still safe")
  assert_eq(nil, feedback.overlay_for(-13, CFG), "just inside the cold edge -> still safe")
end)

test("heat tint across the whole hot lethal band", function()
  assert_eq("heat", feedback.overlay_for(14, CFG), "hot lethal inner edge")
  assert_eq("heat", feedback.overlay_for(22, CFG), "outermost hot edge")
end)

test("cold tint across the whole cold lethal band", function()
  assert_eq("cold", feedback.overlay_for(-14, CFG), "cold lethal inner edge")
  assert_eq("cold", feedback.overlay_for(-22, CFG), "outermost cold edge")
end)

test("intensity is 0 when safe", function()
  assert_eq(0, feedback.intensity_for(0, CFG))
  assert_eq(0, feedback.intensity_for(10, CFG))
end)

test("intensity ramps 0 -> 1 deeper into the hot band", function()
  assert_near(0, feedback.intensity_for(14, CFG), "at the hot edge")
  assert_near(1, feedback.intensity_for(22, CFG), "at the outermost hot edge")
  assert_true(feedback.intensity_for(20, CFG) > feedback.intensity_for(16, CFG),
    "deeper toward the lava -> stronger")
end)

test("intensity ramps 0 -> 1 deeper into the cold band", function()
  assert_near(0, feedback.intensity_for(-14, CFG), "at the cold edge")
  assert_near(1, feedback.intensity_for(-22, CFG), "at the outermost cold edge")
  assert_true(feedback.intensity_for(-22, CFG) > feedback.intensity_for(-16, CFG),
    "deeper toward the ice cap -> stronger")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
