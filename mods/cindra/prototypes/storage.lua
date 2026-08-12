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

-- === Art (ART-MANIFEST; idle body ci-pru, working lights ci-z94) =============
-- ONE geometry for the idle body, its shadow and every animated glow layer. The
-- glow strips are painted in the body's own roof space (scripts/gen-entity-anim.py
-- reuses gen-entity-art's `top_quad`), so they register at the body's own
-- scale/shift with no per-layer tuning -- and a change here moves body and glow
-- together instead of sliding them apart.
local ART_PX, ART_SCALE = 256, 0.5
local BODY_SHIFT, SHADOW_SHIFT = { 0, -0.1 }, { 0.3, 0 }

-- Sheet geometry of scripts/gen-entity-anim.py. These MUST match the shipped
-- strips: a wrong frame_count/line_length does not error, it just draws sliced
-- or repeated garbage in world. unit-tests/test_storage_graphics.lua checks
-- these numbers against the actual PNG dimensions on disk.
local ANIM_FRAMES, ANIM_LINE_LENGTH = 16, 4

local function art_path(name, suffix)
  return "__cindra__/graphics/entity/" .. name .. "/" .. name .. suffix .. ".png"
end

-- The idle body + its ground shadow. `repeat_count` is set only when these are
-- layers of an Animation: every layer of a layered Animation must run the same
-- number of frames, so the two single-frame images are held for the whole cycle
-- (the vanilla accumulator does exactly this in accumulator_charge()).
local function body_layers(name, repeat_count)
  return {
    {
      filename = art_path(name, ""),
      width = ART_PX, height = ART_PX, scale = ART_SCALE, shift = BODY_SHIFT,
      repeat_count = repeat_count,
    },
    {
      filename = art_path(name, "-shadow"),
      width = ART_PX, height = ART_PX, scale = ART_SCALE, shift = SHADOW_SHIFT,
      draw_as_shadow = true, repeat_count = repeat_count,
    },
  }
end

-- Wire a delivered entity sprite (ART-MANIFEST) onto a cloned entity: the idle,
-- doing-nothing state.
local function entity_art(name)
  return { layers = body_layers(name) }
end

-- The idle body with an ADDITIVE emissive glow strip over it: the WORKING state.
-- The engine chooses when to play it (charge/discharge on an accumulator, energy
-- consumption on the dissipator), which is the whole point -- a field of flare
-- storage has to show at a glance which units are taking the surge.
local function working_art(name, state, speed)
  local layers = body_layers(name, ANIM_FRAMES)
  layers[#layers + 1] = {
    filename = art_path(name, "-" .. state),
    width = ART_PX, height = ART_PX, scale = ART_SCALE, shift = BODY_SHIFT,
    frame_count = ANIM_FRAMES, line_length = ANIM_LINE_LENGTH,
    animation_speed = speed,
    -- draw_as_glow alone does NOT change the blend op (the ci-036 glass-furnace
    -- regression): without "additive" the glow frame is painted OVER the body
    -- instead of lighting it up.
    draw_as_glow = true, blend_mode = "additive",
  }
  return { layers = layers }
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
-- Accumulator art lives in `chargable_graphics` -- a top-level `picture` is
-- silently ignored by the engine (that made the capacitor INVISIBLE, ci-sop).
-- ci-z94: the v1 static picture is now only the IDLE state. Charging runs arc
-- filaments crawling the plates; discharging strobes a core flash and a shock
-- ring. The cooldowns are short because the capacitor's identity is speed -- it
-- catches the leading edge of a flare and dumps it again, so its light should
-- snap on and off rather than linger (contrast the battery below).
capacitor.chargable_graphics = {
  picture = entity_art("capacitor"),
  charge_animation = working_art("capacitor", "charge", 0.6),
  charge_cooldown = 12,
  charge_light = { intensity = 0.45, size = 5, color = { r = 0.60, g = 0.38, b = 1.0 } },
  discharge_animation = working_art("capacitor", "discharge", 1.0),
  discharge_cooldown = 20,
  discharge_light = { intensity = 0.7, size = 6, color = { r = 0.78, g = 0.62, b = 1.0 } },
}
set_icon(capacitor, "capacitor")
capacitor.localised_name = { "entity-name." .. C.CAPACITOR }
capacitor.localised_description = { "entity-description." .. C.CAPACITOR }

local capacitor_item = util.table.deepcopy(data.raw["item"]["accumulator"])
capacitor_item.name = C.CAPACITOR
capacitor_item.place_result = C.CAPACITOR
-- Sit next to the vanilla accumulator in the crafting tab (ci-wcu): same
-- "energy" subgroup (inherited from the accumulator item deepcopy), ordered
-- right after it. The vanilla accumulator is "e[accumulator]-a[accumulator]";
-- capacitor/battery follow as -b/-c and the dissipator closes the group as -d.
capacitor_item.subgroup = "energy"
capacitor_item.order = "e[accumulator]-b[capacitor]"
set_icon(capacitor_item, "capacitor")
capacitor_item.localised_name = { "item-name." .. C.CAPACITOR }
capacitor_item.localised_description = { "item-description." .. C.CAPACITOR }

-- Capacitor plates are aluminium (ci-txh): the textbook material for an
-- electrolytic capacitor, and the demand hook for Cindra's ruinous-power metal --
-- the power-metal builds the thing that stores the power. This is a deliberate
-- coupling to the aluminium chain (prototypes/aluminium.lua). It does NOT gate
-- flare survival on aluminium: the dissipator (not the capacitor) is the
-- panel-damage safety floor, so a player can weather flares before ever refining
-- aluminium; the capacitor is optional recoverable storage. No soft-lock.
local capacitor_recipe = {
  type = "recipe",
  name = C.CAPACITOR,
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 5 },
    { type = "item", name = "cindra-aluminium", amount = 5 },
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
-- Same accumulator-graphics rule as the capacitor: art must go in
-- `chargable_graphics`, not a top-level `picture` (ci-sop).
-- ci-z94: the salt pool heats while charging (convection rolling under a slow
-- swell) and drains outward in rings while discharging. Everything about it is
-- SLOW next to the capacitor -- quarter-speed animation and long cooldowns -- so
-- the two read as different machines at a glance across a field of them. The
-- long cooldown is also honest thermal mass: molten salt does not stop glowing
-- the tick the flare ends.
battery.chargable_graphics = {
  picture = entity_art("molten-salt-battery"),
  charge_animation = working_art("molten-salt-battery", "charge", 0.25),
  charge_cooldown = 90,
  charge_light = { intensity = 0.4, size = 6, color = { r = 1.0, g = 0.48, b = 0.16 } },
  discharge_animation = working_art("molten-salt-battery", "discharge", 0.25),
  discharge_cooldown = 120,
  discharge_light = { intensity = 0.5, size = 7, color = { r = 1.0, g = 0.58, b = 0.22 } },
}
set_icon(battery, "molten-salt-battery")
battery.localised_name = { "entity-name." .. C.BATTERY }
battery.localised_description = { "entity-description." .. C.BATTERY }

local battery_item = util.table.deepcopy(data.raw["item"]["accumulator"])
battery_item.name = C.BATTERY
battery_item.place_result = C.BATTERY
battery_item.subgroup = "energy"
battery_item.order = "e[accumulator]-c[molten-salt-battery]"
set_icon(battery_item, "molten-salt-battery")
battery_item.localised_name = { "item-name." .. C.BATTERY }
battery_item.localised_description = { "item-description." .. C.BATTERY }

-- CHEAP recipe (ci-wcu): a molten-salt battery is a THERMAL store -- a tank of
-- salt, no chemical cells. It deliberately uses NO `battery` item (unlike the
-- vanilla accumulator and the capacitor), so it is markedly cheaper than either;
-- that cheapness is its whole identity (large-ish, slow, cheap, leaky).
local battery_recipe = {
  type = "recipe",
  name = C.BATTERY,
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 4 },
    { type = "item", name = "stone", amount = 10 },
    { type = "item", name = "pipe", amount = 4 },
  },
  results = { { type = "item", name = C.BATTERY, amount = 1 } },
}

-- === Dissipator: infinite safe waste, rate-limited (the fuse) ================
-- A pure consumer (electric-energy-interface). Its rated draw is the reliable
-- disposal floor and the sacrificial fuse: counted before any panel is damaged.
-- TODO(ci-wcu FUTURE, not implemented): decide dissipator control -- gate its
-- draw via a circuit connection vs a power switch. Note only for now.
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
  -- ci-z94: the fins glow under a heat wave sweeping across them. An
  -- electric-energy-interface scales its `animation` to what it is actually
  -- consuming (that is the default; `continuous_animation` would override it),
  -- so this is a LOAD READOUT, not decoration: a dissipator with nothing to burn
  -- sits dark and still, and one eating a flare runs hot. `picture` is dropped
  -- rather than kept alongside -- the engine renders one or the other, and the
  -- animation's first layer IS the idle body, so nothing is lost.
  animation = working_art("dissipator", "heat", 0.6),
  light = { intensity = 0.55, size = 6, color = { r = 1.0, g = 0.52, b = 0.18 } },
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
  -- Last in the accumulator group (ci-wcu): after capacitor (-b) and battery (-c).
  order = "e[accumulator]-d[dissipator]",
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
-- (proves the ~6 MW peak / 330 kW baseline against the engine, not just the model).
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
