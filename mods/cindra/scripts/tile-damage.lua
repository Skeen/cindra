-- Belt-based lethal-ground damage (§4, §15-2; ci-3yl, ci-da2, ci-4jl, REKEYED ci-oe83).
--
-- The ribbon's danger is FELT as environmental damage: the hot belt burns and the cold
-- belt freezes anything standing in it -- the player AND machines/entities alike. The
-- damage is keyed to the ONE heightmap FIELD (scripts/terrain.lua): the field value at an
-- entity's perpendicular POSITION decides the damage (M.field_damage), NOT the tile-type
-- under it.
--
-- Why belt/field-based, not per-tile (ci-oe83): ci-4jl keyed damage to the TILE under an
-- entity. Because the tile art is noisy, a high-elevation ridge of non-damaging tiles
-- could reach all the way to the lava ocean, giving a walk-to-lava corridor that took ZERO
-- damage. Keying damage to the field value (i.e. the perpendicular position) closes that:
-- the field is monotonic + clamped, so the damage is two contiguous EDGE BELTS you cannot
-- get around -- there is no non-damaging path to either ocean at any elevation, and a
-- cosmetic hot-looking tile scattered in the safe middle does ZERO damage.
--
-- We read the entity's whole collision FOOTPRINT and take the MOST-LETHAL point in it (the
-- deepest into a belt), so a machine whose footprint overlaps the belt burns even if its
-- centre reads safe -- the ci-8vu spirit, now position-keyed.
--
-- Factorio has NO native per-tick damaging-field, so this is a script sweep.
--
-- 🚨 Scoped to `surface.name == "cindra"`: never touches an entity on any other planet.
-- Buildings' nightside FREEZE (needs a heat source) is a separate, richer mechanic in
-- scripts/building-heat.lua; this is the raw lethal-ground burn.

local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

local M = {}

-- Sweep cadence (ticks). on_nth_tick(N) is REPLACE-not-add, so this N stays distinct from
-- every other periodic system (building-heat 47, flare 23, panel-damage 29); it inherits
-- the old edge-damage cadence (20).
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

-- The MOST-LETHAL field damage under an entity's collision footprint: returns
-- (intensity, kind) for the deepest-into-a-belt point any part of the entity touches, or
-- (0, nil) if it sits entirely in the safe middle. Reads the field at the footprint's
-- perpendicular EXTREMES (the sunward-most corner for heat, the nightward-most for cold),
-- so an entity overlapping a belt burns even if its centre reads safe. Position-keyed, so
-- this is pure of the tile art; `cfg` (optional) overrides the live widths for tests.
function M.footprint_damage(e, orient, cfg)
  orient = orient or axis.orientation()
  local box = e.bounding_box
  local lt, rb = box.left_top, box.right_bottom
  -- The perpendicular coordinate over the box's four corners -> its [min, max] perp span.
  local pmin, pmax
  for _, corner in ipairs({ lt, rb, { x = lt.x, y = rb.y }, { x = rb.x, y = lt.y } }) do
    local p = axis.perp(corner.x, corner.y, orient)
    if pmin == nil or p < pmin then pmin = p end
    if pmax == nil or p > pmax then pmax = p end
  end
  -- Heat is worst at the highest perp (sunward-most), cold at the lowest (nightward-most).
  local hot_i, hot_k = terrain.field_damage(pmax, cfg)
  local cold_i, cold_k = terrain.field_damage(pmin, cfg)
  if hot_i >= cold_i then return hot_i, hot_k end
  return cold_i, cold_k
end

-- Damage every player and machine standing in a lethal BELT, scaled by how deep into the
-- belt its footprint reaches (heat on the hot belt, cold on the cold belt). `dps`
-- (optional) overrides the settings value so tests are deterministic; it is the peak dps
-- at a full-intensity (1.0) point. `cfg` (optional) overrides the live zone widths.
function M.sweep(surface, interval_ticks, dps, cfg)
  if not (surface and surface.valid) or surface.name ~= "cindra" then return end
  interval_ticks = interval_ticks or M.DAMAGE_INTERVAL
  dps = dps or settings_dps() or 0
  if dps <= 0 then return end
  local orient = axis.orientation()

  for _, e in pairs(surface.find_entities_filtered({ type = M.DAMAGEABLE_TYPES })) do
    if e.valid then
      local intensity, kind = M.footprint_damage(e, orient, cfg)
      if intensity > 0 and kind then
        -- Intensity scales the peak dps into a per-point dps -> the depth ramp; the
        -- entity's own force + resistances still apply, so heat/cold-shielded gear or
        -- buildings mitigate the burn, never zeroing geography.
        local amount = M.damage_amount(dps * intensity, interval_ticks)
        e.damage(amount, e.force, M.DAMAGE_TYPE[kind])
      end
    end
  end
end

return M
