local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 5,["6"] = 6,["7"] = 7,["8"] = 8,["10"] = 10,["11"] = 11,["12"] = 6,["13"] = 14,["14"] = 15,["15"] = 16,["16"] = 17,["17"] = 17,["18"] = 17,["19"] = 18,["20"] = 19,["23"] = 20,["24"] = 21,["27"] = 22,["28"] = 23,["31"] = 24,["32"] = 17,["33"] = 17});
local ____exports = {}
local guiActions = {}
function ____exports.guiAction(name, func)
    if guiActions[name] ~= nil then
        error("Duplicate guiAction " .. name)
    end
    guiActions[name] = func
    return name
end
local modName = script.mod_name
local events = {"on_gui_click", "on_gui_selection_state_changed", "on_gui_text_changed"}
for ____, eventName in ipairs(events) do
    script.on_event(
        defines.events[eventName],
        function(e)
            local element = e.element
            if not element then
                return
            end
            local tags = element.tags
            if tags.modName ~= modName then
                return
            end
            local method = tags[eventName]
            if not method then
                return
            end
            guiActions[method](e)
        end
    )
end
return ____exports
