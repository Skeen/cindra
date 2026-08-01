-- Plain-Lua unit test for the PURE feedback decision (scripts/damage-feedback.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_feedback.lua
--
-- for_tile maps the cindra TILE a character stands on to (which heat/cold tint, if
-- any, 0..1 intensity for the tint alpha). It reads the SAME terrain.tile_damage the
-- tile-damage sweep uses (ci-ma18), so the tint lines up EXACTLY with the damage it
-- explains: a hazard tile tints, a safe natural or a player-placed COVER tile shows
-- nothing. The live show/hide of the screen tint is proven in tests/test_feedback.lua;
-- this asserts the decision off the game.

package.path = package.path .. ";./?.lua;./?/init.lua"
_G.settings = { startup = {} }
local feedback = require("scripts.damage-feedback")
local terrain = require("scripts.terrain")

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
local function which(name) return (select(2, feedback.for_tile(name))) end
local function intensity(name) return (select(1, feedback.for_tile(name))) end

test("no tint on a safe natural or in the safe middle", function()
  assert_eq(nil, which("cindra-volcanic-ash-flats"), "the ash middle is safe")
  assert_eq(0, intensity("cindra-volcanic-ash-flats"), "and its intensity is 0")
  assert_eq(nil, which("cindra-volcanic-cracks-warm"), "the safe-band warm cracks are safe")
  assert_eq(nil, which("cindra-snow-flat"), "safe-band snow is safe")
end)

test("heat tint on the hot naturals, scaling toward the lava core", function()
  assert_eq("heat", which("cindra-volcanic-cracks-hot"), "glowing cracks tint red")
  assert_eq("heat", which("cindra-lava-hot"), "the lava core tints red")
  assert_true(intensity("cindra-lava-hot") > intensity("cindra-volcanic-cracks-hot"),
    "deeper toward the lava -> stronger tint")
end)

test("cold tint on the cold naturals, scaling toward the ice core", function()
  assert_eq("cold", which("cindra-snow-crests"), "snow tints blue")
  assert_eq("cold", which("cindra-ice-smooth"), "the ice core tints blue")
  assert_true(intensity("cindra-ice-smooth") > intensity("cindra-snow-crests"),
    "deeper toward the ice cap -> stronger tint")
end)

test("a COVER tile (concrete) shows NOTHING -- the tint matches the shield (ci-ma18)", function()
  for _, name in ipairs({ "concrete", "refined-concrete", "stone-path" }) do
    assert_eq(nil, which(name), name .. " shows no tint")
    assert_eq(0, intensity(name), name .. " has zero intensity")
  end
end)

test("for_tile IS terrain.tile_damage (single source of truth: tint == damage)", function()
  for _, name in ipairs({ "cindra-lava-hot", "cindra-ice-smooth", "cindra-volcanic-ash-flats", "concrete" }) do
    local fi, fk = feedback.for_tile(name)
    local ti, tk = terrain.tile_damage(name)
    assert_eq(ti, fi, name .. " intensity matches the damage source")
    assert_eq(tk, fk, name .. " kind matches the damage source")
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
