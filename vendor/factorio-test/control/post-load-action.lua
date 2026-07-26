local ____lualib = require("lualib_bundle")
local __TS__ArrayIsArray = ____lualib.__TS__ArrayIsArray
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["6"] = 6,["7"] = 7,["8"] = 8,["9"] = 9,["10"] = 10,["14"] = 12,["15"] = 7,["16"] = 15,["17"] = 16,["18"] = 17,["19"] = 17,["21"] = 18,["22"] = 19,["23"] = 20,["24"] = 19,["25"] = 16,["26"] = 24,["27"] = 24,["28"] = 24,["29"] = 25,["30"] = 26,["31"] = 27,["32"] = 28,["34"] = 28,["37"] = 24,["38"] = 24});
local ____exports = {}
local lsId = "factorio-test.fake-translation"
local function fireFakeTranslation(data)
    local ls = {lsId, data}
    for ____, player in ipairs(game.connected_players) do
        if player.request_translation(ls) then
            return
        end
    end
    error("No connected players found to raise fake translation event. Please report this to the mod author")
end
local loadEvents = {}
function ____exports.postLoadAction(name, func)
    if loadEvents[name] ~= nil then
        error("duplicate load event name " .. name)
    end
    loadEvents[name] = func
    return function()
        fireFakeTranslation(name)
    end
end
script.on_event(
    defines.events.on_string_translated,
    function(data)
        local ls = data.localised_string
        if __TS__ArrayIsArray(ls) and ls[1] == lsId then
            local action = ls[2]
            local ____opt_0 = loadEvents[action]
            if ____opt_0 ~= nil then
                ____opt_0()
            end
        end
    end
)
return ____exports
