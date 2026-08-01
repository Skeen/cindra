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

-- The two inherited sprites the helpers MUST NOT leak.
local BATTERY_PNG = "__base__/graphics/entity/accumulator/accumulator.png"
local POLE_PNG = "__base__/graphics/entity/small-electric-pole/small-electric-pole.png"
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
    -- The accumulator-interface the BUFFERS clone -- carries the battery sprite.
    ["electric-energy-interface"] = {
      ["electric-energy-interface"] = {
        type = "electric-energy-interface",
        name = "electric-energy-interface",
        picture = { filename = BATTERY_PNG, width = 124, height = 103 },
        energy_source = { type = "electric", buffer_capacity = "10GJ", usage_priority = "dynamic" },
        energy_production = "500GW",
        energy_usage = "0kW",
      },
    },
    -- The small pole the TAPS clone -- carries the pole sprite + wire draw.
    ["electric-pole"] = {
      ["small-electric-pole"] = {
        type = "electric-pole",
        name = "small-electric-pole",
        pictures = { layers = { { filename = POLE_PNG, width = 72, height = 220, direction_count = 4 } } },
        maximum_wire_distance = 7.5,
        supply_area_distance = 2.5,
        connection_points = { { wire = { copper = { 0, -2.5 } }, shadow = { copper = { 3, 0 } } } },
        draw_copper_wires = true,
        draw_circuit_wires = true,
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
    assert_eq(false, buf.draw_copper_wires, n .. " must not draw copper wires")
    assert_eq(false, buf.draw_circuit_wires, n .. " must not draw circuit wires")
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

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
