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
-- Each sweep the runtime moves buffered joules from the input buffer to the output
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
-- DEMAND-DRIVEN CONTROLLER (ci-76if). The naive "keep both buffers topped up"
-- sweep hoarded a large self-charging reservoir: the output rested FULL, so the
-- input kept pulling from the source no matter what the sink wanted (a flat
-- parasitic draw), and that full output could dump into the sink even after the
-- source went dark (free energy from a store, violating conservation). The sweep
-- (M.step_pair) is therefore a metered controller that rests both buffers near
-- EMPTY and obeys transfer = min(source supplied this interval, far-side demand):
--   * it METERS the interval just elapsed -- how much the source actually pushed
--     into the input buffer (`charged`) and how much the sink actually pulled out
--     of the output buffer (`consumed`);
--   * it carries ONLY that real `charged` amount across into the output buffer,
--     so output energy can never exceed what was pulled this interval (source
--     dark -> nothing crosses; no free generation);
--   * it sizes the NEXT interval's source pull to the sink's realized demand
--     (plus a tiny probe so a hungry sink ramps to the full rate), by parking the
--     input buffer with exactly that much headroom -- so an idle far side draws
--     ~0 and a hungry one draws up to the demand.
-- The device also has an on/off gate (M.set_enabled): when OFF it fully blocks --
-- output emptied (sink fed nothing), input parked full (source sees no load).
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
    -- Demand-driven controller state (ci-76if). `enabled` gates transfer on/off;
    -- `in_base`/`served` are the buffer levels we parked the input/output at last
    -- sweep, so the next sweep can meter how much the source charged and the sink
    -- consumed in between. Both buffers spawn empty, so start the meters at 0.
    enabled = true,
    in_base = 0,
    served = 0,
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

-- Park a diode's buffers for the OFF (fully-blocked) state: input FULL so it
-- presents NO headroom and therefore NO load to the source (zero draw), output
-- EMPTY so the sink is fed nothing. Reset the meters so a later re-enable starts
-- clean (charged/consumed both read 0 on the first ON sweep). Shared by the OFF
-- branch of the sweep and by M.set_enabled so toggling off blocks immediately,
-- not just at the next sweep.
local function park_off(d)
  local input, output = d.input, d.output
  if not (input and input.valid and output and output.valid) then return end
  local bufsize = input.electric_buffer_size
  input.energy = bufsize
  output.energy = 0
  d.in_base = bufsize
  d.served = 0
end
M.park_off = park_off

-- Enable/disable a placed diode's transfer. OFF fully blocks (see park_off);
-- turning off parks the buffers at once so there is no <=one-sweep window where an
-- off device still draws. Accepts the device entity or its unit_number.
function M.set_enabled(device_or_unit, on)
  local reg = storage.cindra_diodes
  if not reg then return end
  local unit = type(device_or_unit) == "number" and device_or_unit
    or (device_or_unit and device_or_unit.valid and device_or_unit.unit_number)
  if not unit then return end
  local d = reg[unit]
  if not d then return end
  d.enabled = (on ~= false)
  if not d.enabled then park_off(d) end
  return d.enabled
end

-- Drive one diode for one sweep: the demand-driven, conservation-respecting
-- controller (ci-76if). Moves energy input->output ONLY when the two buffers sit
-- on SEPARATE electric networks (an unwired device, or one whose switch is closed
-- so both sides merged, is a no-op loop we skip). Returns joules moved.
--
-- The controller meters the interval just elapsed and carries only the source's
-- real contribution across, then sizes the next interval's source pull to the
-- sink's realized demand -- so an idle far side draws ~0, a hungry one draws up
-- to its demand, and the output can never exceed what was pulled (no free
-- generation). See the file header for the full rationale.
function M.step_pair(d, opts)
  opts = opts or {}
  local input, output = d.input, d.output
  if not (input and input.valid and output and output.valid) then return 0 end

  local rate_w = opts.rate_w or C.RATE_W
  local dt = opts.dt or C.TICK_INTERVAL
  local cap = rate_w / 60 * dt
  local bufsize = output.electric_buffer_size

  -- OFF: fully block -- input parked full (no load on the source), output emptied
  -- (nothing to the sink). Nothing crosses.
  if d.enabled == false then
    park_off(d)
    return 0
  end

  -- Only bridge two SEPARATE networks. nil (unwired) or a shared id (switch
  -- closed, both sides merged) is a no-op -- keeps the device honest about
  -- bridging two distinct networks and never self-loops.
  local in_net, out_net = input.electric_network_id, output.electric_network_id
  if in_net == nil or out_net == nil then return 0 end
  if in_net == out_net then return 0 end

  local in_base = d.in_base or 0
  local served = d.served or 0

  -- Meter the interval just elapsed:
  --   charged  = joules the SOURCE actually pushed into the input buffer (it rose
  --              above the virtual floor we parked it at last sweep) -- how much
  --              the source could spare this interval.
  --   consumed = joules the SINK actually pulled out of the output buffer -- the
  --              far side's realized, unmet demand.
  local charged = input.energy - in_base
  if charged < 0 then charged = 0 end
  local consumed = served - output.energy
  if consumed < 0 then consumed = 0 end

  -- Carry the source's real contribution across into the output buffer, capped by
  -- the rate and the output's free space. This is the ONLY way the output buffer
  -- ever gains energy, so it can never exceed what the source supplied this
  -- interval (source dark -> move 0 -> no free generation) and flow is one-way.
  local headroom = bufsize - output.energy
  local move = math.min(charged, cap, headroom)
  if move < 0 then move = 0 end
  output.energy = output.energy + move

  -- Decide how much to make available to the sink next interval: its realized
  -- demand plus a small probe so a hungry sink ramps to the full rate, while an
  -- idle sink settles to ~probe (=> ~0 draw). Never exceed the per-sweep cap.
  local want = consumed + cap * C.PROBE_FRAC
  if want > cap then want = cap end

  -- Pull from the source only enough to top the output up to `want` (never build
  -- a reservoir beyond it), and never more than the rate cap. Park the input
  -- buffer with exactly that much headroom -- a virtual floor near full when
  -- little is wanted -- so the engine draws ~target_pull next interval and the
  -- source draw scales with demand rather than a fixed load. The parked floor is
  -- inert: the input buffer's output_flow_limit is 0, so it can never feed that
  -- energy back to the source, and the sweep only ever moves the metered `charged`
  -- delta across, never the floor.
  local target_pull = want - output.energy
  if target_pull < 0 then target_pull = 0 end
  if target_pull > cap then target_pull = cap end
  local floor = bufsize - target_pull
  input.energy = floor

  d.in_base = floor
  d.served = output.energy
  return move
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
