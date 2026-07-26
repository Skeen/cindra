-- Mass-driver control stage: wire the launch loop to the tick loop, and run
-- the factorio-test suite when the test mod is present.

local launch = require("scripts.launch")

launch.register()

script.on_init(function()
  launch.init()
end)
script.on_configuration_changed(function()
  launch.init()
end)

if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/test_mass_driver",
  }, {
    load_luassert = true,
  })
end
