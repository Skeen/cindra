-- Tile-based lethal-ground damage (§4, §15-2; ci-3yl, redefined ci-da2, reworked ci-4jl).
--
-- The ribbon's danger is FELT as environmental damage: hot ground burns and the
-- smooth-ice cap freezes anything on it -- the player AND machines/entities alike.
-- The damage is done BY THE TILES THEMSELVES: each damaging tile prototype carries
-- an intensity (0..1) x peak-dps and a kind ("heat"/"cold") in scripts/terrain.lua
-- (M.tile_damage). Each sweep, for every damageable entity (+ the character) we
-- read the tile(s) under its collision FOOTPRINT and apply damage from the
-- MOST-LETHAL tile in that footprint.
--
-- Why tile-based (ci-4jl): the old model keyed damage to a single perpendicular
-- COORDINATE and applied a FLAT dps across a whole band. That over-damaged at the
-- entry edge (full damage the instant you crossed the threshold) and could MISS an
-- entity sitting on a lava tile whose centre coordinate read "safe" -- so pumps and
-- machines could be placed in the lava without dying. Reading the ACTUAL tile the
-- entity touches fixes both: the ci-da2 zones are noisy MIXES, so near the safe
-- edge an entity mostly stands on warm/low-intensity tiles (a gentle burn) and
-- deeper in on lava/hot-lava (max) -- the depth ramp emerges from the terrain, and
-- anything overlapping a lava tile burns.
--
-- Factorio has NO native per-tick damaging-tile field, so this is a script sweep.
--
-- 🚨 Scoped to `surface.name == "cindra"`: never touches an entity on any other
-- planet. Buildings' nightside FREEZE (needs a heat source) is a separate,
-- richer mechanic in scripts/building-heat.lua; this is the raw lethal-ground burn.

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
-- too". Bounded so the sweep stays cheap (safe tiles resolve to intensity 0 and
-- are skipped without a damage call).
M.DAMAGEABLE_TYPES = {
  "character",
  "assembling-machine", "furnace", "mining-drill", "lab", "pump",
  "electric-pole", "inserter", "transport-belt", "boiler", "generator",
  "solar-panel", "accumulator", "container", "storage-tank", "beacon",
  "roboport", "radar", "turret", "ammo-turret", "electric-turret",
}

-- Peak damage-per-second at a max-intensity (1.0) tile, read from the mod settings
-- (mirrors the ribbon max-dps knob). Returns nil if settings are absent (tests pass cfg).
local function settings_dps()
  local s = settings and settings.startup
  if s and s["cindra-ribbon-max-dps"] then return s["cindra-ribbon-max-dps"].value end
  return nil
end

-- HP to inflict over `interval_ticks` at damage-per-second `dps`. Pure helper.
function M.damage_amount(dps, interval_ticks)
  return dps * (interval_ticks / 60)
end

-- The MOST-LETHAL tile under an entity's collision footprint: returns
-- (intensity, kind) for the highest-intensity damaging tile any part of the
-- entity touches, or (0, nil) if it sits entirely on safe ground. Reading the
-- whole footprint (not just the centre) is what burns a pump overlapping a lava
-- tile -- the exploit fix. Characters have a tiny footprint, so this is the tile
-- they stand on. `surface` reads live tiles, so this is intentionally NOT pure;
-- the pure per-tile lookup is terrain.tile_damage.
function M.footprint_damage(surface, e)
  local box = e.bounding_box
  local lt, rb = box.left_top, box.right_bottom
  -- Integer tile coordinates the box spans (a tile at integer (tx,ty) covers
  -- [tx, tx+1) x [ty, ty+1)). floor(lt) .. ceil(rb)-1 covers every touched tile.
  local x0, x1 = math.floor(lt.x), math.ceil(rb.x) - 1
  local y0, y1 = math.floor(lt.y), math.ceil(rb.y) - 1
  local best_intensity, best_kind = 0, nil
  for tx = x0, x1 do
    for ty = y0, y1 do
      local tile = surface.get_tile(tx, ty)
      if tile and tile.valid then
        local intensity, kind = terrain.tile_damage(tile.name)
        if intensity > best_intensity then
          best_intensity, best_kind = intensity, kind
        end
      end
    end
  end
  return best_intensity, best_kind
end

-- Damage every player and machine standing on lethal GROUND, scaled by the
-- intensity of the most-lethal tile in its footprint (heat on hot ground, cold on
-- the smooth-ice cap). `dps` (optional) overrides the settings value so tests are
-- deterministic; it is the peak dps at a full-intensity (1.0) tile.
function M.sweep(surface, interval_ticks, dps)
  if not (surface and surface.valid) or surface.name ~= "cindra" then return end
  interval_ticks = interval_ticks or M.DAMAGE_INTERVAL
  dps = dps or settings_dps() or 0
  if dps <= 0 then return end

  for _, e in pairs(surface.find_entities_filtered({ type = M.DAMAGEABLE_TYPES })) do
    if e.valid then
      local intensity, kind = M.footprint_damage(surface, e)
      if intensity > 0 and kind then
        -- Intensity scales the peak dps into a per-tile dps -> the depth ramp;
        -- the entity's own force + resistances still apply, so heat/cold-shielded
        -- gear or buildings mitigate the burn, never zeroing geography.
        local amount = M.damage_amount(dps * intensity, interval_ticks)
        e.damage(amount, e.force, M.DAMAGE_TYPE[kind])
      end
    end
  end
end

return M
