local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["4"] = 3,["5"] = 3,["6"] = 5,["7"] = 7,["8"] = 13,["9"] = 14,["10"] = 14,["11"] = 14,["13"] = 14,["15"] = 14,["16"] = 15,["17"] = 16,["19"] = 18,["20"] = 19,["21"] = 20,["22"] = 21,["23"] = 22,["24"] = 23,["26"] = 7,["27"] = 27});
local ____auto_2Dstart_2Dconfig = require("factorio-test.auto-start-config")
local getAutoStartMod = ____auto_2Dstart_2Dconfig.getAutoStartMod
local initCalled = false
local function init(a, b, c)
    local files = a or b or error("Files must be specified")
    local ____a_0
    if a then
        ____a_0 = b
    else
        ____a_0 = c
    end
    local config = ____a_0 or ({})
    if initCalled then
        error("Duplicate call to test init")
    end
    initCalled = true
    remote.add_interface("factorio-test-tests-available-for-" .. script.mod_name, {})
    local autoStartMod = getAutoStartMod()
    local manualMod = settings.global["factorio-test-mod-to-test"].value
    if script.mod_name == autoStartMod or script.mod_name == manualMod then
        require("__factorio-test__._factorio-test")(files, config)
    end
end
local ____exports = init
return ____exports
