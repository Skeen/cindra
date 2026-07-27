-- Plain-Lua unit test for the pure feedback decision (scripts/damage-feedback.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_feedback.lua
--
-- overlay_for maps a perpendicular coordinate to which heat/cold banner (if any)
-- the player should see. It reads the ribbon zone, so it lines up exactly with
-- the edge damage it explains. The GUI show/hide is proven against a live player
-- in tests/test_feedback.lua; this asserts the decision off the game.

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

test("no banner in the safe ribbon", function()
  assert_eq(nil, feedback.overlay_for(0))
  assert_eq(nil, feedback.overlay_for(24))
  assert_eq(nil, feedback.overlay_for(-24))
end)

test("heat banner across the whole hot zone (warn + lethal)", function()
  assert_eq("heat", feedback.overlay_for(60), "sunward margin")
  assert_eq("heat", feedback.overlay_for(110), "sunward lethal edge")
end)

test("cold banner across the whole cold zone (warn + lethal)", function()
  assert_eq("cold", feedback.overlay_for(-60), "nightward margin")
  assert_eq("cold", feedback.overlay_for(-110), "nightward lethal edge")
end)

test("honours orientation-independent perp coordinate + per-side cfg", function()
  -- Shallow hot zone: +30 is already lethal-hot -> heat; deep cold zone: -30 safe.
  local cfg = { safe_half_width = 20, hot_lethal_at = 25, cold_lethal_at = 96 }
  assert_eq("heat", feedback.overlay_for(30, cfg))
  assert_eq(nil, feedback.overlay_for(-18, cfg), "still inside the safe band nightward")
  assert_eq("cold", feedback.overlay_for(-40, cfg))
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
