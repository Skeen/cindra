-- Plain-Lua unit test for the electrolysis cell's BESPOKE entity/item art
-- (prototypes/aluminium.lua, ci-eb9: replaces the reused electric-furnace sprite
-- + icon with the ART-MANIFEST generator's electrolysis-cell art).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_aluminium_graphics.lua
--
-- The Factorio runtime API does not expose an entity/item prototype's sprite or
-- icon FILE paths (LuaEntityPrototype has no graphics accessor), so the in-engine
-- test (tests/test_aluminium.lua) cannot assert the art is wired. This test closes
-- that gap the same way test_lava_graphics does: it stubs the data stage, requires
-- the real prototype module, and asserts the cell's graphics_set body + shadow
-- layers, the bespoke icon on both the entity and the item, that every referenced
-- PNG ships as truecolour RGBA, and that NO electric-furnace art (the v1
-- placeholder) leaks back in. A revert to the reused electric-furnace sprite/icon,
-- a renamed/missing PNG, or a palette re-export fails here.

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

local function assert_nil(x, msg)
  if x ~= nil then error(msg or "expected nil", 2) end
end

-- === Stub the Factorio data stage ==========================================
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

-- The vanilla prototypes aluminium.lua deep-copies. The electric furnace carries
-- its OWN graphics (graphics_set + directional overlays) and a layered icon so we
-- can prove the bespoke wiring REPLACES them rather than leaking furnace art.
local registry = {}
local data = {
  raw = {
    ["item"] = {
      ["calcite"] = { type = "item", name = "calcite" },
      ["steel-plate"] = { type = "item", name = "steel-plate" },
      ["electric-furnace"] = {
        type = "item", name = "electric-furnace",
        icon = "__base__/graphics/icons/electric-furnace.png",
        icons = { { icon = "__base__/graphics/icons/electric-furnace.png" } },
        pictures = { { filename = "__base__/graphics/icons/electric-furnace.png" } },
      },
    },
    ["furnace"] = {
      ["electric-furnace"] = {
        type = "furnace", name = "electric-furnace",
        energy_usage = "180kW",
        crafting_categories = { "smelting" },
        graphics_set = {
          animation = { layers = { { filename = "__base__/graphics/entity/electric-furnace/electric-furnace.png", width = 239, height = 250 } } },
          working_visualisations = { { animation = { filename = "__base__/graphics/entity/electric-furnace/electric-furnace-heater.png" } } },
        },
        graphics_set_flipped = { animation = { filename = "__base__/graphics/entity/electric-furnace/electric-furnace-flipped.png" } },
        working_visualisations = { { animation = { filename = "__base__/graphics/entity/electric-furnace/electric-furnace-wv.png" } } },
        icon = "__base__/graphics/icons/electric-furnace.png",
        icons = { { icon = "__base__/graphics/icons/electric-furnace.png" } },
      },
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

require("prototypes.aluminium")

local CELL = "cindra-electrolysis-cell"
local function proto(kind, name) return (registry[kind] or {})[name] end

-- Translate a Factorio mod path ("__cindra__/graphics/...") to a cwd-relative path
-- (unit tests run from mods/cindra) and check the file exists.
local function ships(modpath)
  local rel = modpath:gsub("^__cindra__/", "./")
  local f = io.open(rel, "rb")
  if f then f:close() return true end
  return false
end

-- PNG IHDR colour-type byte (26th, 1-indexed): 6 = truecolour+alpha (RGBA).
-- Factorio draws indexed/palette PNGs (type 3) black, so art must be RGBA.
local RGBA = 6
local function png_color_type(modpath)
  local rel = modpath:gsub("^__cindra__/", "./")
  local f = io.open(rel, "rb")
  if not f then return nil end
  local head = f:read(26)
  f:close()
  if not head or #head < 26 then return nil end
  return head:byte(26)
end

local function no_vanilla(path)
  assert_true(path:find("__base__", 1, true) == nil and path:find("__space%-age__") == nil,
    "must not reference a vanilla placeholder: " .. path)
  assert_true(path:find("electric%-furnace") == nil,
    "must not reference the reused electric-furnace art: " .. path)
end

local function layers()
  local cell = proto("furnace", CELL)
  assert_true(cell ~= nil, "the electrolysis cell entity must be registered")
  assert_true(cell.graphics_set ~= nil and cell.graphics_set.animation ~= nil,
    "the furnace must render from graphics_set.animation")
  local ls = cell.graphics_set.animation.layers
  assert_true(ls ~= nil, "the cell animation must be layered (body + shadow)")
  return ls
end

-- === graphics_set.animation: body + shadow layers ==========================
test("the cell wires a bespoke 2-layer graphics_set (body + shadow)", function()
  local cell = proto("furnace", CELL)
  assert_eq("furnace", cell.type, "still a furnace (electric-furnace clone)")
  assert_eq(2, #layers(), "expected exactly a body + shadow layer")
end)

test("body layer is the bespoke electrolysis-cell sprite (ships, RGBA, no furnace leak)", function()
  local body
  for _, l in ipairs(layers()) do
    if not l.draw_as_shadow then body = l end
  end
  assert_true(body ~= nil, "a lit (non-shadow) body layer must exist")
  local expected = "__cindra__/graphics/entity/electrolysis-cell/electrolysis-cell.png"
  assert_eq(expected, body.filename, "body must be the bespoke cell sprite")
  no_vanilla(body.filename)
  assert_true(ships(body.filename), "body PNG must ship: " .. body.filename)
  assert_eq(RGBA, png_color_type(body.filename),
    "body PNG must be truecolour RGBA (not palette): " .. body.filename)
end)

test("shadow layer is a draw_as_shadow layer from the bespoke shadow image", function()
  local shadow
  for _, l in ipairs(layers()) do if l.draw_as_shadow then shadow = l end end
  assert_true(shadow ~= nil, "a draw_as_shadow layer must exist")
  assert_true(shadow.filename:find("electrolysis%-cell%-shadow") ~= nil,
    "shadow must use the bespoke shadow image, got: " .. tostring(shadow.filename))
  assert_true(ships(shadow.filename), "shadow PNG must ship: " .. shadow.filename)
  assert_eq(RGBA, png_color_type(shadow.filename),
    "shadow PNG must be truecolour RGBA: " .. shadow.filename)
end)

-- === Inherited electric-furnace overlays must be dropped ====================
test("inherited electric-furnace overlays are cleared (no reskinned-furnace leak)", function()
  local cell = proto("furnace", CELL)
  assert_nil(cell.graphics_set_flipped, "electric-furnace graphics_set_flipped must be dropped")
  assert_nil(cell.working_visualisations, "electric-furnace working_visualisations must be dropped")
  -- No layer of the replaced graphics_set may reference electric-furnace art.
  for _, l in ipairs(layers()) do
    if l.filename then no_vanilla(l.filename) end
  end
end)

-- === Bespoke icon on both the entity and the item ==========================
test("entity + item share the bespoke electrolysis-cell icon at icon_size 64", function()
  local e = proto("furnace", CELL)
  local item = proto("item", CELL)
  assert_true(item ~= nil, "the electrolysis cell item must be registered")
  local expected = "__cindra__/graphics/icons/electrolysis-cell.png"
  for _, p in ipairs({ e, item }) do
    assert_eq(expected, p.icon, "icon must be the bespoke cell icon, got: " .. tostring(p.icon))
    assert_eq(64, p.icon_size, "icon_size must be 64")
    assert_nil(p.icons, "the inherited layered electric-furnace icon must be cleared")
    no_vanilla(p.icon)
    assert_true(ships(p.icon), "icon PNG must ship: " .. p.icon)
    assert_eq(RGBA, png_color_type(p.icon),
      "icon PNG must be truecolour RGBA (not palette): " .. p.icon)
  end
  -- The cloned electric-furnace item's own pictures must not linger.
  assert_nil(item.pictures, "the inherited electric-furnace item pictures must be cleared")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
