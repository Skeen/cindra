local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 2,["6"] = 2,["7"] = 8,["8"] = 9,["9"] = 8,["10"] = 12,["11"] = 13,["12"] = 12,["13"] = 16,["14"] = 17,["15"] = 17,["17"] = 18,["18"] = 19,["19"] = 16,["20"] = 22,["21"] = 22,["22"] = 22,["23"] = 22,["24"] = 24,["25"] = 25,["26"] = 26,["27"] = 24});
local ____exports = {}
local ____post_2Dload_2Daction = require("control.post-load-action")
local postLoadAction = ____post_2Dload_2Daction.postLoadAction
function ____exports.hasAutoStarted()
    return storage.__tests_autostarted == true
end
function ____exports.markAutoStarted()
    storage.__tests_autostarted = true
end
function ____exports.startTests(modToTest)
    if not remote.interfaces["factorio-test"] then
        return false
    end
    remote.call("factorio-test", "runTests", modToTest)
    return true
end
local triggerStartTests = postLoadAction(
    "startTests",
    function() return ____exports.startTests() end
)
function ____exports.reloadAndStartTests()
    game.reload_mods()
    triggerStartTests()
end
return ____exports
