-- Plain-Lua unit test for footprint belt damage (scripts/tile-damage.lua; ci-oe83).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_tile_damage.lua
--
-- footprint_damage reads the perpendicular EXTREMES of an entity's collision box and
-- returns the MOST-LETHAL field damage any part of it touches -- so a machine whose
-- footprint overlaps a belt burns even when its centre reads safe, and an entity fully in
-- the safe middle takes nothing. It reads only the pure field + axis maths (no game.*), so
-- it is testable off-game with a synthetic bounding box.

package.path = package.path .. ";./?.lua;./?/init.lua"
local td = require("scripts.tile-damage")
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
local function assert_true(x, msg) if not x then error(msg or "expected true", 2) end end

-- A fake entity with a square collision box of `half` tiles centred at world x = cx
-- (vertical orientation: perp = -x, so the box spans perp [-(cx+half), -(cx-half)]).
local function box_entity(cx, half)
  return { bounding_box = { left_top = { x = cx - half, y = 0 - half }, right_bottom = { x = cx + half, y = 0 + half } } }
end

test("a footprint fully in the safe middle takes ZERO damage", function()
  local i, k = td.footprint_damage(box_entity(0, 0.4), "vertical")
  assert_eq(0, i, "middle intensity is 0")
  assert_eq(nil, k, "middle has no damage kind")
end)

test("a footprint deep in the hot belt burns; deeper burns more", function()
  local shallow = select(1, td.footprint_damage(box_entity(-135, 0.4), "vertical")) -- perp ~135
  local deep = select(1, td.footprint_damage(box_entity(-165, 0.4), "vertical"))     -- perp ~165
  assert_true(shallow > 0, "the shallow hot belt burns")
  assert_true(deep > shallow, "deeper into the hot belt burns more")
  assert_eq("heat", (select(2, td.footprint_damage(box_entity(-165, 0.4), "vertical"))), "hot belt is heat")
end)

test("a footprint deep in the cold belt freezes; deeper freezes more", function()
  local shallow = select(1, td.footprint_damage(box_entity(135, 0.4), "vertical"))
  local deep = select(1, td.footprint_damage(box_entity(165, 0.4), "vertical"))
  assert_true(shallow > 0, "the shallow cold belt freezes")
  assert_true(deep > shallow, "deeper into the cold belt freezes more")
  assert_eq("cold", (select(2, td.footprint_damage(box_entity(165, 0.4), "vertical"))), "cold belt is cold")
end)

test("a WIDE footprint centred in the safe zone but OVERLAPPING the hot belt burns", function()
  -- Centre at perp = 120 (safe), but a half-width of 20 reaches perp 140 -> in the belt.
  local i, k = td.footprint_damage(box_entity(-120, 20), "vertical")
  assert_true(i > 0, "the overlapping edge burns even though the centre reads safe")
  assert_eq("heat", k, "the overlap is heat")
  -- The same box centred deeper safe (perp 90, reach 110) never touches the belt.
  local i2 = select(1, td.footprint_damage(box_entity(-90, 15), "vertical"))
  assert_eq(0, i2, "a box that stays inside the safe zone takes nothing")
end)

test("the footprint takes the MOST-LETHAL point (max intensity in its span)", function()
  -- A box spanning perp [130, 170]: the intensity is that of the deepest point (perp 170),
  -- not the shallow edge.
  local edge = select(1, td.footprint_damage(box_entity(-170, 0), "vertical")) -- a point at perp 170
  local span = select(1, td.footprint_damage(box_entity(-150, 20), "vertical")) -- perp [130,170]
  assert_true(math.abs(span - edge) < 1e-6, "the span's damage equals its deepest point")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
