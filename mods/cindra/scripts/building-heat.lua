-- Nightside building-heat requirement (§4 "Aquilo-like cold", §15 item 2).
--
-- The nightward half of the ribbon applies the same buildings-need-heat pressure
-- as Aquilo: a machine past the cold threshold takes CONTINUOUS COLD DAMAGE
-- (the spec's "freeze / stop / take cold damage" option) unless it sits near an
-- active heat source. This makes nightward expansion drag a heat-and-power
-- umbilical with it: deeper = colder, and the coldest, best resources (ice,
-- volatiles) live out there, so the heating cost scales with the reward.
--
-- The cold threshold is read off the ribbon axis (scripts/ribbon.lua is the
-- single source of truth): a tile is "cold" when its axis temperature is below
-- `freeze_temp`. Cold damage self-corrects the instant a heat source is placed in
-- range (unlike toggling `active`, which the engine makes read-only for crafting
-- machines), so a heated machine is simply never a damage target.
--
-- Heat sources for v1 are vanilla heat producers (heat pipes, reactors, heat
-- interfaces); the mechanics track's electric heater (§15-10) registers itself
-- by adding its name to M.HEAT_SOURCE_NAMES, so this stays decoupled from it.
--
-- 🚨 Scoped to `surface.name == "cindra"`; never cold-damages a machine on any
-- other planet.

local ribbon = require("scripts.ribbon")

local M = {}

-- Sweep cadence (ticks). Distinct from edge-damage's N (on_nth_tick is
-- REPLACE-not-add). Cold creep is slow-moving, so this can be coarse.
M.FREEZE_INTERVAL = 47

-- Cold damage-per-second an unheated machine takes in the cold band. Modest, so
-- the player has time to run a heat umbilical out before the machine dies. (tune)
M.FREEZE_DPS = 20

-- The cold-edge damage type (prototypes/damage-types.lua), shared with the
-- player-facing edge damage.
M.COLD_DAMAGE_TYPE = "cindra-cold"

-- Default axis temperature (°C) at/below which unheated machines take cold
-- damage. Tuned so the cold zone begins around the nightward edge of the safe
-- band (a machine in the temperate ribbon is safe; step nightward and it is
-- not). (tune)
M.DEFAULT_FREEZE_TEMP = -30

-- How close an active heat source must be to keep a machine thawed.
M.HEAT_RADIUS = 6

-- Machine types subject to the cold damage. Bounded on purpose (the common
-- producers / consumers), so the sweep stays cheap.
M.FREEZABLE_TYPES = { "assembling-machine", "furnace", "mining-drill", "lab", "pump" }

-- Vanilla heat producers that count as "active heating". The electric heater and
-- any other mod heat source add their prototype name here.
M.HEAT_SOURCE_TYPES = { "heat-pipe", "reactor", "heat-interface" }
-- Name-keyed heat sources (extension point for the mechanics track).
M.HEAT_SOURCE_NAMES = {}

local function is_cindra(surface)
  return surface and surface.valid and surface.name == "cindra"
end

local function freeze_temp(cfg)
  if cfg and cfg.freeze_temp ~= nil then return cfg.freeze_temp end
  local s = settings and settings.startup
  if s and s["cindra-nightside-freeze-temp"] then
    return s["cindra-nightside-freeze-temp"].value
  end
  return M.DEFAULT_FREEZE_TEMP
end

-- Pure: is the axis at coordinate `y` cold enough to freeze unheated machines?
function M.is_cold(y, cfg)
  return ribbon.temperature(y, cfg) <= freeze_temp(cfg)
end

-- Is there an active heat source within HEAT_RADIUS of `entity`?
function M.is_heated(surface, entity)
  local found = surface.find_entities_filtered({
    position = entity.position,
    radius = M.HEAT_RADIUS,
    type = M.HEAT_SOURCE_TYPES,
  })
  if #found > 0 then return true end
  if next(M.HEAT_SOURCE_NAMES) then
    local names = {}
    for name in pairs(M.HEAT_SOURCE_NAMES) do names[#names + 1] = name end
    local by_name = surface.find_entities_filtered({
      position = entity.position, radius = M.HEAT_RADIUS, name = names,
    })
    if #by_name > 0 then return true end
  end
  return false
end

-- One nightside cold-damage sweep. Every unheated machine in the cold band takes
-- `interval_ticks` worth of cold damage; heated machines are spared entirely
-- (place a heat source in range and the damage stops on the next sweep).
function M.sweep(surface, cfg, interval_ticks)
  if not is_cindra(surface) then return end
  interval_ticks = interval_ticks or M.FREEZE_INTERVAL
  local amount = M.FREEZE_DPS * (interval_ticks / 60)

  for _, m in pairs(surface.find_entities_filtered({ type = M.FREEZABLE_TYPES })) do
    if m.valid and M.is_cold(m.position.y, cfg) and not M.is_heated(surface, m) then
      m.damage(amount, m.force, M.COLD_DAMAGE_TYPE)
    end
  end
end

function M.init() end

return M
