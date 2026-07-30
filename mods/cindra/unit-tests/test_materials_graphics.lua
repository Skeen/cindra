-- Plain-Lua unit test for the BESPOKE item/fluid icons of the materials +
-- petrochemical economy (ci-6vj S6). Sources: Malcolm Riley's `unused-renders`
-- (CC-BY-4.0); per-item mapping + attribution in graphics/ART-MANIFEST.md.
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_materials_graphics.lua
--
-- The Factorio runtime API does not expose an item/fluid prototype's icon FILE
-- path, so the in-engine tests cannot assert the icons are wired (only that the
-- prototypes load). This test closes that gap the same way test_lava_graphics does:
-- it stubs the data stage, requires the REAL prototype modules, and asserts each
-- new item/fluid draws a bespoke `__cindra__/graphics/icons/<name>.png` at
-- icon_size 64, that every referenced PNG actually ships and is truecolour RGBA,
-- and that NO vanilla placeholder (__base__/__space-age__) leaks back in. A revert
-- to a tinted-vanilla placeholder, a renamed/missing PNG, or a palette re-export
-- fails here.

package.path = package.path .. ";./?.lua;./?/init.lua"

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

-- === Stub the Factorio data stage =========================================
local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

package.loaded["util"] = {
  table = { deepcopy = deepcopy },
  by_pixel = function(x, y) return { x / 32, y / 32 } end,
}

-- aluminium.lua reads defines.direction.north for the cell's O2 output box.
_G.defines = { direction = { north = 1 } }

-- Minimal vanilla prototypes the three modules deep-copy. Each is only cloned and
-- then has fields SET on it, so a bare {type,name} table suffices.
local function item(name) return { type = "item", name = name } end
local registry = {}
local data = {
  raw = {
    ["item"] = {
      ["calcite"] = item("calcite"),
      ["copper-plate"] = item("copper-plate"),
      ["steel-plate"] = item("steel-plate"),
      ["electric-furnace"] = item("electric-furnace"),
      ["rocket-silo"] = item("rocket-silo"),
      ["rocket-part"] = item("rocket-part"),
    },
    ["furnace"] = {
      ["electric-furnace"] = { type = "furnace", name = "electric-furnace" },
    },
    ["rocket-silo"] = {
      ["rocket-silo"] = { type = "rocket-silo", name = "rocket-silo" },
    },
  },
}
function data:extend(list)
  for _, proto in ipairs(list) do
    registry[proto.type] = registry[proto.type] or {}
    registry[proto.type][proto.name] = proto
  end
end
_G.data = data

require("prototypes.plastics")
require("prototypes.aluminium")
require("prototypes.mass-driver")

local function proto(kind, name) return (registry[kind] or {})[name] end

-- The layered `icons` (set by every Cindra item/fluid) wins; fall back to `icon`.
local function icon_path(p)
  if p.icons and p.icons[1] then return p.icons[1].icon end
  return p.icon
end

-- Map a Factorio mod path to a cwd-relative path (unit tests run from mods/cindra).
local function to_rel(modpath) return (modpath:gsub("^__cindra__/", "./")) end

local function ships(modpath)
  local f = io.open(to_rel(modpath), "rb")
  if f then f:close() return true end
  return false
end

-- PNG colour-type byte (26th, 1-indexed): 6 = truecolour+alpha (RGBA). Factorio
-- draws indexed/palette PNGs (type 3) black, so icons must be RGBA.
local function png_color_type(modpath)
  local f = io.open(to_rel(modpath), "rb")
  if not f then return nil end
  local head = f:read(26)
  f:close()
  if not head or #head < 26 then return nil end
  return head:byte(26)
end

-- name -> registry kind. The four gases/liquids are fluids; the rest are items.
local ICONS = {
  { kind = "fluid", name = "cindra-hydrogen" },
  { kind = "fluid", name = "cindra-oxygen" },
  { kind = "fluid", name = "cindra-carbon-dioxide" },
  { kind = "fluid", name = "cindra-methanol" },
  { kind = "item",  name = "cindra-quicklime" },
  { kind = "item",  name = "cindra-alumina" },
  { kind = "item",  name = "cindra-aluminium" },
  { kind = "item",  name = "cindra-aluminium-powder" },
  { kind = "item",  name = "cindra-methanol-catalyst" },
  { kind = "item",  name = "cindra-spent-methanol-catalyst" },
  { kind = "item",  name = "cindra-zeolite-catalyst" },
  { kind = "item",  name = "cindra-spent-zeolite-catalyst" },
}

for _, spec in ipairs(ICONS) do
  test("bespoke icon wired for " .. spec.name, function()
    local p = proto(spec.kind, spec.name)
    assert_true(p ~= nil, spec.name .. " must be registered as a " .. spec.kind)
    local path = icon_path(p)
    assert_true(path ~= nil, spec.name .. " must set an icon")
    -- The icon file is named for the prototype: __cindra__/graphics/icons/<name>.png.
    local expected = "__cindra__/graphics/icons/" .. spec.name .. ".png"
    assert_eq(expected, path, spec.name .. " must draw its bespoke icon")
    assert_eq(64, p.icon_size, spec.name .. " icon_size must be 64")
    -- No vanilla placeholder may leak back in.
    assert_true(path:find("__base__", 1, true) == nil and path:find("__space%-age__") == nil,
      spec.name .. " must not fall back to a vanilla placeholder icon: " .. path)
    assert_true(ships(path), "icon PNG must ship: " .. path)
    assert_eq(6, png_color_type(path), "icon PNG must be truecolour RGBA (not palette): " .. path)
  end)
end

-- The two SPENT catalysts additionally carry an in-engine greying tint so the
-- live/spent pair reads apart at a glance (the renders alone are similar).
for _, name in ipairs({ "cindra-spent-methanol-catalyst", "cindra-spent-zeolite-catalyst" }) do
  test(name .. " keeps a greying tint to read as 'spent'", function()
    local p = proto("item", name)
    assert_true(p.icons and p.icons[1] and p.icons[1].tint ~= nil,
      name .. " must set a darkening tint on its icon layer")
  end)
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
