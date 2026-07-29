-- Plain-Lua unit test for the lava-manufacturer's ENTITY/ITEM art wiring
-- (prototypes/lava.lua, ci-oi8: the user-supplied glass-furnace set by
-- Hurricane046 / CC-BY -- see graphics/entity/lava-manufacturer/ATTRIBUTION.md).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_lava_graphics.lua
--
-- The Factorio runtime API does not expose an entity/item prototype's sprite or
-- icon FILE paths (LuaEntityPrototype has no graphics accessor), so the in-engine
-- test (tests/test_lava.lua) cannot assert the art is wired. This test closes the
-- prototype-shape gap: it stubs the data stage, requires the real prototype
-- module, and asserts the animated body / shadow / emissive-glow layers, the
-- two-part animation-sheet geometry, the icon, that every referenced PNG actually
-- ships, and that the inherited foundry overlays were dropped. A renamed/removed
-- asset, an un-wired layer, a wrong frame count, or a leftover foundry
-- working-visualisation fails here.

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
-- prototypes/lava.lua needs `util` (deepcopy + table + by_pixel), the global
-- `data` (a `foundry` assembling-machine + item to clone, and an :extend sink),
-- and the pure prototypes.lava-icon module (loaded for real).

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

-- Registry is keyed by type then name: the entity, item, recipe, and build recipe
-- share the "cindra-lava-manufacturer" name, so a name-only key would collide.
local registry = {}
local data = {
  raw = {
    -- The shared foundry the manufacturer deep-copies. Carries a graphics_set,
    -- directional working_visualisations, and a layered icon so we can prove the
    -- glass-furnace wiring REPLACES them rather than leaking foundry art through.
    ["assembling-machine"] = {
      ["foundry"] = {
        type = "assembling-machine",
        name = "foundry",
        graphics_set = { animation = { filename = "__space-age__/foundry.png" } },
        graphics_set_flipped = { animation = { filename = "__space-age__/foundry-flipped.png" } },
        working_visualisations = { { animation = { filename = "__space-age__/foundry-work.png" } } },
        -- Foundry fluid_boxes reference working visualisations BY NAME; those
        -- dangle once the graphics_set is replaced and error the load unless
        -- cleared (the "input-pipe doesn't exist" regression).
        fluid_boxes = {
          { production_type = "input", enable_working_visualisations = { "input-pipe" } },
          { production_type = "output", enable_working_visualisations = { "output-pipe" } },
          off_when_no_fluid_recipe = true, -- non-array key: must be tolerated
        },
        heating_energy = "100kW",
      },
    },
    ["item"] = {
      ["foundry"] = {
        type = "item",
        name = "foundry",
        icon = "__space-age__/foundry-icon.png",
        icons = { { icon = "__space-age__/foundry-icon.png" } },
        pictures = { { filename = "__space-age__/foundry-item.png" } },
      },
    },
    -- ci-669: lava.lua also deep-copies the shared lava fluid (for its tinted
    -- cindra-lava clone) and the two vanilla molten-from-lava recipes (for the
    -- Cindra casting clones). Stub them so the module loads; this test only
    -- asserts the MACHINE art, not the recipe balance (that is tests/test_lava.lua).
    ["fluid"] = {
      ["lava"] = { type = "fluid", name = "lava", icon = "__space-age__/lava.png" },
    },
    ["recipe"] = {
      ["molten-iron-from-lava"] = {
        type = "recipe", name = "molten-iron-from-lava", category = "metallurgy",
        ingredients = {}, results = {},
      },
      ["molten-copper-from-lava"] = {
        type = "recipe", name = "molten-copper-from-lava", category = "metallurgy",
        ingredients = {}, results = {},
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

require("prototypes.lava")

local MACHINE = "cindra-lava-manufacturer"
local function proto(kind, name) return (registry[kind] or {})[name] end

-- Translate a Factorio mod path ("__cindra__/graphics/...") to a path relative to
-- the mod root (the cwd this test runs from) and check it exists.
local function ships(modpath)
  local rel = modpath:gsub("^__cindra__/", "./")
  local f = io.open(rel, "rb")
  if f then f:close() return true end
  return false
end

-- Every filename referenced by a layer (single `filename` or multi-file
-- `filenames`) must ship.
local function all_ship(layer)
  if layer.filename then assert_true(ships(layer.filename), "PNG must ship: " .. layer.filename) end
  if layer.filenames then
    for _, fn in ipairs(layer.filenames) do
      assert_true(ships(fn), "PNG must ship: " .. fn)
    end
  end
end

local function layers()
  local m = proto("assembling-machine", MACHINE)
  assert_true(m ~= nil, "lava-manufacturer entity must be registered")
  assert_true(m.graphics_set ~= nil and m.graphics_set.animation ~= nil, "graphics_set.animation must exist")
  local ls = m.graphics_set.animation.layers
  assert_true(ls ~= nil, "animation must be layered (body + shadow + glow)")
  return ls
end

-- === graphics_set.animation: body / shadow / glow layers ====================
test("lava-manufacturer wires a 3-layer animation (body + shadow + glow)", function()
  local m = proto("assembling-machine", MACHINE)
  assert_eq("assembling-machine", m.type, "still an assembling-machine (foundry clone)")
  assert_eq(3, #layers(), "expected body + shadow + glow layers")
end)

-- The body is a TWO-PART animation sheet: 80 frames of 270x310 laid out 8/row,
-- part 1 (8 rows = 64 frames) + part 2 (2 rows = 16 frames), stitched via
-- filenames + lines_per_file. This geometry is what makes the furnace animate.
test("body layer is a two-part 80-frame glass-furnace animation (270x310)", function()
  local body = layers()[1]
  assert_true(body.filenames ~= nil, "body must use a multi-file (two-part) sheet")
  assert_eq(2, #body.filenames, "body sheet is split across two files")
  assert_true(body.filenames[1]:find("glass%-furnace%-hr%-animation%-1") ~= nil,
    "body part 1 must be the animation-1 sheet, got: " .. tostring(body.filenames[1]))
  assert_true(body.filenames[2]:find("glass%-furnace%-hr%-animation%-2") ~= nil,
    "body part 2 must be the animation-2 sheet, got: " .. tostring(body.filenames[2]))
  assert_eq(270, body.width, "frame width")
  assert_eq(310, body.height, "frame height")
  assert_eq(80, body.frame_count, "80 frames total (matches the source gif)")
  assert_eq(8, body.line_length, "8 frames per row")
  assert_eq(8, body.lines_per_file, "8 rows read from part 1 before spilling to part 2")
  assert_true(body.scale ~= nil, "body must set a scale")
  assert_true(body.shift ~= nil, "body must set a shift")
  assert_true(not body.draw_as_shadow and not body.draw_as_glow, "body is the lit, opaque layer")
  all_ship(body)
end)

test("shadow layer is a draw_as_shadow layer from the shadow image", function()
  local shadow
  for _, l in ipairs(layers()) do if l.draw_as_shadow then shadow = l end end
  assert_true(shadow ~= nil, "a draw_as_shadow layer must exist")
  assert_true(shadow.filename:find("shadow") ~= nil, "shadow must use the shadow image")
  all_ship(shadow)
end)

test("emission layer is a draw_as_glow two-part animation of the emission sheet", function()
  local glow
  for _, l in ipairs(layers()) do if l.draw_as_glow then glow = l end end
  assert_true(glow ~= nil, "a draw_as_glow (emission) layer must exist")
  assert_true(glow.filenames ~= nil and #glow.filenames == 2, "glow is a two-part sheet too")
  assert_true(glow.filenames[1]:find("emission") ~= nil, "glow must use the emission sheet")
  -- Emission is drawn on the SAME frame geometry as the body so it registers.
  assert_eq(270, glow.width, "glow frame width matches body")
  assert_eq(310, glow.height, "glow frame height matches body")
  assert_eq(80, glow.frame_count, "glow frame count matches body")
  all_ship(glow)
end)

-- === Inherited foundry art must be dropped (no reskinned-foundry leak) =======
test("inherited foundry overlays are cleared", function()
  local m = proto("assembling-machine", MACHINE)
  assert_nil(m.graphics_set_flipped, "foundry graphics_set_flipped must be dropped")
  assert_nil(m.working_visualisations, "foundry working_visualisations must be dropped")
  -- No fluid box may still enable a working visualisation by name: the names live
  -- in the replaced graphics_set and would dangle ("input-pipe doesn't exist").
  for _, fb in pairs(m.fluid_boxes or {}) do
    if type(fb) == "table" then
      assert_nil(fb.enable_working_visualisations, "fluid_box WV reference must be cleared")
    end
  end
  -- The replaced graphics_set must not reference any foundry art.
  local ls = layers()
  for _, l in ipairs(ls) do
    if l.filename then
      assert_true(l.filename:find("foundry") == nil, "no foundry art may leak: " .. l.filename)
    end
    if l.filenames then
      for _, fn in ipairs(l.filenames) do
        assert_true(fn:find("foundry") == nil, "no foundry art may leak: " .. fn)
      end
    end
  end
end)

-- === Item + entity icon =====================================================
test("entity and item share the glass-furnace icon at icon_size 64", function()
  local e = proto("assembling-machine", MACHINE)
  local item = proto("item", MACHINE)
  assert_true(item ~= nil, "lava-manufacturer item must be registered")
  for _, p in ipairs({ e, item }) do
    assert_true(p.icon and p.icon:find("glass%-furnace%-icon") ~= nil,
      "icon must be the glass-furnace icon, got: " .. tostring(p.icon))
    assert_eq(64, p.icon_size, "icon_size must match the 64px icon")
    assert_nil(p.icons, "the inherited layered foundry icon must be cleared")
    assert_true(ships(p.icon), "icon PNG must ship: " .. p.icon)
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
