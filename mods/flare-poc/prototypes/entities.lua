-- Flare PoC entities. All are self-contained clones/definitions so the mod
-- adds nothing to any other planet: it only introduces NEW prototypes, never
-- edits vanilla ones (the never-mutate-other-planets rule).
--
-- Entities are created directly by tests via surface.create_entity, so no items
-- or recipes are needed here; they can be placed from the editor for a playtest.

local util = require("util")
local C = require("scripts.config")

local function watts(w) return string.format("%dW", math.floor(w)) end
local function joules(j) return string.format("%dJ", math.floor(j)) end

-- The flare solar panel: a high-output panel we can track and degrade. Its
-- actual output = PANEL_NOMINAL_W * solar_factor * surface.solar_power_multiplier,
-- so at the fixed SOLAR_MULT it swings from ~1x (baseline/dim) to ~100x (flare).
local panel = util.table.deepcopy(data.raw["solar-panel"]["solar-panel"])
panel.name = C.PANEL
panel.minable = nil -- no item dependency; created directly in tests
panel.next_upgrade = nil
panel.max_health = C.PANEL_MAX_HEALTH
panel.production = watts(C.PANEL_NOMINAL_W)
panel.placeable_by = nil

-- Capacitor: fast, small. Huge flow, tiny buffer -> catches the sharp leading
-- edge of a flare, then fills almost instantly (spec sec.12 item 5).
local capacitor = util.table.deepcopy(data.raw["accumulator"]["accumulator"])
capacitor.name = C.CAPACITOR
capacitor.minable = nil
capacitor.next_upgrade = nil
capacitor.energy_source = {
  type = "electric",
  buffer_capacity = joules(C.CAPACITOR_BUFFER_J),
  usage_priority = "tertiary",
  input_flow_limit = watts(C.CAPACITOR_FLOW_W),
  output_flow_limit = watts(C.CAPACITOR_FLOW_W),
}

-- Molten-salt battery: bulk, slow. Huge buffer, small flow -> soaks the
-- sustained plateau but can never catch the spike alone (spec sec.12 item 6).
-- Its heat upkeep (slow self-discharge when idle) is applied in scripts/sinks.lua.
local battery = util.table.deepcopy(data.raw["accumulator"]["accumulator"])
battery.name = C.BATTERY
battery.minable = nil
battery.next_upgrade = nil
battery.energy_source = {
  type = "electric",
  buffer_capacity = joules(C.BATTERY_BUFFER_J),
  usage_priority = "tertiary",
  input_flow_limit = watts(C.BATTERY_FLOW_W),
  output_flow_limit = watts(C.BATTERY_FLOW_W),
}

-- Dissipator: infinite safe waste, rate-limited per building. A pure consumer
-- (electric-energy-interface). Its rated draw is the reliable disposal floor and
-- the sacrificial fuse: counted before any panel takes damage (spec sec.10).
local dissipator = {
  type = "electric-energy-interface",
  name = C.DISSIPATOR,
  icon = "__base__/graphics/icons/accumulator.png",
  icon_size = 64,
  flags = { "placeable-neutral", "player-creation" },
  max_health = 150,
  collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } },
  selection_box = { { -1, -1 }, { 1, 1 } },
  energy_source = {
    type = "electric",
    buffer_capacity = "1MJ",
    usage_priority = "secondary-input",
    input_flow_limit = watts(C.DISSIPATOR_DRAW_W),
    output_flow_limit = "0W",
  },
  energy_production = "0W",
  energy_usage = watts(C.DISSIPATOR_DRAW_W),
  gui_mode = "none",
  picture = {
    filename = "__core__/graphics/empty.png",
    priority = "extra-high",
    width = 1,
    height = 1,
  },
}

-- Test measurement rig: absorbs a panel's full output unthrottled so a test can
-- read real engine solar output (see scripts/config.lua C.MEASURE_SINK).
local measure = util.table.deepcopy(data.raw["accumulator"]["accumulator"])
measure.name = C.MEASURE_SINK
measure.minable = nil
measure.next_upgrade = nil
measure.energy_source = {
  type = "electric",
  buffer_capacity = joules(C.MEASURE_BUFFER_J),
  usage_priority = "tertiary",
  input_flow_limit = watts(C.MEASURE_FLOW_W),
  output_flow_limit = watts(C.MEASURE_FLOW_W),
}

data:extend({ panel, capacitor, battery, dissipator, measure })
