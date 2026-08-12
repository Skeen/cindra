-- Cindra data-stage entry point.
--
-- v1 foundation (§15 item 1): the planet + surface + ribbon/temperature-axis
-- framing. As Cindra is built out, add prototype files under prototypes/ and
-- require them here, following the §15 implementation order, e.g.
--
--   require("prototypes.ice-processing")  -- §15-4  ice -> water (+ calcite)
--   require("prototypes.lava")            -- §15-5  1 stone + power -> 10 cindra-lava
--   require("prototypes.aluminium")       -- signature: power-manufactured metal
--   require("prototypes.flare")           -- §15-7  solar + flare event
--   require("prototypes.storage")         -- §15-9  capacitor + molten-salt battery
--   require("prototypes.electric-heater") -- §15-10
--   require("prototypes.mass-driver")     -- §15-11
--   require("prototypes.science")         -- §15-12 Cindra science pack + tech tree
--
-- See DESIGN.md for the authoritative design and TODO.md for the backlog.

-- Map-gen foundations (§4, §15-2; ci-3yl): the named noise expression the planet
-- overrides, and Cindra's own terrain tiles (the noise-driven ribbon bands). Both
-- must exist for the planet's map_gen_settings to reference them.
require("prototypes.noise")
require("prototypes.tiles")

-- Zone-appropriate decoratives (ci-6fq): cosmetic decals cloned from vanilla and
-- scattered per gradient zone (rocks/craters on the hot half, ice/snow on the cold
-- half), gated to the perpendicular ribbon axis. Must exist before the planet's
-- map_gen_settings references them in its decorative allow-list.
require("prototypes.decoratives")

-- The Cindra planet: tidally-locked ribbon planet, surface + reachability + the
-- temperature-axis framing, generated as a REAL noise-driven ribbon planet.
require("prototypes.planet")

-- § freeze (ci-bvk): the invisible ambient lava-heat emitter. The planet carries
-- `entities_require_heating = true` (planet.lua), so every freezable entity freezes
-- unless a hot heat source is in reach; scripts/freeze-emitters.lua lines these along
-- the ribbon to keep the habitable band thawed while the deep nightside freezes for
-- real. A deep-copied heat-interface -- mutates no shared prototype. Loads after the
-- planet (whose flag it serves); needs no other Cindra prototype.
require("prototypes.freeze-emitter")

-- §15-4 ice processing: mining an ice field yields a FIXED MIX of `ice` + `calcite`
-- directly (ci-9l6, see resources.lua) -- calcite is a native mined resource and
-- there is no feedstock chunk or ground crusher any more. The ONLY processing step
-- left is the vanilla `ice-melting` recipe (`ice` -> `water`) in the vanilla
-- chemical plant (ci-3mx: reuse vanilla, no custom item/melter/tech). This file
-- just appends that melt unlock to the Cindra discovery tech.
require("prototypes.ice-processing")

-- §15-5 manufactured lava: the central economy spine. `1 stone + [power] -> 10
-- cindra-lava` (ci-669), cast in the brought-not-re-unlocked Vulcanus foundry via
-- Cindra-exclusive casting recipes whose small, productivity-immune stone
-- byproduct loops back (net-consuming at every tier, never self-sustaining).
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

-- §15-11 mass driver: a RESKINNED ROCKET-SILO (ci-o39, ci-loa), gated behind the
-- cindra-orbital-launch tech. It supports PRODUCTIVITY MODULES and assembles its
-- launch vehicle INTERNALLY from RAW MATERIALS -- raw aluminium + vanilla rocket-fuel
-- (minted from aluminium by the "Solid rocket fuel" recipe, ci-519) + a shitton of
-- power (petrochemical-free), no pre-crafted can. The vanilla rocket path delivers
-- cargo to the space platform hub -- no catcher, no runtime loop. Loads after
-- aluminium (its material/fuel chain reads cindra-aluminium).
require("prototypes.mass-driver")

-- Worldgen track (§15 items 2-3): the two lethal-edge damage types, and the
-- ribbon's world resources (stone / ice / bootstrap rocks). Placed
-- at runtime by scripts/worldgen.lua; see DESIGN.md file-ownership map.
require("prototypes.damage-types")
require("prototypes.resources")

-- ci-nw0: the tinted fill sprite for the ambient thermal grade -- the subtle
-- position-driven warm/cool screen wash (drawn at runtime by
-- scripts/damage-feedback.lua on the worldgen cadence). A plain sprite prototype;
-- adds nothing to any entity and applies no damage.
require("prototypes.feedback")

-- ci-mk5y icy-side snowfall: the flake sprite the runtime (scripts/snowfall.lua) draws as
-- drifting snow over the FROZEN half of the ribbon only -- the ci-wly epic's "snow-fall
-- only on the icy side". A plain sprite prototype; adds nothing to any entity.
require("prototypes.snowfall")

-- Power system (§15 items 7-9), integrated from the proven flare-poc (ci-zg3):
--   * flare   §15-7  the sunward-band solar variants (ci-8al: Cindra uses the
--                    plain vanilla panel; only the reduced position bands are new
--                    prototypes). The flare itself is a surface property.
--   * storage §15-9  capacitor + molten-salt battery + dissipator (the sink web).
-- The panel-damage rule (§15-8) is runtime-only (scripts/panels.lua); it adds no
-- prototypes. Shared tuning lives in scripts/flare-config.lua.
require("prototypes.flare")
require("prototypes.storage")

-- The overload-damage spark (ci-clf): a short electric-arc explosion the runtime
-- panel-damage sweep (scripts/panels.lua) pops on a panel the instant it takes
-- disposal-deficit damage, giving the otherwise-silent degradation a visible cue.
-- A cosmetic explosion entity (self-reaping); wires into no recipe/tech.
require("prototypes.panel-spark")

-- §15-12 Cindra science: the HEADLINE science pack (petrochemical-free, native
-- inputs only) crafted in an ordinary assembling machine -- its energy cost rides
-- on a long craft plus the power-hungry aluminium input. Its tech is gated behind
-- the signature aluminium (which needs both lava and ice), and it folds the
-- launch tech into the Cindra tree so the pack has real downstream unlocks.
-- Consumes the signature aluminium (prototypes/aluminium.lua), so it loads after.
require("prototypes.science")

-- Calcite-To-Olefins plastic chain (ci-400): the planet's petrochemical-free
-- PLASTIC. Water electrolysis + calcite calcination + methanol-to-olefins over a
-- copper-on-aluminium catalyst, all in stock machines, ending in the vanilla
-- `plastic-bar`. Its catalyst consumes the signature `cindra-aluminium`, so it
-- loads AFTER aluminium; its tech gates behind the aluminium tech (rock+ice+power).
require("prototypes.plastics")

-- Red mud (ci-c7j): the Bayer alumina route + iron recovery, folded into the
-- ci-6vj graph. `stone + quicklime -> alumina + red mud` (an alternative to the
-- acid leach), then `red mud + CO2 + [ruinous power] -> iron + slag` in a
-- dedicated arc furnace -- Cindra's waste-born iron, and the sink that
-- closes the calcination loop (quicklime -> Bayer, CO2 -> iron recovery). Loads
-- AFTER plastics (reads its quicklime + CO2) and aluminium (reads its alumina);
-- gates behind the materials-chemistry tech (calcination is its prereq).
require("prototypes.red-mud")

-- One-way power transfer PoC (ci-gcd): the "power diode" -- two electric-energy-
-- interface poles the runtime bridges to move power A->B between two networks,
-- never B->A. An ISOLATED feasibility spike: wired into NO recipe / tech /
-- worldgen, so it loads here without touching the main economy chain.
require("prototypes.power-diode")

-- Graphics guard (ci-sop): MUST be last -- audits every registered Cindra entity
-- for a wired render sprite and errors the load on any invisible building. Catches
-- the class of bug the runtime API cannot see (LuaEntityPrototype has no graphics
-- accessor). See prototypes/graphics-audit.lua + scripts/graphics-audit.lua.
require("prototypes.graphics-audit")

-- Frost guard (ci-u92y): the same shape, one layer down -- audits every Cindra
-- CRAFTING MACHINE for a frozen_patch, so none can ship freezing bare on the
-- nightside while its neighbours wear frost (the bug that landed twice: ci-z7nu
-- then ci-u92y). See prototypes/frost-audit.lua + scripts/frost-audit.lua.
require("prototypes.frost-audit")
