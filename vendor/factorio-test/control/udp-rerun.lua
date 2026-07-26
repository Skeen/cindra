local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 1,["6"] = 1,["7"] = 2,["8"] = 2,["9"] = 4,["10"] = 5,["11"] = 5,["12"] = 5,["13"] = 5,["14"] = 6,["15"] = 6,["16"] = 6,["17"] = 7,["20"] = 8,["21"] = 6,["22"] = 6});
local ____exports = {}
local ____auto_2Dstart_2Dconfig = require("factorio-test.auto-start-config")
local isHeadlessMode = ____auto_2Dstart_2Dconfig.isHeadlessMode
local ____start_2Dtests = require("control.start-tests")
local reloadAndStartTests = ____start_2Dtests.reloadAndStartTests
if not isHeadlessMode() then
    script.on_nth_tick(
        1,
        function() return helpers.recv_udp() end
    )
    script.on_event(
        defines.events.on_udp_packet_received,
        function(event)
            if event.payload ~= "rerun" then
                return
            end
            reloadAndStartTests()
        end
    )
end
return ____exports
