-- Plain-Lua unit test for the WORKING-LIGHT art of Cindra's flare-storage kit
-- (prototypes/storage.lua, ci-z94: the capacitor / molten-salt battery /
-- dissipator stopped being the still images ci-pru shipped).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_storage_graphics.lua
--
-- WHY THIS TEST AND NOT AN IN-ENGINE ONE: LuaEntityPrototype exposes no graphics
-- accessor, so factorio-test cannot see a sprite at all. But the ways an animated
-- building breaks VISIBLY are all decidable off-game, and this test decides them:
--
--   • THE SHEET GEOMETRY MATCHES THE FILE. A frame_count / line_length that does
--     not divide the actual PNG is not an error -- the engine happily slices
--     frames out of nothing, so the player sees the building flickering through
--     blank and half cells. Every animation layer is checked against the real
--     PNG's IHDR dimensions, so the declared grid must genuinely exist on disk.
--   • THE GLOW LIGHTS THE BODY INSTEAD OF PAINTING OVER IT. draw_as_glow alone
--     does NOT change the blend op (the ci-036 glass-furnace regression); the
--     emission layer must also blend "additive".
--   • THE BODY HOLDS FOR THE WHOLE CYCLE. Every layer of a layered Animation runs
--     the same length, so the single-frame body/shadow need repeat_count equal to
--     the glow's frame_count or the building blinks out mid-animation.
--   • THE MOTION IS REGISTERED ON THE BODY. Glow and body share scale and shift,
--     so the light sits on the machine rather than beside it.
--   • THE STATES ARE ACTUALLY DISTINCT. Idle, charging and discharging must be
--     three different sheets -- the whole point is telling them apart in world.
--   • EVERY REFERENCED PNG SHIPS, as RGBA (Factorio draws palette art black).
--
-- The class is walked LIVE out of the registry, so a new Cindra power building
-- with a mis-declared sheet fails here without anyone adding a case.

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
-- prototypes/storage.lua needs `util` (deepcopy) and the global `data` carrying
-- the vanilla accumulator entity + item it clones, plus an :extend sink. The
-- flare numbers come from the REAL scripts/flare-config.lua.

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

package.loaded["util"] = { table = { deepcopy = deepcopy } }

local registry = {}
local data = {
  raw = {
    ["accumulator"] = {
      ["accumulator"] = {
        type = "accumulator", name = "accumulator",
        minable = { mining_time = 0.1, result = "accumulator" },
        chargable_graphics = { picture = { filename = "__base__/accumulator.png" } },
      },
    },
    ["item"] = {
      ["accumulator"] = {
        type = "item", name = "accumulator",
        icon = "__base__/accumulator-icon.png", subgroup = "energy",
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

require("prototypes.storage")

local C = require("scripts.flare-config")
local audit = require("scripts.graphics-audit")

local function proto(kind, name) return (registry[kind] or {})[name] end

-- === PNG helpers ===========================================================
-- A PNG is: 8-byte signature, then the IHDR chunk (4-byte length + "IHDR" tag +
-- width[4] + height[4] + bit-depth[1] + colour-type[1]). So width/height are the
-- big-endian 4-byte fields at 1-indexed offsets 17 and 21, and the colour type
-- is byte 26 (6 = truecolour+alpha; 3 = indexed, which Factorio draws black).
local function png_header(modpath)
  local f = io.open((modpath:gsub("^__cindra__/", "./")), "rb")
  if not f then return nil end
  local head = f:read(26)
  f:close()
  if not head or #head < 26 then return nil end
  local function be32(at)
    local a, b, c, d = head:byte(at, at + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return { width = be32(17), height = be32(21), color_type = head:byte(26) }
end

-- Walk a graphics table and hand every layer that names a file to `visit`.
local function each_layer(node, visit)
  if type(node) ~= "table" then return end
  if type(node.filename) == "string" then visit(node) end
  for _, child in pairs(node) do each_layer(child, visit) end
end

-- Every Cindra power building the player places, discovered live.
local function player_buildings()
  local out = {}
  for _, kind in ipairs({ "accumulator", "electric-energy-interface" }) do
    for name, p in pairs(registry[kind] or {}) do
      if name:sub(1, 7) == "cindra-" and audit.is_player_building(p) then
        out[#out + 1] = { type = kind, name = name, proto = p }
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

test("the flare-storage kit is discovered as three player-placed buildings", function()
  local found = {}
  for _, b in ipairs(player_buildings()) do found[b.name] = true end
  assert_true(found[C.CAPACITOR], "capacitor must be a player building")
  assert_true(found[C.BATTERY], "molten-salt battery must be a player building")
  assert_true(found[C.DISSIPATOR], "dissipator must be a player building")
end)

-- === The coverage guard: no Cindra power building ships as a still image =====
test("every player-placed Cindra power building shows its working state", function()
  local specs = {}
  for _, b in ipairs(player_buildings()) do specs[#specs + 1] = { type = b.type, name = b.name } end
  local bad = audit.static_offenders(registry, specs)
  assert_eq(0, #bad, "static building(s): " .. table.concat(bad, ", "))
end)

-- === The sheet geometry must exist on disk ==================================
test("every declared animation grid genuinely fits its PNG", function()
  local checked = 0
  for _, b in ipairs(player_buildings()) do
    each_layer(b.proto, function(layer)
      if layer.filename:sub(1, 11) ~= "__cindra__/" then return end
      local hdr = png_header(layer.filename)
      assert_true(hdr ~= nil, "PNG must ship: " .. layer.filename)
      assert_eq(6, hdr.color_type,
        "PNG must be truecolour RGBA (Factorio draws palette art black): " .. layer.filename)
      local frames = layer.frame_count or 1
      if frames > 1 then
        checked = checked + 1
        local per_row = layer.line_length or frames
        local rows = math.ceil(frames / per_row)
        -- The declared grid must FIT: a sheet too small means the engine slices
        -- frames out of empty space and the building flickers through blanks.
        assert_true(per_row * layer.width <= hdr.width,
          string.format("%s: %d frames/row x %dpx exceeds the %dpx-wide sheet",
            layer.filename, per_row, layer.width, hdr.width))
        assert_true(rows * layer.height <= hdr.height,
          string.format("%s: %d rows x %dpx exceeds the %dpx-tall sheet",
            layer.filename, rows, layer.height, hdr.height))
        -- ...and it must not leave a spare row/column of art unused, which is
        -- how a frame silently goes missing after a regenerate.
        assert_true(hdr.width < (per_row + 1) * layer.width,
          layer.filename .. ": sheet is wider than the declared grid (a frame column is unused)")
        assert_true(hdr.height < (rows + 1) * layer.height,
          layer.filename .. ": sheet is taller than the declared grid (a frame row is unused)")
      end
    end)
  end
  assert_true(checked >= 5, "expected at least 5 animation sheets, checked " .. checked)
end)

-- === Layer discipline inside each working animation ==========================
-- Collect the animations the engine plays for a building: an accumulator's
-- charge/discharge pair, an electric-energy-interface's load animation.
local function working_animations(b)
  local anims = {}
  if b.type == "accumulator" then
    local g = b.proto.chargable_graphics or {}
    anims["charge"] = g.charge_animation
    anims["discharge"] = g.discharge_animation
  else
    anims["load"] = b.proto.animation
  end
  return anims
end

test("each working animation is body + shadow + an ADDITIVE glow", function()
  for _, b in ipairs(player_buildings()) do
    for state, a in pairs(working_animations(b)) do
      local label = b.name .. "/" .. state
      assert_true(a ~= nil and a.layers ~= nil, label .. " must be a layered animation")
      assert_eq(3, #a.layers, label .. " expected body + shadow + glow layers")
      local body, shadow, glow
      for _, l in ipairs(a.layers) do
        if l.draw_as_shadow then shadow = l
        elseif l.draw_as_glow then glow = l
        else body = l end
      end
      assert_true(body ~= nil, label .. ": needs an opaque body layer")
      assert_true(shadow ~= nil, label .. ": needs a ground shadow")
      assert_true(glow ~= nil, label .. ": needs an emissive glow layer")
      -- ci-036: draw_as_glow alone does not change the blend op.
      assert_eq("additive", glow.blend_mode,
        label .. ": the glow must ADD to the body, not paint over it")
      -- Layered animations run one length: the still body/shadow must be held
      -- for the glow's whole cycle or the building blinks out mid-animation.
      assert_eq(glow.frame_count, body.repeat_count, label .. ": body must hold for every glow frame")
      assert_eq(glow.frame_count, shadow.repeat_count, label .. ": shadow must hold for every glow frame")
      assert_true((glow.frame_count or 1) > 1, label .. ": a one-frame 'animation' does not move")
      -- Registered on the body: same scale, same shift.
      assert_eq(body.scale, glow.scale, label .. ": glow must be drawn at the body's scale")
      assert_eq(body.shift[1], glow.shift[1], label .. ": glow x-shift must match the body")
      assert_eq(body.shift[2], glow.shift[2], label .. ": glow y-shift must match the body")
    end
  end
end)

test("idle, charging and discharging are three DIFFERENT sheets", function()
  for _, b in ipairs(player_buildings()) do
    local seen, glows = {}, 0
    for state, a in pairs(working_animations(b)) do
      for _, l in ipairs(a.layers) do
        if l.draw_as_glow then
          assert_true(not seen[l.filename],
            b.name .. ": " .. state .. " reuses another state's sheet (" .. l.filename .. ")")
          seen[l.filename] = true
          glows = glows + 1
        end
      end
    end
    assert_true(glows >= 1, b.name .. ": no working sheet at all")
  end
end)

-- === Per-building state wiring ==============================================
test("the capacitor snaps and the battery lingers (their identities, in ticks)", function()
  local cap = proto("accumulator", C.CAPACITOR).chargable_graphics
  local bat = proto("accumulator", C.BATTERY).chargable_graphics
  -- The capacitor is the SPIKE CATCHER and the battery the sluggish bulk store
  -- (DESIGN.md §5). If both lit up the same way the player could not tell a full
  -- capacitor bank from a full battery bank at a glance, which is the read the
  -- whole flare loop is played on.
  assert_true(cap.charge_cooldown < bat.charge_cooldown,
    "the capacitor's light must settle faster than the battery's")
  assert_true(cap.discharge_cooldown < bat.discharge_cooldown,
    "the capacitor must stop glowing sooner after a dump than the battery")
  local function glow_speed(a)
    for _, l in ipairs(a.layers) do if l.draw_as_glow then return l.animation_speed end end
  end
  assert_true(glow_speed(cap.charge_animation) > glow_speed(bat.charge_animation),
    "the capacitor's charge animation must run faster than the battery's")
  -- Every cooldown is a uint8 in the engine.
  for _, v in ipairs({ cap.charge_cooldown, cap.discharge_cooldown,
                       bat.charge_cooldown, bat.discharge_cooldown }) do
    assert_true(v >= 0 and v <= 255 and v % 1 == 0, "cooldown must be a uint8, got " .. tostring(v))
  end
end)

test("both accumulators keep an IDLE picture distinct from their working sheets", function()
  for _, name in ipairs({ C.CAPACITOR, C.BATTERY }) do
    local g = proto("accumulator", name).chargable_graphics
    assert_true(g.picture ~= nil, name .. ": must keep a still idle picture")
    local idle = {}
    each_layer(g.picture, function(l) idle[l.filename] = true end)
    for _, a in ipairs({ g.charge_animation, g.discharge_animation }) do
      for _, l in ipairs(a.layers) do
        if l.draw_as_glow then
          assert_true(not idle[l.filename], name .. ": the idle state must not glow")
        end
      end
    end
  end
end)

test("the dissipator's animation IS its render (no rival picture field)", function()
  local d = proto("electric-energy-interface", C.DISSIPATOR)
  -- An electric-energy-interface renders ONE of picture/pictures/animation/
  -- animations, and scales `animation` to what it is consuming. Leaving a
  -- `picture` alongside risks the engine drawing the still one and the load
  -- readout never showing.
  assert_nil(d.picture, "picture must be dropped in favour of the load animation")
  assert_nil(d.pictures)
  assert_nil(d.animations)
  assert_true(d.animation ~= nil, "the dissipator must animate")
  -- `continuous_animation` would decouple the animation from the load, turning
  -- the readout back into decoration.
  assert_nil(d.continuous_animation, "the shimmer must stay tied to actual consumption")
  assert_true(d.light ~= nil, "waste heat should cast light")
  assert_true(audit.is_visible(d, "electric-energy-interface"), "and still render at all")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
