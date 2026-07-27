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
  assert_eq(C.PANEL_NOMINAL_W * 0.5, panel_solar.nominal_w(C.PANEL_BAND_PREFIX .. "-b50"))
  assert_eq(C.PANEL_NOMINAL_W, panel_solar.nominal_w("some-other-entity"),
    "unknown name over-estimates to full (safe default)")
end)

test("a sunward panel snaps to a materially higher band than a nightward one", function()
  local sunward = panel_solar.band_factor(96)   -- deep sunward
  local nightward = panel_solar.band_factor(-24) -- nightward floor
  assert_eq(1.0, sunward, "deep sunward saturates at the full band")
  assert_true(sunward > 4 * nightward, "sunward output dwarfs nightward: "
    .. sunward .. " vs " .. nightward)
end)

test("variant_for_y picks the base sunward and a reduced variant nightward", function()
  assert_eq(C.PANEL, panel_solar.variant_for_y(96), "deep sunward stays the base panel")
  assert_true(panel_solar.variant_for_y(-24) ~= C.PANEL, "nightward morphs to a reduced variant")
end)

test("band snapping is monotonic: sunward never snaps below nightward", function()
  local prev = -1
  for _, y in ipairs({ -40, -24, -10, 0, 24, 48, 72, 96 }) do
    local b = panel_solar.band_factor(y)
    assert_true(b >= prev, "y=" .. y .. " band must not drop going sunward")
    prev = b
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
