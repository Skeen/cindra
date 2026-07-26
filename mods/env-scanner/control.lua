-- Environmental scanner control stage.
--
-- Tracks built scanners, refreshes their circuit output on a periodic tick, and
-- boots the factorio-test suite when the test mod is present. on_init /
-- on_configuration_changed / on_nth_tick are REPLACE-not-add, so they live here
-- and fan out to the scanner runtime.

local C = require("scripts.config")
local scanner = require("scripts.scanner")

local function on_built(event)
  local e = event.entity or event.destination
  scanner.register_entity(e)
end

local function on_removed(event)
  scanner.forget_entity(event.entity)
end

-- Build events: hand-placed, robot, script-raised, revived, and (if the engine
-- defines it) space-platform builds. Filtered to our entity so the handler only
-- fires for scanners.
local build_filter = { { filter = "name", name = C.SCANNER } }
script.on_event(defines.events.on_built_entity, on_built, build_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, build_filter)
script.on_event(defines.events.script_raised_built, on_built, build_filter)
script.on_event(defines.events.script_raised_revive, on_built, build_filter)
if defines.events.on_space_platform_built_entity then
  script.on_event(defines.events.on_space_platform_built_entity, on_built, build_filter)
end

script.on_event(defines.events.on_player_mined_entity, on_removed, build_filter)
script.on_event(defines.events.on_robot_mined_entity, on_removed, build_filter)
script.on_event(defines.events.on_entity_died, on_removed, build_filter)
script.on_event(defines.events.script_raised_destroy, on_removed, build_filter)
if defines.events.on_space_platform_mined_entity then
  script.on_event(defines.events.on_space_platform_mined_entity, on_removed, build_filter)
end

script.on_nth_tick(C.UPDATE_INTERVAL, function()
  scanner.update_all()
end)

script.on_init(scanner.init)
script.on_configuration_changed(scanner.init)

if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/test_scanner",
  }, {
    load_luassert = true,
  })
end
