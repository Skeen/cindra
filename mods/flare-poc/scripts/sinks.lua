-- The sink web (planet_design.md sec.10 "The disposal problem", sec.12 items 5-6).
--
-- Three buckets absorb flare power, in priority order for the damage rule:
--   1. consumption   - the factory's baseline draw (runs on baseline solar).
--   2. dissipators   - infinite safe waste, rate-limited per building. The
--                      reliable floor AND the sacrificial fuse: its rated draw
--                      is counted before any panel can be damaged.
--   3. storage       - capacitor (fast, small) + molten-salt battery (bulk,
--                      slow). Recoverable capture, but flow-limited so it can
--                      never absorb the whole spike (that is the catchability
--                      rule: capture < delivery at every scale).
--
-- All quantities are power (W). A sink counts toward capture only if it can
-- actually accept power THIS tick: a full accumulator contributes 0.

local C = require("scripts.config")

local M = {}

-- Baseline factory consumption on the grid. Global for the PoC; tests override
-- via storage.fp.consumption_w to model different loads.
function M.consumption_w()
  local fp = storage.fp
  if fp and fp.consumption_w ~= nil then return fp.consumption_w end
  return C.DEFAULT_CONSUMPTION_W
end

function M.set_consumption(w)
  storage.fp = storage.fp or {}
  storage.fp.consumption_w = w
end

local function in_network(entity, network_id)
  return network_id == nil or entity.electric_network_id == network_id
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
    if in_network(c, network_id) and c.energy < c.electric_buffer_size then
      capacitor = capacitor + C.CAPACITOR_FLOW_W
    end
  end
  for _, b in pairs(surface.find_entities_filtered({ name = C.BATTERY })) do
    if in_network(b, network_id) and b.energy < b.electric_buffer_size then
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
-- capacity per driver tick when left idle-cold, so the battery is itself a mild
-- power sink and thrives here / is awkward elsewhere (spec sec.12 item 6). The
-- capacitor has no such drain. Per-surface only.
function M.apply_battery_upkeep(surface)
  for _, b in pairs(surface.find_entities_filtered({ name = C.BATTERY })) do
    local drain = b.electric_buffer_size * C.BATTERY_UPKEEP_FRACTION
    if b.energy > 0 then
      b.energy = math.max(0, b.energy - drain)
    end
  end
end

return M
