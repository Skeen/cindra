local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 6,["6"] = 7,["7"] = 7,["8"] = 7,["9"] = 7,["10"] = 7,["11"] = 6,["12"] = 16,["13"] = 16,["14"] = 16,["15"] = 16,["16"] = 16,["17"] = 16,["18"] = 16,["19"] = 16,["20"] = 16,["21"] = 16,["22"] = 27,["23"] = 28,["24"] = 28,["25"] = 28,["26"] = 28,["27"] = 28,["28"] = 27});
local ____exports = {}
data:extend({{
    type = "sprite",
    name = "factorio-test-test-tube-sprite",
    filename = "__factorio-test__/graphics/test-tube.png",
    priority = "extra-high-no-scale",
    size = 48
}})
data.raw["gui-style"].default["factorio-test-test-output-box-style"] = {
    type = "textbox_style",
    minimal_width = 0,
    natural_width = 1000,
    maximal_width = 1000,
    horizontally_stretchable = "on",
    default_background = {},
    font_color = {1, 1, 1},
    font = "factorio-test-mono"
}
data:extend({{
    type = "font",
    name = "factorio-test-mono",
    from = "default-mono",
    size = 14,
    spacing = -0.5
}})
return ____exports
