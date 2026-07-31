-- Power-diode prototypes -- the one-way power-transfer device (ci-gcd, reworked
-- to a power-SWITCH-style single building in ci-8l4).
--
-- ISOLATED feasibility spike: a single placed building that takes TWO power
-- inputs (like a power-switch) and SHIFTS power one direction between them, never
-- back. Deliberately wired into NO recipe / tech / worldgen -- the PoC is placed
-- via the editor for its headless proof. See docs/power-diode-poc.md.
--
-- THE SHAPE (why four prototypes for one building):
--   * DEVICE   -- a reskinned vanilla POWER-SWITCH. This is the ONLY thing the
--                player places / sees / mines. It carries the two copper wire
--                connection points; the player wires the source network to the
--                left connector and the sink network to the right.
--   * INPUT / OUTPUT -- two HIDDEN electric-energy-interface buffers the runtime
--                (scripts/diode.lua) shuttles energy between, one way. Not
--                player-placeable (no item): placing the DEVICE spawns them.
--   * INPUT_TAP / OUTPUT_TAP -- two HIDDEN electric poles. An EEI has no copper
--                connector of its own (it joins a network only via a pole's
--                supply area), so each buffer needs a co-located tap pole that
--                the script copper-wires to a switch connector. The tap pole
--                joins the wired network and its supply area carries that network
--                to the buffer.
--
-- We ADD ONLY new prototypes and DEEP-COPY the shared vanilla power-switch /
-- electric-energy-interface / electric-pole before touching them (never-mutate-
-- other-planets). The clones inherit real sprites so they pass the data-stage
-- graphics audit (prototypes/graphics-audit.lua) unchanged; vanilla Nauvis
-- power-switches / EEIs are completely unaffected.
--
-- The DIRECTIONALITY lives in each buffer's energy_source (usage_priority + flow
-- limits), so it holds even without the script:
--   * input buffer  -- a LOAD (usage_priority "secondary-input", output_flow_limit
--                      = 0). It draws power from the source network to fill its
--                      buffer as real demand, and can NEVER feed that network back.
--   * output buffer -- a SOURCE (usage_priority "secondary-output", input_flow_limit
--                      = 0). It feeds its buffer into the sink network as
--                      production, and can NEVER draw power out of it.
-- (A "tertiary"/accumulator buffer would NOT work here: accumulators only charge
-- from network SURPLUS, so an input buffer would never fill unless production
-- already exceeded consumption. The input/output priorities charge/discharge on
-- demand, which is what a conduit needs.)

local util = require("util")
local C = require("scripts.diode-config")

local function watts(w) return string.format("%dW", math.floor(w)) end
local function joules(j) return string.format("%dJ", math.floor(j)) end

local DEVICE_TINT = { 0.7, 0.9, 1, 1 }

-- THE DEVICE: a deep-copied vanilla power-switch, re-tinted/re-iconed. It keeps
-- the switch's two copper connection points (left/right) and its wire reach so
-- one compact building can straddle two far-apart networks. The switch's OPEN
-- state keeps the two sides isolated (the diode's whole premise); its own
-- open/closed toggle is irrelevant to the transfer -- the script never merges the
-- networks, it shuttles buffered joules across.
local device = util.table.deepcopy(data.raw["power-switch"]["power-switch"])
device.name = C.DEVICE
device.minable = { mining_time = 0.3, result = C.DEVICE }
device.icons = { { icon = "__base__/graphics/icons/power-switch.png", tint = DEVICE_TINT } }
device.localised_name = { "entity-name." .. C.DEVICE }
device.localised_description = { "entity-description." .. C.DEVICE }
device.next_upgrade = nil

-- A hidden, script-owned helper: never in the player's way, never selectable /
-- minable, no map / factoriopedia entry. Shared by the buffers and the tap poles.
local function make_hidden(proto, name)
  proto.name = name
  proto.hidden = true
  proto.hidden_in_factoriopedia = true
  proto.selectable_in_game = false
  proto.minable = nil
  proto.next_upgrade = nil
  -- Collide with nothing: the helpers are phantoms spawned under / next to the
  -- device, so they must never fail to place or block the player's builds.
  proto.collision_mask = { layers = {} }
  proto.localised_name = { "entity-name." .. C.DEVICE }
  proto.flags = { "placeable-off-grid", "not-on-map", "not-deconstructable", "not-blueprintable" }
  return proto
end

-- A hidden buffer: an EEI clone with the vanilla editor knobs neutralised (fixed
-- 0 production / usage), so energy only crosses via the network flow limits and
-- the script.
local function make_buffer(name, source)
  local buf = make_hidden(util.table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"]), name)
  buf.gui_mode = "none"
  buf.energy_production = "0W"
  buf.energy_usage = "0W"
  buf.energy_source = source
  return buf
end

-- INPUT buffer: a charge-only LOAD (output_flow_limit = 0). Draws from the source
-- network and can never push power back into it.
local input = make_buffer(C.INPUT, {
  type = "electric",
  buffer_capacity = joules(C.BUFFER_J),
  usage_priority = "secondary-input",
  input_flow_limit = watts(C.INPUT_FLOW_W),
  output_flow_limit = "0W",
})

-- OUTPUT buffer: a discharge-only SOURCE (input_flow_limit = 0). Feeds the sink
-- network and can never draw power out of it.
local output = make_buffer(C.OUTPUT, {
  type = "electric",
  buffer_capacity = joules(C.BUFFER_J),
  usage_priority = "secondary-output",
  input_flow_limit = "0W",
  output_flow_limit = watts(C.OUTPUT_FLOW_W),
})

-- A hidden tap pole: a small-electric-pole clone whose supply area is trimmed so
-- it powers ONLY its co-located buffer (never the other side's), and whose wire
-- reach spans from the tap offset to the device's copper connector.
local function make_tap(name)
  local tap = make_hidden(util.table.deepcopy(data.raw["electric-pole"]["small-electric-pole"]), name)
  -- Cover just the co-located buffer (radius ~1), so the input tap can never
  -- also power the output buffer -- which would blur the two networks into one.
  tap.supply_area_distance = 1
  -- CRITICAL: keep the reach BELOW the two taps' separation (2*TAP_DX). Electric
  -- poles auto-wire to any neighbour within maximum_wire_distance, so a reach
  -- that spanned the gap would auto-connect the input tap to the output tap and
  -- merge the two networks into one -- silently defeating the diode. TAP_DX+1 is
  -- comfortably past the short script wire to the switch connector (~TAP_DX-0.5,
  -- made with reach_check off) yet short of the far tap (2*TAP_DX).
  tap.maximum_wire_distance = C.TAP_DX + 1
  return tap
end

data:extend({
  device,
  input,
  output,
  make_tap(C.INPUT_TAP),
  make_tap(C.OUTPUT_TAP),
})

-- The DEVICE item (the only placeable one). No recipe or tech: the PoC stays off
-- the main progression chain by design, so it is editor-spawn only.
local device_item = util.table.deepcopy(data.raw["item"]["power-switch"])
device_item.name = C.DEVICE
device_item.place_result = C.DEVICE
device_item.order = "e[energy]-z[power-diode]"
device_item.icons = { { icon = "__base__/graphics/icons/power-switch.png", tint = DEVICE_TINT } }
device_item.localised_name = { "item-name." .. C.DEVICE }
device_item.hidden = false
data:extend({ device_item })
