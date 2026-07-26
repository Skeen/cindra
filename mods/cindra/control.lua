-- Cindra control-stage entry point.
--
-- v1 foundation (§15 item 1): the runtime surface exists; the ribbon temperature
-- axis (scripts/ribbon.lua) is a pure module ready for the systems that consume
-- it. No world-mutating handlers are registered yet — the lethal-edge damage
-- sweep (§15-2), flare driver (§15-7), etc. attach here as they land.
--
-- Reminders for when that work starts (mirrors the inspiration AGENTS.md):
--   * NEVER mutate global state that affects other planets. Gate every runtime
--     handler on `surface.name == "cindra"` (or scope by electric_network_id /
--     per-surface runtime APIs). This mod adds Cindra; it MUST NOT change any
--     other planet's gameplay.
--   * `script.on_nth_tick(N, fn)` is REPLACE-not-add: one handler per N. Give
--     each periodic system (edge-damage sweep, flare ramp, ...) a distinct N.
--
-- The factorio-test bootstrap below runs the integration suite when the
-- factorio-test mod is present. Keep the test list in sync with tests/.

if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/test_example",
    "tests/test_planet",
    "tests/test_ribbon",
  }, {
    load_luassert = true,
  })
end
