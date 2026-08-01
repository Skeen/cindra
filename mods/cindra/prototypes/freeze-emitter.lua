-- The Cindra lava-heat emitter (§ freeze, ci-bvk step 3).
--
-- An INVISIBLE, non-colliding, worldgen-placed AMBIENT heat source representing the
-- LAVA's own warmth radiating off the fire edge. It is NOT a player structure: the
-- runtime (scripts/freeze-emitters.lua) lines these along the ribbon as chunks
-- generate and re-affirms their heat, so the warm band stays thawed on the
-- `entities_require_heating` Cindra surface while the deep nightside freezes for
-- real -- "from the lava side outward, ice starts where the warmth runs out."
--
-- WHY A HEAT-PIPE (not a heat-interface): the engine's `heating_radius` -- the field
-- that makes a heat source thaw entities OUT TO A RADIUS -- exists only on HeatPipe
-- and Reactor prototypes (base changelog: "Added heating_radius to ReactorPrototype
-- and HeatPipePrototype"). A heat-interface IGNORES it and warms only its own tile
-- (measured: a heating_radius-100 heat-interface leaves a machine 5 tiles away
-- frozen). Of the two that honour it, the reactor is multi-tile (its bounding box
-- shifts the reach off the pinned 1-tile geometry), so the emitter is a 1x1 HEAT-PIPE
-- -- single tile (exact reach) AND radius-honouring. It is held hot at runtime.
--
-- We start from a deep-copied vanilla heat-pipe (name + heating_radius + hidden/
-- minable/placeable_by, like the ci-b5i fixtures) and add the two things real play
-- needs beyond a test fixture:
--   * INVISIBLE: an empty picture + no heat-glow, so nothing renders in-world.
--   * NON-COLLIDING: an empty collision mask, so worldgen placement never fails on an
--     occupied or impassable tile (a sunward emitter row falls in the lava sea).
--
-- 🚨 NEVER MUTATES A SHARED PROTOTYPE: table.deepcopy of the vanilla heat-pipe before
-- touching any field, and the runtime only ever creates this entity on the Cindra
-- surface (never on another planet). Not audited by graphics-audit (heat-pipe is not
-- one of its graphics-bearing types) -- it is deliberately invisible.

local freeze = require("scripts.freeze")

-- Deep-copy the base heat-pipe so we never alias the shared vanilla prototype or its
-- nested tables (the never-mutate-other-planets invariant).
local emitter = table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])

emitter.name = freeze.EMITTER_NAME
emitter.heating_radius = freeze.EMITTER_HEATING_RADIUS

-- A pure test fixture becomes worldgen furniture: out of the build menu, unminable,
-- invisible, and non-colliding for real play.
emitter.hidden = true
emitter.minable = nil
emitter.placeable_by = nil
emitter.selectable_in_game = false
emitter.collision_mask = { layers = {} } -- collides with nothing (place anywhere)
-- Blank the visible heat-pipe art so it renders nothing in-world.
emitter.heat_glow_sprites = nil
emitter.connection_sprites = nil
emitter.picture = util.empty_sprite()
-- Keep it out of blueprints / deconstruction planners; the runtime owns it.
emitter.flags = { "placeable-neutral", "not-blueprintable", "not-deconstructable", "not-upgradable" }

data:extend({ emitter })
