-- Cindra control-stage entry point.
--
-- v1 foundation (§15 item 1) established the runtime surface + the pure ribbon
-- temperature axis (scripts/ribbon.lua). The WORLDGEN track (§15 items 2-3) now
-- attaches its runtime here via scripts/driver.lua: the lethal-edge damage sweep,
-- the NATIVE nightside freeze (§ freeze, ci-bvk: the entities_require_heating flag +
-- the worldgen lava-heat emitter line), and the finite-ribbon bound. Later tracks
-- (flare §15-7, etc.) register their own runtime; keep each track's handlers disjoint.
--
-- Invariants (mirrors AGENTS.md / DESIGN.md):
--   * NEVER mutate global state that affects other planets. Every runtime handler
--     is gated on `surface.name == "cindra"`. This mod adds Cindra; it MUST NOT
--     change any other planet's gameplay.
--   * `script.on_nth_tick(N, fn)` is REPLACE-not-add: one handler per N. Each
--     periodic system (edge-damage, flare, ...) uses a distinct N; the single
--     on_init lives here.

local driver = require("scripts.driver")
driver.register()

-- §15-11 mass driver: a reskinned ROCKET-SILO (prototypes/mass-driver.lua, ci-o39).
-- It launches and delivers cargo to orbit via the NATIVE vanilla rocket path, so it
-- needs NO runtime loop here -- the old scripted fire/charge loop was removed with
-- the composite-container design.

-- Cross-mod flare forecast (the `cindra-flare` remote interface, ci-2ba/ci-3o3).
-- The standalone environmental scanner calls `forecast(surface_index)` to act as
-- a REACTIVE early-warning device: because flares are sporadic (no clock to read
-- them off), it gets a live forecast ONLY while a flare is telegraphing/active,
-- and nil ('calm') otherwise. Registered at load (interfaces re-register every
-- load); the scanner degrades gracefully when this mod is absent.
local flare = require("scripts.flare")
remote.add_interface("cindra-flare", {
  forecast = function(surface_index) return flare.forecast(surface_index) end,
})

-- One-way power transfer device (ci-gcd, reworked to a power-SWITCH-style single
-- building in ci-8l4): the "power diode". Registered on its OWN distinct nth-tick
-- (7), disjoint from the driver's periodic systems, because it is an isolated
-- feasibility spike. It spawns each placed device's hidden guts on build (its own
-- build/mine event handlers, disjoint from every other track) and shuttles
-- buffered power one way between the two networks the player wires to the switch.
-- A cheap no-op on any surface where no device is placed.
local diode = require("scripts.diode")
diode.register()

-- No paving over the ribbon (ci-cbn): revert + refund any landfill/foundation
-- (is_foundation) tile built on a Cindra surface, so the hot/cold danger zones and
-- the finite ribbon width can never be paved away. Registers its OWN tile-build
-- events, disjoint from every other track; gated on surface.name == "cindra" so no
-- other planet or space platform is affected.
local no_paving = require("scripts.no-paving")
no_paving.register()

local function on_init()
  driver.init()
end
script.on_init(on_init)
script.on_configuration_changed(on_init)

-- The factorio-test bootstrap below runs the integration suite when the
-- factorio-test mod is present. Keep the test list in sync with tests/.

if script.active_mods["factorio-test"] then
  local test_files = {
    "tests/test_example",
    "tests/test_planet",
    "tests/test_ribbon",
    "tests/test_heater",
    "tests/test_ice_processing",
    "tests/test_lava",
    "tests/test_sulfur", -- ci-eat: stone -> roast -> sulfur -> sulfuric acid
    "tests/test_aluminium",
    -- ci-400 Calcite-To-Olefins: the petrochemical-free plastic chain (water
    -- electrolysis + calcite calcination + methanol-to-olefins over a Cu/Al
    -- catalyst), ending in the vanilla plastic-bar; byproduct vents; gating.
    "tests/test_plastics",
    -- ci-6vj S6: the WHOLE materials/petrochemical graph as one object -- no
    -- byproduct deadlock, the O2 economy's real sinks, net-negative stone at the
    -- +300% cap, and no free-metal/carbon/plastic loop (DESIGN §8.4/§8.6).
    "tests/test_materials_graph",
    -- ci-c7j: the red-mud subsystem (Bayer alumina route + iron recovery) --
    -- both alumina routes feed electrolysis unchanged, iron is waste-born and a
    -- power sink, the Al<->Fe coupling closes without hard-deadlock (DESIGN §8).
    "tests/test_red_mud",
    "tests/test_tile_damage",
    -- ci-cbn: you cannot pave over Cindra's ribbon (landfill/foundation blocked +
    -- the runtime revert/refund safety net).
    "tests/test_paving",
    -- §15 v2 item 4 (ci-7tl): the full-screen heat/cold damage feedback tint
    -- shows/clears in step with the tile-based lethal-zone damage above.
    "tests/test_feedback",
    "tests/test_worldgen",
    -- ci-oe83: the ONE-heightmap merge gate -- emergent oceans, belt-confined damage,
    -- no walk-to-ocean corridor, no enclosure (drives the real sweep as the oracle).
    "tests/test_heightmap",
    "tests/test_decoratives",
    -- § freeze (ci-bvk): NATIVE freeze via the entities_require_heating flag + the
    -- worldgen lava-heat emitter line. Replaces the retired scripted building-heat
    -- cold-damage model: measured reach/seam vs the real emitter, warm-band thawed /
    -- nightward frozen, both orientations, ci-f5l heater extends the warm pocket, no
    -- other-planet mutation.
    "tests/test_freeze",
    "tests/test_mass_driver",
    "tests/test_space_appearance",
    -- ci-810e: PlanetsLib interop guards. Cindra takes NO dependency on PlanetsLib
    -- (see docs/planetslib-evaluation.md), but players install it alongside planet
    -- mods and its data-final-fixes imposes hard preconditions -- including a gas-
    -- percentage assert that REFUSES TO LOAD the game. Pinned from our own side.
    "tests/test_planetslib_compat",
    -- Power system (§15 items 7-9), integrated from the flare-poc (ci-zg3):
    -- flare cycle, disposal-deficit panel damage, storage + dissipator sinks.
    "tests/test_flare",
    "tests/test_panel_damage",
    "tests/test_panel_damage_runtime",
    -- ci-sz8q: overload damage follows the REAL undisposed surplus (a grid that
    -- consumes all its solar takes none), and a panel killed by overload breaks
    -- properly instead of vanishing.
    "tests/test_panel_overload",
    "tests/test_panel_solar",
    "tests/test_disposal",
    "tests/test_storage",
    "tests/test_catchability",
    "tests/test_power_prototypes",
    -- ci-ezk: ABSOLUTE solar output magnitudes (baseline ~330 kW = Vulcanus + 100-200
    -- pp after the ci-63d trim, flare peak in the MW range, dim sky does not suppress
    -- production).
    "tests/test_solar_magnitude",
    -- §15-12 the headline Cindra science pack (crafted in a stock assembler) + the
    -- folded tech tree (petrochemical-free, native inputs, a real energy cost).
    "tests/test_science",
    -- ci-84s signature PIVOT: aluminium is the signature product; the cryo-quench
    -- + cryo-hardened alloy are GONE. Guards that no cryo prototype survives and
    -- that aluminium carries the signature (science input + mass-driver export).
    "tests/test_pivot",
    -- §15-1 / ci-uex: the whole planet is bootstrappable from NOTHING -- land
    -- with only stone + hand-minable rocks and reach a self-sustaining
    -- lava->metal economy, with no chicken-and-egg and no soft-lock.
    "tests/test_bootstrap",
    -- ci-arw start-on-Cindra foundry bootstrap: finite bootstrap coal, native
    -- lubricant (crude + renewable), and the Cindra-buildable field foundry.
    "tests/test_foundry_bootstrap",
    -- ci-gcd one-way power transfer PoC: energy flows A->B up to a rate cap,
    -- never B->A; the two networks stay isolated.
    "tests/test_power_diode",
    -- ci-xor: the standalone env-scanner mod (the radio tower) loads alongside
    -- cindra via a required (~ env-scanner) dependency, so its buildable scanner
    -- exists in every Cindra playtest instead of silently going missing.
    "tests/test_env_scanner",
    -- §15-14 / ci-63d BALANCE PASS: the throughput/ratio audit -- every production
    -- edge's feeder-per-consumer count stays single-digit (no ~100:1 imbalance),
    -- craft times/rates are sane, and the exportable buildings stay
    -- situational-not-strictly-better (§12). All derived LIVE from the prototypes.
    "tests/test_balance_audit",
  }
  -- Companion-mod suites. any-planet-start is now an OPTIONAL dependency of
  -- cindra-start, so cindra-start can be active WITH or WITHOUT APS. Pick the
  -- suite that matches the loaded set:
  --   * WITH APS  -> test_aps_start: asserts APS registration took effect
  --     (add_choice/add_default/add_planet). That set rewrites Cindra's
  --     discovery tech, so it is never enabled in the default `mods/cindra` run.
  --   * WITHOUT APS -> test_aps_absent: asserts the companion mods load clean and
  --     register NOTHING (the guarded APS calls were skipped, no error).
  -- The default run enables neither companion mod, so neither suite registers.
  if script.active_mods["cindra-start"] then
    if script.active_mods["any-planet-start"] then
      test_files[#test_files + 1] = "tests/test_aps_start"
      -- ci-arw: the pre-researched foundry path is a Cindra-start guarantee, so
      -- it is only meaningful (and only asserted) when the APS chain is loaded.
      test_files[#test_files + 1] = "tests/test_aps_foundry"
      -- ci-8wu: the MINIMAL bootstrap kit (a stocked supply capsule) a Cindra
      -- start lands with; likewise only meaningful under the APS chain.
      test_files[#test_files + 1] = "tests/test_aps_kit"
      -- ci-7p6: the END-TO-END from-nothing bootstrap -- drives a start-on-Cindra
      -- run reaching a foundry + the lava->metal economy (and reproducing foundries)
      -- with no Vulcanus. The positive counterpart to test_bootstrap's from-zero
      -- stall; only meaningful under the APS kit + pre-research.
      test_files[#test_files + 1] = "tests/test_aps_bootstrap"
    else
      test_files[#test_files + 1] = "tests/test_aps_absent"
    end
  end
  require("__factorio-test__/init")(test_files, {
    load_luassert = true,
  })
end
