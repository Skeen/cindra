-- Cindra runtime driver (§15 items 2-3 worldgen + items 7-9 power).
--
-- Hooks every Cindra periodic system to the live game:
--   * worldgen track: lethal-edge damage sweep, nightside building-heat freeze,
--     per-chunk world generation (hard-wall backstop + resource placement).
--   * power system (integrated flare-poc, ci-zg3): the solar-flare cycle (drives
--     daytime + multiplier along the telegraph/ramp/plateau/decay curve and
--     applies battery heat upkeep) and the panel disposal-deficit damage sweep.
-- Everything here is scoped to surfaces named "cindra" (the individual modules
-- re-check), so no other planet is ever touched.
--
-- 🚨 on_nth_tick / on_init / on_chunk_generated are REPLACE-not-add. Each
-- periodic system uses a DISTINCT N (edge-damage 20, building-heat 47, flare 23,
-- panel-damage 29), and the single on_init / event registrations live here
-- (control.lua calls M.register once).

local edge_damage = require("scripts.edge-damage")
local building_heat = require("scripts.building-heat")
local worldgen = require("scripts.worldgen")
local flare = require("scripts.flare")
local panels = require("scripts.panels")
local sinks = require("scripts.sinks")
local flare_config = require("scripts.flare-config")

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

-- Advance the flare (daytime + multiplier along the curve) and bleed the
-- molten-salt batteries' idle heat upkeep.
local function on_flare_tick(event)
  if not driver_enabled() then return end
  for_each_cindra(function(s)
    flare.apply(s, event.tick)
    sinks.apply_battery_upkeep(s)
  end)
end

-- Morph freshly placed panels to their sunward-position output band (§ ci-9ht),
-- then run the panel disposal-deficit damage / recovery sweep on the settled
-- variants. Reconcile-then-sweep keeps the damage model reading each panel's real
-- position-scaled output.
local function on_panel_damage_tick()
  if not driver_enabled() then return end
  for_each_cindra(function(s)
    panels.reconcile_variants(s)
    panels.sweep(s)
  end)
end

function M.register()
  script.on_nth_tick(edge_damage.DAMAGE_INTERVAL, on_edge_damage_tick)
  script.on_nth_tick(building_heat.FREEZE_INTERVAL, on_building_heat_tick)
  script.on_nth_tick(flare_config.FLARE_INTERVAL, on_flare_tick)
  script.on_nth_tick(flare_config.PANEL_DAMAGE_INTERVAL, on_panel_damage_tick)
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
