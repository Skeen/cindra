-- Positional lethal-zone damage (§4, §15-2; ci-3yl, redefined ci-da2).
--
-- The ribbon's danger is FELT as environmental damage in the hot and cold ZONES:
-- the hot zones (1+2+3) burn and the smooth-ice cap (zone 11) freezes anything in
-- them -- the player AND machines/entities alike. ci-da2 makes the zones MIXES of
-- several tiles, and some of those tiles (e.g. volcanic-cracks-warm) also appear in
-- a SAFE neighbour zone, so lethality can no longer be a per-tile flag; it is keyed
-- to POSITION on the perpendicular ribbon axis instead (scripts/terrain.lua
-- M.damage_bounds / M.lethal_at). Because the tiles are placed by that SAME axis,
-- the damage still tracks the visible ground: stand or build in a hot zone and you
-- burn, in the smooth-ice cap and you freeze; the walkable middle is safe.
--
-- Factorio has NO native per-tick damaging-tile field, so this is a script sweep --
-- the clean area damage the design calls for. It replaces the old coordinate-ramp
-- character-only edge damage.
--
-- 🚨 Scoped to `surface.name == "cindra"`: never touches an entity on any other
-- planet. Buildings' nightside FREEZE (needs a heat source) is a separate,
-- richer mechanic in scripts/building-heat.lua; this is the raw lethal-zone burn.

local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

local M = {}

-- Sweep cadence (ticks). on_nth_tick(N) is REPLACE-not-add, so this N stays
-- distinct from every other periodic system (building-heat 47, flare 23,
-- panel-damage 29); it inherits the old edge-damage cadence (20).
M.DAMAGE_INTERVAL = 20

-- Semantic damage kind ("heat"/"cold", from the tile) -> the concrete Cindra
-- damage-type prototype (prototypes/damage-types.lua).
M.DAMAGE_TYPE = {
  heat = "cindra-heat",
  cold = "cindra-cold",
}

-- Entity kinds the lethal tiles damage. Characters plus the built structures a
-- player would push out to the resource-rich edges -- so "damage hits machines
-- too". Bounded so the sweep stays cheap (lethal tiles are a thin edge band).
M.DAMAGEABLE_TYPES = {
  "character",
  "assembling-machine", "furnace", "mining-drill", "lab", "pump",
  "electric-pole", "inserter", "transport-belt", "boiler", "generator",
  "solar-panel", "accumulator", "container", "storage-tank", "beacon",
  "roboport", "radar", "turret", "ammo-turret", "electric-turret",
}

-- Peak damage-per-second at a lethal tile, read from the mod settings (mirrors
-- the ribbon max-dps knob). Returns nil if settings are absent (tests pass cfg).
local function settings_dps()
  local s = settings and settings.startup
  if s and s["cindra-ribbon-max-dps"] then return s["cindra-ribbon-max-dps"].value end
  return nil
end

-- HP to inflict over `interval_ticks` at damage-per-second `dps`. Pure helper.
function M.damage_amount(dps, interval_ticks)
  return dps * (interval_ticks / 60)
end

-- Damage every player and machine in a lethal ZONE (heat in the hot zones, cold in
-- the smooth-ice cap), keyed to the perpendicular ribbon axis. `dps` (optional)
-- overrides the settings value so tests are deterministic.
function M.sweep(surface, interval_ticks, dps)
  if not (surface and surface.valid) or surface.name ~= "cindra" then return end
  interval_ticks = interval_ticks or M.DAMAGE_INTERVAL
  dps = dps or settings_dps() or 0
  if dps <= 0 then return end
  local amount = M.damage_amount(dps, interval_ticks)
  -- Resolve the orientation ONCE (tight loop); terrain reads the same axis.
  local orient = axis.orientation()

  for _, e in pairs(surface.find_entities_filtered({ type = M.DAMAGEABLE_TYPES })) do
    if e.valid then
      local pos = e.position
      local kind = terrain.lethal_at(axis.perp(pos.x, pos.y, orient))
      if kind then
        -- The entity's own force + resistances apply, so heat/cold-shielded gear
        -- or buildings mitigate the burn (edge-pushing), never zeroing geography.
        e.damage(amount, e.force, M.DAMAGE_TYPE[kind])
      end
    end
  end
end

return M
