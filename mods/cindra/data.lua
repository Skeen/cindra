-- Cindra data-stage entry point.
--
-- v1 foundation (§15 item 1): the planet + surface + ribbon/temperature-axis
-- framing. As Cindra is built out, add prototype files under prototypes/ and
-- require them here, following the §15 implementation order, e.g.
--
--   require("prototypes.ice-processing")  -- §15-4  ice -> water (+ calcite)
--   require("prototypes.lava")            -- §15-5  1 stone + power -> 5 lava
--   require("prototypes.cryo-alloy")      -- §15-6  two-temperature quench
--   require("prototypes.flare")           -- §15-7  solar + flare event
--   require("prototypes.storage")         -- §15-9  capacitor + molten-salt battery
--   require("prototypes.electric-heater") -- §15-10
--   require("prototypes.mass-driver")     -- §15-11
--   require("prototypes.science")         -- §15-12 Cindra science pack + tech tree
--
-- See DESIGN.md for the authoritative design and TODO.md for the backlog.

-- The Cindra planet: tidally-locked ribbon world, surface + reachability + the
-- temperature-axis framing.
require("prototypes.planet")

-- §15-4 ice processing: a ground crusher (asteroid-crushing model, relocated)
-- that grinds nightside ice into water, or water + calcite -- the player picks
-- the ratio by choosing the recipe.
require("prototypes.ice-processing")

-- §15-10 electric heater: capped-heat / uncapped-electric-draw surplus sink
-- (flare sink, nightside warmth, water boil-off, safe dissipation).
require("prototypes.electric-heater")

-- Worldgen track (§15 items 2-3): the two lethal-edge damage types, and the
-- ribbon's world resources (stone / ice / volatiles / bootstrap rocks). Placed
-- at runtime by scripts/worldgen.lua; see DESIGN.md file-ownership map.
require("prototypes.damage-types")
require("prototypes.resources")
