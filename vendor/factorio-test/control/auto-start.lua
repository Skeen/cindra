local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 2,["6"] = 2,["7"] = 2,["8"] = 2,["9"] = 4,["10"] = 4,["11"] = 4,["12"] = 4,["13"] = 6,["14"] = 7,["17"] = 8,["20"] = 10,["21"] = 11,["22"] = 13,["23"] = 13,["24"] = 13,["25"] = 14,["26"] = 16,["27"] = 17,["28"] = 17,["30"] = 18,["31"] = 19,["32"] = 20,["33"] = 21,["34"] = 22,["35"] = 23,["36"] = 23,["38"] = 16,["39"] = 26,["40"] = 27,["42"] = 30,["43"] = 31,["45"] = 34,["46"] = 35,["47"] = 13,["48"] = 13,["49"] = 6});
local ____exports = {}
local ____auto_2Dstart_2Dconfig = require("factorio-test.auto-start-config")
local getAutoStartConfig = ____auto_2Dstart_2Dconfig.getAutoStartConfig
local isAutoStartEnabled = ____auto_2Dstart_2Dconfig.isAutoStartEnabled
local isHeadlessMode = ____auto_2Dstart_2Dconfig.isHeadlessMode
local ____start_2Dtests = require("control.start-tests")
local hasAutoStarted = ____start_2Dtests.hasAutoStarted
local markAutoStarted = ____start_2Dtests.markAutoStarted
local startTests = ____start_2Dtests.startTests
script.on_load(function()
    if not isAutoStartEnabled() then
        return
    end
    if hasAutoStarted() then
        return
    end
    local headless = isHeadlessMode()
    local modToTest = getAutoStartConfig().mod
    script.on_event(
        defines.events.on_tick,
        function()
            script.on_event(defines.events.on_tick, nil)
            local function autoStartError(message)
                if not headless then
                    game.print(message)
                end
                log(message)
                print("FACTORIO-TEST-MESSAGE-START")
                log(message)
                print("FACTORIO-TEST-MESSAGE-END")
                print("FACTORIO-TEST-RESULT:could not auto start")
                if headless then
                    error("FACTORIO-TEST-EXIT")
                end
            end
            if not (script.active_mods[modToTest] ~= nil) then
                return autoStartError(("Cannot auto-start tests: mod " .. modToTest) .. " is not active.")
            end
            if not remote.interfaces["factorio-test"] then
                return autoStartError("Cannot auto-start tests: the selected mod is not registered with Factorio Test.")
            end
            markAutoStarted()
            startTests(modToTest)
        end
    )
end)
return ____exports
