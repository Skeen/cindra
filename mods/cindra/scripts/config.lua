-- Runtime bridge from the mod's startup settings to a ribbon cfg table (worldgen
-- v2). This is the ONE place the runtime reads the ribbon/worldgen sliders, so
-- every consumer (edge-damage, building-heat, worldgen, damage-feedback) shares a
-- single, consistent config; scripts/ribbon.lua stays pure (no `settings.*`).
--
-- The sliders are per-side "zone depth" values (§15 v2 item 7): the hot and cold
-- zones can be tuned to different depths. A fixed MARGIN_FRAC of each zone is the
-- survivable damage-ramp margin (sand / icy), the rest is the lethal deep edge
-- (molten rock + lava ocean / ice wall) out to the hard wall.

local ribbon = require("scripts.ribbon")

local M = {}

-- Fraction of each zone's depth (safe edge -> wall) that is the survivable
-- ramping margin. The remainder is the lethal band. (tune)
M.MARGIN_FRAC = 0.5

local function val(name, default)
  local s = settings and settings.startup
  if s and s[name] ~= nil then return s[name].value end
  return default
end

-- A complete ribbon cfg built from the sliders. Absent settings (e.g. in a bare
-- test load) fall back to ribbon.DEFAULTS so the result is always valid.
function M.ribbon_cfg()
  local floor = math.floor
  local safe = val("cindra-playable-half-width", ribbon.DEFAULTS.safe_half_width)
  local hot_depth = val("cindra-hot-zone-depth", 104)
  local cold_depth = val("cindra-cold-zone-depth", 104)
  return {
    orientation = val("cindra-ribbon-orientation", ribbon.DEFAULTS.orientation),
    safe_half_width = safe,
    hot_lethal_at = safe + floor(hot_depth * M.MARGIN_FRAC),
    hot_wall_at = safe + hot_depth,
    cold_lethal_at = safe + floor(cold_depth * M.MARGIN_FRAC),
    cold_wall_at = safe + cold_depth,
    max_dps = val("cindra-ribbon-max-dps", ribbon.DEFAULTS.max_dps),
    freeze_temp = val("cindra-nightside-freeze-temp", -30),
  }
end

return M
