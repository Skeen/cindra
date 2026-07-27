-- Runtime for the environmental scanner.
--
-- Each scanner is a constant-combinator: we compute its surface's readings
-- (scripts/readings.lua) plus an optional flare forecast (scripts/forecast.lua)
-- and write them to the combinator's output every UPDATE_INTERVAL ticks. Built
-- scanners are tracked in `storage` so the periodic sweep is O(scanners), not a
-- whole-map entity scan.
--
-- Each placed scanner also gets an animated building overlay
-- (rendering.draw_animation) drawn on top of its static combinator body, since a
-- constant-combinator's own sprite cannot frame-animate. See prototypes/scanner.lua.
--
-- This mod only ADDS its own entity and reads surface state; it never mutates
-- another planet's gameplay (the never-mutate-other-planets rule): setting a
-- constant combinator's own output signals affects nothing but that building's
-- circuit wires.

local C = require("scripts.config")
local readings = require("scripts.readings")
local forecast = require("scripts.forecast")

local M = {}

-- storage.es.scanners : unit_number -> LuaEntity (the tracked scanner set).
local function tracked()
  storage.es = storage.es or {}
  storage.es.scanners = storage.es.scanners or {}
  return storage.es.scanners
end

-- storage.es.overlays : unit_number -> { body = id, glow = id } (uint64 render
-- object ids). The animated building overlay drawn on top of each placed scanner
-- (the constant-combinator body itself is a static Sprite4Way and cannot
-- animate). We store the numeric ids -- not the LuaRenderObjects -- so `storage`
-- stays trivially serialisable across save/load, and re-fetch via
-- rendering.get_object_by_id when we need to touch them.
local function overlays()
  storage.es = storage.es or {}
  storage.es.overlays = storage.es.overlays or {}
  return storage.es.overlays
end

-- Resolve a stored render-object id back to a live LuaRenderObject, or nil.
local function live(id)
  if not id then return nil end
  local o = rendering.get_object_by_id(id)
  if o and o.valid then return o end
  return nil
end

-- Draw the animated body + emissive-glow overlays on a placed scanner, tracked
-- so they can be torn down when it is removed. Idempotent: a scanner that
-- already carries a live overlay is left alone (so the init/config-change
-- rescan does not stack duplicates on scanners whose overlays persisted across
-- the save). The overlays target the entity, so they also follow it and the
-- engine drops them automatically if the entity ever vanishes without an event.
function M.ensure_overlay(entity)
  if not (entity and entity.valid and entity.name == C.SCANNER) then return end
  local ov = overlays()
  local un = entity.unit_number
  local existing = ov[un]
  if existing and live(existing.body) then return existing end

  local body = rendering.draw_animation({
    animation = C.BODY_ANIM,
    surface = entity.surface,
    target = entity,
    render_layer = "higher-object-above", -- above the static combinator body
    animation_speed = C.ANIM_SPEED,
  })
  local glow = rendering.draw_animation({
    animation = C.GLOW_ANIM,
    surface = entity.surface,
    target = entity,
    render_layer = "higher-object-above",
    animation_speed = C.ANIM_SPEED,
  })
  ov[un] = { body = body.id, glow = glow.id }
  return ov[un]
end

-- Tear down a scanner's overlay render objects (safe if already gone; the engine
-- also drops them automatically when their target entity is destroyed).
function M.remove_overlay(unit_number)
  local ov = storage.es and storage.es.overlays
  if not (ov and unit_number) then return end
  local o = ov[unit_number]
  if o then
    local body, glow = live(o.body), live(o.glow)
    if body then body.destroy() end
    if glow then glow.destroy() end
    ov[unit_number] = nil
  end
end

-- Compute the full signal table for a surface (generic readings + optional
-- flare forecast merged in when a provider/interface supplies one).
function M.signals_for(surface)
  local sigs = readings.surface_signals(
    surface.daytime,
    surface.solar_power_multiplier,
    C.DAY_TICKS,
    { dusk = surface.dusk, evening = surface.evening, morning = surface.morning, dawn = surface.dawn }
  )
  local fc = forecast.get(surface)
  if fc then
    readings.merge_forecast(sigs, fc)
  end
  return sigs
end

-- Write a signal table to a scanner's constant-combinator output. Rebuilds the
-- whole first section each call, so the output is idempotent and stale signals
-- (e.g. a flare forecast that just went inactive) are cleared automatically.
function M.write(entity, sigs)
  local behavior = entity.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section(1) or behavior.add_section()
  -- Custom output requires a manual (non-group) section; a fresh combinator's
  -- section is manual. Skip rather than error if a player grouped it.
  if not section or (section.is_manual == false) then return end

  local filters = {}
  for _, name in ipairs(C.SIGNAL_ORDER) do
    local v = sigs[name]
    if v ~= nil then
      filters[#filters + 1] = {
        -- quality is mandatory once min is non-zero, so always set it.
        value = { type = "virtual", name = name, quality = "normal", comparator = "=" },
        min = v,
      }
    end
  end
  section.filters = filters
end

-- Recompute + write one scanner. Returns false if the entity is gone.
function M.update(entity)
  if not (entity and entity.valid) then return false end
  M.write(entity, M.signals_for(entity.surface))
  return true
end

-- Periodic sweep: refresh every tracked scanner, dropping dead references.
function M.update_all()
  local t = tracked()
  for un, e in pairs(t) do
    if e.valid then
      M.update(e)
    else
      t[un] = nil
    end
  end
end

-- Track a newly built scanner (idempotent) and give it its animated overlay.
function M.register_entity(entity)
  if entity and entity.valid and entity.name == C.SCANNER then
    tracked()[entity.unit_number] = entity
    M.ensure_overlay(entity)
  end
end

-- Stop tracking a removed scanner and tear down its overlay.
function M.forget_entity(entity)
  if entity and entity.unit_number then
    local t = storage.es and storage.es.scanners
    if t then t[entity.unit_number] = nil end
    M.remove_overlay(entity.unit_number)
  end
end

-- (Re)discover every existing scanner on every surface. Run on init and on
-- configuration change so adding the mod to a live save, or a test creating its
-- own surface, picks up scanners already on the map.
function M.rescan()
  local t = tracked()
  for un in pairs(t) do t[un] = nil end
  for _, surface in pairs(game.surfaces) do
    for _, e in pairs(surface.find_entities_filtered({ name = C.SCANNER })) do
      t[e.unit_number] = e
      M.ensure_overlay(e) -- idempotent: only draws for scanners lacking one
    end
  end
end

function M.init()
  storage.es = storage.es or {}
  storage.es.scanners = storage.es.scanners or {}
  storage.es.overlays = storage.es.overlays or {}
  M.rescan()
end

return M
