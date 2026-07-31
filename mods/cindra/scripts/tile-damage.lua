-- Field-based lethal-ground damage (§4, §15-2; ci-3yl, redefined ci-da2, reworked
-- ci-4jl, rebuilt ci-oe83 to key off the CONTINUOUS FIELD).
--
-- The ribbon's danger is FELT as environmental damage: the hot side burns and the cold
-- side freezes -- the player AND machines/entities alike. The lethality is a function
-- of the CONTINUOUS FIELD (the perpendicular coordinate), NOT the tile art under the
-- entity: terrain.field_damage(p) ramps a heat/cold intensity from 0 at the damage
-- onset (the region inner edge) up to full at the ocean, monotonic toward the ocean.
--
-- 🚨 Why field-based, not per-tile (ci-oe83): the per-tile model (ci-4jl) keyed damage
-- to which TILE an entity touched. That let a high-elevation ridge of "non-damaging"
-- tile art reach out to the lava, giving a WALK-TO-LAVA no-damage corridor -- the exact
-- bug the user hit. Keying to the field closes it: because the worldgen only lets lava
-- EMERGE beyond the damage onset (the elevation ramp is bounded), there is NO
-- non-damaging path from the safe middle to any lava tile -- you always cross the
-- damaging band first, whatever tile art is underfoot. This is the SAME positional
-- field the resource band masks and the screen-tint feedback read, so damage, feedback
-- and resources all line up on ONE axis (DESIGN §3: positional lethal-zone damage).
--
-- The footprint is still read WHOLE (not just the centre): an entity is damaged by the
-- most-lethal part of its collision box (its edge nearest the ocean), so a machine
-- reaching into the danger burns -- the ci-4jl footprint fix, now field-driven.
--
-- Factorio has NO native per-tick damaging field, so this is a script sweep.
--
-- 🚨 Scoped to `surface.name == "cindra"`: never touches an entity on any other
-- planet. Buildings' nightside FREEZE (needs a heat source) is a separate, richer
-- mechanic in scripts/building-heat.lua; this is the raw lethal-ground burn.

local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

local M = {}

-- Sweep cadence (ticks). on_nth_tick(N) is REPLACE-not-add, so this N stays distinct
-- from every other periodic system (building-heat 47, flare 23, panel-damage 29); it
-- inherits the old edge-damage cadence (20).
M.DAMAGE_INTERVAL = 20

-- Semantic damage kind ("heat"/"cold") -> the concrete Cindra damage-type prototype.
M.DAMAGE_TYPE = {
  heat = "cindra-heat",
  cold = "cindra-cold",
}

-- Entity kinds the lethal field damages. Characters plus the built structures a player
-- would push out to the resource-rich edges -- so "damage hits machines too". Bounded
-- so the sweep stays cheap (safe positions resolve to intensity 0 and are skipped).
M.DAMAGEABLE_TYPES = {
  "character",
  "assembling-machine", "furnace", "mining-drill", "lab", "pump",
  "electric-pole", "inserter", "transport-belt", "boiler", "generator",
  "solar-panel", "accumulator", "container", "storage-tank", "beacon",
  "roboport", "radar", "turret", "ammo-turret", "electric-turret",
}

-- Peak damage-per-second at a full-intensity (1.0) point, read from the mod settings.
-- Returns nil if settings are absent (tests pass an explicit dps).
local function settings_dps()
  local s = settings and settings.startup
  if s and s["cindra-ribbon-max-dps"] then return s["cindra-ribbon-max-dps"].value end
  return nil
end

-- HP to inflict over `interval_ticks` at damage-per-second `dps`. Pure helper.
function M.damage_amount(dps, interval_ticks)
  return dps * (interval_ticks / 60)
end

-- The MOST-LETHAL field intensity under an entity's collision footprint: returns
-- (intensity, kind) for the highest field-damage intensity any part of the entity's
-- bounding box reaches. Reading the whole box (not just the centre) is what burns a
-- machine reaching into the danger. `orient` is resolved once by the caller.
-- Intentionally NOT pure (reads the entity's live box); the pure decision is
-- terrain.field_damage on a perpendicular coordinate.
function M.footprint_damage(e, cfg, orient)
  local box = e.bounding_box
  local lt, rb = box.left_top, box.right_bottom
  -- The field is monotonic in the perpendicular coordinate, so the most-lethal point of
  -- an axis-aligned box is one of its four corners; sample all four and take the max.
  local best_intensity, best_kind = 0, nil
  local corners = {
    { lt.x, lt.y }, { rb.x, lt.y }, { lt.x, rb.y }, { rb.x, rb.y },
  }
  for _, c in ipairs(corners) do
    local p = axis.perp(c[1], c[2], orient)
    local intensity, kind = terrain.field_damage(p, cfg)
    if intensity > best_intensity then
      best_intensity, best_kind = intensity, kind
    end
  end
  return best_intensity, best_kind
end

-- Damage every player and machine standing in a lethal field, scaled by the field
-- intensity at the most-lethal point of its footprint (heat on the hot side, cold on
-- the cold side). `dps` (optional) overrides the settings value so tests are
-- deterministic; it is the peak dps at a full-intensity (1.0) point. `cfg` (optional)
-- overrides the zone widths for tests.
function M.sweep(surface, interval_ticks, dps, cfg)
  if not (surface and surface.valid) or surface.name ~= "cindra" then return end
  interval_ticks = interval_ticks or M.DAMAGE_INTERVAL
  dps = dps or settings_dps() or 0
  if dps <= 0 then return end
  local orient = axis.orientation()

  for _, e in pairs(surface.find_entities_filtered({ type = M.DAMAGEABLE_TYPES })) do
    if e.valid then
      local intensity, kind = M.footprint_damage(e, cfg, orient)
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
