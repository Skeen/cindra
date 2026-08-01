-- Plain-Lua unit test for footprint TILE damage (scripts/tile-damage.lua; ci-ma18).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_tile_damage.lua
--
-- footprint_damage samples every integer tile an entity's collision box covers and
-- returns the MOST-LETHAL tile's damage (terrain.tile_damage) -- so a machine
-- straddling a lava tile burns even when its centre sits on safe ground, a fully
-- covered (concrete) footprint takes nothing, and an entity fully on safe ground takes
-- nothing. It reads the pure tile predicate, so it is testable off-game against a fake
-- surface whose get_tile returns a synthetic tile grid.

package.path = package.path .. ";./?.lua;./?/init.lua"
local td = require("scripts.tile-damage")

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

-- A fake surface: get_tile(x, y) returns the tile whose name grid_fn(tx, ty) gives.
-- Defaults every tile to a safe ash tile unless grid_fn overrides it.
local function fake_surface(grid_fn)
  return {
    get_tile = function(tx, ty)
      local name = grid_fn(tx, ty) or "cindra-volcanic-ash-flats"
      return { valid = true, name = name }
    end,
  }
end

-- A fake entity with a square collision box of `half` tiles centred at (cx, cy).
local function box_entity(cx, cy, half)
  return { bounding_box = { left_top = { x = cx - half, y = cy - half },
                            right_bottom = { x = cx + half, y = cy + half } } }
end

test("damage_amount is dps * seconds (pure, linear in time)", function()
  assert_eq(100, td.damage_amount(300, 20), "300 dps over 20 ticks = 100 HP")
  assert_eq(200, td.damage_amount(300, 40), "twice the ticks = twice the HP")
end)

test("a footprint entirely on a SAFE tile takes ZERO damage", function()
  local s = fake_surface(function() return "cindra-volcanic-ash-flats" end)
  local i, k = td.footprint_damage(s, box_entity(0.5, 0.5, 0.4))
  assert_eq(0, i, "safe ground intensity is 0")
  assert_eq(nil, k, "safe ground has no damage kind")
end)

test("a footprint on a HOT natural burns; a hotter natural burns more", function()
  local hot = fake_surface(function() return "cindra-volcanic-cracks-hot" end)
  local hotter = fake_surface(function() return "cindra-lava" end)
  local i1, k1 = td.footprint_damage(hot, box_entity(0.5, 0.5, 0.4))
  local i2 = select(1, td.footprint_damage(hotter, box_entity(0.5, 0.5, 0.4)))
  assert_true(i1 > 0, "glowing cracks-hot burns")
  assert_eq("heat", k1, "and it is heat")
  assert_true(i2 > i1, "molten lava burns more than the cracks")
end)

test("a footprint on a COLD natural freezes; a colder natural freezes more", function()
  local cold = fake_surface(function() return "cindra-snow-crests" end)
  local colder = fake_surface(function() return "cindra-ice-smooth" end)
  local i1, k1 = td.footprint_damage(cold, box_entity(0.5, 0.5, 0.4))
  local i2 = select(1, td.footprint_damage(colder, box_entity(0.5, 0.5, 0.4)))
  assert_true(i1 > 0, "snow freezes")
  assert_eq("cold", k1, "and it is cold")
  assert_true(i2 > i1, "smooth ice freezes more than snow")
end)

test("CONCRETE cover over a hot natural SHIELDS the whole footprint (ci-ma18)", function()
  -- Every tile the footprint covers is concrete (a player-placed cover), so even though
  -- lava sits "underneath" in the world, the TILE is concrete -> zero damage.
  local s = fake_surface(function() return "concrete" end)
  local i, k = td.footprint_damage(s, box_entity(0.5, 0.5, 1.4))
  assert_eq(0, i, "concrete-covered ground deals no damage")
  assert_eq(nil, k, "concrete-covered ground has no damage kind")
end)

test("a footprint STRADDLING a lava tile burns even if its centre is safe (most-lethal)", function()
  -- A 3-wide machine centred on safe ash at tile (0,0), but tile (1,0) is lava.
  local s = fake_surface(function(tx, ty)
    if tx == 1 and ty == 0 then return "cindra-lava-hot" end
    return "cindra-volcanic-ash-flats"
  end)
  local i, k = td.footprint_damage(s, box_entity(0, 0, 1.4)) -- covers tx,ty in [-2..1]
  assert_true(i > 0, "the overlapping lava tile burns even though the centre is safe ash")
  assert_eq("heat", k, "and the overlap is heat")
  -- Shrink the box so it no longer reaches tile (1,0): back to zero.
  local i2 = select(1, td.footprint_damage(s, box_entity(-1, 0, 0.4))) -- covers tile (-1,0) only
  assert_eq(0, i2, "a footprint that stays on safe ground takes nothing")
end)

test("the sweep is a no-op on a surface that is not named cindra", function()
  -- sweep bails before ever touching entities when the surface name is wrong.
  local touched = false
  local s = { valid = true, name = "nauvis",
    find_entities_filtered = function() touched = true; return {} end }
  td.sweep(s, 60, 200)
  assert_true(not touched, "sweep never scans entities off Cindra")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
