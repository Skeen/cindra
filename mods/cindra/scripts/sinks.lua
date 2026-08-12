-- The sink web (§15-9 storage + dissipator; DESIGN.md §5). Integrated from the
-- proven flare-poc (ci-zg3).
--
-- Three buckets absorb flare power, in priority order for the damage rule:
--   1. consumption   - the factory's baseline draw (runs on baseline solar).
--   2. dissipators   - infinite safe waste, rate-limited per building. The
--                      reliable floor AND the sacrificial fuse: its rated draw
--                      is counted before any panel can be damaged.
--   3. storage       - capacitor (fast, small) + molten-salt battery (bulk,
--                      slow). Recoverable capture, but flow-limited so it can
--                      never absorb the whole spike (the catchability rule:
--                      capture < delivery at every scale).
--
-- Since ci-sz8q this breakdown is the MODELLED estimate: real play sizes the
-- panel-damage deficit from the engine's own per-network accounting instead
-- (M.unconsumed_solar_w below), which counts these same sinks by what they
-- ACTUALLY drew. `capture` remains the model's telemetry, the fallback when a
-- load is simulated rather than built, and the sink web's own spec.
--
-- All quantities are power (W). A sink counts toward capture only if it can
-- actually accept power THIS tick: a SATURATED accumulator (real fill at/above
-- C.STORAGE_SATURATION_THRESHOLD) contributes 0. That real-fill read is Cindra's
-- "a full battery is the alarm" (ci-snq): storage stops masking the surge as soon
-- as it is genuinely near cap, so the disposal deficit -- and panel damage --
-- fires reliably rather than only when a buffer pegs bit-exact full.
--
-- 🚨 Every lookup is per-surface (the caller passes a Cindra surface); this
-- module never reaches onto another planet.

local C = require("scripts.flare-config")

local M = {}

-- Baseline factory consumption on the grid. A per-grid SCALAR fallback used by
-- the MODELLED capture path; tests override it via set_consumption to simulate
-- loads. Real play measures the grid instead (M.unconsumed_solar_w below).
function M.consumption_w()
  local w = storage.cindra_consumption_w
  if w ~= nil then return w end
  return C.DEFAULT_CONSUMPTION_W
end

function M.set_consumption(w)
  storage.cindra_consumption_w = w
end

-- The explicit consumption override, or nil when none is set. When it IS set the
-- caller is simulating a load (tests / dev), so the deficit must come from the
-- MODEL; when it is nil (real play) the deficit comes from the engine
-- measurement below. One accessor so that choice is made in exactly one place.
function M.consumption_override()
  return storage.cindra_consumption_w
end

-- ENGINE-MEASURED unconsumed solar power (W) on `entity`'s electric network, or
-- nil when it cannot be read (no entity, not wired to a network yet).
--
-- WHY (ci-sz8q): the modelled deficit (potential - capture) sizes the surplus
-- from a panel's NAMEPLATE output minus a guessed load, so a grid that was
-- actually drawing every watt the panels made still read as "surplus" and the
-- panels burned. The engine already does this accounting exactly, once per
-- network update: `solar_output` is the energy the solar producers OFFERED this
-- tick and `solar_output_usage` the fraction of it that was actually taken away
-- by consumers, dissipators and charging accumulators. So the power that truly
-- had nowhere to go is offered * (1 - used) -- zero when the grid consumes 100%
-- of what the panels provide, no matter how big the array's nameplate is.
--
-- Units: flow_last_tick is per network update (J/tick), so * 60 gives W, the
-- unit the whole damage model speaks. Read-only, and scoped to the network of
-- the entity handed in (a Cindra panel), so it never reaches off-planet.
function M.unconsumed_solar_w(entity)
  if not (entity and entity.valid) then return nil end
  -- LuaEntity.electric_network is the SUB network; the flow accounting lives on
  -- its parent (sub networks joined by power switches share one update).
  local sub = entity.electric_network
  local net = sub and sub.parent_network
  local flow = net and net.flow_last_tick
  if not flow then return nil end
  local offered = flow.solar_output or 0
  local used = flow.solar_output_usage or 0
  if used > 1 then used = 1 elseif used < 0 then used = 0 end
  local unconsumed = offered * (1 - used) * 60
  if unconsumed < 0 then return 0 end
  return unconsumed
end

local function in_network(entity, network_id)
  return network_id == nil or entity.electric_network_id == network_id
end

-- Cindra's "full battery is the alarm" (ci-snq): a storage buffer only counts as
-- available disposal while its REAL fill is below the saturation threshold. Read
-- from live engine state (entity.energy vs its buffer), so once the grid's storage
-- is genuinely pegged near cap it stops masking the surplus and the deficit fires.
-- An accumulator charging through its final headroom during a flare plateau reads
-- as saturated here, not as free capacity.
local function has_headroom(acc)
  return acc.energy < C.STORAGE_SATURATION_THRESHOLD * acc.electric_buffer_size
end

-- Capture capacity available on `surface` (optionally restricted to one electric
-- network). Returns a breakdown plus the total; `storage` is capacitor+battery
-- and only counts accumulators that still have room to accept power.
function M.capture(surface, network_id)
  local consumption = M.consumption_w()
  local dissipator, capacitor, battery = 0, 0, 0

  for _, d in pairs(surface.find_entities_filtered({ name = C.DISSIPATOR })) do
    if in_network(d, network_id) then dissipator = dissipator + C.DISSIPATOR_DRAW_W end
  end
  for _, c in pairs(surface.find_entities_filtered({ name = C.CAPACITOR })) do
    if in_network(c, network_id) and has_headroom(c) then
      capacitor = capacitor + C.CAPACITOR_FLOW_W
    end
  end
  for _, b in pairs(surface.find_entities_filtered({ name = C.BATTERY })) do
    if in_network(b, network_id) and has_headroom(b) then
      battery = battery + C.BATTERY_FLOW_W
    end
  end

  local storage_w = capacitor + battery
  return {
    consumption = consumption,
    dissipator = dissipator,
    capacitor = capacitor,
    battery = battery,
    storage = storage_w,
    -- Non-panel disposal that protects panels: consumption + dissipator +
    -- storage. Everything above this each tick has nowhere to go.
    total = consumption + dissipator + storage_w,
  }
end

-- Idle self-discharge shared by both storage tiers: an accumulator of `name`
-- bleeds `fraction` of its capacity per flare-driver tick when it holds charge.
-- Per-surface only (the caller passes a Cindra surface).
local function apply_upkeep(surface, name, fraction)
  for _, a in pairs(surface.find_entities_filtered({ name = name })) do
    local drain = a.electric_buffer_size * fraction
    if a.energy > 0 then
      a.energy = math.max(0, a.energy - drain)
    end
  end
end

-- Heat upkeep for molten-salt batteries: they bleed a small fraction of their
-- capacity per flare-driver tick when idle, so the battery is itself a mild
-- power sink and thrives here / is awkward elsewhere. This is the battery's
-- signature downside (a punishing full-drain in ~5-10 min). Per-surface only.
function M.apply_battery_upkeep(surface)
  apply_upkeep(surface, C.BATTERY, C.BATTERY_UPKEEP_FRACTION)
end

-- The capacitor leaks too (ci-411), but MUCH more gently than the battery -- a
-- slight trickle (~15-20 min to empty from full), not a punishing drain. Same
-- upkeep mechanism, far lower rate. Per-surface only.
function M.apply_capacitor_upkeep(surface)
  apply_upkeep(surface, C.CAPACITOR, C.CAPACITOR_UPKEEP_FRACTION)
end

return M
