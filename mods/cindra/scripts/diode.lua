-- One-way power transfer device -- the "power diode" (ci-gcd, reworked to a
-- power-SWITCH-style single building in ci-8l4).
--
-- THE PROBLEM: Factorio's electric grid is a single shared pool. Every entity
-- wired into one network draws from and feeds the same pot; there is no
-- directional flow WITHIN a network. So a one-way transfer is only meaningful
-- BETWEEN two separate networks, bridged by a device that moves energy A->B and
-- never B->A.
--
-- THE DEVICE (ci-8l4): a single placed building reskinned from the vanilla
-- POWER-SWITCH, so it has TWO copper wire connection points. The player wires the
-- SOURCE network to the left connector and the SINK network to the right -- two
-- explicit power inputs, exactly like a power-switch, instead of the old two
-- separately-placed poles paired by proximity. On placement the runtime spawns
-- the switch's hidden guts (prototypes/power-diode.lua):
--   * an INPUT buffer  -- an electric-energy-interface that is a LOAD
--     (output_flow_limit 0). It draws power from the left/source network to fill
--     its buffer but can NEVER push power back.
--   * an OUTPUT buffer -- an EEI that is a SOURCE (input_flow_limit 0). It feeds
--     its buffer into the right/sink network but can NEVER draw power out of it.
--   * two hidden TAP poles, one co-located with each buffer, copper-wired to the
--     matching switch connector -- an EEI has no copper connector of its own, so
--     the tap pole is how each buffer lands on the network the player wired.
-- Each tick the runtime moves buffered joules from the input buffer to the output
-- buffer, rate-capped. The energy path is therefore strictly:
--
--     source net --(charge <= rate)--> input.buffer --(script)--> output.buffer --(discharge <= rate)--> sink net
--
-- One-way is guaranteed THREE independent ways: the input buffer cannot output to
-- the source, the output buffer cannot input from the sink, and the script only
-- ever subtracts from the input buffer and adds to the output buffer (a
-- non-negative move). Any one alone blocks reverse flow; together they are
-- belt-and-braces.
--
-- Approach (b) (a pure-prototype directional trick, no script) was investigated
-- and found NOT viable -- see docs/power-diode-poc.md. This module is approach (a).
--
-- The pure arithmetic (M.transfer_amount) is unit-tested off the game in
-- unit-tests/test_diode.lua; the runtime behaviour is proven under Factorio in
-- tests/test_power_diode.lua. Both read C so nothing is hard-coded twice.

local C = require("scripts.diode-config")

local M = {}
M.DEVICE = C.DEVICE
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

-- Move energy from one input buffer to one output buffer, one-way, rate-capped.
-- Reads/writes only entity.energy (the live buffer content, J). Returns the
-- joules moved. `opts.rate_w` overrides the configured rate; `opts.dt` overrides
-- the tick delta. This is a PURE buffer move (no network check) so the
-- deterministic buffer-level tests can drive it directly; the sweep below adds
-- the cross-network guard.
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

-- ===========================================================================
-- Placement: spawn + wire the switch's hidden guts, and register the device.
-- ===========================================================================

local function registry()
  storage.cindra_diodes = storage.cindra_diodes or {}
  return storage.cindra_diodes
end
M.registry = registry

-- Test/black-box reset: forget every registered diode (does NOT destroy world
-- entities -- callers that wipe the surface handle that). Keeps repeated tests
-- from inheriting stale registry entries.
function M.reset()
  storage.cindra_diodes = {}
end

-- Copper-connect a tap pole to one side of the device's power-switch. `side` is
-- the wire_connector_id for that connector (left/right copper). reach_check is
-- disabled: the tap sits a few tiles off the connector by construction, and the
-- link is script-made, not a player drag.
local function wire_tap(device, tap, side)
  local dev_conn = device.get_wire_connector(side, true)
  local tap_conn = tap.get_wire_connector(defines.wire_connector_id.pole_copper, true)
  dev_conn.connect_to(tap_conn, false, defines.wire_origin.script)
end

local function destroy_helpers(d)
  for _, key in ipairs({ "input", "output", "input_tap", "output_tap" }) do
    local e = d[key]
    if e and e.valid then e.destroy() end
  end
end
M.destroy_helpers = destroy_helpers

-- Build the two buffers + two tap poles for a placed device and wire each tap to
-- its switch connector, then record the set in storage keyed by the device's
-- unit_number. Idempotent: a device already registered is left untouched.
function M.attach(device)
  if not (device and device.valid and device.name == C.DEVICE) then return end
  local reg = registry()
  local unit = device.unit_number
  if reg[unit] then return end

  local surface = device.surface
  local force = device.force
  local p = device.position
  local function spawn(name, dx)
    return surface.create_entity({
      name = name,
      position = { p.x + dx, p.y },
      force = force,
      raise_built = false,
    })
  end

  -- Input pair sits at -TAP_DX (the source/left side), output pair at +TAP_DX
  -- (the sink/right side) -- far enough apart that neither tap's supply area
  -- reaches the other side's buffer.
  local input_tap = spawn(C.INPUT_TAP, -C.TAP_DX)
  local output_tap = spawn(C.OUTPUT_TAP, C.TAP_DX)
  local input = spawn(C.INPUT, -C.TAP_DX)
  local output = spawn(C.OUTPUT, C.TAP_DX)

  local d = {
    device = device,
    input = input,
    output = output,
    input_tap = input_tap,
    output_tap = output_tap,
  }

  -- If any helper failed to spawn, roll back rather than register a half-built
  -- device (the sweep would only ever no-op on it).
  if not (input_tap and output_tap and input and output) then
    destroy_helpers(d)
    return
  end

  wire_tap(device, input_tap, defines.wire_connector_id.power_switch_left_copper)
  wire_tap(device, output_tap, defines.wire_connector_id.power_switch_right_copper)

  -- A power diode must NEVER bridge: a closed switch would merge the two sides
  -- into one network and turn the one-way shuttle into a plain two-way bridge.
  -- Force the switch OPEN so the two wired networks stay isolated. The sweep
  -- re-asserts this each tick (see M.tick), so the device can never be toggled
  -- into a bridge.
  device.power_switch_state = false

  reg[unit] = d
  return d
end

-- Remove a device: destroy its hidden guts and forget it.
function M.detach(device)
  if not (device and device.name == C.DEVICE) then return end
  local reg = registry()
  local unit = device.unit_number
  local d = reg[unit]
  if not d then return end
  destroy_helpers(d)
  reg[unit] = nil
end

-- ===========================================================================
-- The sweep: shuttle every registered diode's input buffer -> output buffer.
-- ===========================================================================

-- Drive one diode: move energy input->output ONLY when the two buffers sit on
-- SEPARATE electric networks. A same-network match (device unwired, or its switch
-- closed so both sides merged) is a no-op loop, so we skip it -- keeping the
-- device honest about bridging two SEPARATE networks. Returns joules moved.
function M.step_pair(d, opts)
  local input, output = d.input, d.output
  if not (input and input.valid and output and output.valid) then return 0 end
  if input.electric_network_id == nil or output.electric_network_id == nil then return 0 end
  if input.electric_network_id == output.electric_network_id then return 0 end
  return M.step(input, output, opts)
end

-- One sweep over every registered diode. Prunes entries whose device has vanished
-- without a mined/died event (defensive), destroying any orphaned guts. Returns
-- total joules moved (handy for tests).
function M.tick(opts)
  local reg = storage.cindra_diodes
  if not reg then return 0 end
  local moved = 0
  for unit, d in pairs(reg) do
    if d.device and d.device.valid then
      -- Keep the switch OPEN so the diode is always a one-way valve, never a
      -- bridge (a closed switch would merge the two networks into one).
      d.device.power_switch_state = false
      moved = moved + M.step_pair(d, opts)
    else
      destroy_helpers(d)
      reg[unit] = nil
    end
  end
  return moved
end

-- Register the runtime: the periodic sweep on its OWN distinct nth-tick (kept off
-- the main driver -- this is an isolated spike), plus the build / remove events
-- that spawn and tear down each device's hidden guts. A cheap no-op while no
-- device is placed.
function M.register()
  script.on_nth_tick(C.TICK_INTERVAL, function()
    M.tick({ dt = C.TICK_INTERVAL })
  end)

  local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
  }
  script.on_event(build_events, function(event)
    local e = event.entity
    if e and e.valid and e.name == C.DEVICE then M.attach(e) end
  end)

  local remove_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_space_platform_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy,
  }
  script.on_event(remove_events, function(event)
    local e = event.entity
    if e and e.name == C.DEVICE then M.detach(e) end
  end)
end

return M
