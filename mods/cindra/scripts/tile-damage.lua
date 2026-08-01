-- Tile-based lethal-ground damage (§4, §15-2; ci-3yl, ci-da2, ci-4jl, RESTORED ci-ma18).
--
-- The ribbon's danger is FELT as environmental damage: hot ground burns and cold ground
-- freezes anything standing on it -- the player AND machines/entities alike. The damage
-- is a function of the ACTUAL TILE under an entity (terrain.tile_damage), NOT of a raw
-- perpendicular position: a lava / hot-crack tile burns wherever it renders, and a
-- player-placed COVER tile (concrete / refined-concrete) shields, because a cover tile is
-- not one of our hazard naturals.
--
-- Why TILE-based, not position-keyed (ci-ma18 fixes ci-oe83's regression): ci-oe83
-- decoupled damage from the tile and keyed it to the perpendicular position to close the
-- OLD three-heightmap "walk-to-lava corridor". That over-corrected two ways: (1) concrete
-- placed over hot ground STILL burned (the position stayed "hot"), and (2) a hot-looking
-- crack the noise nudged off its nominal band dealt ZERO damage (the position read "safe").
-- The ribbon is now ONE monotonic heightmap (terrain.lua), so the damaging TILES already
-- form two contiguous EDGE BELTS -- keying damage back to the tile is corridor-safe AND
-- honours the cover: see terrain.tile_damage for the no-corridor argument.
--
-- We read the entity's whole collision FOOTPRINT and take the MOST-LETHAL tile under it,
-- so a machine straddling a lava tile burns even if its centre sits on safe ground -- the
-- ci-4jl / ci-8vu spirit.
--
-- Factorio has NO native per-tick damaging-field, so this is a script sweep.
--
-- 🚨 Scoped to `surface.name == "cindra"`: never touches an entity on any other
-- planet. Buildings' nightside FREEZE (needs a heat source) is a separate, NATIVE
-- mechanic (§ freeze, ci-bvk: entities_require_heating + the lava-heat emitter
-- line); this is the raw lethal-ground burn.

local terrain = require("scripts.terrain")

local M = {}

-- Sweep cadence (ticks). on_nth_tick(N) is REPLACE-not-add, so this N stays distinct from
-- every other periodic system (flare 23, panel-damage 29; freeze reheat now owns the
-- freed 47); it inherits the old edge-damage cadence (20).
M.DAMAGE_INTERVAL = 20

-- Semantic damage kind ("heat"/"cold", from the field) -> the concrete Cindra
-- damage-type prototype (prototypes/damage-types.lua).
M.DAMAGE_TYPE = {
  heat = "cindra-heat",
  cold = "cindra-cold",
}

-- Entity kinds the belts damage. Characters plus the built structures a player would push
-- out to the resource-rich edges -- so "damage hits machines too". Bounded so the sweep
-- stays cheap (safe positions resolve to intensity 0 and are skipped).
M.DAMAGEABLE_TYPES = {
  "character",
  "assembling-machine", "furnace", "mining-drill", "lab", "pump",
  "electric-pole", "inserter", "transport-belt", "boiler", "generator",
  "solar-panel", "accumulator", "container", "storage-tank", "beacon",
  "roboport", "radar", "turret", "ammo-turret", "electric-turret",
}

-- Peak damage-per-second at a max-intensity (1.0) point, read from the mod settings
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

-- The MOST-LETHAL tile damage under an entity's collision footprint: returns
-- (intensity, kind) for the worst (deepest-into-a-belt) tile ANY part of the entity
-- covers, or (0, nil) if every covered tile is safe. Samples every integer tile the
-- bounding box overlaps, so a machine straddling a lava tile burns even if its CENTRE
-- sits on safe ground -- and a cover tile (concrete) under the whole footprint shields,
-- because a cover tile is not a hazard natural (terrain.tile_damage).
function M.footprint_damage(surface, e)
  local box = e.bounding_box
  local lt, rb = box.left_top, box.right_bottom
  local x0, x1 = math.floor(lt.x), math.floor(rb.x)
  local y0, y1 = math.floor(lt.y), math.floor(rb.y)
  local best_i, best_k = 0, nil
  for ty = y0, y1 do
    for tx = x0, x1 do
      local tile = surface.get_tile(tx, ty)
      if tile and tile.valid then
        local i, k = terrain.tile_damage(tile.name)
        if i > best_i then best_i, best_k = i, k end
      end
    end
  end
  return best_i, best_k
end

-- Damage every player and machine standing on a lethal TILE, scaled by how lethal that
-- tile is (heat on the hot naturals, cold on the cold naturals). `dps` (optional)
-- overrides the settings value so tests are deterministic; it is the peak dps at a
-- full-intensity (1.0) tile (the lava-hot / smooth-ice ocean cores).
function M.sweep(surface, interval_ticks, dps)
  if not (surface and surface.valid) or surface.name ~= "cindra" then return end
  interval_ticks = interval_ticks or M.DAMAGE_INTERVAL
  dps = dps or settings_dps() or 0
  if dps <= 0 then return end

  for _, e in pairs(surface.find_entities_filtered({ type = M.DAMAGEABLE_TYPES })) do
    if e.valid then
      local intensity, kind = M.footprint_damage(surface, e)
      if intensity > 0 and kind then
        -- Intensity scales the peak dps into a per-tile dps -> the depth ramp; the
        -- entity's own force + resistances still apply, so heat/cold-shielded gear or
        -- buildings mitigate the burn, never zeroing geography.
        local amount = M.damage_amount(dps * intensity, interval_ticks)
        e.damage(amount, e.force, M.DAMAGE_TYPE[kind])
      end
    end
  end
end

return M
