-- Plain-Lua unit test for the settings->cfg bridge (scripts/config.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_config.lua
--
-- config.lua is the ONE place the runtime turns the mod's startup sliders into a
-- ribbon cfg. It reads the `settings` global, so we stub that here (no Factorio
-- needed) and assert the slider -> cfg mapping: orientation passthrough, the
-- per-side hot/cold zone depths, the MARGIN_FRAC split, and the density knobs.

package.path = package.path .. ";./?.lua;./?/init.lua"

-- Stub the Factorio `settings` global BEFORE requiring config.lua.
local stub = {}
_G.settings = { startup = stub }
local function setval(name, value) stub[name] = { value = value } end

local config = require("scripts.config")

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1; print("ok - " .. name)
  else failed = failed + 1; print("not ok - " .. name .. ": " .. tostring(err)) end
end
local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

test("empty settings fall back to valid defaults", function()
  for k in pairs(stub) do stub[k] = nil end
  local cfg = config.ribbon_cfg()
  assert_eq("east-west", cfg.orientation, "default orientation")
  assert_eq(24, cfg.safe_half_width, "default playable half-width")
  assert_eq(24 + 104, cfg.hot_wall_at, "default hot wall = safe + depth")
end)

test("orientation passes straight through", function()
  setval("cindra-ribbon-orientation", "north-south")
  assert_eq("north-south", config.ribbon_cfg().orientation)
end)

test("per-side zone depths derive wall + lethal via MARGIN_FRAC", function()
  setval("cindra-playable-half-width", 30)
  setval("cindra-hot-zone-depth", 40)
  setval("cindra-cold-zone-depth", 100)
  local cfg = config.ribbon_cfg()
  assert_eq(30, cfg.safe_half_width)
  -- hot: wall = 30 + 40 = 70; lethal = 30 + floor(40*0.5) = 50
  assert_eq(70, cfg.hot_wall_at, "hot wall")
  assert_eq(50, cfg.hot_lethal_at, "hot lethal")
  -- cold: wall = 30 + 100 = 130; lethal = 30 + floor(100*0.5) = 80
  assert_eq(130, cfg.cold_wall_at, "cold wall")
  assert_eq(80, cfg.cold_lethal_at, "cold lethal")
end)

test("damage + freeze sliders are read", function()
  setval("cindra-ribbon-max-dps", 333)
  setval("cindra-nightside-freeze-temp", -10)
  local cfg = config.ribbon_cfg()
  assert_eq(333, cfg.max_dps)
  assert_eq(-10, cfg.freeze_temp)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
