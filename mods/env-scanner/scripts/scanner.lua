-- Runtime for the environmental scanner.
--
-- Each scanner is a constant-combinator: we compute its surface's readings
-- (scripts/readings.lua) plus an optional flare forecast (scripts/forecast.lua)
-- and write them to the combinator's output every UPDATE_INTERVAL ticks. Built
-- scanners are tracked in `storage` so the periodic sweep is O(scanners), not a
-- whole-map entity scan.
--
-- This mod only ADDS its own entity and reads surface state; it never mutates
-- another planet's gameplay (the never-mutate-other-planets rule): setting a
-- constant combinator's own output signals affects nothing but that building's
-- circuit wires.

local C = require("scripts.config")
local readings = require("scripts.readings")
local forecast = require("scripts.forecast")

local M = {}

-- storage.es.scanners : unit_number -> LuaEntity (the tracked scanner set).
local function tracked()
  storage.es = storage.es or {}
  storage.es.scanners = storage.es.scanners or {}
  return storage.es.scanners
end

-- Compute the full signal table for a surface (generic readings + optional
-- flare forecast merged in when a provider/interface supplies one).
function M.signals_for(surface)
  local sigs = readings.surface_signals(
    surface.daytime,
    surface.solar_power_multiplier,
    C.DAY_TICKS,
    { dusk = surface.dusk, evening = surface.evening, morning = surface.morning, dawn = surface.dawn }
  )
  local fc = forecast.get(surface)
  if fc then
    readings.merge_forecast(sigs, fc)
  end
  return sigs
end

-- Write a signal table to a scanner's constant-combinator output. Rebuilds the
-- whole first section each call, so the output is idempotent and stale signals
-- (e.g. a flare forecast that just went inactive) are cleared automatically.
function M.write(entity, sigs)
  local behavior = entity.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section(1) or behavior.add_section()
  -- Custom output requires a manual (non-group) section; a fresh combinator's
  -- section is manual. Skip rather than error if a player grouped it.
  if not section or (section.is_manual == false) then return end

  local filters = {}
  for _, name in ipairs(C.SIGNAL_ORDER) do
    local v = sigs[name]
    if v ~= nil then
      filters[#filters + 1] = {
        -- quality is mandatory once min is non-zero, so always set it.
        value = { type = "virtual", name = name, quality = "normal", comparator = "=" },
        min = v,
      }
    end
  end
  section.filters = filters
end

-- Recompute + write one scanner. Returns false if the entity is gone.
function M.update(entity)
  if not (entity and entity.valid) then return false end
  M.write(entity, M.signals_for(entity.surface))
  return true
end

-- Periodic sweep: refresh every tracked scanner, dropping dead references.
function M.update_all()
  local t = tracked()
  for un, e in pairs(t) do
    if e.valid then
      M.update(e)
    else
      t[un] = nil
    end
  end
end

-- Track a newly built scanner (idempotent).
function M.register_entity(entity)
  if entity and entity.valid and entity.name == C.SCANNER then
    tracked()[entity.unit_number] = entity
  end
end

-- Stop tracking a removed scanner.
function M.forget_entity(entity)
  if entity and entity.unit_number then
    local t = storage.es and storage.es.scanners
    if t then t[entity.unit_number] = nil end
  end
end

-- (Re)discover every existing scanner on every surface. Run on init and on
-- configuration change so adding the mod to a live save, or a test creating its
-- own surface, picks up scanners already on the map.
function M.rescan()
  local t = tracked()
  for un in pairs(t) do t[un] = nil end
  for _, surface in pairs(game.surfaces) do
    for _, e in pairs(surface.find_entities_filtered({ name = C.SCANNER })) do
      t[e.unit_number] = e
    end
  end
end

function M.init()
  storage.es = storage.es or {}
  storage.es.scanners = storage.es.scanners or {}
  M.rescan()
end

return M
