-- Cindra worldgen runtime driver (§15 items 2-3).
--
-- Hooks the worldgen-track mechanics to the live game: the lethal-edge damage
-- sweep, the nightside building-heat freeze, and per-chunk world generation
-- (hard-wall backstop + resource placement). Everything here is scoped to
-- surfaces named "cindra" (the individual modules re-check), so no other planet
-- is ever touched.
--
-- 🚨 on_nth_tick / on_init / on_chunk_generated are REPLACE-not-add. Each
-- periodic system uses a DISTINCT N, and the single on_init / event
-- registrations live here (control.lua calls M.register once). The mechanics
-- track (recipes/power) registers its own runtime elsewhere; keep the two sets
-- of handlers disjoint to avoid clobbering.

local edge_damage = require("scripts.edge-damage")
local building_heat = require("scripts.building-heat")
local worldgen = require("scripts.worldgen")

local M = {}

-- Tests set storage.cindra_driver_enabled = false to keep the periodic sweeps
-- from firing during unrelated deterministic tests. Default (nil) = enabled.
local function driver_enabled()
  return storage.cindra_driver_enabled ~= false
end

local function for_each_cindra(fn)
  for _, s in pairs(game.surfaces) do
    if s.name == "cindra" then fn(s) end
  end
end

local function on_edge_damage_tick()
  if not driver_enabled() then return end
  for_each_cindra(function(s) edge_damage.sweep(s) end)
end

local function on_building_heat_tick()
  if not driver_enabled() then return end
  for_each_cindra(function(s) building_heat.sweep(s) end)
end

function M.register()
  script.on_nth_tick(edge_damage.DAMAGE_INTERVAL, on_edge_damage_tick)
  script.on_nth_tick(building_heat.FREEZE_INTERVAL, on_building_heat_tick)
  script.on_event(defines.events.on_chunk_generated, function(event)
    if not driver_enabled() then return end
    worldgen.on_chunk_generated(event)
  end)
end

-- Called from control.lua's single on_init / on_configuration_changed.
function M.init()
  if storage.cindra_driver_enabled == nil then storage.cindra_driver_enabled = true end
  building_heat.init()
end

return M
