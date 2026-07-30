-- Plain-Lua unit test for the pure position-scaled solar bands (§ ci-9ht,
-- scripts/panel-solar.lua). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_panel_solar.lua
--
-- panel-solar is pure (no game.* / prototypes.*): it snaps the ribbon's sunward
-- falloff into the discrete output bands the data stage (variant prototypes) and
-- the runtime (morph + damage model) both read. Both consume THIS band list, so
-- proving it here proves the prototypes and the runtime agree. The integration
-- test tests/test_panel_solar.lua asserts the SAME behaviour drives real engine
-- output under Factorio; keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local panel_solar = require("scripts.panel-solar")
local C = require("scripts.flare-config")

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

test("the full band IS the vanilla panel; reduced bands are cindra variants", function()
  assert_eq(C.PANEL, panel_solar.name_for_band(1.0), "1.0 -> the vanilla solar panel")
  assert_eq("solar-panel", panel_solar.name_for_band(1.0), "the full band is literally vanilla")
  assert_eq(C.PANEL_BAND_PREFIX .. "-b75", panel_solar.name_for_band(0.75))
  assert_eq(C.PANEL_BAND_PREFIX .. "-b05", panel_solar.name_for_band(0.05))
end)

test("all_names lists the vanilla panel plus one name per reduced band", function()
  local names = panel_solar.all_names()
  assert_eq(#panel_solar.BANDS, #names, "one name per band")
  assert_eq(C.PANEL, names[1], "the vanilla panel is first (the full band)")
  -- names are unique
  local seen = {}
  for _, n in ipairs(names) do
    assert_true(not seen[n], "duplicate band name: " .. n)
    seen[n] = true
  end
end)

test("nominal_w scales with the band; unknown names fall back to full", function()
  assert_eq(C.PANEL_NOMINAL_W, panel_solar.nominal_w(C.PANEL), "full band = full nominal")
  assert_eq(C.PANEL_NOMINAL_W * 0.4, panel_solar.nominal_w(C.PANEL_BAND_PREFIX .. "-b40"))
  assert_eq(C.PANEL_NOMINAL_W, panel_solar.nominal_w("some-other-entity"),
    "unknown name over-estimates to full (safe default)")
end)

test("a sunward panel snaps to a materially higher band than a nightward one", function()
  -- Recalibrated to the ci-da2 zones (ci-22v): the FULL band lands on the lava side
  -- (deep sunward), the floor on the ice side (deep nightward).
  local sunward = panel_solar.band_factor(360)   -- the lava side
  local nightward = panel_solar.band_factor(-150) -- the ice side
  assert_eq(1.0, sunward, "the lava side saturates at the full band")
  assert_true(sunward > 4 * nightward, "sunward output dwarfs nightward: "
    .. sunward .. " vs " .. nightward)
end)

test("the temperate centre is a REDUCED band, not full (the ci-22v bug)", function()
  -- The reported bug was the panel hitting the full band at/near spawn. The centre
  -- must snap to a reduced variant well below full, above the ice floor.
  local centre = panel_solar.band_factor(0)
  assert_true(centre < 1.0, "the centre is NOT the full band (got " .. centre .. ")")
  assert_true(centre > 0.05, "the centre still beats the deep-ice floor")
  assert_true(panel_solar.variant_for_y(0) ~= C.PANEL, "a centre panel morphs to a reduced variant")
end)

test("variant_for_y picks the base on the lava side and a reduced variant nightward", function()
  assert_eq(C.PANEL, panel_solar.variant_for_y(360), "the lava side stays the base panel")
  assert_true(panel_solar.variant_for_y(-150) ~= C.PANEL, "the ice side morphs to a reduced variant")
end)

test("band snapping is monotonic: sunward never snaps below nightward", function()
  local prev = -1
  for _, y in ipairs({ -200, -100, -50, 0, 50, 100, 200, 300, 360 }) do
    local b = panel_solar.band_factor(y)
    assert_true(b >= prev, "y=" .. y .. " band must not drop going sunward")
    prev = b
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
