-- Cindra flare storage + dissipator (§15-9; DESIGN.md §5). Integrated from the
-- proven flare-poc (ci-zg3). Three new buildings absorb the flare's surplus:
--
--   * capacitor          fast, small: catches the sharp leading edge of a flare.
--   * molten-salt battery bulk, slow: soaks the sustained plateau across an
--                        array; self-discharges (heat upkeep) when idle.
--   * dissipator         infinite safe waste, rate-limited: the disposal floor
--                        and the sacrificial fuse for the panel-damage rule.
--
-- The capacitor + battery are EXPORTABLE, so each is deliberately
-- situational-not-strictly-better than a vanilla accumulator (§12 guardrail):
-- the capacitor trades buffer for flow (spike catcher, poor reservoir); the
-- battery trades flow for buffer (bulk reserve, sluggish) and pays a
-- heat-upkeep self-discharge. See scripts/flare-config.lua for the numbers.
--
-- We add ONLY new prototypes and deep-copy the shared vanilla accumulator before
-- touching it (never-mutate-other-planets). Art is the delivered Cindra set
-- (graphics/ART-MANIFEST.md).
--
-- PROVISIONAL tech gate: like the electric heater (§15-10), unlocked by a
-- placeholder tech on vanilla science packs until the Cindra science tree lands.
-- TODO(ci-3or): fold the unlock into the Cindra tech tree.

local util = require("util")
local C = require("scripts.flare-config")

local function watts(w) return string.format("%dW", math.floor(w)) end
local function joules(j) return string.format("%dJ", math.floor(j)) end

-- Wire a delivered entity sprite (ART-MANIFEST) onto a cloned entity.
local function entity_art(name)
  return {
    layers = {
      {
        filename = "__cindra__/graphics/entity/" .. name .. "/" .. name .. ".png",
        width = 256, height = 256, scale = 0.5, shift = { 0, -0.1 },
      },
      {
        filename = "__cindra__/graphics/entity/" .. name .. "/" .. name .. "-shadow.png",
        width = 256, height = 256, scale = 0.5, shift = { 0.3, 0 }, draw_as_shadow = true,
      },
    },
  }
end

local function set_icon(proto, name)
  proto.icon = "__cindra__/graphics/icons/" .. name .. ".png"
  proto.icons = nil
  proto.icon_size = 64
  proto.icon_mipmaps = 4
end

-- === Capacitor: fast, small (spike catcher) ==================================
local capacitor = util.table.deepcopy(data.raw["accumulator"]["accumulator"])
capacitor.name = C.CAPACITOR
capacitor.next_upgrade = nil
capacitor.minable = { mining_time = 0.3, result = C.CAPACITOR }
capacitor.energy_source = {
  type = "electric",
  buffer_capacity = joules(C.CAPACITOR_BUFFER_J),
  usage_priority = "tertiary",
  input_flow_limit = watts(C.CAPACITOR_FLOW_W),
  output_flow_limit = watts(C.CAPACITOR_FLOW_W),
}
capacitor.chargable_graphics = nil -- v1 static art; drop the vanilla charge lamp.
capacitor.picture = entity_art("capacitor")
set_icon(capacitor, "capacitor")
capacitor.localised_name = { "entity-name." .. C.CAPACITOR }
capacitor.localised_description = { "entity-description." .. C.CAPACITOR }

local capacitor_item = util.table.deepcopy(data.raw["item"]["accumulator"])
capacitor_item.name = C.CAPACITOR
capacitor_item.place_result = C.CAPACITOR
capacitor_item.order = "b[cindra]-b[capacitor]"
set_icon(capacitor_item, "capacitor")
capacitor_item.localised_name = { "item-name." .. C.CAPACITOR }
capacitor_item.localised_description = { "item-description." .. C.CAPACITOR }

local capacitor_recipe = {
  type = "recipe",
  name = C.CAPACITOR,
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 5 },
    { type = "item", name = "battery", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 10 },
  },
  results = { { type = "item", name = C.CAPACITOR, amount = 1 } },
}

-- === Molten-salt battery: bulk, slow (plateau soak) ==========================
local battery = util.table.deepcopy(data.raw["accumulator"]["accumulator"])
battery.name = C.BATTERY
battery.next_upgrade = nil
battery.minable = { mining_time = 0.5, result = C.BATTERY }
battery.energy_source = {
  type = "electric",
  buffer_capacity = joules(C.BATTERY_BUFFER_J),
  usage_priority = "tertiary",
  input_flow_limit = watts(C.BATTERY_FLOW_W),
  output_flow_limit = watts(C.BATTERY_FLOW_W),
}
battery.chargable_graphics = nil
battery.picture = entity_art("molten-salt-battery")
set_icon(battery, "molten-salt-battery")
battery.localised_name = { "entity-name." .. C.BATTERY }
battery.localised_description = { "entity-description." .. C.BATTERY }

local battery_item = util.table.deepcopy(data.raw["item"]["accumulator"])
battery_item.name = C.BATTERY
battery_item.place_result = C.BATTERY
battery_item.order = "b[cindra]-c[molten-salt-battery]"
set_icon(battery_item, "molten-salt-battery")
battery_item.localised_name = { "item-name." .. C.BATTERY }
battery_item.localised_description = { "item-description." .. C.BATTERY }

local battery_recipe = {
  type = "recipe",
  name = C.BATTERY,
  enabled = false,
  energy_required = 12,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "battery", amount = 40 },
    { type = "item", name = "pipe", amount = 10 },
  },
  results = { { type = "item", name = C.BATTERY, amount = 1 } },
}

-- === Dissipator: infinite safe waste, rate-limited (the fuse) ================
-- A pure consumer (electric-energy-interface). Its rated draw is the reliable
-- disposal floor and the sacrificial fuse: counted before any panel is damaged.
local dissipator = {
  type = "electric-energy-interface",
  name = C.DISSIPATOR,
  icon = "__cindra__/graphics/icons/dissipator.png",
  icon_size = 64,
  icon_mipmaps = 4,
  flags = { "placeable-neutral", "player-creation" },
  max_health = 200,
  minable = { mining_time = 0.3, result = C.DISSIPATOR },
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
  picture = entity_art("dissipator"),
  localised_name = { "entity-name." .. C.DISSIPATOR },
  localised_description = { "entity-description." .. C.DISSIPATOR },
}

local dissipator_item = {
  type = "item",
  name = C.DISSIPATOR,
  icon = "__cindra__/graphics/icons/dissipator.png",
  icon_size = 64,
  icon_mipmaps = 4,
  subgroup = "energy",
  order = "b[cindra]-d[dissipator]",
  stack_size = 20,
  place_result = C.DISSIPATOR,
  localised_name = { "item-name." .. C.DISSIPATOR },
  localised_description = { "item-description." .. C.DISSIPATOR },
}

local dissipator_recipe = {
  type = "recipe",
  name = C.DISSIPATOR,
  enabled = false,
  energy_required = 6,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 10 },
    { type = "item", name = "heat-pipe", amount = 5 },
    { type = "item", name = "copper-plate", amount = 15 },
  },
  results = { { type = "item", name = C.DISSIPATOR, amount = 1 } },
}

-- Provisional tech unlocking all three storage/disposal buildings. Gated behind
-- vanilla electric-energy-accumulators; vanilla packs for now.
local technology = {
  type = "technology",
  name = "cindra-flare-storage",
  icon = "__cindra__/graphics/icons/capacitor.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = C.CAPACITOR },
    { type = "unlock-recipe", recipe = C.BATTERY },
    { type = "unlock-recipe", recipe = C.DISSIPATOR },
  },
  prerequisites = { "electric-energy-accumulators" },
  unit = {
    count = 200,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  },
}

data:extend({
  capacitor, capacitor_item, capacitor_recipe,
  battery, battery_item, battery_recipe,
  dissipator, dissipator_item, dissipator_recipe,
  technology,
})

-- Test-only measurement rig: an accumulator with flow far above the flare peak,
-- so it absorbs a panel's full output WITHOUT throttling. Registered ONLY when
-- factorio-test is loaded, so the shipped mod never carries it. Reading its
-- energy delta over a window measures real, unthrottled engine solar output
-- (proves the ~100x peak against the engine, not just the canonical model).
if mods and mods["factorio-test"] then
  local measure = util.table.deepcopy(data.raw["accumulator"]["accumulator"])
  measure.name = C.MEASURE_SINK
  measure.next_upgrade = nil
  measure.minable = nil
  measure.energy_source = {
    type = "electric",
    buffer_capacity = joules(C.MEASURE_BUFFER_J),
    usage_priority = "tertiary",
    input_flow_limit = watts(C.MEASURE_FLOW_W),
    output_flow_limit = watts(C.MEASURE_FLOW_W),
  }
  data:extend({ measure })
end
