-- Cindra data-stage entry point.
--
-- v1 foundation (§15 item 1): the planet + surface + ribbon/temperature-axis
-- framing. As Cindra is built out, add prototype files under prototypes/ and
-- require them here, following the §15 implementation order, e.g.
--
--   require("prototypes.ice-processing")  -- §15-4  ice -> water (+ calcite)
--   require("prototypes.lava")            -- §15-5  1 stone + power -> 5 lava
--   require("prototypes.aluminium")       -- signature: power-manufactured metal
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

-- §15-4 ice processing: pure vanilla-recipe reuse (ci-3mx). The nightside deposit
-- yields the vanilla oxide-asteroid-chunk; a ground crusher (the one custom entity,
-- since the vanilla crusher is zero-gravity-gated) runs the vanilla oxide crushing
-- recipes -> ice (+ calcite; the two recipes are the ratio knob), and the vanilla
-- chemical plant runs the vanilla ice-melting recipe -> water. No custom item,
-- recipe, melter, or tech; the chain hangs off the Cindra discovery tech.
require("prototypes.ice-processing")

-- §15-5 manufactured lava: the central economy spine. `1 stone + [power] -> 5
-- lava` (crafted in the brought-not-re-unlocked Vulcanus foundry), feeding the
-- foundry's molten iron/copper chain with its stone byproduct looping back.
require("prototypes.lava")

-- ci-arw start-on-Cindra foundry bootstrap: a native, petrochemical-free lubricant
-- (crude coal-liquefaction for the finite bootstrap, plus a renewable stone+water
-- "silica oil" for the sustain) and a Cindra-buildable `foundry` recipe that drops
-- the Vulcanus pressure gate. Rescues the no-Vulcanus start (any-planet-start)
-- without leaking a free foundry into normal imported play. Must load AFTER lava
-- (shares the metal-economy framing) and before the science tree (§15-12) folds
-- its tech in. Requires resources.lua's bootstrap-rock coal, required below.
require("prototypes.lubricant")

-- Manufactured aluminium (ci-txh): Cindra's SIGNATURE product + primary export.
-- Native Hall-Heroult chain (stone + calcite -> alumina -> [huge power] ->
-- aluminium) in a dedicated high-draw electrolysis cell -- the planet's biggest
-- flare-timed power sink. It is petrochemical-free and power-intensive, so it
-- carries the core thesis (power-manufactured metal); gated behind BOTH the lava
-- and ice-processing techs. Consumed by the flare capacitor (see storage.lua) and
-- exported via the mass driver; also the input to the headline science pack.
-- Required BEFORE storage.lua, which reads aluminium as a capacitor input.
require("prototypes.aluminium")

-- §15-10 electric heater: capped-heat / uncapped-electric-draw surplus sink
-- (flare sink, nightside warmth, water boil-off, safe dissipation).
require("prototypes.electric-heater")

-- §15-11 mass driver: a RESKINNED ROCKET-SILO (ci-o39), gated behind the
-- cindra-orbital-launch tech. A launch consumes an aluminium can + vanilla rocket-fuel
-- (minted from aluminium by the "Solid rocket fuel" recipe, ci-519) + a shitton of
-- power (petrochemical-free), and the vanilla
-- rocket path delivers cargo to the space platform hub -- no catcher, no runtime
-- loop. Loads after aluminium (its can/fuel chain reads cindra-aluminium).
require("prototypes.mass-driver")

-- Worldgen track (§15 items 2-3): the two lethal-edge damage types, and the
-- ribbon's world resources (stone / ice / volatiles / bootstrap rocks). Placed
-- at runtime by scripts/worldgen.lua; see DESIGN.md file-ownership map.
require("prototypes.damage-types")
require("prototypes.resources")

-- Power system (§15 items 7-9), integrated from the proven flare-poc (ci-zg3):
--   * flare   §15-7  the sunward-band solar variants (ci-8al: Cindra uses the
--                    plain vanilla panel; only the reduced position bands are new
--                    prototypes). The flare itself is a surface property.
--   * storage §15-9  capacitor + molten-salt battery + dissipator (the sink web).
-- The panel-damage rule (§15-8) is runtime-only (scripts/panels.lua); it adds no
-- prototypes. Shared tuning lives in scripts/flare-config.lua.
require("prototypes.flare")
require("prototypes.storage")

-- §15-12 Cindra science: the HEADLINE science pack (petrochemical-free, native
-- inputs only) crafted in an ordinary assembling machine -- its energy cost rides
-- on a long craft plus the power-hungry aluminium input. Its tech is gated behind
-- the signature aluminium (which needs both lava and ice), and it folds the
-- launch tech into the Cindra tree so the pack has real downstream unlocks.
-- Consumes the signature aluminium (prototypes/aluminium.lua), so it loads after.
require("prototypes.science")

-- Graphics guard (ci-sop): MUST be last -- audits every registered Cindra entity
-- for a wired render sprite and errors the load on any invisible building. Catches
-- the class of bug the runtime API cannot see (LuaEntityPrototype has no graphics
-- accessor). See prototypes/graphics-audit.lua + scripts/graphics-audit.lua.
require("prototypes.graphics-audit")
