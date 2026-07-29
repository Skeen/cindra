-- One-way power transfer PoC prototypes -- the "power diode" (ci-gcd).
--
-- ISOLATED feasibility spike: two electric-energy-interface poles that the
-- runtime (scripts/diode.lua) bridges to move power A->B between two networks,
-- never B->A. Deliberately wired into NO recipe / tech / worldgen -- the PoC is
-- placed via the editor for its headless proof. See docs/power-diode-poc.md.
--
-- We ADD ONLY new prototypes and DEEP-COPY the shared vanilla electric-energy-
-- interface before touching it (never-mutate-other-planets). The vanilla EEI
-- carries its `picture`, so the clones inherit a real sprite and pass the
-- data-stage graphics audit (prototypes/graphics-audit.lua) unchanged.
--
-- The DIRECTIONALITY lives in the energy_source (usage_priority + flow limits),
-- so it holds even without the script:
--   * input pole  -- a LOAD (usage_priority "secondary-input", output_flow_limit
--                    = 0). It draws power from network A to fill its buffer as
--                    real demand, and can NEVER feed A back.
--   * output pole -- a SOURCE (usage_priority "secondary-output", input_flow_limit
--                    = 0). It feeds its buffer into network B as production, and
--                    can NEVER draw power out of B.
-- (A "tertiary"/accumulator pole would NOT work here: accumulators only charge
-- from network SURPLUS, so an input pole would never fill unless production
-- already exceeded consumption. The input/output priorities charge/discharge on
-- demand, which is what a conduit needs.)

local util = require("util")
local C = require("scripts.diode-config")

local function watts(w) return string.format("%dW", math.floor(w)) end
local function joules(j) return string.format("%dJ", math.floor(j)) end

-- Clone the vanilla EEI, retint its inherited icon, and neutralise the vanilla
-- editor knobs (500 GW free production) so the pole is a pure buffer -- energy
-- only crosses via the network flow limits and the script.
local function base_pole(name, tint)
  local pole = util.table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
  pole.name = name
  pole.hidden = false
  pole.hidden_in_factoriopedia = false
  pole.flags = { "placeable-neutral", "player-creation" }
  pole.minable = { mining_time = 0.3, result = name }
  pole.gui_mode = "none" -- no editor GUI: production/usage are fixed at 0.
  pole.energy_production = "0W"
  pole.energy_usage = "0W"
  pole.icons = { { icon = "__base__/graphics/icons/accumulator.png", tint = tint } }
  pole.localised_name = { "entity-name." .. name }
  pole.localised_description = { "entity-description." .. name }
  pole.next_upgrade = nil
  return pole
end

-- INPUT pole: a charge-only LOAD (output_flow_limit = 0). Green tint. It draws
-- from network A to fill its buffer and can never push power back into A.
local input = base_pole(C.INPUT, { 0.4, 1, 0.4, 1 })
input.energy_source = {
  type = "electric",
  buffer_capacity = joules(C.BUFFER_J),
  usage_priority = "secondary-input",
  input_flow_limit = watts(C.INPUT_FLOW_W),
  output_flow_limit = "0W",
}

-- OUTPUT pole: a discharge-only SOURCE (input_flow_limit = 0). Red tint. It feeds
-- its buffer into network B and can never draw power out of B.
local output = base_pole(C.OUTPUT, { 1, 0.4, 0.4, 1 })
output.energy_source = {
  type = "electric",
  buffer_capacity = joules(C.BUFFER_J),
  usage_priority = "secondary-output",
  input_flow_limit = "0W",
  output_flow_limit = watts(C.OUTPUT_FLOW_W),
}

-- Items so the poles can be given / placed from the editor. No recipe or tech:
-- the PoC stays off the main progression chain by design.
local function pole_item(name, order)
  local item = util.table.deepcopy(data.raw["item"]["electric-energy-interface"])
  item.name = name
  item.place_result = name
  item.order = order
  item.icons = { { icon = "__base__/graphics/icons/accumulator.png",
    tint = name == C.INPUT and { 0.4, 1, 0.4, 1 } or { 1, 0.4, 0.4, 1 } } }
  item.localised_name = { "item-name." .. name }
  item.hidden = false
  return item
end

data:extend({
  input,
  output,
  pole_item(C.INPUT, "e[energy]-z[power-diode]-a[input]"),
  pole_item(C.OUTPUT, "e[energy]-z[power-diode]-b[output]"),
})
