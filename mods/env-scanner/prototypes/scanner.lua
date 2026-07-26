-- Environmental scanner prototypes.
--
-- The scanner is a CONSTANT-COMBINATOR clone: reusing that type gives us a
-- native circuit-network output (wires, sections) for free, and the runtime
-- (scripts/scanner.lua) just writes the surface readings into its output each
-- tick. Cloning a vanilla prototype into a NEW name means this mod adds content
-- without editing any shared/vanilla prototype (the never-mutate rule).
--
-- The recipe is deliberately chemistry-free (iron + copper + electronic
-- circuits, no plastic / sulfur / oil) to preserve Cindra's zero-chemistry
-- identity, while remaining buildable on any vanilla planet (it is exportable).
--
-- Signal art is placeholder (reused base icons); a follow-up bead tracks bespoke
-- icons. See scripts/readings.lua for the signal meanings and scaling.

local util = require("util")
local C = require("scripts.config")
local readings = require("scripts.readings")

local S = readings.SIGNALS

-- === The buildable scanner (a renamed constant combinator) ===================
local scanner = util.table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
scanner.name = C.SCANNER
scanner.minable = { mining_time = 0.1, result = C.SCANNER }
scanner.next_upgrade = nil

local scanner_item = util.table.deepcopy(data.raw["item"]["constant-combinator"])
scanner_item.name = C.SCANNER
scanner_item.place_result = C.SCANNER
scanner_item.order = "c[combinators]-z[environmental-scanner]"

-- Chemistry-free recipe, enabled from the start for this standalone PoC.
local scanner_recipe = {
  type = "recipe",
  name = C.SCANNER,
  enabled = true,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "iron-plate", amount = 5 },
    { type = "item", name = "copper-cable", amount = 5 },
    { type = "item", name = "electronic-circuit", amount = 5 },
  },
  results = { { type = "item", name = C.SCANNER, amount = 1 } },
}

-- === Virtual signals =========================================================
-- A dedicated subgroup under the vanilla "signals" group so the scanner's
-- readouts cluster together in the signal picker.
local subgroup = {
  type = "item-subgroup",
  name = "env-scanner-signals",
  group = "signals",
  order = "z[env-scanner]",
}

-- Placeholder icons reused from base items (art follow-up bead filed).
local SIGNAL_DEFS = {
  { name = S.DAYTIME,         icon = "__base__/graphics/icons/accumulator.png",     order = "a" },
  { name = S.DAYLIGHT,        icon = "__base__/graphics/icons/solar-panel.png",     order = "b" },
  { name = S.SOLAR,           icon = "__base__/graphics/icons/substation.png",      order = "c" },
  { name = S.TICK_OF_DAY,     icon = "__base__/graphics/icons/radar.png",           order = "d" },
  { name = S.FLARE_COUNTDOWN, icon = "__base__/graphics/icons/lab.png",             order = "e" },
  { name = S.FLARE_PHASE,     icon = "__base__/graphics/icons/iron-plate.png",      order = "f" },
  { name = S.FLARE_INTENSITY, icon = "__base__/graphics/icons/copper-plate.png",    order = "g" },
}

local signals = {}
for _, def in ipairs(SIGNAL_DEFS) do
  signals[#signals + 1] = {
    type = "virtual-signal",
    name = def.name,
    icon = def.icon,
    icon_size = 64,
    subgroup = "env-scanner-signals",
    order = def.order .. "[" .. def.name .. "]",
  }
end

data:extend({ scanner, scanner_item, scanner_recipe, subgroup })
data:extend(signals)
