-- Power-diode control stage: wire the one-way transfer loop to the tick loop,
-- and run the factorio-test suite when the test mod is present.

local diode = require("scripts.diode")

diode.register()

script.on_init(function()
  diode.init()
end)
script.on_configuration_changed(function()
  diode.init()
end)

if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/test_power_diode",
  }, {
    load_luassert = true,
  })
end
