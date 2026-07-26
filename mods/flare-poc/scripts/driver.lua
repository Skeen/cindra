-- Runtime driver: hooks the flare cycle and the damage sweep to the tick loop.
--   * every FLARE_INTERVAL ticks: advance the flare (daytime + multiplier) and
--     apply battery heat upkeep,
--   * every DAMAGE_INTERVAL ticks: run the panel damage/recovery sweep.
--
-- on_nth_tick and on_init are REPLACE-not-add. The two periodic handlers use
-- DISTINCT N (FLARE_INTERVAL vs DAMAGE_INTERVAL). Everything is scoped to
-- surfaces named C.SURFACE, so nothing here touches another planet.

local C = require("scripts.config")
local flare = require("scripts.flare")
local panels = require("scripts.panels")
local sinks = require("scripts.sinks")

local M = {}

-- Tests set storage.fp.driver_enabled = false to freeze the periodic handlers so
-- they can drive the flare/sweep manually and deterministically. Default = on.
local function driver_enabled()
  local fp = storage.fp
  return not (fp and fp.driver_enabled == false)
end

local function for_each_surface(fn)
  for _, s in pairs(game.surfaces) do
    if s.name == C.SURFACE then fn(s) end
  end
end

local function on_flare_tick(event)
  if not driver_enabled() then return end
  for_each_surface(function(s)
    flare.apply(s, event.tick)
    sinks.apply_battery_upkeep(s)
  end)
end

local function on_damage_tick()
  if not driver_enabled() then return end
  for_each_surface(function(s) panels.sweep(s) end)
end

function M.register()
  script.on_nth_tick(C.FLARE_INTERVAL, on_flare_tick)
  script.on_nth_tick(C.DAMAGE_INTERVAL, on_damage_tick)
end

function M.init()
  storage.fp = storage.fp or {}
  if storage.fp.driver_enabled == nil then storage.fp.driver_enabled = true end
end

return M
