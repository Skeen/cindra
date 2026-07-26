local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 2,["6"] = 2,["7"] = 3,["8"] = 3,["9"] = 5,["10"] = 5,["11"] = 5,["12"] = 6,["13"] = 7,["14"] = 8,["16"] = 10,["18"] = 10,["20"] = 5,["21"] = 5,["22"] = 13,["23"] = 13,["24"] = 13,["25"] = 14,["26"] = 15,["28"] = 13,["29"] = 13});
local ____exports = {}
local _____util = require("factorio-test._util")
local getPlayer = _____util.getPlayer
local ____guiAction = require("control.guiAction")
local guiAction = ____guiAction.guiAction
guiAction(
    "close-test-gui",
    function()
        if remote.interfaces["factorio-test"] then
            remote.call("factorio-test", "cancelTestRun")
            remote.call("factorio-test", "fireCustomEvent", "closeProgressGui")
        end
        local ____opt_0 = getPlayer().gui.screen["factorio-test-test-gui"]
        if ____opt_0 ~= nil then
            ____opt_0.destroy()
        end
    end
)
guiAction(
    "cancel-test-run",
    function()
        if remote.interfaces["factorio-test"] then
            remote.call("factorio-test", "cancelTestRun")
        end
    end
)
return ____exports
