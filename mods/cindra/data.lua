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

-- §15-5 manufactured lava: the central economy spine. `1 stone + [power] -> 5
-- lava` (crafted in the brought-not-re-unlocked Vulcanus foundry), feeding the
-- foundry's molten iron/copper chain with its stone byproduct looping back.
require("prototypes.lava")

-- §15-6 cryo-hardened alloy: the SIGNATURE two-temperature quench. One craft that
-- needs a HOT input (the manufactured `lava` fluid, temperature-gated) and a COLD
-- input (cryo-coolant packed from nightside ice) at once -> cryo-hardened alloy.
-- Impossible off-world; gated behind BOTH the lava and ice-processing techs.
require("prototypes.cryo-alloy")

-- Manufactured aluminium (ci-txh): the ruinous-power material. Native
-- Hall-Heroult chain (stone + calcite -> alumina -> [huge power] -> aluminium) in
-- a dedicated high-draw electrolysis cell -- another flare-timed power sink.
-- Consumed by the flare capacitor (see storage.lua) and exportable via the mass
-- driver. Required BEFORE storage.lua, which reads aluminium as a capacitor input.
require("prototypes.aluminium")

-- §15-10 electric heater: capped-heat / uncapped-electric-draw surplus sink
-- (flare sink, nightside warmth, water boil-off, safe dissipation).
require("prototypes.electric-heater")

-- §15-11 mass driver: electric launch-to-orbit (driver + hidden charger + native
-- shell), gated behind the cindra-orbital-launch tech. No platform-side catcher --
-- cargo lands in the space platform hub like normal rocket cargo (ci-98r). Removes
-- launch chemistry entirely. Runtime loop in scripts/mass-driver.lua.
require("prototypes.mass-driver")

-- Worldgen track (§15 items 2-3): the two lethal-edge damage types, and the
-- ribbon's world resources (stone / ice / volatiles / bootstrap rocks). Placed
-- at runtime by scripts/worldgen.lua; see DESIGN.md file-ownership map.
require("prototypes.damage-types")
require("prototypes.resources")

-- Power system (§15 items 7-9), integrated from the proven flare-poc (ci-zg3):
--   * flare   §15-7  the high-output Cindra solar panel (the flare's producer).
--   * storage §15-9  capacitor + molten-salt battery + dissipator (the sink web).
-- The panel-damage rule (§15-8) is runtime-only (scripts/panels.lua); it adds no
-- prototypes. Shared tuning lives in scripts/flare-config.lua.
require("prototypes.flare")
require("prototypes.storage")

-- §15-12 Cindra science: the HEADLINE science pack (petrochemical-free, native
-- inputs only) crafted in a dedicated power-hungry "starforge" -- the largest
-- continuous activity is another flare-timed power sink. Its tech is gated behind
-- the signature cryo-quench (which needs both lava and ice), and it folds the
-- launch tech into the Cindra tree so the pack has real downstream unlocks.
-- Consumes the cryo-hardened alloy (prototypes/cryo-alloy.lua), so it loads after.
require("prototypes.science")

-- Graphics guard (ci-sop): MUST be last -- audits every registered Cindra entity
-- for a wired render sprite and errors the load on any invisible building. Catches
-- the class of bug the runtime API cannot see (LuaEntityPrototype has no graphics
-- accessor). See prototypes/graphics-audit.lua + scripts/graphics-audit.lua.
require("prototypes.graphics-audit")
