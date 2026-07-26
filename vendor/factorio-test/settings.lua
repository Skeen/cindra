local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 6,["6"] = 7,["7"] = 7,["8"] = 7,["9"] = 7,["10"] = 7,["11"] = 7,["12"] = 6,["13"] = 15,["14"] = 15,["15"] = 15,["16"] = 15,["17"] = 15,["18"] = 15,["19"] = 15,["20"] = 6,["21"] = 24,["22"] = 24,["23"] = 24,["24"] = 24,["25"] = 24,["26"] = 24,["27"] = 24,["28"] = 6,["29"] = 33,["30"] = 33,["31"] = 33,["32"] = 33,["33"] = 33,["34"] = 33,["35"] = 6});
local ____exports = {}
data:extend({{
    type = "string-setting",
    setting_type = "runtime-global",
    name = "factorio-test-mod-to-test",
    default_value = "",
    allow_blank = true,
    order = "a"
}, {
    type = "string-setting",
    setting_type = "startup",
    name = "factorio-test-auto-start-config",
    default_value = "{}",
    allow_blank = true,
    hidden = true,
    order = "a1"
}, {
    type = "string-setting",
    setting_type = "runtime-global",
    name = "factorio-test-config",
    default_value = "{}",
    allow_blank = true,
    hidden = true,
    order = "c"
}, {
    type = "bool-setting",
    setting_type = "startup",
    name = "factorio-test-auto-start",
    default_value = false,
    hidden = true,
    order = "z"
}})
return ____exports
