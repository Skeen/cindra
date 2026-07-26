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

-- §15-11 mass-driver launch loop. Its own track: build/remove events + a distinct
-- fire tick (N=31), disjoint from the worldgen driver's handlers. Registered here
-- alongside the worldgen driver; the single on_init below fans out to both.
local mass_driver = require("scripts.mass-driver")
mass_driver.register()

local function on_init()
  driver.init()
  mass_driver.init()
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
    "tests/test_cryo_alloy",
    "tests/test_edge_damage",
    "tests/test_worldgen",
    "tests/test_building_heat",
    "tests/test_mass_driver",
    "tests/test_space_appearance",
    -- Power system (§15 items 7-9), integrated from the flare-poc (ci-zg3):
    -- flare cycle, disposal-deficit panel damage, storage + dissipator sinks.
    "tests/test_flare",
    "tests/test_panel_damage",
    "tests/test_panel_solar",
    "tests/test_disposal",
    "tests/test_storage",
    "tests/test_catchability",
    "tests/test_power_prototypes",
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
    else
      test_files[#test_files + 1] = "tests/test_aps_absent"
    end
  end
  require("__factorio-test__/init")(test_files, {
    load_luassert = true,
  })
end
