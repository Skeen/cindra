-- Plain-Lua unit test for the power-diode's RENDER wiring (prototypes/power-diode.lua,
-- ci-qj5k). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_power_diode_graphics.lua
--
-- THE BUG (ci-qj5k): the diode was reworked into a reskinned power-SWITCH whose
-- one-way transfer is implemented by two HIDDEN electric-energy-interface buffers
-- + two HIDDEN tap poles. Those helpers were cloned straight from the vanilla
-- accumulator-interface and small-electric-pole, so they inherited the BATTERY and
-- POLE sprites -- which leaked into the world, and the diode read as "two batteries
-- with power poles inside" instead of the clean switch.
--
-- The Factorio runtime API exposes NO graphics accessor (LuaEntityPrototype), so
-- the in-engine test (tests/test_power_diode.lua) cannot assert this. This test
-- closes the gap: it stubs the data stage, requires the real prototype module, and
-- asserts (1) the VISIBLE device keeps the power-switch's own animation, and (2)
-- every hidden helper renders EMPTY -- its render field points at the 1x1
-- transparent core sprite and NO inherited battery/pole sprite survives, and its
-- internal copper/circuit wires are suppressed. A regression that drops the blank
-- (re-leaking the battery/pole art) fails here.
--
-- ci-ntgh WIDENED it. Blanking the ONE field the engine draws from is not the
-- whole graphics set: each source prototype carries more art than that, and the
-- leftovers drew in states the placed-and-idle view never showed -- the pole's
-- supply-area overlay (paints whenever the player holds a pole), its water
-- reflection, and the corpse / explosion models a killed helper left lying TAP_DX
-- tiles off the device. So the sprite-leak scan now covers the WHOLE helper
-- prototype, and each leftover render field is asserted cleared by name. The
-- stubs below deliberately carry every one of those leftovers, pointing at the
-- battery / pole sprites, so a regression that stops clearing them is caught
-- twice: by name, and by the deep filename scan.

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

local function assert_false(x, msg)
  if x then error(msg or "expected false", 2) end
end

-- === Stub the Factorio data stage ==========================================

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

local EMPTY_PNG = "__core__/graphics/empty.png"

package.loaded["util"] = {
  table = { deepcopy = deepcopy },
  by_pixel = function(x, y) return { x / 32, y / 32 } end,
  empty_sprite = function()
    return { filename = EMPTY_PNG, priority = "extra-high", width = 1, height = 1 }
  end,
}

-- The inherited art the helpers MUST NOT leak -- the main sprites (ci-qj5k) and
-- the secondary render surfaces around them (ci-ntgh).
local BATTERY_PNG = "__base__/graphics/entity/accumulator/accumulator.png"
local POLE_PNG = "__base__/graphics/entity/small-electric-pole/small-electric-pole.png"
local POLE_RADIUS_PNG = "__base__/graphics/entity/small-electric-pole/electric-pole-radius-visualization.png"
local POLE_REFLECTION_PNG = "__base__/graphics/entity/small-electric-pole/small-electric-pole-reflection.png"
local BATTERY_ICON = "__base__/graphics/icons/accumulator.png"
local POLE_ICON = "__base__/graphics/icons/small-electric-pole.png"
local SWITCH_PNG = "__base__/graphics/entity/power-switch/power-switch.png"

local registry = {}
local data = {
  raw = {
    -- The power-switch the DEVICE clones. Its animation is the graphics the diode
    -- must keep as its ONLY visible art.
    ["power-switch"] = {
      ["power-switch"] = {
        type = "power-switch",
        name = "power-switch",
        power_on_animation = { layers = { { filename = SWITCH_PNG, width = 168, height = 138 } } },
      },
    },
    -- The accumulator-interface the BUFFERS clone -- carries the battery sprite,
    -- plus (ci-ntgh) the secondary render surfaces vanilla ships with it.
    ["electric-energy-interface"] = {
      ["electric-energy-interface"] = {
        type = "electric-energy-interface",
        name = "electric-energy-interface",
        icons = { { icon = BATTERY_ICON } },
        picture = { filename = BATTERY_PNG, width = 124, height = 103 },
        energy_source = { type = "electric", buffer_capacity = "10GJ", usage_priority = "dynamic" },
        energy_production = "500GW",
        energy_usage = "0kW",
        corpse = "medium-remnants",
        damaged_trigger_effect = { type = "create-entity", entity_name = "spark-explosion" },
        selection_box = { { -1, -1 }, { 1, 1 } },
        drawing_box_vertical_extension = 0.5,
      },
    },
    -- The small pole the TAPS clone -- carries the pole sprite + wire draw, the
    -- supply-area overlay, the water reflection, and its wreckage models.
    ["electric-pole"] = {
      ["small-electric-pole"] = {
        type = "electric-pole",
        name = "small-electric-pole",
        icon = POLE_ICON,
        pictures = { layers = { { filename = POLE_PNG, width = 72, height = 220, direction_count = 4 } } },
        maximum_wire_distance = 7.5,
        supply_area_distance = 2.5,
        connection_points = { { wire = { copper = { 0, -2.5 } }, shadow = { copper = { 3, 0 } } } },
        draw_copper_wires = true,
        draw_circuit_wires = true,
        radius_visualisation_picture = { filename = POLE_RADIUS_PNG, width = 12, height = 12 },
        water_reflection = { pictures = { filename = POLE_REFLECTION_PNG, width = 12, height = 28 } },
        corpse = "small-electric-pole-remnants",
        dying_explosion = "small-electric-pole-explosion",
        damaged_trigger_effect = { type = "create-entity", entity_name = "spark-explosion" },
        selection_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
        drawing_box_vertical_extension = 2.2,
      },
    },
    ["item"] = {
      ["power-switch"] = {
        type = "item", name = "power-switch",
        icons = { { icon = "__base__/graphics/icons/power-switch.png" } },
        stack_size = 50,
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

require("prototypes.power-diode")

local C = require("scripts.diode-config")
local function proto(kind, name) return (registry[kind] or {})[name] end

-- Recursively true if any string value under `t` contains `substr`.
local function has_filename(t, substr)
  if type(t) ~= "table" then return false end
  for _, v in pairs(t) do
    if type(v) == "string" and v:find(substr, 1, true) then return true end
    if type(v) == "table" and has_filename(v, substr) then return true end
  end
  return false
end

-- The single render field the ENGINE draws from, per helper type (mirrors
-- scripts/graphics-audit.lua RENDER_FIELDS): EEI -> picture, pole -> pictures.
local function assert_renders_empty(kind, name, field)
  local p = proto(kind, name)
  assert_true(p, name .. " prototype must exist")
  assert_true(type(p[field]) == "table" and p[field].filename == EMPTY_PNG,
    name .. "." .. field .. " must be the empty core sprite (renders nothing)")
end

-- === The VISIBLE device keeps ONLY the power-switch's own graphics ==========

test("the device is a power-switch that keeps the power-switch animation", function()
  local dev = proto("power-switch", C.DEVICE)
  assert_true(dev, "the device prototype must exist")
  assert_eq("power-switch", dev.type, "the device must be a power-switch")
  assert_true(dev.power_on_animation and has_filename(dev.power_on_animation, SWITCH_PNG),
    "the device must render the vanilla power-switch animation")
  -- The device is NOT blanked: its own art is what the player sees.
  assert_false(dev.picture and dev.picture.filename == EMPTY_PNG,
    "the device must not be blanked -- it is the visible model")
end)

-- === The hidden buffers (batteries) render EMPTY ============================

for _, name in ipairs({ "INPUT", "OUTPUT" }) do
  test("buffer " .. name .. " renders empty (no leaked battery sprite)", function()
    local n = C[name]
    assert_renders_empty("electric-energy-interface", n, "picture")
    local buf = proto("electric-energy-interface", n)
    assert_false(has_filename(buf, BATTERY_PNG),
      n .. " must not leak the inherited accumulator/battery sprite")
    assert_false(has_filename(buf, BATTERY_ICON),
      n .. " must not leak the inherited accumulator/battery ICON")
    assert_eq(false, buf.draw_copper_wires, n .. " must not draw copper wires")
    assert_eq(false, buf.draw_circuit_wires, n .. " must not draw circuit wires")
  end)
end

-- === THE FLOATING WARNING SYMBOL (ci-ntgh) =================================
--
-- The buffers sit TAP_DX tiles off the device (the tap poles' supply areas must
-- not cross-cover the far side's buffer, or the two networks merge and the diode
-- stops being one). An electric energy source draws the engine's "no power" /
-- "no network" icon over ITS OWN entity, so the input buffer's unmet demand
-- painted a warning symbol out in open ground, well outside the device model.
-- A hidden internal buffer must not raise a player-facing power alert at all.

for _, name in ipairs({ "INPUT", "OUTPUT" }) do
  test("buffer " .. name .. " raises no floating power warning icon", function()
    local buf = proto("electric-energy-interface", C[name])
    local src = buf.energy_source
    assert_true(src, C[name] .. " must have an electric energy source")
    assert_eq(false, src.render_no_power_icon,
      C[name] .. " must not draw the 'no power' icon (it would float TAP_DX tiles off the device)")
    assert_eq(false, src.render_no_network_icon,
      C[name] .. " must not draw the 'no network' icon (same floating position)")
  end)
end

-- === The hidden tap poles render EMPTY =====================================

for _, name in ipairs({ "INPUT_TAP", "OUTPUT_TAP" }) do
  test("tap " .. name .. " renders empty (no leaked pole sprite or wire)", function()
    local n = C[name]
    assert_renders_empty("electric-pole", n, "pictures")
    local tap = proto("electric-pole", n)
    assert_false(has_filename(tap, POLE_PNG),
      n .. " must not leak the inherited small-electric-pole sprite")
    -- The tap<->switch link is script-made and internal; its wire must not draw.
    assert_eq(false, tap.draw_copper_wires, n .. " must not draw its internal copper wire")
    assert_eq(false, tap.draw_circuit_wires, n .. " must not draw circuit wires")
  end)
end

-- === No STRAY models anywhere in the helper graphics sets (ci-ntgh) =========
--
-- Blanking the one field the engine draws from is not the whole graphics set.
-- Each leftover below renders in a state the placed-and-idle view never showed,
-- and each one puts the CLONED battery/pole art back on screen TAP_DX tiles off
-- the device -- exactly the "two batteries with power poles" look ci-qj5k was
-- supposed to have ended.
local STRAY_FIELDS = {
  "radius_visualisation_picture", -- pole supply-area overlay (paints on pole-in-hand)
  "water_reflection",             -- pole reflection over water
  "corpse",                       -- wreckage model left by a killed phantom
  "dying_explosion",              -- explosion model on the same
  "damaged_trigger_effect",       -- hit particles thrown from the phantom
}

local HELPERS = {
  { kind = "electric-energy-interface", key = "INPUT" },
  { kind = "electric-energy-interface", key = "OUTPUT" },
  { kind = "electric-pole", key = "INPUT_TAP" },
  { kind = "electric-pole", key = "OUTPUT_TAP" },
}

for _, h in ipairs(HELPERS) do
  local n = C[h.key]
  test("helper " .. h.key .. " carries no stray secondary render surfaces", function()
    local p = proto(h.kind, n)
    assert_true(p, n .. " prototype must exist")
    for _, field in ipairs(STRAY_FIELDS) do
      assert_eq(nil, p[field], n .. "." .. field .. " must be cleared (stray leftover model)")
    end
    assert_eq(false, p.alert_when_damaged, n .. " must not raise a damage alert at its offset position")
  end)

  test("helper " .. h.key .. " leaks NO cloned art anywhere in its prototype", function()
    local p = proto(h.kind, n)
    -- Deep scan of the WHOLE prototype, not just the engine's render field: any
    -- surviving reference to the battery/pole art is a model that can still draw.
    for _, png in ipairs({ BATTERY_PNG, POLE_PNG, POLE_RADIUS_PNG, POLE_REFLECTION_PNG, BATTERY_ICON, POLE_ICON }) do
      assert_false(has_filename(p, png), n .. " must not reference cloned art: " .. png)
    end
  end)

  test("helper " .. h.key .. " claims no drawing space (it draws nothing)", function()
    local p = proto(h.kind, n)
    local sb = p.selection_box
    assert_true(type(sb) == "table", n .. " must declare a selection box")
    assert_eq(0, sb[1][1], n .. " selection box must collapse to a point")
    assert_eq(0, sb[1][2], n .. " selection box must collapse to a point")
    assert_eq(0, sb[2][1], n .. " selection box must collapse to a point")
    assert_eq(0, sb[2][2], n .. " selection box must collapse to a point")
    assert_eq(0, p.drawing_box_vertical_extension,
      n .. " must not extend its drawing box upward -- there is nothing to draw")
  end)
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
