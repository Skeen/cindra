-- SCRIPT FREEZE (ci-de55): freezing the buildings the engine refuses to freeze.
--
-- Cindra's core mechanic is that the dark kills your factory. The planet flag
-- `entities_require_heating` delivers that for most things -- but the engine
-- honours `heating_energy` on only some prototype types, and an accumulator, a
-- solar panel and an electric-energy-interface are on none of them (MEASURED in
-- ci-qha1: the field is accepted at the data stage and silently discarded;
-- `is_freezable` stays false and the entity never freezes). So the capacitor, the
-- molten-salt battery, the sunward solar bands and the dissipator all kept working
-- in the deep dark. A battery bank humming away on the nightside is exactly the
-- immunity the human ruling -- "It should not be immune, I don't think anything
-- should be" -- rejected, so Cindra freezes them itself.
--
-- HOW, AND WHY THIS WAY.
--   * NOT a hidden freezable companion per building. That would be engine-driven
--     and poll-free, but it DOUBLES the entity count of anything placed in bulk,
--     and solar panels are placed in bulk. Rejected on UPS grounds (ci-de55).
--   * NOT a runtime flag: there is none. `LuaEntity.frozen` and `LuaEntity.active`
--     are both READ ONLY on these types (measured), and the one writable lever
--     (`electric_buffer_size`) exists only on an electric-energy-interface.
--   * So: a slow sweep swaps a building outside every heat source's reach for its
--     FROZEN TWIN prototype (prototypes/frozen-twins.lua) -- same footprint, same
--     buffer, zero flow, zero production, wearing ice -- and swaps it back when
--     heat returns. The twin is a prototype, not an entity, so a thousand frozen
--     panels cost a thousand entities, not two thousand.
--
-- ENERGY IS NEVER CREATED OR DESTROYED. The swap copies `energy` across, and the
-- twin keeps the base's buffer capacity, so a frozen battery still holds every
-- joule it held -- it simply cannot move them (the twin's flow limits are 0). This
-- is not a claim: tests/test_power_conservation.lua measures the whole grid's
-- stored energy across a freeze and a thaw and requires the total to be unchanged.
-- We have shipped a power entity that minted 10 MW from nothing behind a green
-- suite once (ci-76if); the ledger here is measured, not asserted by comment.
--
-- THE PLAYER CAN SEE IT. The engine draws no frost for these types, so the twin
-- carries ice in its own art and announces itself with a custom alert on the map.
-- A building that silently stopped working would be worse than the immunity being
-- fixed -- it reads as a mod bug, and the player never learns the rule.
--
-- COST. One sweep every SWEEP_INTERVAL ticks per Cindra surface: two filtered
-- entity queries, a coarse spatial index over the hot heat sources
-- (scripts/freeze.lua), and one hash lookup per candidate building. No per-entity
-- state, no per-tick work, and NOTHING at all on a surface that is not Cindra.
--
-- 🚨 Per-surface, gated on `surface.name == "cindra"`. No other planet is touched.

local audit = require("scripts.frost-audit")
local freeze = require("scripts.freeze")

local M = {}

-- Sweep cadence (ticks). DELIBERATELY SLOW and distinct from every other periodic
-- system (snowfall 3, diode 7, tile-damage 20, flare 23, panel-damage 29, emitter
-- reheat 47): on_nth_tick is REPLACE-not-add. ~5 s is far quicker than a player
-- can drag a heat line out to a battery bank and notice, and slow enough that the
-- sweep is invisible on a UPS graph. Freezing here is POSITIONAL (Cindra is
-- tidally locked -- the dark side is always dark), so transitions happen only when
-- someone builds or breaks a heat source. There is nothing to chase per tick.
M.SWEEP_INTERVAL = 313

-- The alert icon. `ice` is a Space Age item (Cindra depends on Space Age), so the
-- signal always resolves; tests/test_script_freeze.lua pins that.
M.ALERT_ICON = { type = "item", name = "ice" }

local function is_cindra(s)
  return s and s.valid and s.name == "cindra"
end

-- === The class ==============================================================
-- Discovered LIVE from the loaded prototypes, using the SAME policy tables the
-- data-stage guard used to build the twins (scripts/frost-audit.lua), so the
-- runtime and the load guard can never disagree about who is script-frozen.
-- Cached per load: prototypes cannot change while the game is running.
local class_cache = nil

local function class()
  if class_cache then return class_cache end
  local frozen_of, thawed_of, names = {}, {}, {}
  for name, proto in pairs(prototypes.entity) do
    if name:sub(1, 7) == "cindra-"
      and audit.must_script_freeze({ type = proto.type, name = name })
      and prototypes.entity[audit.frozen_name(name)] then
      local twin = audit.frozen_name(name)
      frozen_of[name] = twin
      thawed_of[twin] = name
      names[#names + 1] = name
      names[#names + 1] = twin
    end
  end
  class_cache = { frozen_of = frozen_of, thawed_of = thawed_of, names = names }
  return class_cache
end

-- The live building names the sweep freezes (sorted; for tests and guards).
function M.frozen_class()
  local out = {}
  for name in pairs(class().frozen_of) do out[#out + 1] = name end
  table.sort(out)
  return out
end

function M.frozen_name_of(name) return class().frozen_of[name] end
function M.thawed_name_of(name) return class().thawed_of[name] end

-- === Heat coverage ==========================================================

-- Is this heat source actually emitting? A heat-pipe or reactor warms its radius
-- only while its buffer is above the temperature it rests at -- a cold pipe is
-- just a pipe. (The worldgen lava-heat emitters are held at 1000 C by the
-- driver's reheat sweep; a player's heat network is hot only while it is fed.)
local function is_hot(entity)
  local buffer = entity.prototype.heat_buffer_prototype
  local rest = buffer and buffer.default_temperature or 15
  return entity.temperature ~= nil and entity.temperature > rest
end

-- The tile regions kept thawed on `surface` by every hot heat source on it.
function M.heated_regions(surface)
  local regions = {}
  for _, e in pairs(surface.find_entities_filtered({ type = freeze.HEAT_SOURCE_TYPES })) do
    if e.valid then
      local radius = e.prototype.heating_radius or 0
      if radius > 0 and is_hot(e) then
        regions[#regions + 1] =
          freeze.heated_region(freeze.tile_box(e.selection_box), radius)
      end
    end
  end
  return regions
end

-- === The swap ===============================================================

-- Copy the circuit/copper wires from `old` onto `new`. An accumulator publishes
-- its charge to the circuit network, so a player may well have it wired; losing
-- those wires every time the sun went out would be a bug the freeze introduced.
local function transfer_wires(old, new)
  for id, connector in pairs(old.get_wire_connectors(false)) do
    local target = new.get_wire_connector(id, true)
    if target then
      for _, conn in pairs(connector.connections) do
        target.connect_to(conn.target, false, conn.origin)
      end
    end
  end
end

-- Swap `entity` for prototype `to`, preserving everything a player would notice:
-- position, facing, ownership, damage, WIRES and -- the load-bearing one --
-- every stored joule.
local function swap(entity, to)
  local surface, position, force = entity.surface, entity.position, entity.force
  local direction, last_user = entity.direction, entity.last_user
  local health = entity.health
  local energy = entity.energy
  local old = entity

  local new = surface.create_entity({
    name = to, position = position, force = force, direction = direction,
    create_build_effect_smoke = false,
  })
  if not new then return nil end

  if old.valid then
    transfer_wires(old, new)
    old.destroy()
  end
  if energy then new.energy = energy end
  if health and new.health then new.health = math.min(health, new.max_health) end
  if last_user then new.last_user = last_user end
  return new
end

-- Tell the player. The frost art says WHAT happened on screen; the alert says
-- WHERE, for a battery bank the player is not currently looking at. Raised ONCE,
-- on the freeze itself: an alert is an event, and re-raising it for every frozen
-- building on every sweep is both redundant and the single most expensive thing
-- the sweep could do (measured: it was most of a 15 ms sweep over a 240-building
-- field, which is the "correct but tanks UPS" regression ci-de55 warns about).
local function announce(entity)
  local force = entity.force
  if not (force and force.valid and force.add_custom_alert) then return end
  -- Name the building the player BUILT, not its frozen form: the twin's own name
  -- already carries the "(frozen)" mark, so using it would read "Molten-salt
  -- battery (frozen) has frozen".
  local base = prototypes.entity[audit.thawed_name(entity.name) or ""]
  force.add_custom_alert(entity, M.ALERT_ICON,
    { "cindra-message.frozen-alert", (base or entity).localised_name }, true)
end

-- ...and take it back the moment the building thaws. A custom alert OUTLIVES the
-- entity it was raised on (measured: destroying the frozen twin leaves the alert
-- standing), so thawing has to clear it explicitly or the player's alert list
-- fills with warnings about buildings that are working fine.
local function silence(entity)
  local force = entity.force
  if not (force and force.valid and force.remove_alert) then return end
  force.remove_alert({ entity = entity, type = defines.alert_type.custom })
end

-- === The sweep ==============================================================

-- One pass over `surface`: freeze every script-freezable building outside all
-- heat, thaw every frozen one back inside it. Returns { froze =, thawed =,
-- frozen = } (frozen = how many are frozen after the pass), which the tests read
-- and which makes the sweep measurable rather than merely observable.
-- A no-op off Cindra.
function M.sweep(surface)
  if not is_cindra(surface) then return { froze = 0, thawed = 0, frozen = 0 } end
  local c = class()
  if #c.names == 0 then return { froze = 0, thawed = 0, frozen = 0 } end

  local index = freeze.coverage_index(M.heated_regions(surface))
  local froze, thawed, frozen = 0, 0, 0

  for _, e in pairs(surface.find_entities_filtered({ name = c.names })) do
    if e.valid then
      local warm = freeze.covered_by_index(index, freeze.tile_box(e.selection_box))
      local twin = c.frozen_of[e.name]
      if twin then
        if not warm then
          local new = swap(e, twin)
          if new then
            froze = froze + 1
            frozen = frozen + 1
            announce(new)
          end
        end
      else
        if warm then
          silence(e)
          if swap(e, c.thawed_of[e.name]) then thawed = thawed + 1 end
        else
          frozen = frozen + 1
        end
      end
    end
  end
  return { froze = froze, thawed = thawed, frozen = frozen }
end

-- Every Cindra surface, one pass. Called from the driver's own slow tick.
function M.sweep_all()
  for _, s in pairs(game.surfaces) do
    if is_cindra(s) then M.sweep(s) end
  end
end

return M
