-- Flare PoC control-stage entry point.
--
-- Wires the flare cycle + panel-damage sweep to the tick loop and boots the
-- integration suite. Every handler is gated on `surface.name == C.SURFACE`, so
-- the mod is inert on nauvis and every real planet.

local driver = require("scripts.driver")

driver.register()

-- on_init / on_configuration_changed are REPLACE-not-add, so they live here and
-- fan out to the driver's init.
script.on_init(driver.init)
script.on_configuration_changed(driver.init)

if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/test_flare_cycle",
    "tests/test_panel_damage",
    "tests/test_disposal",
    "tests/test_storage",
    "tests/test_catchability",
  }, {
    load_luassert = true,
  })
end
