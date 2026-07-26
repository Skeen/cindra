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
script.on_init(driver.init)
script.on_configuration_changed(driver.init)

-- The factorio-test bootstrap below runs the integration suite when the
-- factorio-test mod is present. Keep the test list in sync with tests/.

if script.active_mods["factorio-test"] then
  local test_files = {
    "tests/test_example",
    "tests/test_planet",
    "tests/test_ribbon",
    "tests/test_heater",
    "tests/test_lava",
    "tests/test_edge_damage",
    "tests/test_worldgen",
    "tests/test_building_heat",
  }
  -- The APS-start suite asserts prototype/setting state that only exists when
  -- the companion mods are loaded (any-planet-start + cindra-start +
  -- cindra-dev-default, picker defaulting to Cindra). That mod set rewrites
  -- Cindra's discovery tech, so it is NOT enabled in the default `mods/cindra`
  -- run; the suite is registered only when cindra-start is actually present.
  if script.active_mods["cindra-start"] then
    test_files[#test_files + 1] = "tests/test_aps_start"
  end
  require("__factorio-test__/init")(test_files, {
    load_luassert = true,
  })
end
