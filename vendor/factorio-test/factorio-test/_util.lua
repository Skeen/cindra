local ____lualib = require("lualib_bundle")
local __TS__StringSplit = ____lualib.__TS__StringSplit
local __TS__StringEndsWith = ____lualib.__TS__StringEndsWith
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["7"] = 10,["8"] = 10,["9"] = 12,["10"] = 12,["11"] = 12,["12"] = 12,["13"] = 14,["15"] = 15,["16"] = 15,["17"] = 15,["18"] = 16,["19"] = 17,["20"] = 17,["22"] = 18,["24"] = 15,["27"] = 21,["29"] = 1,["30"] = 6,["31"] = 7,["32"] = 1,["33"] = 26,["34"] = 27,["35"] = 26,["36"] = 30,["37"] = 31,["38"] = 32,["39"] = 31});
local ____exports = {}
local getErrorWithStacktrace
function getErrorWithStacktrace(____error)
    local stacktrace = debug.traceback(
        tostring(____error),
        3
    )
    local lines = __TS__StringSplit(stacktrace, "\n")
    do
        local i = 1
        local l = #lines
        while i <= l do
            if __TS__StringEndsWith(lines[i], ": in function '__factorio_test__pcallWithStacktrace'") then
                if lines[i - 3 + 1] == "\t[C]: in function 'rawxpcall'" then
                    i = i - 1
                end
                return table.concat(lines, "\n", 1, i - 2)
            end
            i = i + 1
        end
    end
    return stacktrace
end
function ____exports.__factorio_test__pcallWithStacktrace(fn, ...)
    local success, result = xpcall(fn, getErrorWithStacktrace, ...)
    return success, result
end
function ____exports.getPlayer()
    return game.players[1] or error("No player found")
end
____exports.debugAdapterEnabled = script.active_mods.debugadapter ~= nil
function ____exports.assertNever(value)
    return error(("value " .. tostring(value)) .. " should be never")
end
return ____exports
