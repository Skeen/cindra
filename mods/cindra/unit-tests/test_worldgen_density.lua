-- Plain-Lua unit test for worldgen's pure density-scaling helpers
-- (scripts/worldgen.lua). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_worldgen_density.lua
--
-- The density sliders (§15 v2 item 7) scale both the per-lattice placement CHANCE
-- and the node RICHNESS. Those transforms are pure (no game.*), so they are
-- asserted here; tests/test_worldgen.lua proves the runtime honours the playable
-- gate that these feed.

package.path = package.path .. ";./?.lua;./?/init.lua"
-- worldgen.lua reads `settings` only inside runtime functions, never at load, so
-- it requires cleanly here. Provide an empty stub for safety.
_G.settings = { startup = {} }
local worldgen = require("scripts.worldgen")

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

test("density 1.0 is the neutral baseline", function()
  assert_eq(0.22, worldgen.scaled_chance(0.22, 1.0))
  assert_eq(600, worldgen.scaled_amount(600, 1.0))
  -- nil density (unset slider) also behaves as 1.0.
  assert_eq(0.22, worldgen.scaled_chance(0.22, nil))
  assert_eq(600, worldgen.scaled_amount(600, nil))
end)

test("higher density raises chance and richness", function()
  assert_true(worldgen.scaled_chance(0.22, 2.0) > worldgen.scaled_chance(0.22, 1.0))
  assert_eq(1200, worldgen.scaled_amount(600, 2.0))
end)

test("lower density lowers chance and richness", function()
  assert_true(worldgen.scaled_chance(0.22, 0.5) < worldgen.scaled_chance(0.22, 1.0))
  assert_eq(300, worldgen.scaled_amount(600, 0.5))
end)

test("chance is clamped to a valid probability", function()
  assert_eq(1, worldgen.scaled_chance(0.5, 5.0), "cannot exceed 1.0")
  assert_eq(0, worldgen.scaled_chance(0, 5.0), "stays 0 when base is 0")
end)

-- control_scale reads the world-gen-screen sliders (Frequency/Size/Richness) off
-- a surface's map_gen_settings.autoplace_controls -> (chance_mult, amount_mult).
test("control_scale defaults to neutral (1,1) when the control/surface is absent", function()
  local ch, amt = worldgen.control_scale(nil, "cindra-stone")
  assert_eq(1, ch); assert_eq(1, amt)
  ch, amt = worldgen.control_scale({ autoplace_controls = {} }, "cindra-stone")
  assert_eq(1, ch); assert_eq(1, amt)
end)

test("control_scale maps Frequency->chance and Size*Richness->amount", function()
  local mgs = { autoplace_controls = {
    ["cindra-stone"] = { frequency = 2, size = 3, richness = 4 },
  } }
  local ch, amt = worldgen.control_scale(mgs, "cindra-stone")
  assert_eq(2, ch, "frequency drives placement chance")
  assert_eq(12, amt, "size * richness drives node amount")
  -- Missing sub-keys fall back to 1 each.
  local ch2, amt2 = worldgen.control_scale({ autoplace_controls = { ["cindra-ice"] = { size = 2 } } }, "cindra-ice")
  assert_eq(1, ch2, "absent frequency -> 1")
  assert_eq(2, amt2, "size 2 * richness 1 -> 2")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
