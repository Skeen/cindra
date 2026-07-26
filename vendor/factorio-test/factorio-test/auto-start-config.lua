local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 9,["6"] = 11,["7"] = 12,["8"] = 12,["10"] = 13,["11"] = 13,["12"] = 14,["13"] = 15,["14"] = 16,["16"] = 18,["17"] = 19,["18"] = 11,["19"] = 22,["20"] = 23,["21"] = 22,["22"] = 26,["23"] = 27,["24"] = 28,["25"] = 26,["26"] = 31,["27"] = 32,["28"] = 31});
local ____exports = {}
local cachedConfig
function ____exports.getAutoStartConfig()
    if cachedConfig then
        return cachedConfig
    end
    local ____opt_0 = settings.startup["factorio-test-auto-start-config"]
    local json = ____opt_0 and ____opt_0.value
    if not json or json == "{}" then
        cachedConfig = {}
        return cachedConfig
    end
    cachedConfig = helpers.json_to_table(json)
    return cachedConfig
end
function ____exports.isHeadlessMode()
    return ____exports.getAutoStartConfig().headless == true
end
function ____exports.isAutoStartEnabled()
    local config = ____exports.getAutoStartConfig()
    return config.mod ~= nil and config.mod ~= ""
end
function ____exports.getAutoStartMod()
    return ____exports.getAutoStartConfig().mod
end
return ____exports
