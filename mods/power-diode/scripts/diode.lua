-- Power-diode runtime: the one-way A->B transfer loop.
--
-- Each diode is a pair of accumulators: an INPUT end on network A (charges from
-- A, can never discharge to A) and an OUTPUT end on network B (discharges to B,
-- can never charge from B). This module is the ONLY thing that moves energy
-- between the two buffers, and it only ever moves INPUT -> OUTPUT, rate-capped.
--
-- One-way is guaranteed three times over:
--   1. transfer() only ever does `input.energy -= t; output.energy += t` with
--      t >= 0. It never writes energy from output back to input.
--   2. the INPUT accumulator has output_flow_limit = 0 (data stage), so it can
--      never discharge into network A regardless of script.
--   3. the OUTPUT accumulator has input_flow_limit = 0 (data stage), so network B
--      can never charge it -- B's energy can never enter the diode.
--
-- storage layout:
--   storage.pd.pairs   [input_unit_number] = { input = LuaEntity, output = LuaEntity }
--   storage.pd.by_out  [output_unit_number] = input_unit_number   (reverse lookup)

local proto = require("prototypes.power-diode")

local M = {}

M.INPUT = proto.INPUT
M.OUTPUT = proto.OUTPUT

-- Tuning knobs. Tests may override these on the module before building/linking.
M.MAX_TRANSFER_RATE_W = proto.MAX_TRANSFER_RATE_W  -- one-way transfer rate cap (W)
M.TICK_INTERVAL = 6                                -- ticks between transfer steps
M.OUTPUT_OFFSET = { x = 3, y = 0 }                 -- where the OUTPUT end spawns

local function ensure_storage()
  storage.pd = storage.pd or {}
  storage.pd.pairs = storage.pd.pairs or {}
  storage.pd.by_out = storage.pd.by_out or {}
end

-- Joules movable per transfer step, derived from the rate cap and cadence.
-- rate (J/s) * (TICK_INTERVAL ticks / 60 ticks-per-second) = J per step.
function M.per_step_cap_j()
  return M.MAX_TRANSFER_RATE_W * (M.TICK_INTERVAL / 60)
end

-- Record a pair. Used by both the auto-spawn on build and directly by tests
-- (which place the two ends where they like, on genuinely separate networks).
function M.link(input, output)
  ensure_storage()
  local rec = { input = input, output = output }
  storage.pd.pairs[input.unit_number] = rec
  storage.pd.by_out[output.unit_number] = input.unit_number
  return rec
end

-- Dissolve a pair by its input and destroy the runtime-spawned output helper.
local function dissolve(input_un)
  ensure_storage()
  local rec = storage.pd.pairs[input_un]
  if not rec then return end
  if rec.output and rec.output.valid then
    storage.pd.by_out[rec.output.unit_number] = nil
    rec.output.destroy()
  end
  storage.pd.pairs[input_un] = nil
end

function M.get_pair(input)
  ensure_storage()
  return storage.pd.pairs[input.unit_number]
end

-- Move energy INPUT -> OUTPUT for one pair, rate-capped and bounded by what the
-- input holds and the room left in the output buffer. Returns joules moved.
-- This is the single source of directional flow; it NEVER moves output->input.
function M.transfer(rec)
  local input, output = rec.input, rec.output
  if not (input and input.valid and output and output.valid) then return 0 end

  local room = output.electric_buffer_size - output.energy
  if room <= 0 then return 0 end

  local moved = math.min(input.energy, M.per_step_cap_j(), room)
  if moved <= 0 then return 0 end

  input.energy = input.energy - moved
  output.energy = output.energy + moved
  return moved
end

-- Spawn the OUTPUT end for a freshly built INPUT end and link the pair. The
-- output is placed at OUTPUT_OFFSET; the player wires network B to it. If the
-- offset tile is blocked, fall back to the nearest free position so the diode is
-- never left without an output end.
local function attach_output(input)
  local pos = { x = input.position.x + M.OUTPUT_OFFSET.x, y = input.position.y + M.OUTPUT_OFFSET.y }
  local surface = input.surface
  local place = pos
  if not surface.can_place_entity({ name = M.OUTPUT, position = pos, force = input.force }) then
    place = surface.find_non_colliding_position(M.OUTPUT, pos, 8, 0.5) or pos
  end
  local output = surface.create_entity({
    name = M.OUTPUT,
    position = place,
    force = input.force,
    create_build_effect_smoke = false,
  })
  if not output then return nil end
  output.operable = false
  return M.link(input, output)
end

local function on_build_event(event)
  local e = event.entity
  if not (e and e.valid) then return end
  ensure_storage()
  if e.name == M.INPUT then
    attach_output(e)
  end
end

local function on_remove_event(event)
  local e = event.entity
  if not (e and e.valid) then return end
  ensure_storage()
  if e.name == M.INPUT then
    dissolve(e.unit_number)
  elseif e.name == M.OUTPUT then
    -- The visible input outlives a destroyed output helper; drop the dangling
    -- pair so the input is inert until rebuilt.
    local input_un = storage.pd.by_out[e.unit_number]
    if input_un then
      storage.pd.by_out[e.unit_number] = nil
      storage.pd.pairs[input_un] = nil
    end
  end
end

-- Run the transfer step for every live pair; clean up any pair whose input end
-- has gone away.
function M.transfer_all()
  ensure_storage()
  for input_un, rec in pairs(storage.pd.pairs) do
    if rec.input and rec.input.valid then
      M.transfer(rec)
    else
      dissolve(input_un)
    end
  end
end

function M.init()
  ensure_storage()
end

function M.register()
  local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
  }
  for _, ev in pairs(build_events) do
    script.on_event(ev, on_build_event)
  end

  local remove_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy,
  }
  for _, ev in pairs(remove_events) do
    script.on_event(ev, on_remove_event)
  end

  script.on_nth_tick(M.TICK_INTERVAL, M.transfer_all)
end

return M
