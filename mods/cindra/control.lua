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
    -- ci-7k6 NO DEAD KNOBS: every mod setting a player can move is proven to reach
    -- the world (bounded axis / burn on a hazard tile / band + world width), plus
    -- the coverage guard that fails when a new setting ships with no effect.
    "tests/test_settings_live",
    "tests/test_heater",
    "tests/test_ice_processing",
    "tests/test_lava",
    -- ci-8vu: the fire-edge lava is scenery + hazard, NEVER a tap -- an offshore
    -- pump aimed at it draws nothing (lava is manufactured from stone, never found).
    "tests/test_lava_tap",
    "tests/test_sulfur", -- ci-eat: stone -> roast -> sulfur -> sulfuric acid
    "tests/test_aluminium",
    -- ci-r7w4: the "reach Cindra first" gate as a player-observable REACHABILITY
    -- sweep (drive a fresh force through the whole tech tree, then look at what it
    -- can craft), stated so it holds in BOTH worlds: normal play, where the
    -- discovery tech gates the signature chain, and an APS Cindra start, which
    -- retires that tech on purpose and must strand nothing behind it.
    "tests/test_discovery_gate",
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
    -- ci-nw0: the ambient thermal grade -- a subtle screen hue wash driven by the
    -- player's POSITION on the temperature axis (neutral in the temperate band,
    -- deepening warm/cool toward each extreme), cosmetic and independent of damage.
    "tests/test_feedback",
    "tests/test_worldgen",
    -- ci-65p: the ribbon is bounded ACROSS its hot-cold axis only and runs forever
    -- along its long axis, with the fire on the sunward side, in EITHER orientation.
    "tests/test_orientation",
    -- ci-i4z: the ribbon GEOMETRY sliders on the new-game map-gen screen (playable
    -- width + hot/cold zone depths). Generates surfaces with a slider moved and
    -- measures the ground a player would walk: wider safe band, relocated lethal
    -- belts, same map size, oceans still walling both edges.
    "tests/test_worldgen_sliders",
    -- ci-y19: the STONE / ICE resource sliders on the same screen. Generates surfaces
    -- with one slider moved and counts the ore actually in the ground: Richness puts
    -- more ore in the same patches, Size fattens them, Frequency scatters more of
    -- them, Size 0 removes the ore entirely and leaves the other resource untouched,
    -- and no setting pushes a field out of its band. Found ci-l3k3 + ci-bgpm.
    "tests/test_worldgen_resource_sliders",
    -- ci-bgpm: no harvestable field ever lies on ground that damages you, at ANY
    -- map-gen slider setting. Generates the world with every Stone/Ice slider maxed
    -- (where the leak shows) and reads the tile under every single ore tile.
    "tests/test_worldgen_field_ground",
    -- ci-pxlz: the hand-mined bootstrap rocks stand on ground that does not damage
    -- you. Reads the real footprint-damage decision under every rock that generated
    -- on a tall fixed-seed strip, plus a no-retreat guard (the cold scatter must
    -- still reach the icy edge) and a LIVE coverage sweep over every Cindra scatter
    -- family, so a new rock cannot ship without the invariant.
    "tests/test_worldgen_rock_ground",
    -- ci-oe83: the ONE-heightmap merge gate -- emergent oceans, belt-confined damage,
    -- no walk-to-ocean corridor, no enclosure (drives the real sweep as the oracle).
    "tests/test_heightmap",
    "tests/test_decoratives",
    -- ci-mk5y: the icy-side SNOWFALL -- snow falls on the frozen half of the ribbon and
    -- NOWHERE else (not on the habitable band, not on the hot side, not on other planets),
    -- and it actually falls.
    "tests/test_snowfall",
    -- § freeze (ci-bvk): NATIVE freeze via the entities_require_heating flag + the
    -- worldgen lava-heat emitter line. Replaces the retired scripted building-heat
    -- cold-damage model: measured reach/seam vs the real emitter, warm-band thawed /
    -- nightward frozen, both orientations, ci-f5l heater extends the warm pocket, no
    -- other-planet mutation.
    "tests/test_freeze",
    -- ci-u92y: the claim the frost-layer art + the data-stage frost audit rest on
    -- -- EVERY Cindra crafting machine really freezes in the cold (so it needs a
    -- frost layer) and thaws beside heat (so the sheen is never always-on). The
    -- class is enumerated live, so a new machine is measured without being listed.
    "tests/test_frost",
    "tests/test_mass_driver",
    "tests/test_space_appearance",
    -- ci-810e: PlanetsLib interop guards. Cindra declares only an OPTIONAL
    -- `? PlanetsLib` (ci-dza6, load order only), so the library may or may not be
    -- there; either way its data-final-fixes imposes hard preconditions on every
    -- planet -- including a gas-percentage assert that REFUSES TO LOAD the game.
    -- Pinned from our own side, in every config.
    "tests/test_planetslib_compat",
    -- ci-ndm9: every Cindra building is placeable on Cindra and every Cindra recipe
    -- craftable there -- the coverage guard over surface conditions, which a clone
    -- of a vanilla prototype inherits silently. Enumerated live, so a new machine
    -- is checked without being listed. (The helpers that edit those conditions,
    -- and their PlanetsLib delegation, live in scripts/surface-conditions.lua.)
    "tests/test_surface_conditions",
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
    -- ci-m96z MOD-WIDE POWER POLICY: the player-observable conservation invariants
    -- (nothing mints energy, a dead/unplugged source delivers nothing, the sun is
    -- the only generation) plus the coverage guard that fails when a new Cindra
    -- power entity ships without one.
    "tests/test_power_conservation",
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
  -- cindra-start, so cindra-start can be active WITH or WITHOUT APS -- and when
  -- it IS installed, the player still has to CHOOSE Cindra in APS's picker.
  -- Installed and chosen are different worlds (ci-e9sj: keying on the mod alone
  -- made 14 tests assert a Cindra start that was not happening), so there are
  -- THREE variants and exactly one registers:
  --   * NO APS            -> test_aps_absent: the companion mods load clean and
  --     register NOTHING (the guarded APS calls were skipped, no error).
  --   * APS + Cindra CHOSEN -> the full start chain (registration took effect AND
  --     the start-only guarantees: pre-research, kit, end-to-end bootstrap). That
  --     set rewrites Cindra's discovery tech, so it is never in the default run.
  --   * APS + ANOTHER start -> test_aps_offered: Cindra is on the menu but was not
  --     picked, so APS changed nothing. Only the registration half is meaningful;
  --     the start-only guarantees must specifically NOT have fired.
  -- The default run enables neither companion mod, so none of them register.
  --
  -- The predicate is the SAME one cindra-start/control.lua gates its pre-research
  -- on (helpers.aps_cindra_start -> settings.startup["aps-planet"].value), so the
  -- suite selection can never disagree with the mod's own behaviour.
  if script.active_mods["cindra-start"] then
    local H = require("tests.helpers")
    if not H.aps_loaded() then
      test_files[#test_files + 1] = "tests/test_aps_absent"
    elseif H.aps_cindra_start() then
      test_files[#test_files + 1] = "tests/test_aps_start"
      -- ci-arw: the pre-researched foundry path is a Cindra-start guarantee, so
      -- it is only meaningful (and only asserted) when Cindra is the chosen start.
      test_files[#test_files + 1] = "tests/test_aps_foundry"
      -- ci-8wu: the MINIMAL bootstrap kit a Cindra start lands with, stocked
      -- into the crash-site spaceship itself since ci-q6nh (no chest capsule);
      -- likewise only meaningful when Cindra is the chosen start.
      test_files[#test_files + 1] = "tests/test_aps_kit"
      -- ci-7p6: the END-TO-END from-nothing bootstrap -- drives a start-on-Cindra
      -- run reaching a foundry + the lava->metal economy (and reproducing foundries)
      -- with no Vulcanus. The positive counterpart to test_bootstrap's from-zero
      -- stall; only meaningful under the APS kit + pre-research.
      test_files[#test_files + 1] = "tests/test_aps_bootstrap"
    else
      -- ci-e9sj: APS loaded, Cindra offered, some other planet started.
      test_files[#test_files + 1] = "tests/test_aps_offered"
    end
  end
  -- The two halves of the PlanetsLib story, split on whether the player actually
  -- installed it. `? PlanetsLib` is OPTIONAL (ci-dza6), so both are real mod sets:
  --   * WITH PlanetsLib    -> test_planetslib_coload (ci-gg3x, stage 1): the library
  --     ran, and Cindra did not move on the star map. Not vendored and not in the
  --     flake, so the default run never reaches it (README "PlanetsLib co-load").
  --   * WITHOUT PlanetsLib -> test_planetslib_absent (ci-dza6, stage 3): Cindra
  --     loads and plays anyway, and none of the library's global mutations reach a
  --     player who never installed it. This is the default run.
  -- tests/test_planetslib_compat runs in EITHER config and guards the same edges
  -- from our own side.
  if script.active_mods["PlanetsLib"] then
    test_files[#test_files + 1] = "tests/test_planetslib_coload"
  else
    test_files[#test_files + 1] = "tests/test_planetslib_absent"
  end
  -- ci-vjc: the HORIZONTAL (E-W) ribbon. The orientation is a STARTUP setting baked
  -- into the tile probability expressions and the resource band masks at the DATA
  -- stage, so one engine run generates exactly one orientation -- no runtime override
  -- can rotate a world that already generated vertical. A horizontal world therefore
  -- needs its OWN run (`npm run test:integration:horizontal`, which flips the setting
  -- default via mods/cindra-dev-horizontal), and that run swaps the suite:
  --   * tests/test_worldgen_horizontal states, in RAW x/y, where the rotated world
  --     puts fire, ice, resources and lethal ground -- the end-to-end proof the
  --     ci-d7x audit found missing (the maths was covered, the world never was).
  --   * tests/test_orientation is orientation-agnostic (every position read through
  --     scripts/axis.lua), so re-running it rotated is a second, independent pass.
  -- The REST of the suite is written against the default vertical layout in hard-coded
  -- x bands (tests/test_worldgen and friends), so it is deliberately NOT re-run
  -- rotated: it would fail on geometry it never claimed to describe.
  if require("scripts.axis").orientation() == "horizontal" then
    test_files = {
      "tests/test_orientation",
      "tests/test_worldgen_horizontal",
    }
  end
  require("__factorio-test__/init")(test_files, {
    load_luassert = true,
  })
end
