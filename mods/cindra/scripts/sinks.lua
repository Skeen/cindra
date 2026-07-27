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
-- All quantities are power (W). A sink counts toward capture only if it can
-- actually accept power THIS tick: a SATURATED accumulator (real fill at/above
-- C.STORAGE_SATURATION_THRESHOLD) contributes 0. That real-fill read is Coercia's
-- "a full battery is the alarm" (ci-snq): storage stops masking the surge as soon
-- as it is genuinely near cap, so the disposal deficit -- and panel damage --
-- fires reliably rather than only when a buffer pegs bit-exact full.
--
-- 🚨 Every lookup is per-surface (the caller passes a Cindra surface); this
-- module never reaches onto another planet.

local C = require("scripts.flare-config")

local M = {}

-- Baseline factory consumption on the grid. A per-grid SCALAR for now (see the
-- flare-config NOTE); tests override it via set_consumption to model loads.
function M.consumption_w()
  local w = storage.cindra_consumption_w
  if w ~= nil then return w end
  return C.DEFAULT_CONSUMPTION_W
end

function M.set_consumption(w)
  storage.cindra_consumption_w = w
end

local function in_network(entity, network_id)
  return network_id == nil or entity.electric_network_id == network_id
end

-- Coercia's "full battery is the alarm" (ci-snq): a storage buffer only counts as
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

-- Heat upkeep for molten-salt batteries: they bleed a small fraction of their
-- capacity per flare-driver tick when idle, so the battery is itself a mild
-- power sink and thrives here / is awkward elsewhere. The capacitor has no such
-- drain. Per-surface only.
function M.apply_battery_upkeep(surface)
  for _, b in pairs(surface.find_entities_filtered({ name = C.BATTERY })) do
    local drain = b.electric_buffer_size * C.BATTERY_UPKEEP_FRACTION
    if b.energy > 0 then
      b.energy = math.max(0, b.energy - drain)
    end
  end
end

return M
