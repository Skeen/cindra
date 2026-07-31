-- Data stage for the freeze-radius PoC (ci-b5i).
--
-- Registers exactly two NEW kinds of prototype and edits no vanilla content:
--
--   1. A minimal freeze-carrier PLANET whose ONLY meaningful property is
--      `entities_require_heating = true`. `entities_require_heating` lives only on
--      PlanetPrototype (a whole-planet bool -- confirmed by the ci-p7z spike), so
--      to make the engine freeze entities on our controlled surface we need a real
--      planet to associate that surface with. Everything else on the planet is the
--      bare minimum to load (SpaceLocationPrototype needs `distance` +
--      `orientation`; PrototypeBase needs `type` + `name`).
--
--   2. A FAMILY of heat-interface clones, one per radius in C.RADII, differing
--      ONLY in `heating_radius`. This is the whole experiment: heating_radius is a
--      prototype float with no documented max, and the 2.x changelog note "Heat
--      interface can now heat entities and tiles" implies a hot interface thaws
--      freezable entities within that radius as an ambient source. The clones let
--      a headless test sweep the radius (a prototype value, not runtime-settable)
--      and read LuaEntity.frozen to map the real effective range + any clamp.
--
-- Nothing here is landable/playable; the planet exists purely as a freeze flag
-- carrier for tests. No recipes, no tech, no vanilla mutation.

local C = require("scripts.config")

-- Deep-copy the base heat-interface so we never mutate the shared vanilla
-- prototype (the never-touch-other-planets rule). `util.table.deepcopy` is
-- available in the data stage.
local base_interface = data.raw["heat-interface"]["heat-interface"]

local emitters = {}
for _, radius in ipairs(C.RADII) do
  local clone = table.deepcopy(base_interface)
  clone.name = C.emitter_name(radius)
  clone.heating_radius = radius
  -- Not player-minable / not in any menu: a pure test fixture. Keep it hidden
  -- and give it the same trivial box as the base so placement maths is simple.
  clone.hidden = true
  clone.minable = nil
  -- A clone shares the base item's `place_result`; drop any so nothing points a
  -- vanilla item at our clone. Tests spawn it directly via create_entity.
  clone.placeable_by = nil
  emitters[#emitters + 1] = clone
end

-- Completeness check: heating_radius also lives on ReactorPrototype and
-- HeatPipePrototype, and the heat-interface may be special-cased. Clone a base
-- reactor and a base heat-pipe at a small and a large radius so a probe can test
-- whether EITHER honours a large heating_radius for entity thawing (if one does,
-- the sparse-line mechanic could still live on that entity kind).
local function clone_named(source, new_name, radius)
  local clone = table.deepcopy(source)
  clone.name = new_name
  clone.heating_radius = radius
  clone.hidden = true
  clone.minable = nil
  clone.placeable_by = nil
  return clone
end

local base_reactor = data.raw["reactor"]["nuclear-reactor"]
local base_heatpipe = data.raw["heat-pipe"]["heat-pipe"]
for _, radius in ipairs({ 2, 100 }) do
  emitters[#emitters + 1] = clone_named(base_reactor, "freeze-poc-reactor-r" .. radius, radius)
  emitters[#emitters + 1] = clone_named(base_heatpipe, "freeze-poc-heatpipe-r" .. radius, radius)
end

data:extend(emitters)

data:extend({
  {
    type = "planet",
    name = C.PLANET,
    -- A valid loadable icon, never shown in real play (this planet is a test
    -- fixture, not a destination). Use base art so the PoC loads even without
    -- space-age (the dep is optional).
    icon = "__base__/graphics/icons/heat-interface.png",
    icon_size = 64,
    -- SpaceLocationPrototype minimum. Placed far out so it can never collide with
    -- a real planet's star-map slot; irrelevant to the freeze behaviour.
    distance = 100,
    orientation = 0.5,
    -- THE reason this planet exists: turn on whole-surface freezing so associated
    -- surfaces freeze freezable entities unless heated.
    entities_require_heating = true,
  },
})
