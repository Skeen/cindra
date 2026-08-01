-- Plain-Lua unit test for the electrolysis-cell's ENTITY/ITEM art + shape wiring
-- (prototypes/aluminium.lua, ci-a6z: Hurricane046's bespoke "oxidizer" set,
-- CC-BY 4.0 -- see graphics/entity/electrolysis-cell/ATTRIBUTION.md).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_aluminium_graphics.lua
--
-- The Factorio runtime API exposes neither an entity/item prototype's sprite or
-- icon FILE paths (LuaEntityPrototype has no graphics accessor) NOR its circuit
-- connector wire offset, so the in-engine test (tests/test_aluminium.lua) cannot
-- assert either. This test closes the prototype-shape gap: it stubs the data
-- stage, requires the real prototype module, and asserts the animated body /
-- shadow / emissive-glow layers, the 60-frame oxidizer animation-sheet geometry
-- (8x8 grid of 280x320 frames, last 4 empty), the additive glow blend, the icon,
-- that every referenced PNG actually ships AS RGBA (never indexed/palette, which
-- Factorio draws as a black box), that the inherited electric-furnace overlays
-- were dropped, that the footprint grew to a 4x4 box, and that the circuit wire
-- attaches at the BOTTOM-RIGHT. A renamed/removed asset, an un-wired layer, a
-- wrong frame count, a re-exported palette sheet, a leftover electric-furnace
-- working-visualisation, a shrunk box, or a wire that drifts back to centre-top
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

local function assert_nil(x, msg)
  if x ~= nil then error(msg or "expected nil", 2) end
end

-- === Stub the Factorio data stage ==========================================
-- prototypes/aluminium.lua needs `util` (deepcopy + table + by_pixel), the global
-- `data` (calcite + steel-plate items to clone for the two item defs, the
-- electric-furnace `furnace` entity + item to clone for the cell, and an :extend
-- sink), and `defines.direction` for the cell's output fluid box.

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

_G.defines = { direction = { north = 0, east = 2, south = 4, west = 6 } }

-- Registry is keyed by type then name (the entity, item, recipe, and build recipe
-- share the "cindra-electrolysis-cell" name, so a name-only key would collide).
local registry = {}
local data = {
  raw = {
    -- The electric furnace the cell deep-copies. Carries a graphics_set, a
    -- graphics_set_flipped, and working_visualisations so we can prove the
    -- oxidizer wiring REPLACES them rather than leaking electric-furnace art.
    ["furnace"] = {
      ["electric-furnace"] = {
        type = "furnace",
        name = "electric-furnace",
        icon = "__base__/electric-furnace-icon.png",
        icons = { { icon = "__base__/electric-furnace-icon.png" } },
        icon_size = 64,
        crafting_categories = { "smelting" },
        graphics_set = {
          animation = { layers = { { filename = "__base__/electric-furnace.png", width = 239, height = 219 } } },
          working_visualisations = { { animation = { filename = "__base__/electric-furnace-heater.png" } } },
        },
        graphics_set_flipped = { animation = { filename = "__base__/electric-furnace-flipped.png" } },
        working_visualisations = { { animation = { filename = "__base__/electric-furnace-work.png" } } },
        fast_replaceable_group = "furnace",
        next_upgrade = "electric-furnace",
      },
    },
    ["item"] = {
      ["electric-furnace"] = {
        type = "item",
        name = "electric-furnace",
        icon = "__base__/electric-furnace-icon.png",
        icons = { { icon = "__base__/electric-furnace-icon.png" } },
        icon_size = 64,
      },
      -- alumina clones calcite; aluminium clones steel-plate (item defs only; this
      -- test asserts the MACHINE art, not the item icons, but the module needs them
      -- to load).
      ["calcite"] = { type = "item", name = "calcite", icon = "__base__/calcite.png", icon_size = 64, stack_size = 50 },
      ["steel-plate"] = { type = "item", name = "steel-plate", icon = "__base__/steel-plate.png", icon_size = 64, stack_size = 100 },
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

-- === Stub the core circuit-connector globals (ci-sz0k) ======================
-- aluminium.lua now builds the cell's connector from the core
-- `universal_connector_template` via `circuit_connector_definitions.create_vector`
-- (a real connector SPRITE at the bottom-right, matching the lava-manufacturer),
-- replacing the ci-a6z points-only connector that rendered nothing. Those are
-- core globals absent in plain Lua; stub a create_vector that records the
-- main_offset(s) and returns a minimal 4-direction connector carrying the offset
-- as the wire point AND a sprites marker -- enough to assert the module built a
-- real (sprite-bearing) connector aimed bottom-right.
_G.universal_connector_template = { name = "stub-universal-template" }
local captured_offsets = {}
_G.circuit_connector_definitions = {
  create_vector = function(template, defs)
    assert(template == _G.universal_connector_template, "must reuse the universal connector template")
    local out = {}
    for i, d in ipairs(defs) do
      captured_offsets[i] = d.main_offset
      out[i] = {
        points = { wire = { red = d.main_offset, green = d.main_offset } },
        sprites = { has_sprites = true, variation = d.variation },
      }
    end
    return out
  end,
}

require("prototypes.aluminium")

local CELL = "cindra-electrolysis-cell"
local function proto(kind, name) return (registry[kind] or {})[name] end

-- Translate a Factorio mod path ("__cindra__/graphics/...") to a path relative to
-- the mod root (the cwd this test runs from) and check it exists.
local function ships(modpath)
  local rel = modpath:gsub("^__cindra__/", "./")
  local f = io.open(rel, "rb")
  if f then f:close() return true end
  return false
end

local function all_ship(layer)
  if layer.filename then assert_true(ships(layer.filename), "PNG must ship: " .. layer.filename) end
  if layer.filenames then
    for _, fn in ipairs(layer.filenames) do
      assert_true(ships(fn), "PNG must ship: " .. fn)
    end
  end
end

-- The PNG IHDR colour-type byte (offset 25, 0-indexed): 6 = truecolour+alpha
-- (RGBA), 2 = truecolour, 4 = grey+alpha, 0 = grey, 3 = indexed/palette. The PNG
-- layout is: 8-byte signature, then the IHDR chunk (length + "IHDR" + width[4] +
-- height[4] + bit-depth[1] + colour-type[1] ...), so the colour type is the 26th
-- byte (1-indexed) of the file.
local function png_color_type(modpath)
  local rel = modpath:gsub("^__cindra__/", "./")
  local f = io.open(rel, "rb")
  if not f then return nil end
  local head = f:read(26)
  f:close()
  if not head or #head < 26 then return nil end
  return head:byte(26)
end

-- Every PNG a layer references must be a truecolour RGBA sheet (colour type 6).
-- The oxidizer source PNGs shipped as indexed/palette (type 3) and the shadow as
-- grey+alpha (type 4); Factorio draws both as a solid black box (the ci-8r6
-- glass-furnace bug). ci-a6z converts them to RGBA; this fails on any regression
-- back to a palette/grey sheet, passes on RGBA.
local RGBA = 6
local function all_rgba(layer)
  local files = {}
  if layer.filename then files[#files + 1] = layer.filename end
  for _, fn in ipairs(layer.filenames or {}) do files[#files + 1] = fn end
  for _, fn in ipairs(files) do
    assert_eq(RGBA, png_color_type(fn),
      "PNG must be truecolour RGBA (not indexed/palette/grey, which Factorio draws black): " .. fn)
  end
end

local function layers()
  local m = proto("furnace", CELL)
  assert_true(m ~= nil, "electrolysis-cell entity must be registered")
  assert_true(m.graphics_set ~= nil and m.graphics_set.animation ~= nil, "graphics_set.animation must exist")
  local ls = m.graphics_set.animation.layers
  assert_true(ls ~= nil, "animation must be layered (body + shadow + glow)")
  return ls
end

local function find_layers()
  local body, shadow, glow
  for _, l in ipairs(layers()) do
    if l.draw_as_shadow then shadow = l
    elseif l.draw_as_glow then glow = l
    else body = l end
  end
  return body, shadow, glow
end

-- === graphics_set.animation: body / shadow / glow layers ====================
test("electrolysis-cell wires a 3-layer animation (body + shadow + glow)", function()
  local m = proto("furnace", CELL)
  assert_eq("furnace", m.type, "still a furnace (electric-furnace clone)")
  assert_eq(3, #layers(), "expected body + shadow + glow layers")
  local body, shadow, glow = find_layers()
  assert_true(body ~= nil, "a lit opaque body layer must exist")
  assert_true(shadow ~= nil, "a draw_as_shadow layer must exist")
  assert_true(glow ~= nil, "a draw_as_glow (emission) layer must exist")
end)

-- === Body is the 60-frame oxidizer animation (280x320, 8/row) ===============
test("body layer is the 60-frame oxidizer animation (280x320, line_length 8)", function()
  local body = find_layers()
  assert_true(body.filename ~= nil, "body uses a single-file sheet")
  assert_true(body.filename:find("oxidizer%-hr%-animation%-1") ~= nil,
    "body must be the oxidizer animation sheet, got: " .. tostring(body.filename))
  assert_eq(280, body.width, "frame width (2240/8)")
  assert_eq(320, body.height, "frame height (2560/8)")
  assert_eq(60, body.frame_count, "60 non-empty frames (rows 0-6 full + 4 of row 7; last 4 cells empty)")
  assert_eq(8, body.line_length, "8 frames per row")
  assert_true(body.scale ~= nil, "body must set a scale")
  assert_true(body.shift ~= nil, "body must set a shift")
  assert_true(not body.draw_as_shadow and not body.draw_as_glow, "body is the lit, opaque layer")
  all_ship(body)
  all_rgba(body)
end)

-- === Body must sit on the 4x4 footprint, not float or vanish ================
test("body/emission scale fits the footprint and the shift does not float it", function()
  local body, _, glow = find_layers()
  -- 320px-tall frame; a scale in [0.35, 0.6] renders ~112-192 px tall, seating the
  -- machine over its 4x4 box with a modest signature overhang (0.45 -> ~4.5 tiles
  -- tall). A regression to a tiny or absurd scale fails here.
  assert_true(body.scale >= 0.35 and body.scale <= 0.6,
    "body scale must fit the 4x4 box (0.35-0.6), got " .. tostring(body.scale))
  -- ci-sz0k (playtest): the body was nudged UP a smidge so it centres in the 4x4
  -- box (north = -y), but the lift stays tiny -- it must NOT float off the ground.
  -- So shift.y is strictly negative (moved up from the old {0,0}) yet above the
  -- -0.2-tile float floor.
  assert_true(body.shift[2] < 0,
    "body must be nudged UP a smidge (shift.y < 0), got " .. tostring(body.shift[2]))
  assert_true(body.shift[2] > -0.2,
    "body must not be lifted off the ground (shift.y > -0.2), got " .. tostring(body.shift[2]))
  -- Body + emission must stay locked together (same scale + shift) or the molten
  -- arc glow drifts off the body.
  assert_eq(body.scale, glow.scale, "emission scale must match the body")
  assert_eq(body.shift[1], glow.shift[1], "emission shift.x must match the body")
  assert_eq(body.shift[2], glow.shift[2], "emission shift.y must match the body")
end)

test("shadow layer is a draw_as_shadow layer from the shadow image", function()
  local _, shadow = find_layers()
  assert_true(shadow.filename:find("shadow") ~= nil, "shadow must use the shadow image")
  all_ship(shadow)
  all_rgba(shadow)
end)

test("emission layer is a draw_as_glow oxidizer emission sheet matching the body", function()
  local _, _, glow = find_layers()
  assert_true(glow.filename ~= nil, "glow uses a single-file sheet")
  assert_true(glow.filename:find("oxidizer%-hr%-emission%-1") ~= nil,
    "glow must use the oxidizer emission sheet, got: " .. tostring(glow.filename))
  -- Emission is drawn on the SAME frame geometry as the body so it registers.
  assert_eq(280, glow.width, "glow frame width matches body")
  assert_eq(320, glow.height, "glow frame height matches body")
  assert_eq(60, glow.frame_count, "glow frame count matches body")
  assert_eq(8, glow.line_length, "glow line_length matches body")
  all_ship(glow)
  all_rgba(glow)
end)

-- === The emission layer MUST blend additive (the ci-036 black-box cause) =====
test("emission layer blends additive so it never paints a black box over the body", function()
  -- The emission sheet is FULLY OPAQUE (alpha 1 everywhere) with a black
  -- background and bright arc openings. draw_as_glow alone does NOT change the
  -- blend op, so the opaque black background would draw straight over the furnace
  -- body -> a solid black box with only the openings showing (the ci-036
  -- glass-furnace symptom). blend_mode = "additive" makes the black background
  -- contribute nothing and only the bright openings add glow. Fails on a nil
  -- blend_mode, passes on the fix.
  local _, _, glow = find_layers()
  assert_eq("additive", glow.blend_mode,
    "emission layer must set blend_mode = 'additive' (opaque black bg would else box the body)")
end)

-- === Every layer ships as truecolour RGBA, never indexed/palette (ci-8r6) ====
test("every oxidizer layer ships as truecolour RGBA, not indexed/palette", function()
  for _, l in ipairs(layers()) do all_rgba(l) end
end)

-- === Inherited electric-furnace art must be dropped (no reskin leak) =========
test("inherited electric-furnace overlays are cleared", function()
  local m = proto("furnace", CELL)
  assert_nil(m.graphics_set_flipped, "electric-furnace graphics_set_flipped must be dropped")
  assert_nil(m.working_visualisations, "electric-furnace working_visualisations must be dropped")
  -- The replaced graphics_set must not carry the electric-furnace's own nested
  -- working_visualisations either.
  assert_nil(m.graphics_set.working_visualisations,
    "the cloned graphics_set.working_visualisations must be gone (replaced wholesale)")
  -- No layer may reference electric-furnace art.
  for _, l in ipairs(layers()) do
    if l.filename then
      assert_true(l.filename:find("electric%-furnace") == nil, "no electric-furnace art may leak: " .. l.filename)
    end
  end
end)

-- === Nightside frost overlay (ci-z7nu) ======================================
-- Replacing the electric-furnace graphics_set wholesale dropped the furnace's
-- frozen_patch, so the oxidizer froze on the nightside with NO frost sheen while
-- the other frozen buildings kept theirs. The engine draws the frozen visual
-- ONLY from graphics_set.frozen_patch, so it must be restored. This fails on main
-- (no frozen_patch) and passes on the fix.
test("frozen oxidizer wears a frost overlay (graphics_set.frozen_patch)", function()
  local m = proto("furnace", CELL)
  local fp = m.graphics_set.frozen_patch
  assert_true(fp ~= nil, "graphics_set.frozen_patch must exist so the frozen cell shows frost")
  assert_true(fp.filename ~= nil and fp.filename:find("frozen") ~= nil,
    "frozen_patch must point at a frost sprite, got: " .. tostring(fp and fp.filename))
  assert_true(fp.width ~= nil and fp.height ~= nil, "frozen_patch must set width/height")
  assert_true(m.graphics_set.reset_animation_when_frozen == true,
    "reset_animation_when_frozen halts the cycle so a frozen cell reads as stopped")
end)

-- === Item + entity icon =====================================================
test("entity and item share the oxidizer icon at icon_size 64", function()
  local e = proto("furnace", CELL)
  local item = proto("item", CELL)
  assert_true(item ~= nil, "electrolysis-cell item must be registered")
  for _, p in ipairs({ e, item }) do
    assert_true(p.icon and p.icon:find("oxidizer%-icon") ~= nil,
      "icon must be the oxidizer icon, got: " .. tostring(p.icon))
    assert_eq(64, p.icon_size, "icon_size must match the 64px icon")
    assert_nil(p.icons, "the inherited layered electric-furnace icon must be cleared")
    assert_true(ships(p.icon), "icon PNG must ship: " .. p.icon)
  end
end)

-- === Footprint grew to a 4x4 box (ci-a6z) ===================================
-- The cell was a 3x3 electric-furnace clone; the oxidizer body reads far bigger,
-- so the box was enlarged to a full 4x4 (tile_width/height pinned to 4, selection
-- box 4.0, collision box just inside it). A regression to the inherited 3x3 (or a
-- selection box that no longer matches the model) fails here.
test("selection/collision box is a 4x4 footprint", function()
  local m = proto("furnace", CELL)
  assert_eq(4, m.tile_width, "tile_width must be pinned to 4 (even-grid snap)")
  assert_eq(4, m.tile_height, "tile_height must be pinned to 4")
  assert_true(m.selection_box ~= nil, "the cell must set an explicit selection_box")
  local sb = m.selection_box
  local w = sb[2][1] - sb[1][1]
  local h = sb[2][2] - sb[1][2]
  assert_true(w >= 3.8 and w <= 4.2, "selection box must be ~4 tiles wide, got " .. tostring(w))
  assert_true(h >= 3.8 and h <= 4.2, "selection box must be ~4 tiles tall, got " .. tostring(h))
  -- Collision box must sit strictly inside the selection box (a bigger collision
  -- would block placement it shouldn't).
  local cb = m.collision_box
  assert_true(cb ~= nil, "the cell must set an explicit collision_box")
  assert_true((cb[2][1] - cb[1][1]) < w, "collision box must be smaller than the selection box")
  assert_true(cb[1][1] > sb[1][1] and cb[2][1] < sb[2][1], "collision box must sit inside the selection box")
end)

-- === Circuit connector RENDERS a sprite at the bottom-right (ci-sz0k) ========
-- ci-a6z re-anchored the wire bottom-right but left a POINTS-ONLY connector, so
-- nothing rendered on the model (the playtest bug: no connector visible at all).
-- The cell now rebuilds the connector from the universal template via
-- create_vector, which ships a real connector SPRITE co-located with the wire
-- pins at the bottom-right of the 4x4 box (+x = east, +y = south -> bottom-right
-- is (+,+)). Assert every direction carries a sprite AND a bottom-right wire
-- point inside the footprint. A regression to points-only (no sprite) or a drift
-- back toward the centre/top (y < 0) fails here. The module aims the connector
-- via create_vector's main_offset, captured by the stub above.
test("circuit connector renders a sprite at the bottom-right", function()
  local m = proto("furnace", CELL)
  assert_true(m.circuit_connector ~= nil, "the cell must define a circuit_connector")
  assert_eq(4, #m.circuit_connector, "the connector must cover all 4 directions")
  for i, def in ipairs(m.circuit_connector) do
    assert_true(def.sprites ~= nil,
      "connector entry " .. i .. " must carry SPRITES so a connector graphic renders")
    assert_true(def.points ~= nil and def.points.wire ~= nil,
      "connector entry " .. i .. " must define points.wire")
    local red = def.points.wire.red
    assert_true(red ~= nil, "the wire point must be set")
    assert_true(red[1] > 0 and red[2] > 0,
      "wire must attach bottom-right (x>0, y>0), got {" .. red[1] .. ", " .. red[2] .. "}")
    -- The wire point must sit inside the 4x4 half-extent (2.0), not off the machine.
    assert_true(red[1] <= 2.0 and red[2] <= 2.0,
      "the wire point must sit within the 4x4 footprint")
  end
  -- Every direction must have been aimed bottom-right through create_vector.
  assert_eq(4, #captured_offsets, "create_vector must be called for all 4 directions")
  for i, off in ipairs(captured_offsets) do
    assert_true(off[1] > 0 and off[2] > 0,
      "direction " .. i .. " main_offset must be bottom-right, got {" .. off[1] .. ", " .. off[2] .. "}")
  end
  assert_true(m.circuit_wire_max_distance and m.circuit_wire_max_distance > 0,
    "the cell must stay circuit-connectable (circuit_wire_max_distance > 0)")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
