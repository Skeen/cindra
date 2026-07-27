-- Plain-Lua unit test for the pure terrain gradient (scripts/terrain.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_terrain.lua
--
-- terrain.lua is pure (no game.* / prototypes.*): it maps a perpendicular
-- coordinate to a themed band + placeholder tile. This asserts the band
-- boundaries, the full hot->cold gradient ORDER, the impassable/void backstop,
-- and which bands are "playable" (resource-eligible). The factorio-test in
-- tests/test_worldgen.lua asserts the same shape paints real tiles at runtime;
-- keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
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

-- Symmetric default geometry: safe 24, lethal 96, wall 128 -> hot_ocean_at 112.
local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128 }

test("temperate band straddles the centre", function()
  assert_eq("temperate", terrain.band(0, CFG))
  assert_eq("temperate", terrain.band(24, CFG), "sunward edge of safe band")
  assert_eq("temperate", terrain.band(-24, CFG), "nightward edge of safe band")
end)

test("sunward gradient: sand -> molten rock -> lava ocean -> void", function()
  assert_eq("sand", terrain.band(40, CFG), "sunward margin")
  assert_eq("molten_rock", terrain.band(100, CFG), "just past the hot lethal edge")
  assert_eq("lava_ocean", terrain.band(120, CFG), "deep sunward, past the ocean split")
  assert_eq("void", terrain.band(128, CFG), "at the sunward hard wall")
  assert_eq("void", terrain.band(300, CFG), "beyond the wall")
end)

test("nightward gradient: icy -> ice wall -> void", function()
  assert_eq("icy", terrain.band(-40, CFG), "nightward margin")
  assert_eq("ice_wall", terrain.band(-110, CFG), "past the cold lethal edge")
  assert_eq("void", terrain.band(-128, CFG), "at the nightward hard wall")
  assert_eq("void", terrain.band(-300, CFG), "beyond the wall (death zone)")
end)

test("the full hot->cold sequence is monotonic in M.BANDS order", function()
  -- Sample sunward-most to nightward-most; the observed non-void bands must
  -- appear in exactly the M.BANDS order (each band once, contiguous).
  local rank = {}
  for i, b in ipairs(terrain.BANDS) do rank[b] = i end
  local last = 0
  for p = 127, -127, -1 do
    local b = terrain.band(p, CFG)
    if b ~= "void" then
      assert_true(rank[b] >= last, "band order regressed at p=" .. p .. " (" .. b .. ")")
      last = rank[b]
    end
  end
  -- And every non-void band actually appears somewhere.
  local seen = {}
  for p = 127, -127, -1 do seen[terrain.band(p, CFG)] = true end
  for _, b in ipairs(terrain.BANDS) do assert_true(seen[b], "band missing: " .. b) end
end)

test("each band maps to a DISTINCT placeholder tile", function()
  local tiles, names = {}, {}
  for _, b in ipairs(terrain.BANDS) do
    local t = terrain.TILE[b]
    assert_true(t ~= nil, "band " .. b .. " has a tile")
    assert_true(not names[t], "tile " .. tostring(t) .. " reused across bands")
    names[t] = true
    tiles[#tiles + 1] = t
  end
  assert_eq(6, #tiles, "six distinct band tiles")
  assert_true(terrain.tile_for(300, CFG) == nil, "void paints no tile")
end)

test("only the playable band (temperate/sand/icy) is resource-eligible", function()
  assert_true(terrain.is_playable(0, CFG), "temperate")
  assert_true(terrain.is_playable(40, CFG), "sand margin")
  assert_true(terrain.is_playable(-40, CFG), "icy margin")
  assert_true(not terrain.is_playable(100, CFG), "molten rock is not playable")
  assert_true(not terrain.is_playable(120, CFG), "lava ocean is not playable")
  assert_true(not terrain.is_playable(-110, CFG), "ice wall is not playable")
  assert_true(not terrain.is_playable(300, CFG), "void is not playable")
end)

test("asymmetric per-side depths shift each side's bands independently", function()
  -- Shallow hot zone (lethal 30, wall 40 -> ocean split at 35), deep cold zone.
  local cfg = { safe_half_width = 20, hot_lethal_at = 30, hot_wall_at = 40,
                cold_lethal_at = 80, cold_wall_at = 160 }
  assert_eq("void", terrain.band(40, cfg), "shallow hot wall at 40")
  assert_eq("molten_rock", terrain.band(32, cfg), "molten rock is the thin [30,35) band")
  assert_eq("lava_ocean", terrain.band(37, cfg), "lava ocean is [35,40)")
  assert_eq("icy", terrain.band(-60, cfg), "deep cold margin still icy at -60")
  assert_eq("ice_wall", terrain.band(-120, cfg), "cold lethal reaches far out")
  assert_eq("ice_wall", terrain.band(-150, cfg), "still inside the deep cold wall")
  assert_eq("void", terrain.band(-160, cfg), "nightward wall at 160")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
