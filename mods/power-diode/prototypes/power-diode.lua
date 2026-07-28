-- Power-diode PoC prototypes.
--
-- A "power diode" moves electricity ONE WAY between two electric networks:
-- energy flows A -> B up to a rate cap and NEVER B -> A. Factorio's grid is a
-- single shared pool per network -- all wired entities share one pool and there
-- is no directional flow WITHIN a network -- so a one-way transfer fundamentally
-- needs TWO separate networks bridged by a device that moves energy A->B only.
--
-- The diode is a COMPOSITE of two accumulators, mirroring the mass-driver's
-- visible+hidden-helper pattern:
--   * `power-diode` (the INPUT end)   a visible, placeable accumulator that sits
--                                     on network A. `output_flow_limit = 0`, so it
--                                     can CHARGE from A but can never discharge
--                                     back into A. This is the hardware guarantee
--                                     that A never receives energy.
--   * `power-diode-output` (OUTPUT)   a runtime-spawned accumulator placed at a
--                                     fixed offset, meant to sit on network B.
--                                     `input_flow_limit = 0`, so it can DISCHARGE
--                                     into B but can never charge FROM B. This is
--                                     the hardware guarantee that B can never feed
--                                     the diode.
-- The runtime (scripts/diode.lua) is the only thing that moves energy between the
-- two buffers, and it only ever moves INPUT -> OUTPUT, rate-capped. Combined with
-- the two flow-limit guarantees above, energy is strictly one-way A->B.
--
-- Why accumulators (not a single entity): a single Factorio entity sits on
-- exactly ONE electric network -- electric poles merge networks by wire, so no
-- single entity can straddle two isolated networks. Two entities, one per
-- network, bridged by script, is the only way. Accumulators are used because
-- their runtime `.energy` is directly readable AND writable (proven by the
-- mass-driver charger and flare-poc batteries), which the transfer loop needs.

local util = require("util")

-- Tuning knobs (PoC starting points). Exposed on the module so the runtime and
-- tests read the same numbers. The data stage and scripts/diode.lua MUST agree
-- on the rate, so both read MAX_TRANSFER_RATE_W here.
local M = {}
M.INPUT = "power-diode"          -- visible, placeable: the INPUT end (network A)
M.OUTPUT = "power-diode-output"  -- runtime-spawned helper: the OUTPUT end (network B)

M.MAX_TRANSFER_RATE_W = 5e6      -- 5 MW: the configurable one-way transfer rate cap
M.BUFFER_J = 10e6                -- 10 MJ smoothing buffer on each end

local function watts(w) return string.format("%dW", math.floor(w)) end
local function joules(j) return string.format("%dJ", math.floor(j)) end

-- === INPUT end: charges from network A, can NEVER discharge back into A ======
local input = util.table.deepcopy(data.raw.accumulator["accumulator"])
input.name = M.INPUT
input.minable = { mining_time = 0.5, result = M.INPUT }
input.next_upgrade = nil
input.energy_source = {
  type = "electric",
  usage_priority = "tertiary",
  buffer_capacity = joules(M.BUFFER_J),
  input_flow_limit = watts(M.MAX_TRANSFER_RATE_W),  -- charges from A up to the rate cap
  output_flow_limit = "0W",                         -- HARDWARE: never feeds A back
}
input.default_output_signal = nil

-- === OUTPUT end: discharges into network B, can NEVER charge FROM B ==========
-- Spawned by the runtime at the input's tile + OUTPUT_OFFSET (see diode.lua). It
-- is visible so the player can wire network B to it, but not independently
-- placeable/minable -- it lives and dies with its input end.
local output = util.table.deepcopy(data.raw.accumulator["accumulator"])
output.name = M.OUTPUT
output.minable = nil
output.next_upgrade = nil
output.flags = {
  "not-blueprintable", "not-deconstructable", "not-upgradable", "hide-alt-info",
}
output.energy_source = {
  type = "electric",
  usage_priority = "tertiary",
  buffer_capacity = joules(M.BUFFER_J),
  input_flow_limit = "0W",                           -- HARDWARE: never charges from B
  output_flow_limit = watts(M.MAX_TRANSFER_RATE_W),  -- discharges into B up to the rate cap
}
output.default_output_signal = nil

-- === Item + recipe for the placeable INPUT end (electric-only, no chemistry) ==
local input_item = util.table.deepcopy(data.raw.item["accumulator"])
input_item.name = M.INPUT
input_item.place_result = M.INPUT
input_item.order = "z[power-diode]"

local input_recipe = {
  type = "recipe",
  name = M.INPUT,
  enabled = true,
  energy_required = 5,
  ingredients = {
    { type = "item", name = "accumulator", amount = 2 },
    { type = "item", name = "copper-cable", amount = 20 },
    { type = "item", name = "iron-plate", amount = 10 },
  },
  results = { { type = "item", name = M.INPUT, amount = 1 } },
}

data:extend({ input, output, input_item, input_recipe })

return M
