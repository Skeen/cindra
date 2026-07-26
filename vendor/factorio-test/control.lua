local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 1,["6"] = 2,["7"] = 2,["8"] = 2,["9"] = 4,["10"] = 5,["11"] = 6});
local ____exports = {}
require("control.index")
local ____auto_2Dstart_2Dconfig = require("factorio-test.auto-start-config")
local isAutoStartEnabled = ____auto_2Dstart_2Dconfig.isAutoStartEnabled
local getAutoStartMod = ____auto_2Dstart_2Dconfig.getAutoStartMod
local shouldAutoStart = isAutoStartEnabled() and getAutoStartMod() == script.mod_name
if shouldAutoStart then
    require("__factorio-test__/init")({"test.meta.test", "test.reload.test"})
end
return ____exports
