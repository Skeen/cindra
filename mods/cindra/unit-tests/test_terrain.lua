-- Plain-Lua unit test for the ribbon TERRAIN gradient (scripts/terrain.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is pure: it maps a perpendicular coordinate to a vanilla tile name
-- reading the same band boundaries as scripts/ribbon.lua. This proves the tile
-- ORDER and that the three hot damage tiles line up with the fire-damage zone;
-- the factorio-test in tests/test_worldgen.lua proves the tiles actually paint on
-- a live surface with the default (vertical, hot-left) orientation.

package.path = package.path .. ";./?.lua;./?/init.lua"
local terrain = require("scripts.terrain")
local ribbon = require("scripts.ribbon")

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

local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128 } -- edge_mid = 112

test("the wide safe band at spawn is natural land (no painted tile)", function()
  assert_eq(nil, terrain.tile_for(0, CFG), "the terminator centre stays temperate")
  assert_eq(nil, terrain.tile_for(15, CFG), "well inside the safe band stays temperate")
  assert_eq(nil, terrain.tile_for(-15, CFG), "symmetric on the cold side")
end)

test("hot side lays hot-lava -> lava -> volcanic-cracks-hot from the edge inward", function()
  -- Sunward is p > 0; depth increases toward the hot edge.
  assert_eq("volcanic-cracks-hot", terrain.tile_for(60, CFG), "the walkable ramp margin")
  assert_eq("lava", terrain.tile_for(100, CFG), "the molten mid band")
  assert_eq("lava-hot", terrain.tile_for(120, CFG), "the hottest edge, just inside the wall")
  -- Order from the hot edge inward: deepest is lava-hot, then lava, then cracks.
  local edge = terrain.tile_for(126, CFG)
  local mid = terrain.tile_for(104, CFG)
  local inner = terrain.tile_for(50, CFG)
  assert_eq("lava-hot", edge, "leftmost/edge = hot-lava")
  assert_eq("lava", mid, "then lava")
  assert_eq("volcanic-cracks-hot", inner, "then volcanic-cracks-hot toward temperate")
end)

test("a sand fringe blends the hot margin into the temperate band", function()
  assert_eq("sand-1", terrain.tile_for(22, CFG), "the last strip of the safe band is sand")
end)

test("cold side mirrors it: ice-smooth -> ice-rough -> ammoniacal-ocean (the ice wall)", function()
  assert_eq("snow-flat", terrain.tile_for(-22, CFG), "the cold fringe is snow")
  assert_eq("ice-smooth", terrain.tile_for(-60, CFG), "the walkable freezing margin")
  assert_eq("ice-rough", terrain.tile_for(-100, CFG), "deep ice")
  assert_eq("ammoniacal-ocean", terrain.tile_for(-120, CFG), "the frozen ice wall")
end)

test("beyond the wall is void (nil), left to the hard-wall backstop", function()
  assert_eq(nil, terrain.tile_for(140, CFG), "sunward past the wall")
  assert_eq(nil, terrain.tile_for(-140, CFG), "nightward past the wall")
end)

test("the three hot tiles sit exactly in the fire-damage zone (terrain == damage)", function()
  -- Damage begins beyond the safe half-width; the sand fringe is inside it.
  local d_sand = ribbon.damage_per_second(22, CFG)
  local d_cracks = ribbon.damage_per_second(60, CFG)
  local d_lava = ribbon.damage_per_second(100, CFG)
  local d_hotlava = ribbon.damage_per_second(120, CFG)
  assert_eq(0, d_sand, "the sand fringe deals no damage (still the safe band)")
  assert_true(d_cracks > 0, "volcanic-cracks-hot deals fire damage")
  assert_true(d_lava >= d_cracks, "lava is at least as lethal (deeper)")
  assert_true(d_hotlava >= d_lava, "hot-lava is the most lethal edge")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
