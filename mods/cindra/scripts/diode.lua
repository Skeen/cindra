-- One-way power transfer PoC -- the "power diode" (ci-gcd).
--
-- THE PROBLEM: Factorio's electric grid is a single shared pool. Every entity
-- wired into one network draws from and feeds the same pot; there is no
-- directional flow WITHIN a network. So a one-way transfer is only meaningful
-- BETWEEN two separate networks, bridged by a device that moves energy A->B and
-- never B->A.
--
-- THE DEVICE (approach (a), the standard mod pattern): two electric-energy-
-- interface poles (prototypes/power-diode.lua).
--   * the INPUT pole sits on network A as a LOAD (charge-only, output_flow_limit
--     = 0). It draws power from A to fill its buffer but can NEVER push power
--     back into A.
--   * the OUTPUT pole sits on network B as a SOURCE (discharge-only,
--     input_flow_limit = 0). It feeds its buffer into B but can NEVER draw power
--     out of B.
-- Each tick the runtime moves buffered joules from the input pole to the output
-- pole, rate-capped. The energy path is therefore strictly:
--
--     network A --(charge <= rate)--> input.buffer --(script)--> output.buffer --(discharge <= rate)--> network B
--
-- One-way is guaranteed THREE independent ways: the input pole cannot output to
-- A, the output pole cannot input from B, and the script only ever subtracts
-- from the input buffer and adds to the output buffer (a non-negative move). Any
-- one of the three alone blocks reverse flow; together they are belt-and-braces.
--
-- Approach (b) (a pure-prototype directional trick, no script) was investigated
-- and found NOT viable -- see docs/power-diode-poc.md. This module is approach (a).
--
-- The pure arithmetic (M.transfer_amount) is unit-tested off the game in
-- unit-tests/test_diode.lua; the runtime behaviour is proven under Factorio in
-- tests/test_power_diode.lua. Both read C so nothing is hard-coded twice.

local C = require("scripts.diode-config")

local M = {}
M.INPUT = C.INPUT
M.OUTPUT = C.OUTPUT
M.TICK_INTERVAL = C.TICK_INTERVAL

-- PURE core: how many joules a single diode moves this step. The move is the
-- smallest of three limits and never negative, so reverse flow is impossible by
-- construction:
--   * available   -- joules actually sitting in the input buffer.
--   * headroom    -- free space left in the output buffer.
--   * cap         -- the rate limit for this step: rate_w / 60 * dt_ticks.
-- No game.* / prototypes.* here, so it runs in the plain-Lua unit tests.
function M.transfer_amount(available, headroom, rate_w, dt_ticks)
  local cap = rate_w / 60 * dt_ticks
  local move = math.min(available, headroom, cap)
  if move < 0 then return 0 end
  return move
end

-- Move energy from one input pole to one output pole, one-way, rate-capped.
-- Reads/writes only entity.energy (the live buffer content, J). Returns the
-- joules moved. `opts.rate_w` overrides the configured rate (the configurable
-- max transfer rate the PoC asks for); `opts.dt` overrides the tick delta.
function M.step(input, output, opts)
  opts = opts or {}
  if not (input and input.valid and output and output.valid) then return 0 end
  local rate_w = opts.rate_w or C.RATE_W
  local dt = opts.dt or C.TICK_INTERVAL
  local headroom = output.electric_buffer_size - output.energy
  local move = M.transfer_amount(input.energy, headroom, rate_w, dt)
  if move <= 0 then return 0 end
  input.energy = input.energy - move
  output.energy = output.energy + move
  return move
end

-- Runtime pairing for the placed PoC: the output pole NEAREST `input` that sits
-- on a DIFFERENT electric network. A same-network match is rejected -- transfer
-- within one network is a no-op loop -- which keeps the device honest about
-- bridging two SEPARATE networks. There is deliberately no distance cap: two
-- ISOLATED networks force their poles far apart (substations within 18 tiles
-- auto-wire into ONE network), so the poles of a real diode are NOT adjacent. A
-- shipping device would instead record the input<->output link on placement
-- (on_built) rather than infer it by proximity; nearest-cross-network is enough
-- for the single-diode PoC.
function M.find_partner(input, outputs)
  local best, best_d2 = nil, nil
  local ip = input.position
  for _, out in pairs(outputs) do
    if out.valid and out.electric_network_id ~= input.electric_network_id then
      local dx, dy = out.position.x - ip.x, out.position.y - ip.y
      local d2 = dx * dx + dy * dy
      if best_d2 == nil or d2 < best_d2 then
        best, best_d2 = out, d2
      end
    end
  end
  return best
end

-- Drive every diode on `surface` for one sweep. Pairs each input pole with its
-- nearest cross-network output pole and moves energy A->B. Returns total joules
-- moved (handy for tests). This is the ONE place the transfer runs; the runtime
-- and the tests both call it, so there is a single source of truth.
function M.transfer(surface, opts)
  local inputs = surface.find_entities_filtered({ name = C.INPUT })
  if #inputs == 0 then return 0 end
  local outputs = surface.find_entities_filtered({ name = C.OUTPUT })
  if #outputs == 0 then return 0 end
  local moved = 0
  for _, input in pairs(inputs) do
    local partner = M.find_partner(input, outputs)
    if partner then
      moved = moved + M.step(input, partner, opts)
    end
  end
  return moved
end

-- Register the PoC runtime. Kept OFF the main driver (scripts/driver.lua) on
-- purpose: this is an isolated spike, so it owns its own handler on its own
-- distinct interval and touches nothing but its own poles. The sweep is a
-- cheap no-op on any surface where no diode is placed.
function M.register()
  script.on_nth_tick(C.TICK_INTERVAL, function()
    for _, s in pairs(game.surfaces) do
      M.transfer(s, { dt = C.TICK_INTERVAL })
    end
  end)
end

return M
