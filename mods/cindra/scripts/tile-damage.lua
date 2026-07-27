-- Tile-based lethal-edge damage (§4, §15-2; ci-3yl "a tile that damages EVERYTHING").
--
-- The ribbon's danger is now FELT through the TERRAIN itself: the lethal lava and
-- deep-ice tiles (scripts/terrain.lua) damage anything standing on them -- the
-- player AND machines/entities alike. The walkable molten-rock and frost margins
-- are safe; ONLY the actual lava (heat) and deep-ice (cold) tiles bite. Because
-- those tiles are placed by the perpendicular ribbon axis, the damage stays keyed
-- to position exactly as before, but it now reads the VISIBLE ground: stand or
-- build on lava and you burn, stand or build on deep ice and you freeze.
--
-- Factorio has NO native per-tick damaging-tile field (a tile's trigger_effect
-- only fires when the engine invokes it, not continuously), so this is a script
-- sweep -- the clean tile-based area damage the design calls for. It replaces the
-- old coordinate-ramp character-only edge damage.
--
-- 🚨 Scoped to `surface.name == "cindra"`: never touches an entity on any other
-- planet. Buildings' nightside FREEZE (needs a heat source) is a separate,
-- richer mechanic in scripts/building-heat.lua; this is the raw lethal-tile burn.

local terrain = require("scripts.terrain")

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

-- Damage every player and machine standing/built on a lethal Cindra tile. `dps`
-- (optional) overrides the settings value so tests are deterministic.
function M.sweep(surface, interval_ticks, dps)
  if not (surface and surface.valid) or surface.name ~= "cindra" then return end
  interval_ticks = interval_ticks or M.DAMAGE_INTERVAL
  dps = dps or settings_dps() or 0
  if dps <= 0 then return end
  local amount = M.damage_amount(dps, interval_ticks)
  local lethal = terrain.lethal_tiles() -- { tile_name = "heat"/"cold" }

  for _, e in pairs(surface.find_entities_filtered({ type = M.DAMAGEABLE_TYPES })) do
    if e.valid then
      local pos = e.position
      local tile = surface.get_tile(math.floor(pos.x), math.floor(pos.y))
      local kind = tile and tile.valid and lethal[tile.name]
      if kind then
        -- The entity's own force + resistances apply, so heat/cold-shielded gear
        -- or buildings mitigate the burn (edge-pushing), never zeroing geography.
        e.damage(amount, e.force, M.DAMAGE_TYPE[kind])
      end
    end
  end
end

return M
