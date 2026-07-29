-- Cindra control-stage entry point.
--
-- v1 foundation (§15 item 1) established the runtime surface + the pure ribbon
-- temperature axis (scripts/ribbon.lua). The WORLDGEN track (§15 items 2-3) now
-- attaches its runtime here via scripts/driver.lua: the lethal-edge damage sweep,
-- the nightside building-heat freeze, and per-chunk world generation (hard-wall
-- backstop + resource placement). Later tracks (flare §15-7, etc.) register their
-- own runtime; keep each track's handlers disjoint.
--
-- Invariants (mirrors AGENTS.md / DESIGN.md):
--   * NEVER mutate global state that affects other planets. Every runtime handler
--     is gated on `surface.name == "cindra"`. This mod adds Cindra; it MUST NOT
--     change any other planet's gameplay.
--   * `script.on_nth_tick(N, fn)` is REPLACE-not-add: one handler per N. Each
--     periodic system (edge-damage, building-heat, ...) uses a distinct N; the
--     single on_init lives here.

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

-- One-way power transfer PoC (ci-gcd): the "power diode". Registered on its OWN
-- distinct nth-tick (7), disjoint from the driver's periodic systems, because it
-- is an isolated feasibility spike -- it moves buffered power A->B between the
-- two poles of a placed diode and touches nothing else. A cheap no-op on any
-- surface where no diode is placed.
local diode = require("scripts.diode")
diode.register()

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
    "tests/test_aluminium",
    "tests/test_tile_damage",
    "tests/test_worldgen",
    "tests/test_decoratives",
    "tests/test_building_heat",
    "tests/test_mass_driver",
    "tests/test_space_appearance",
    -- Power system (§15 items 7-9), integrated from the flare-poc (ci-zg3):
    -- flare cycle, disposal-deficit panel damage, storage + dissipator sinks.
    "tests/test_flare",
    "tests/test_panel_damage",
    "tests/test_panel_damage_runtime",
    "tests/test_panel_solar",
    "tests/test_disposal",
    "tests/test_storage",
    "tests/test_catchability",
    "tests/test_power_prototypes",
    -- ci-ezk: ABSOLUTE solar output magnitudes (baseline ~400 kW > Vulcanus,
    -- flare peak in the MW range, dim sky does not suppress production).
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
    else
      test_files[#test_files + 1] = "tests/test_aps_absent"
    end
  end
  require("__factorio-test__/init")(test_files, {
    load_luassert = true,
  })
end
