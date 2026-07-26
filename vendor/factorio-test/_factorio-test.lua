--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]

local ____modules = {}
local ____moduleCache = {}
local ____originalRequire = require
local function require(file, ...)
    if ____moduleCache[file] then
        return ____moduleCache[file].value
    end
    if ____modules[file] then
        local module = ____modules[file]
        local value = nil
        if (select("#", ...) > 0) then value = module(...) else value = module(file) end
        ____moduleCache[file] = { value = value }
        return value
    else
        if ____originalRequire then
            return ____originalRequire(file)
        else
            error("module '" .. file .. "' not found")
        end
    end
end
____modules = {
["lualib_bundle"] = function(...) 
local __TS__StringSplit
do
    local sub = string.sub
    local find = string.find
    function __TS__StringSplit(source, separator, limit)
        if limit == nil then
            limit = 4294967295
        end
        if limit == 0 then
            return {}
        end
        local result = {}
        local resultIndex = 1
        if separator == nil or separator == "" then
            for i = 1, #source do
                result[resultIndex] = sub(source, i, i)
                resultIndex = resultIndex + 1
            end
        else
            local currentPos = 1
            while resultIndex <= limit do
                local startPos, endPos = find(source, separator, currentPos, true)
                if not startPos then
                    break
                end
                result[resultIndex] = sub(source, currentPos, startPos - 1)
                resultIndex = resultIndex + 1
                currentPos = endPos + 1
            end
            if resultIndex <= limit then
                result[resultIndex] = sub(source, currentPos)
            end
        end
        return result
    end
end

local function __TS__StringEndsWith(self, searchString, endPosition)
    if endPosition == nil or endPosition > #self then
        endPosition = #self
    end
    return string.sub(self, endPosition - #searchString + 1, endPosition) == searchString
end

local function __TS__ArrayJoin(self, separator)
    if separator == nil then
        separator = ","
    end
    local parts = {}
    for i = 1, #self do
        parts[i] = tostring(self[i])
    end
    return table.concat(parts, separator)
end

local function __TS__StringStartsWith(self, searchString, position)
    if position == nil or position < 0 then
        position = 0
    end
    return string.sub(self, position + 1, #searchString + position) == searchString
end

local function __TS__ObjectAssign(target, ...)
    local sources = {...}
    for i = 1, #sources do
        local source = sources[i]
        for key in pairs(source) do
            target[key] = source[key]
        end
    end
    return target
end

local function __TS__ArrayMap(self, callbackfn, thisArg)
    local result = {}
    for i = 1, #self do
        result[i] = callbackfn(thisArg, self[i], i - 1, self)
    end
    return result
end

local function __TS__ArrayEvery(self, callbackfn, thisArg)
    for i = 1, #self do
        if not callbackfn(thisArg, self[i], i - 1, self) then
            return false
        end
    end
    return true
end

local function __TS__ArraySetLength(self, length)
    if length < 0 or length ~= length or length == math.huge or math.floor(length) ~= length then
        error(
            "invalid array length: " .. tostring(length),
            0
        )
    end
    for i = length + 1, #self do
        self[i] = nil
    end
    return length
end

local function __TS__ArrayPushArray(self, items)
    local len = #self
    for i = 1, #items do
        len = len + 1
        self[len] = items[i]
    end
    return len
end

local function __TS__New(target, ...)
    local instance = setmetatable({}, target.prototype)
    instance:____constructor(...)
    return instance
end

local function __TS__Class(self)
    local c = {prototype = {}}
    c.prototype.__index = c.prototype
    c.prototype.constructor = c
    return c
end

local function __TS__CountVarargs(...)
    return select("#", ...)
end

local function __TS__SparseArrayNew(...)
    local sparseArray = {...}
    sparseArray.sparseLength = __TS__CountVarargs(...)
    return sparseArray
end

local function __TS__SparseArrayPush(sparseArray, ...)
    local args = {...}
    local argsLen = __TS__CountVarargs(...)
    local listLen = sparseArray.sparseLength
    for i = 1, argsLen do
        sparseArray[listLen + i] = args[i]
    end
    sparseArray.sparseLength = listLen + argsLen
end

local function __TS__SparseArraySpread(sparseArray)
    local _unpack = unpack or table.unpack
    return _unpack(sparseArray, 1, sparseArray.sparseLength)
end

local function __TS__ArrayFilter(self, callbackfn, thisArg)
    local result = {}
    local len = 0
    for i = 1, #self do
        if callbackfn(thisArg, self[i], i - 1, self) then
            len = len + 1
            result[len] = self[i]
        end
    end
    return result
end

local function __TS__ArrayIndexOf(self, searchElement, fromIndex)
    if fromIndex == nil then
        fromIndex = 0
    end
    local len = #self
    if len == 0 then
        return -1
    end
    if fromIndex >= len then
        return -1
    end
    if fromIndex < 0 then
        fromIndex = len + fromIndex
        if fromIndex < 0 then
            fromIndex = 0
        end
    end
    for i = fromIndex + 1, len do
        if self[i] == searchElement then
            return i - 1
        end
    end
    return -1
end

local function __TS__ObjectKeys(obj)
    local result = {}
    local len = 0
    for key in pairs(obj) do
        len = len + 1
        result[len] = key
    end
    return result
end

local function __TS__ArraySome(self, callbackfn, thisArg)
    for i = 1, #self do
        if callbackfn(thisArg, self[i], i - 1, self) then
            return true
        end
    end
    return false
end

local function __TS__ArrayReduce(self, callbackFn, ...)
    local len = #self
    local k = 0
    local accumulator = nil
    if __TS__CountVarargs(...) ~= 0 then
        accumulator = ...
    elseif len > 0 then
        accumulator = self[1]
        k = 1
    else
        error("Reduce of empty array with no initial value", 0)
    end
    for i = k + 1, len do
        accumulator = callbackFn(
            nil,
            accumulator,
            self[i],
            i - 1,
            self
        )
    end
    return accumulator
end

local function __TS__StringIncludes(self, searchString, position)
    if not position then
        position = 1
    else
        position = position + 1
    end
    local index = string.find(self, searchString, position, true)
    return index ~= nil
end

local function __TS__ArrayIsArray(value)
    return type(value) == "table" and (value[1] ~= nil or next(value) == nil)
end

local function __TS__ArrayForEach(self, callbackFn, thisArg)
    for i = 1, #self do
        callbackFn(thisArg, self[i], i - 1, self)
    end
end

return {
  __TS__StringSplit = __TS__StringSplit,
  __TS__StringEndsWith = __TS__StringEndsWith,
  __TS__ArrayJoin = __TS__ArrayJoin,
  __TS__StringStartsWith = __TS__StringStartsWith,
  __TS__ObjectAssign = __TS__ObjectAssign,
  __TS__ArrayMap = __TS__ArrayMap,
  __TS__ArrayEvery = __TS__ArrayEvery,
  __TS__ArraySetLength = __TS__ArraySetLength,
  __TS__ArrayPushArray = __TS__ArrayPushArray,
  __TS__New = __TS__New,
  __TS__Class = __TS__Class,
  __TS__SparseArrayNew = __TS__SparseArrayNew,
  __TS__SparseArrayPush = __TS__SparseArrayPush,
  __TS__SparseArraySpread = __TS__SparseArraySpread,
  __TS__ArrayFilter = __TS__ArrayFilter,
  __TS__ArrayIndexOf = __TS__ArrayIndexOf,
  __TS__ObjectKeys = __TS__ObjectKeys,
  __TS__ArraySome = __TS__ArraySome,
  __TS__ArrayReduce = __TS__ArrayReduce,
  __TS__StringIncludes = __TS__StringIncludes,
  __TS__ArrayIsArray = __TS__ArrayIsArray,
  __TS__ArrayForEach = __TS__ArrayForEach
}
 end,
["_util"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__StringSplit = ____lualib.__TS__StringSplit
local __TS__StringEndsWith = ____lualib.__TS__StringEndsWith
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
 end,
["auto-start-config"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
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
 end,
["results"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
function ____exports.createEmptyRunResults()
    return {
        failed = 0,
        passed = 0,
        ran = 0,
        skipped = 0,
        todo = 0,
        cancelled = 0,
        describeBlockErrors = 0
    }
end
____exports.resultCollector = function(event, state)
    if event.type == "testRunStarted" then
        state.results = ____exports.createEmptyRunResults()
        return
    end
    local results = state.results
    repeat
        local ____switch5 = event.type
        local ____cond5 = ____switch5 == "testPassed"
        if ____cond5 then
            do
                results.ran = results.ran + 1
                results.passed = results.passed + 1
                break
            end
        end
        ____cond5 = ____cond5 or ____switch5 == "testFailed"
        if ____cond5 then
            do
                results.ran = results.ran + 1
                results.failed = results.failed + 1
                break
            end
        end
        ____cond5 = ____cond5 or ____switch5 == "testSkipped"
        if ____cond5 then
            do
                results.skipped = results.skipped + 1
                break
            end
        end
        ____cond5 = ____cond5 or ____switch5 == "testTodo"
        if ____cond5 then
            do
                results.todo = results.todo + 1
                break
            end
        end
        ____cond5 = ____cond5 or ____switch5 == "describeBlockFailed"
        if ____cond5 then
            do
                results.describeBlockErrors = results.describeBlockErrors + #event.block.errors
                break
            end
        end
        ____cond5 = ____cond5 or ____switch5 == "testRunFinished"
        if ____cond5 then
            if results.failed ~= 0 or results.describeBlockErrors ~= 0 then
                results.status = "failed"
            elseif results.todo ~= 0 then
                results.status = "todo"
            else
                results.status = "passed"
            end
            break
        end
        ____cond5 = ____cond5 or ____switch5 == "testRunCancelled"
        if ____cond5 then
            results.status = "cancelled"
            break
        end
    until true
end
return ____exports
 end,
["tests"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local collectHooksRecursive
local _____util = require("_util")
local assertNever = _____util.assertNever
function collectHooksRecursive(block, ____type, order, hooks)
    if order == "ancestors-first" and block.parent then
        collectHooksRecursive(block.parent, ____type, order, hooks)
    end
    for ____, hook in ipairs(block.hooks) do
        if hook.type == ____type then
            hooks[#hooks + 1] = hook.func
        end
    end
    if order == "descendants-first" and block.parent then
        collectHooksRecursive(block.parent, ____type, order, hooks)
    end
end
function ____exports.formatSource(source)
    if not source.file then
        return "<unknown source>"
    end
    return (source.file .. ":") .. tostring(source.line or 1)
end
local function tryUseSourcemap(rawFile, line)
    if not rawFile or not line or not __TS__sourcemap then
        return nil
    end
    local fileName = string.match(rawFile, "@?(%S+)%.lua")
    if not fileName then
        return nil
    end
    local fileSourceMap = __TS__sourcemap[fileName .. ".lua"]
    if not fileSourceMap then
        return nil
    end
    local data = fileSourceMap[tostring(line)]
    if not data then
        return nil
    end
    return type(data) == "number" and ({file = fileName .. ".ts", line = data}) or data
end
function ____exports.createSource(file, line)
    return tryUseSourcemap(file, line) or ({file = file, line = line})
end
function ____exports.addTest(parent, name, source, func, declaredMode, tags)
    local path = (parent.path .. " > ") .. name
    for ____, sibling in ipairs(parent.children) do
        if sibling.path == path then
            log(((((((("Warning: Duplicate test name \"" .. name) .. "\" in \"") .. parent.path) .. "\" at ") .. ____exports.formatSource(source)) .. " (first at ") .. ____exports.formatSource(sibling.source)) .. ")")
        end
    end
    local test = {
        type = "test",
        name = name,
        path = path,
        tags = tags,
        parent = parent,
        source = source,
        indexInParent = #parent.children,
        parts = {{func = func, source = source}},
        errors = {},
        declaredMode = declaredMode,
        mode = declaredMode,
        ticksBefore = parent.ticksBetweenTests
    }
    local ____parent_children_0 = parent.children
    ____parent_children_0[#____parent_children_0 + 1] = test
    return test
end
function ____exports.addDescribeBlock(parent, name, source, declaredMode, tags)
    local path = parent.path ~= "" and (parent.path .. " > ") .. name or name
    for ____, sibling in ipairs(parent.children) do
        if sibling.path == path then
            log(((((((("Warning: Duplicate describe name \"" .. name) .. "\" in \"") .. parent.path) .. "\" at ") .. ____exports.formatSource(source)) .. " (first at ") .. ____exports.formatSource(sibling.source)) .. ")")
        end
    end
    local block = {
        type = "describeBlock",
        name = name,
        path = path,
        tags = tags,
        parent = parent,
        indexInParent = parent and #parent.children or -1,
        source = source,
        hooks = {},
        children = {},
        declaredMode = declaredMode,
        ticksBetweenTests = parent.ticksBetweenTests,
        errors = {}
    }
    local ____parent_children_3 = parent.children
    ____parent_children_3[#____parent_children_3 + 1] = block
    return block
end
function ____exports.createRootDescribeBlock(config)
    return {
        type = "describeBlock",
        name = "",
        path = "",
        tags = {},
        source = {},
        parent = nil,
        children = {},
        indexInParent = -1,
        hooks = {},
        declaredMode = nil,
        mode = nil,
        ticksBetweenTests = config.default_ticks_between_tests,
        errors = {}
    }
end
local function testMatchesTagList(test, config)
    if config.tag_whitelist then
        for ____, tag in ipairs(config.tag_whitelist) do
            if not (test.tags[tag] ~= nil) then
                return false
            end
        end
    end
    if config.tag_blacklist then
        for ____, tag in ipairs(config.tag_blacklist) do
            if test.tags[tag] ~= nil then
                return false
            end
        end
    end
    return true
end
function ____exports.isSkippedTest(test, state)
    return test.mode == "skip" or test.mode == "todo" or state.hasFocusedTests and test.mode ~= "only" or state.config.test_pattern ~= nil and not (string.match(test.path, state.config.test_pattern)) or not testMatchesTagList(test, state.config)
end
function ____exports.countActiveTests(block, state)
    if block.mode == "skip" then
        return 0
    end
    local result = 0
    for ____, child in ipairs(block.children) do
        if child.type == "describeBlock" then
            result = result + ____exports.countActiveTests(child, state)
        elseif child.type == "test" then
            if not ____exports.isSkippedTest(child, state) then
                result = result + 1
            end
        else
            assertNever(child)
        end
    end
    return result
end
function ____exports.collectHooks(block, ____type, order)
    local hooks = {}
    collectHooksRecursive(block, ____type, order, hooks)
    return hooks
end
return ____exports
 end,
["state"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____results = require("results")
local createEmptyRunResults = ____results.createEmptyRunResults
local ____test_2Devents = require("test-events")
local _raiseTestEvent = ____test_2Devents._raiseTestEvent
local ____tests = require("tests")
local createRootDescribeBlock = ____tests.createRootDescribeBlock
local TheTestState
function ____exports.getTestState()
    return TheTestState or error("Tests are not configured to be run")
end
function ____exports._setTestState(state)
    TheTestState = state
end
function ____exports.getGlobalTestStage()
    return storage.__factorio_testTestStage or "NotRun"
end
local onTestStageChanged = script.generate_event_name()
____exports.onTestStageChanged = onTestStageChanged
local function setGlobalTestStage(stage)
    storage.__factorio_testTestStage = stage
    script.raise_event(onTestStageChanged, {stage = stage})
end
function ____exports.resetTestState(config)
    local rootBlock = createRootDescribeBlock(config)
    ____exports._setTestState({
        config = config,
        rootBlock = rootBlock,
        currentBlock = rootBlock,
        hasFocusedTests = false,
        cancelRequested = false,
        failureCount = 0,
        bailedOut = false,
        results = createEmptyRunResults(),
        getTestStage = ____exports.getGlobalTestStage,
        setTestStage = setGlobalTestStage,
        raiseTestEvent = function(self, event)
            _raiseTestEvent(self, event)
        end
    })
end
function ____exports.cleanupTestState()
    local state = ____exports.getTestState()
    state.config = nil
    state.rootBlock = nil
    state.currentBlock = nil
    state.currentTestRun = nil
end
function ____exports.setToLoadErrorState(state, ____error)
    state.setTestStage("LoadError")
    state.rootBlock = createRootDescribeBlock(state.config)
    state.currentBlock = nil
    state.currentTestRun = nil
    state.rootBlock.errors = {____error}
    game.speed = 1
end
function ____exports.getCurrentBlock()
    return ____exports.getTestState().currentBlock or error("Tests and hooks cannot be added/configured at this time")
end
return ____exports
 end,
["test-events"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local testListeners = {}
function ____exports.clearTestListeners()
    testListeners = {}
end
function ____exports.addTestListener(self, listener)
    testListeners[#testListeners + 1] = listener
end
function ____exports._raiseTestEvent(state, event)
    for ____, handler in ipairs(testListeners) do
        handler(event, state)
    end
end
return ____exports
 end,
["output"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__ArrayJoin = ____lualib.__TS__ArrayJoin
local __TS__StringSplit = ____lualib.__TS__StringSplit
local __TS__StringStartsWith = ____lualib.__TS__StringStartsWith
local ____exports = {}
local _____util = require("_util")
local debugAdapterEnabled = _____util.debugAdapterEnabled
____exports.Colors = {
    [1] = {1, 1, 1},
    [2] = {71, 221, 37},
    [3] = {252, 237, 50},
    [4] = {230, 60, 60},
    [5] = {177, 156, 220}
}
local ColorFormat = {}
for code, color in pairs(____exports.Colors) do
    ColorFormat[code] = ("[color=" .. __TS__ArrayJoin(color)) .. "]"
end
local function red(text)
    return {text = text, color = 4}
end
local function yellow(text)
    return {text = text, color = 3}
end
local function green(text)
    return {text = text, color = 2}
end
local function purple(text)
    return {text = text, color = 5}
end
local function formatError(text)
    local withSpaces = (string.gsub(text, "\t", "    "))
    local withIndent = (string.gsub(withSpaces, "\n", "\n    "))
    return {richText = "    " .. withIndent, plainText = text, firstColor = 4}
end
local function m(strings, ...)
    local substitutions = {...}
    local plainResult = {}
    local richResult = {""}
    local firstColor = nil
    local isString = true
    for i = 1, #strings * 2 - 1 do
        do
            local ____temp_0
            if i % 2 == 0 then
                ____temp_0 = strings[i / 2 + 1]
            else
                ____temp_0 = substitutions[(i - 1) / 2 + 1]
            end
            local element = ____temp_0
            if element == nil then
                goto __continue9
            end
            local color
            local part
            if type(element) == "table" then
                if element.object_name ~= nil then
                    part = element
                else
                    part = element.text
                    color = element.color
                    if firstColor == nil then
                        firstColor = color
                    end
                end
            else
                part = element
            end
            if color then
                richResult[#richResult + 1] = ColorFormat[color]
            end
            local partIsStr = type(part) == "string"
            if not partIsStr and isString then
                richResult = {
                    "",
                    table.concat(richResult)
                }
                isString = false
            end
            plainResult[#plainResult + 1] = partIsStr and part or "<Profiler>"
            richResult[#richResult + 1] = part
            if color then
                richResult[#richResult + 1] = "[/color]"
            end
        end
        ::__continue9::
    end
    return {
        richText = richResult,
        plainText = table.concat(plainResult),
        firstColor = firstColor
    }
end
local messageHandlers = {}
function ____exports.addMessageHandler(handler)
    messageHandlers[#messageHandlers + 1] = handler
end
local function output(message, source)
    for ____, logHandler in ipairs(messageHandlers) do
        logHandler(message, source)
    end
end
local daOutputEvent
if debugAdapterEnabled then
    if __DebugAdapter == nil then
        __DebugAdapter = {
            stepIgnore = function(f) return f end,
            stepIgnoreAll = function(f) return f end
        }
    end
    daOutputEvent = require("__debugadapter__.print").outputEvent
end
local DebugAdapterCategories = {
    [1] = "stdout",
    [2] = "stdout",
    [3] = "console",
    [4] = "stderr",
    [5] = "console"
}
local function printDebugAdapterText(text, source, category)
    local lines = __TS__StringSplit(text, "\n")
    for ____, line in ipairs(lines) do
        local sourceFile
        local sourceLine
        if source then
            sourceFile = source.file
            sourceLine = source.line
            source = nil
        else
            local ____, ____, file1, line1 = string.find(line, "(__[%w%-_]+__/.-%.%a+):(%d*)")
            sourceFile = file1
            sourceLine = tonumber(line1)
        end
        if sourceFile and not __TS__StringStartsWith(sourceFile, "@") then
            sourceFile = "@" .. sourceFile
        end
        daOutputEvent({category = category, output = line})
        daOutputEvent({category = category, output = "\n"}, sourceFile ~= nil and ({source = sourceFile, currentline = sourceLine or 1}) or nil)
    end
end
____exports.debugAdapterLogger = function(message, source)
    local color = message.firstColor or 1
    local category = DebugAdapterCategories[color]
    printDebugAdapterText(message.plainText, source, category)
end
____exports.logLogger = function(message)
    print("FACTORIO-TEST-MESSAGE-START")
    log(message.plainText)
    print("FACTORIO-TEST-MESSAGE-END")
end
____exports.logListener = function(event, state)
    repeat
        local ____switch34 = event.type
        local ____cond34 = ____switch34 == "testRunStarted"
        if ____cond34 then
            do
                output(m({[1] = "Starting test run...", raw = {"Starting test run..."}}))
                break
            end
        end
        ____cond34 = ____cond34 or ____switch34 == "testPassed"
        if ____cond34 then
            do
                if state.config.log_passed_tests then
                    local ____event_1 = event
                    local test = ____event_1.test
                    output(
                        m(
                            {
                                [1] = "",
                                [2] = " ",
                                [3] = " (",
                                [4] = "",
                                [5] = ")",
                                raw = {
                                    "",
                                    " ",
                                    " (",
                                    "",
                                    ")"
                                }
                            },
                            green("PASS"),
                            test.path,
                            test.profiler,
                            (test.tags.after_reload_mods ~= nil or test.tags.after_reload_script ~= nil) and " after reload" or ""
                        ),
                        test.source
                    )
                end
                break
            end
        end
        ____cond34 = ____cond34 or ____switch34 == "testFailed"
        if ____cond34 then
            do
                local ____event_2 = event
                local test = ____event_2.test
                output(
                    m(
                        {[1] = "", [2] = " ", [3] = "", raw = {"", " ", ""}},
                        red("FAIL"),
                        test.path
                    ),
                    test.source
                )
                for ____, ____error in ipairs(test.errors) do
                    output(formatError(____error))
                end
                break
            end
        end
        ____cond34 = ____cond34 or ____switch34 == "testTodo"
        if ____cond34 then
            do
                local ____event_3 = event
                local test = ____event_3.test
                output(
                    m(
                        {[1] = "", [2] = " ", [3] = "", raw = {"", " ", ""}},
                        purple("TODO"),
                        test.path
                    ),
                    test.source
                )
                break
            end
        end
        ____cond34 = ____cond34 or ____switch34 == "testSkipped"
        if ____cond34 then
            do
                if state.config.log_skipped_tests then
                    local ____event_4 = event
                    local test = ____event_4.test
                    output(
                        m(
                            {[1] = "", [2] = " ", [3] = "", raw = {"", " ", ""}},
                            yellow("SKIP"),
                            test.path
                        ),
                        test.source
                    )
                end
                break
            end
        end
        ____cond34 = ____cond34 or ____switch34 == "describeBlockFailed"
        if ____cond34 then
            do
                local ____event_5 = event
                local block = ____event_5.block
                output(
                    m(
                        {[1] = "", [2] = " ", [3] = "", raw = {"", " ", ""}},
                        red("ERROR"),
                        block.path
                    ),
                    block.source
                )
                for ____, ____error in ipairs(block.errors) do
                    output(formatError(____error))
                end
                break
            end
        end
        ____cond34 = ____cond34 or ____switch34 == "testRunFinished"
        if ____cond34 then
            do
                local results = state.results
                local status = results.status
                output(m(
                    {[1] = "", [2] = "", raw = {"", ""}},
                    {
                        text = "Test run finished: " .. tostring(status == "todo" and "passed with todo tests" or status),
                        color = status == "passed" and 2 or (status == "failed" and 4 or (status == "todo" and 5 or 1))
                    }
                ))
                output(m({[1] = "", [2] = "", [3] = "", raw = {"", "", ""}}, state.profiler, state.reloaded and " since last reload" or ""))
                break
            end
        end
        ____cond34 = ____cond34 or ____switch34 == "loadError"
        if ____cond34 then
            do
                output(m(
                    {[1] = "", [2] = " There was an load error:", raw = {"", " There was an load error:"}},
                    red("ERROR")
                ))
                output(formatError(state.rootBlock.errors[1]))
                break
            end
        end
    until true
end
return ____exports
 end,
["failed-test-storage"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____auto_2Dstart_2Dconfig = require("auto-start-config")
local getAutoStartConfig = ____auto_2Dstart_2Dconfig.getAutoStartConfig
function ____exports.initializeFailedTestsFromConfig()
    if storage.__lastFailedTests ~= nil then
        return
    end
    local fromConfig = getAutoStartConfig().last_failed_tests
    if fromConfig and #fromConfig > 0 then
        local set = {}
        for ____, path in ipairs(fromConfig) do
            set[path] = true
        end
        storage.__lastFailedTests = set
    end
end
function ____exports.getFailedTestsSet()
    return storage.__lastFailedTests or ({})
end
function ____exports.hasFailedTests()
    local set = storage.__lastFailedTests
    return set ~= nil and (next(set)) ~= nil
end
local currentRunFailedPaths
____exports.failedTestCollector = function(event)
    repeat
        local ____switch10 = event.type
        local ____cond10 = ____switch10 == "testRunStarted"
        if ____cond10 then
            currentRunFailedPaths = {}
            break
        end
        ____cond10 = ____cond10 or ____switch10 == "testFailed"
        if ____cond10 then
            local ____opt_0 = currentRunFailedPaths
            if ____opt_0 ~= nil then
                ____opt_0[event.test.path] = true
            end
            break
        end
        ____cond10 = ____cond10 or (____switch10 == "testRunFinished" or ____switch10 == "testRunCancelled")
        if ____cond10 then
            if currentRunFailedPaths then
                storage.__lastFailedTests = currentRunFailedPaths
                currentRunFailedPaths = nil
            end
            break
        end
    until true
end
return ____exports
 end,
["builtin-test-event-listeners"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____output = require("output")
local logListener = ____output.logListener
local ____results = require("results")
local resultCollector = ____results.resultCollector
local ____state = require("state")
local cleanupTestState = ____state.cleanupTestState
local ____auto_2Dstart_2Dconfig = require("auto-start-config")
local isHeadlessMode = ____auto_2Dstart_2Dconfig.isHeadlessMode
local ____failed_2Dtest_2Dstorage = require("failed-test-storage")
local failedTestCollector = ____failed_2Dtest_2Dstorage.failedTestCollector
local function emitResult(status)
    print("FACTORIO-TEST-RESULT:" .. status)
    if isHeadlessMode() then
        error("FACTORIO-TEST-EXIT")
    end
end
local function setupListener(event, state)
    if event.type == "testRunStarted" then
        game.speed = state.config.game_speed
        game.autosave_enabled = false
        local ____this_1
        ____this_1 = state.config
        local ____opt_0 = ____this_1.before_test_run
        if ____opt_0 ~= nil then
            ____opt_0(____this_1)
        end
    elseif event.type == "testRunFinished" then
        game.speed = 1
        local status = state.results.status
        if state.config.sound_effects then
            local passed = status == "passed" or status == "todo"
            game.play_sound({path = passed and "utility/game_won" or "utility/game_lost"})
        end
        local ____this_3
        ____this_3 = state.config
        local ____opt_2 = ____this_3.after_test_run
        if ____opt_2 ~= nil then
            ____opt_2(____this_3)
        end
        cleanupTestState()
        local bailedPrefix = state.bailedOut and "bailed:" or ""
        local focusedSuffix = state.hasFocusedTests and ":focused" or ""
        emitResult((bailedPrefix .. status) .. focusedSuffix)
    elseif event.type == "testRunCancelled" then
        game.speed = 1
        if state.config.sound_effects then
            game.play_sound({path = "utility/console_message"})
        end
        local ____this_5
        ____this_5 = state.config
        local ____opt_4 = ____this_5.after_test_run
        if ____opt_4 ~= nil then
            ____opt_4(____this_5)
        end
        cleanupTestState()
        local status = state.bailedOut and "bailed" or "cancelled"
        emitResult(status)
    elseif event.type == "loadError" then
        game.speed = 1
        game.play_sound({path = "utility/console_message"})
        emitResult("loadError")
    end
end
____exports.builtinTestEventListeners = {resultCollector, setupListener, logListener, failedTestCollector}
return ____exports
 end,
["cli-events"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign
local ____exports = {}
local ____tests = require("tests")
local countActiveTests = ____tests.countActiveTests
local EVENT_PREFIX = "FACTORIO-TEST-EVENT:"
local function computeStatus(r)
    if r.failed ~= 0 or r.describeBlockErrors ~= 0 then
        return "failed"
    end
    if r.todo ~= 0 then
        return "todo"
    end
    return "passed"
end
local function toSummary(r)
    return __TS__ObjectAssign(
        {},
        r,
        {status = r.status or computeStatus(r)}
    )
end
local function emitEvent(event)
    print(EVENT_PREFIX .. helpers.table_to_json(event))
end
local function sourceToLocation(source)
    if not source.file then
        return nil
    end
    local result = {file = source.file}
    if source.line ~= nil then
        result.line = source.line
    end
    return result
end
local function testToInfo(test)
    local result = {path = test.path}
    local source = sourceToLocation(test.source)
    if source then
        result.source = source
    end
    return result
end
local function blockToInfo(block)
    local result = {path = block.path}
    local source = sourceToLocation(block.source)
    if source then
        result.source = source
    end
    return result
end
____exports.cliEventEmitter = function(event, state)
    repeat
        local ____switch15 = event.type
        local ____cond15 = ____switch15 == "testRunStarted"
        if ____cond15 then
            emitEvent({
                type = "testRunStarted",
                total = countActiveTests(state.rootBlock, state)
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "testStarted"
        if ____cond15 then
            emitEvent({
                type = "testStarted",
                test = testToInfo(event.test)
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "testPassed"
        if ____cond15 then
            emitEvent({
                type = "testPassed",
                test = testToInfo(event.test)
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "testFailed"
        if ____cond15 then
            emitEvent({
                type = "testFailed",
                test = testToInfo(event.test),
                errors = {table.unpack(event.test.errors)}
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "testSkipped"
        if ____cond15 then
            emitEvent({
                type = "testSkipped",
                test = testToInfo(event.test)
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "testTodo"
        if ____cond15 then
            emitEvent({
                type = "testTodo",
                test = testToInfo(event.test)
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "describeBlockEntered"
        if ____cond15 then
            emitEvent({
                type = "describeBlockEntered",
                block = blockToInfo(event.block)
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "describeBlockFinished"
        if ____cond15 then
            emitEvent({
                type = "describeBlockFinished",
                block = blockToInfo(event.block)
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "describeBlockFailed"
        if ____cond15 then
            emitEvent({
                type = "describeBlockFailed",
                block = blockToInfo(event.block),
                errors = {table.unpack(event.block.errors)}
            })
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "testRunFinished"
        if ____cond15 then
            do
                local results = toSummary(state.results)
                emitEvent({type = "testRunFinished", results = results})
                break
            end
        end
        ____cond15 = ____cond15 or ____switch15 == "testRunCancelled"
        if ____cond15 then
            emitEvent({type = "testRunCancelled"})
            break
        end
        ____cond15 = ____cond15 or ____switch15 == "loadError"
        if ____cond15 then
            emitEvent({type = "loadError", error = state.rootBlock.errors[1] or "Unknown error"})
            break
        end
    until true
end
return ____exports
 end,
["config"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign
local ____exports = {}
local function getSettingsConfig()
    local ____opt_0 = settings.global["factorio-test-config"]
    local json = ____opt_0 and ____opt_0.value
    if not json or json == "{}" then
        return {}
    end
    return helpers.json_to_table(json)
end
local defaultConfig = {
    default_timeout = 60 * 60,
    default_ticks_between_tests = 1,
    game_speed = 1000,
    log_passed_tests = true,
    log_skipped_tests = false,
    sound_effects = false,
    reorder_failed_first = false,
    load_luassert = false
}
function ____exports.fillConfig(modConfig)
    local settingsConfig = getSettingsConfig()
    return __TS__ObjectAssign({}, defaultConfig, modConfig, settingsConfig)
end
return ____exports
 end,
["test-gui"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign
local __TS__StringSplit = ____lualib.__TS__StringSplit
local ____exports = {}
local buildTestSummary, updateTestCounts
local _____util = require("_util")
local getPlayer = _____util.getPlayer
local ____tests = require("tests")
local countActiveTests = ____tests.countActiveTests
function buildTestSummary(results)
    local parts = {}
    if results.passed > 0 then
        parts[#parts + 1] = {"factorio-test.progress-gui.n-passed", results.passed}
    end
    if results.failed > 0 then
        parts[#parts + 1] = {"factorio-test.progress-gui.n-failed", results.failed}
    end
    if results.describeBlockErrors > 0 then
        parts[#parts + 1] = {"factorio-test.progress-gui.n-errors", results.describeBlockErrors}
    end
    if results.skipped > 0 then
        parts[#parts + 1] = {"factorio-test.progress-gui.n-skipped", results.skipped}
    end
    if results.todo > 0 then
        parts[#parts + 1] = {"factorio-test.progress-gui.n-todo", results.todo}
    end
    if #parts == 0 then
        return ""
    end
    local result = {""}
    for i, part in ipairs(parts) do
        if i > 1 then
            result[#result + 1] = ", "
        end
        result[#result + 1] = part
    end
    return result
end
function updateTestCounts(gui, results)
    gui.progressBar.value = gui.totalTests == 0 and 1 or results.ran / gui.totalTests
    gui.progressLabel.caption = {"", results.ran, "/", gui.totalTests}
    gui.testSummary.caption = buildTestSummary(results)
end
local function StatusText(parent)
    local statusText = parent.add({type = "label"})
    statusText.style.font = "default-large"
    return statusText
end
local function ProgressBar(parent)
    local progressFlow = parent.add({type = "flow", direction = "horizontal"})
    progressFlow.style.horizontally_stretchable = true
    progressFlow.style.vertical_align = "center"
    local progressBar = progressFlow.add({type = "progressbar"})
    progressBar.style.horizontally_stretchable = true
    local progressLabel = progressFlow.add({type = "label"})
    local plStyle = progressLabel.style
    plStyle.width = 80
    plStyle.horizontal_align = "center"
    return {progressBar = progressBar, progressLabel = progressLabel}
end
local function TestSummary(parent)
    local label = parent.add({type = "label"})
    label.style.font = "default-bold"
    return label
end
local function TestOutput(parent)
    local frame = parent.add({type = "frame", style = "inside_shallow_frame", direction = "vertical"})
    local pane = frame.add({type = "scroll-pane", style = "scroll_pane_in_shallow_frame"})
    pane.style.height = 600
    pane.style.horizontally_stretchable = true
    return pane
end
local function bottomButtonsBar(parent)
    local flow = parent.add({type = "flow", direction = "horizontal"})
    local spacer = flow.add({type = "empty-widget"})
    spacer.style.horizontally_stretchable = true
    local actionButton = flow.add({type = "button", caption = {"factorio-test.progress-gui.cancel"}, tags = {modName = "factorio-test", on_gui_click = "cancel-test-run"}})
    return {actionButton = actionButton}
end
local function closeTestProgressGui()
    local player = getPlayer()
    local screen = player.gui.screen
    local ____opt_0 = screen["factorio-test-test-gui"]
    if ____opt_0 ~= nil then
        ____opt_0.destroy()
    end
    storage.__testGui = nil
end
local function createTestProgressGui(state)
    local player = getPlayer()
    local screen = player.gui.screen
    local ____opt_2 = screen["factorio-test-test-gui"]
    if ____opt_2 ~= nil then
        ____opt_2.destroy()
    end
    local mainFrame = screen.add({type = "frame", name = "factorio-test-test-gui", direction = "vertical"})
    mainFrame.auto_center = true
    mainFrame.style.width = 1000
    local titleBar = mainFrame.add({type = "flow", direction = "horizontal"})
    titleBar.drag_target = mainFrame
    local style = titleBar.style
    style.horizontal_spacing = 8
    style.height = 28
    titleBar.add({type = "label", caption = state.hasFocusedTests and ({"", {"factorio-test.progress-gui.title", script.mod_name}, " (.only)"}) or ({"factorio-test.progress-gui.title", script.mod_name}), style = "frame_title", ignored_by_interaction = true})
    do
        local element = titleBar.add({type = "empty-widget", ignored_by_interaction = true, style = "draggable_space"})
        local style = element.style
        style.horizontally_stretchable = true
        style.height = 24
    end
    titleBar.add({
        type = "sprite-button",
        style = "frame_action_button",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = {"gui.close"},
        mouse_button_filter = {"left"},
        tags = {modName = "factorio-test", on_gui_click = "close-test-gui"}
    })
    local contentFlow = mainFrame.add({type = "flow", direction = "vertical"})
    contentFlow.style.vertical_spacing = 15
    local topFrame = contentFlow.add({type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"})
    local gui = __TS__ObjectAssign(
        {
            player = player,
            mainFrame = mainFrame,
            totalTests = countActiveTests(state.rootBlock, state),
            statusText = StatusText(topFrame)
        },
        ProgressBar(topFrame),
        {
            testSummary = TestSummary(topFrame),
            output = TestOutput(contentFlow)
        },
        bottomButtonsBar(contentFlow)
    )
    updateTestCounts(gui, state.results)
    return gui
end
local function getTestProgressGui()
    local gui = storage.__testGui
    if not (gui and gui.mainFrame.valid) then
        storage.__testGui = nil
        return nil
    end
    return gui
end
____exports.progressGuiListener = function(event, state)
    if event.type == "testRunStarted" then
        storage.__testGui = createTestProgressGui(state)
        return
    end
    local gui = getTestProgressGui()
    if not gui then
        return
    end
    repeat
        local ____switch25 = event.type
        local ____cond25 = ____switch25 == "describeBlockEntered"
        if ____cond25 then
            do
                local ____event_6 = event
                local block = ____event_6.block
                gui.statusText.caption = {"factorio-test.progress-gui.running-test", block.path}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "testEntered"
        if ____cond25 then
            do
                local ____event_7 = event
                local test = ____event_7.test
                gui.statusText.caption = {"factorio-test.progress-gui.running-test", test.path}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "testFailed"
        if ____cond25 then
            do
                updateTestCounts(gui, state.results)
                gui.statusText.caption = {"factorio-test.progress-gui.running-test", event.test.parent.path}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "testPassed"
        if ____cond25 then
            do
                updateTestCounts(gui, state.results)
                gui.statusText.caption = {"factorio-test.progress-gui.running-test", event.test.parent.path}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "testSkipped"
        if ____cond25 then
            do
                updateTestCounts(gui, state.results)
                gui.statusText.caption = {"factorio-test.progress-gui.running-test", event.test.parent.path}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "testTodo"
        if ____cond25 then
            do
                updateTestCounts(gui, state.results)
                gui.statusText.caption = {"factorio-test.progress-gui.running-test", event.test.parent.path}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "describeBlockFinished"
        if ____cond25 then
            do
                local ____event_8 = event
                local block = ____event_8.block
                if block.parent then
                    gui.statusText.caption = {"factorio-test.progress-gui.running-test", block.parent.path}
                end
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "describeBlockFailed"
        if ____cond25 then
            do
                updateTestCounts(gui, state.results)
                local ____event_9 = event
                local block = ____event_9.block
                if block.parent then
                    gui.statusText.caption = {"factorio-test.progress-gui.running-test", block.parent.path}
                end
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "testRunFinished"
        if ____cond25 then
            do
                local statusLocale = state.results.status == "passed" and "factorio-test.progress-gui.tests-passed" or (state.results.status == "todo" and "factorio-test.progress-gui.tests-passed-with-todo" or "factorio-test.progress-gui.tests-failed")
                gui.statusText.caption = {statusLocale}
                gui.actionButton.caption = {"factorio-test.config-gui.rerun-tests"}
                gui.actionButton.tags = {modName = "factorio-test", on_gui_click = "start-tests"}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "testRunCancelled"
        if ____cond25 then
            do
                gui.statusText.caption = {"factorio-test.progress-gui.tests-cancelled"}
                gui.actionButton.caption = {"factorio-test.config-gui.rerun-tests"}
                gui.actionButton.tags = {modName = "factorio-test", on_gui_click = "start-tests"}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "loadError"
        if ____cond25 then
            do
                gui.statusText.caption = {"factorio-test.progress-gui.load-error"}
                gui.actionButton.caption = {"factorio-test.config-gui.rerun-tests"}
                gui.actionButton.tags = {modName = "factorio-test", on_gui_click = "start-tests"}
                break
            end
        end
        ____cond25 = ____cond25 or ____switch25 == "customEvent"
        if ____cond25 then
            do
                if event.name == "closeProgressGui" then
                    closeTestProgressGui()
                end
                break
            end
        end
    until true
end
local profilerLength = #"(Duration: 0.082400ms)" - #"(<Profiler>)"
____exports.progressGuiLogger = function(message)
    local gui = storage.__testGui
    if not gui or not gui.progressBar.valid then
        return
    end
    local output = gui.output
    local textBox = output.add({type = "text-box", style = "factorio-test-test-output-box-style"})
    textBox.read_only = true
    textBox.word_wrap = true
    local lines = 0
    local isFirstLine = true
    for ____, line in ipairs(__TS__StringSplit(message.plainText, "\n")) do
        local lineLength = #line + (isFirstLine and profilerLength or 0)
        if lineLength > 110 then
            lines = lines + math.ceil(lineLength / 105)
        else
            lines = lines + 1
        end
        isFirstLine = false
    end
    textBox.style.height = 20 * lines
    textBox.caption = message.richText
end
return ____exports
 end,
["reload-resume"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__ArrayMap = ____lualib.__TS__ArrayMap
local __TS__ArrayEvery = ____lualib.__TS__ArrayEvery
local __TS__ArraySetLength = ____lualib.__TS__ArraySetLength
local __TS__ArrayPushArray = ____lualib.__TS__ArrayPushArray
local ____exports = {}
local ____util = require("util")
local ____table = ____util.table
local compare = ____table.compare
local function saveTest(test)
    local result = {
        type = "test",
        path = test.path,
        tags = test.tags,
        source = test.source,
        numParts = #test.parts,
        mode = test.mode,
        ticksBefore = test.ticksBefore,
        errors = test.errors,
        profiler = test.profiler
    }
    test.parts = nil
    return result
end
local function saveDescribeBlock(block)
    local result = {
        type = "describeBlock",
        path = block.path,
        tags = block.tags,
        source = block.source,
        children = __TS__ArrayMap(
            block.children,
            function(____, child) return child.type == "test" and saveTest(child) or saveDescribeBlock(child) end
        ),
        hookTypes = __TS__ArrayMap(
            block.hooks,
            function(____, hook) return hook.type end
        ),
        mode = block.mode,
        ticksBetweenTests = block.ticksBetweenTests,
        errors = block.errors
    }
    block.hooks = nil
    return result
end
local function structuresMatch(saved, current)
    if saved.path ~= current.path then
        log(((("Structure mismatch: path \"" .. saved.path) .. "\" !== \"") .. current.path) .. "\"")
        return false
    end
    if not compare(saved.tags, current.tags) then
        log(("Structure mismatch in \"" .. saved.path) .. "\": tags differ")
        return false
    end
    if not compare(saved.source, current.source) then
        log((((("Structure mismatch in \"" .. saved.path) .. "\": source ") .. serpent.line(saved.source)) .. " !== ") .. serpent.line(current.source))
        return false
    end
    if saved.numParts ~= #current.parts then
        log((((("Structure mismatch in \"" .. saved.path) .. "\": numParts ") .. tostring(saved.numParts)) .. " !== ") .. tostring(#current.parts))
        return false
    end
    if saved.mode ~= current.mode then
        log(((((("Structure mismatch in \"" .. saved.path) .. "\": mode \"") .. tostring(saved.mode)) .. "\" !== \"") .. tostring(current.mode)) .. "\"")
        return false
    end
    if saved.ticksBefore ~= current.ticksBefore then
        log((((("Structure mismatch in \"" .. saved.path) .. "\": ticksBefore ") .. tostring(saved.ticksBefore)) .. " !== ") .. tostring(current.ticksBefore))
        return false
    end
    return true
end
local function describeBlockStructuresMatch(saved, current)
    if saved.path ~= current.path then
        log(((("Block mismatch: path \"" .. saved.path) .. "\" !== \"") .. current.path) .. "\"")
        return false
    end
    if not compare(saved.tags, current.tags) then
        log(("Block mismatch in \"" .. saved.path) .. "\": tags differ")
        return false
    end
    if not compare(saved.source, current.source) then
        log((((("Block mismatch in \"" .. saved.path) .. "\": source ") .. serpent.line(saved.source)) .. " !== ") .. serpent.line(current.source))
        return false
    end
    if not compare(
        saved.hookTypes,
        __TS__ArrayMap(
            current.hooks,
            function(____, hook) return hook.type end
        )
    ) then
        log(("Block mismatch in \"" .. saved.path) .. "\": hookTypes differ")
        return false
    end
    if saved.mode ~= current.mode then
        log(((((("Block mismatch in \"" .. saved.path) .. "\": mode \"") .. tostring(saved.mode)) .. "\" !== \"") .. tostring(current.mode)) .. "\"")
        return false
    end
    if saved.ticksBetweenTests ~= current.ticksBetweenTests then
        log((((("Block mismatch in \"" .. saved.path) .. "\": ticksBetweenTests ") .. tostring(saved.ticksBetweenTests)) .. " !== ") .. tostring(current.ticksBetweenTests))
        return false
    end
    if #saved.children ~= #current.children then
        log((((("Block mismatch in \"" .. saved.path) .. "\": children.length ") .. tostring(#saved.children)) .. " !== ") .. tostring(#current.children))
        return false
    end
    local currentByPath = {}
    for ____, child in ipairs(current.children) do
        if currentByPath[child.path] ~= nil then
            log(("Duplicate test/describe path \"" .. child.path) .. "\" - this will cause reload issues")
        end
        currentByPath[child.path] = child
    end
    return __TS__ArrayEvery(
        saved.children,
        function(____, child)
            local currentChild = currentByPath[child.path]
            if not currentChild then
                log(((("Block mismatch in \"" .. saved.path) .. "\": child \"") .. child.path) .. "\" not found in current")
                return false
            end
            if currentChild.type ~= child.type then
                log(((((((("Block mismatch in \"" .. saved.path) .. "\": child \"") .. child.path) .. "\" type \"") .. child.type) .. "\" !== \"") .. currentChild.type) .. "\"")
                return false
            end
            local ____temp_0
            if child.type == "test" then
                ____temp_0 = structuresMatch(child, currentChild)
            else
                ____temp_0 = describeBlockStructuresMatch(child, currentChild)
            end
            return ____temp_0
        end
    )
end
local function restoreTestState(saved, current)
    __TS__ArraySetLength(current.errors, 0)
    __TS__ArrayPushArray(current.errors, saved.errors)
    current.profiler = saved.profiler
end
local function restoreDescribeBlockState(saved, current)
    __TS__ArraySetLength(current.errors, 0)
    __TS__ArrayPushArray(current.errors, saved.errors)
    local currentByPath = {}
    for ____, child in ipairs(current.children) do
        currentByPath[child.path] = child
    end
    for ____, savedChild in ipairs(saved.children) do
        local currentChild = currentByPath[savedChild.path]
        if savedChild.type == "test" then
            restoreTestState(savedChild, currentChild)
        else
            restoreDescribeBlockState(savedChild, currentChild)
        end
    end
end
local function findTestByPath(block, path)
    for ____, child in ipairs(block.children) do
        if child.type == "test" then
            if child.path == path then
                return child
            end
        else
            local found = findTestByPath(child, path)
            if found then
                return found
            end
        end
    end
    return nil
end
function ____exports.prepareReload(testState)
    local currentRun = testState.currentTestRun
    storage.__testResume = {
        rootBlock = saveDescribeBlock(testState.rootBlock),
        results = testState.results,
        resumeTestPath = currentRun.test.path,
        resumePartIndex = currentRun.partIndex + 1,
        profiler = testState.profiler
    }
    testState.rootBlock = nil
    testState.currentTestRun = nil
    testState.setTestStage("ReloadingMods")
end
function ____exports.resumeAfterReload(state)
    local testResume = storage.__testResume or error("attempting to resume after reload without resume data saved")
    storage.__testResume = nil
    state.results = testResume.results
    state.profiler = testResume.profiler
    state.reloaded = true
    local saved = testResume.rootBlock
    if not describeBlockStructuresMatch(saved, state.rootBlock) then
        return nil
    end
    restoreDescribeBlockState(saved, state.rootBlock)
    local test = findTestByPath(state.rootBlock, testResume.resumeTestPath)
    if not test then
        return nil
    end
    return {test = test, partIndex = testResume.resumePartIndex}
end
return ____exports
 end,
["test-reordering"] = function(...) 
--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local markRecursive, hasPriority
local ____failed_2Dtest_2Dstorage = require("failed-test-storage")
local getFailedTestsSet = ____failed_2Dtest_2Dstorage.getFailedTestsSet
local hasFailedTests = ____failed_2Dtest_2Dstorage.hasFailedTests
function markRecursive(block, failedPaths)
    local hasFailedDescendant = false
    for ____, child in ipairs(block.children) do
        if child.type == "test" then
            if failedPaths[child.path] ~= nil then
                child._previouslyFailed = true
                hasFailedDescendant = true
            end
        else
            if markRecursive(child, failedPaths) then
                child._hasFailedDescendant = true
                hasFailedDescendant = true
            end
        end
    end
    return hasFailedDescendant
end
function hasPriority(node)
    if node.type == "test" then
        return node._previouslyFailed == true
    end
    return node._hasFailedDescendant == true
end
function ____exports.shouldReorderFailedFirst(state)
    return state.config.reorder_failed_first ~= false and hasFailedTests()
end
function ____exports.markFailedTestsAndDescendants(block)
    markRecursive(
        block,
        getFailedTestsSet()
    )
end
function ____exports.reorderChildren(block)
    if block._reordered then
        return
    end
    block._reordered = true
    table.sort(
        block.children,
        function(a, b)
            local aPriority = hasPriority(a)
            local bPriority = hasPriority(b)
            if aPriority and not bPriority then
                return true
            end
            if not aPriority and bPriority then
                return false
            end
            return a.indexInParent < b.indexInParent
        end
    )
    for i, child in ipairs(block.children) do
        child.indexInParent = i - 1
    end
end
return ____exports
 end,
["runner"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__New = ____lualib.__TS__New
local __TS__Class = ____lualib.__TS__Class
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread
local __TS__ArrayFilter = ____lualib.__TS__ArrayFilter
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf
local __TS__ObjectKeys = ____lualib.__TS__ObjectKeys
local __TS__ArraySome = ____lualib.__TS__ArraySome
local ____exports = {}
local TestRunnerImpl
local _____util = require("_util")
local __factorio_test__pcallWithStacktrace = _____util.__factorio_test__pcallWithStacktrace
local assertNever = _____util.assertNever
local ____reload_2Dresume = require("reload-resume")
local resumeAfterReload = ____reload_2Dresume.resumeAfterReload
local ____state = require("state")
local setToLoadErrorState = ____state.setToLoadErrorState
local ____tests = require("tests")
local collectHooks = ____tests.collectHooks
local formatSource = ____tests.formatSource
local isSkippedTest = ____tests.isSkippedTest
local ____test_2Dreordering = require("test-reordering")
local shouldReorderFailedFirst = ____test_2Dreordering.shouldReorderFailedFirst
local markFailedTestsAndDescendants = ____test_2Dreordering.markFailedTestsAndDescendants
local reorderChildren = ____test_2Dreordering.reorderChildren
function ____exports.createTestRunner(state)
    return __TS__New(TestRunnerImpl, state)
end
TestRunnerImpl = __TS__Class()
TestRunnerImpl.name = "TestRunnerImpl"
function TestRunnerImpl.prototype.____constructor(self, state)
    self.state = state
    self.ticksToWait = 0
    self.nextTask = {task = "init"}
end
function TestRunnerImpl.prototype.tick(self)
    if self.state.cancelRequested and self.nextTask then
        self.nextTask = self:cancelTestRun()
        return
    end
    if self.ticksToWait > 0 then
        local ____self_0, ____ticksToWait_1 = self, "ticksToWait"
        local ____self_ticksToWait_2 = ____self_0[____ticksToWait_1] - 1
        ____self_0[____ticksToWait_1] = ____self_ticksToWait_2
        if ____self_ticksToWait_2 > 0 then
            return
        end
    end
    while self.nextTask do
        if self.state.cancelRequested then
            return
        end
        self.nextTask = self:runTask(self.nextTask)
        if self.nextTask then
            self.ticksToWait = self.nextTask.waitTicks or 0
        end
        if self.ticksToWait > 0 then
            return
        end
    end
end
function TestRunnerImpl.prototype.isDone(self)
    return self.nextTask == nil
end
function TestRunnerImpl.prototype.requestCancel(self)
    self.state.cancelRequested = true
end
function TestRunnerImpl.prototype.cancelTestRun(self)
    local state = self.state
    local startBlock
    if state.currentTestRun then
        local ____state_currentTestRun_3 = state.currentTestRun
        local test = ____state_currentTestRun_3.test
        local afterTestFuncs = ____state_currentTestRun_3.afterTestFuncs
        startBlock = test.parent
        local ____array_4 = __TS__SparseArrayNew(table.unpack(afterTestFuncs))
        __TS__SparseArrayPush(
            ____array_4,
            table.unpack(collectHooks(test.parent, "afterEach", "descendants-first"))
        )
        local afterEach = {__TS__SparseArraySpread(____array_4)}
        for ____, hook in ipairs(afterEach) do
            __factorio_test__pcallWithStacktrace(hook)
        end
        local ____opt_5 = test.profiler
        if ____opt_5 ~= nil then
            ____opt_5.stop()
        end
        state.currentTestRun = nil
    else
        startBlock = self:getBlockFromNextTask()
    end
    local block = startBlock or state.rootBlock
    while block do
        local hooks = __TS__ArrayFilter(
            block.hooks,
            function(____, x) return x.type == "afterAll" end
        )
        for ____, hook in ipairs(hooks) do
            __factorio_test__pcallWithStacktrace(hook.func)
        end
        state:raiseTestEvent({type = "describeBlockFinished", block = block})
        block = block.parent
    end
    local ____opt_7 = state.profiler
    if ____opt_7 ~= nil then
        ____opt_7.stop()
    end
    state.setTestStage("Finished")
    state:raiseTestEvent(state.bailedOut and ({type = "testRunFinished"}) or ({type = "testRunCancelled"}))
    return nil
end
function TestRunnerImpl.prototype.getBlockFromNextTask(self)
    local task = self.nextTask
    if not (task and task.data) then
        return nil
    end
    local data = task.data
    if data.type ~= nil then
        return data.type == "test" and data.parent or (data.type == "describeBlock" and data or nil)
    end
    return data.test ~= nil and data.test.parent or nil
end
function TestRunnerImpl.prototype.runTask(self, task)
    local nextTask = self[task.task](self, task.data)
    if nextTask then
        self.ticksToWait = nextTask.waitTicks or 0
    end
    return nextTask
end
function TestRunnerImpl.prototype.init(self)
    if game.is_multiplayer() then
        error("Tests cannot be in run in multiplayer")
    end
    local stage = self.state.getTestStage()
    if stage == "NotRun" or stage == "Ready" then
        return self:startTestRun()
    elseif stage == "ReloadingMods" then
        return self:attemptResumeAfterReload()
    elseif stage == "Running" then
        return self:createLoadError("Save was unexpectedly reloaded while tests were running. This will cause tests to break. Aborting test run.")
    elseif stage == "Finished" or stage == "LoadError" then
        return self:rerun()
    end
    assertNever(stage)
end
function TestRunnerImpl.prototype.startTestRun(self)
    local state = self.state
    state.profiler = helpers.create_profiler()
    state.setTestStage("Running")
    if shouldReorderFailedFirst(state) then
        markFailedTestsAndDescendants(state.rootBlock)
    end
    state:raiseTestEvent({type = "testRunStarted"})
    return {task = "enterDescribe", data = state.rootBlock}
end
function TestRunnerImpl.prototype.attemptResumeAfterReload(self)
    local resumePoint = resumeAfterReload(self.state)
    if not resumePoint then
        return self:createLoadError("Mod files were changed after reload. Aborting test run.")
    end
    local test = resumePoint.test
    local partIndex = resumePoint.partIndex
    self.state.setTestStage("Running")
    return {
        task = "runTestPart",
        data = TestRunnerImpl:newTestRun(test, partIndex)
    }
end
function TestRunnerImpl.prototype.rerun(self)
    local state = self.state
    local ____state_config_11, ____tag_blacklist_12 = state.config, "tag_blacklist"
    if ____state_config_11[____tag_blacklist_12] == nil then
        ____state_config_11[____tag_blacklist_12] = {}
    end
    local tagBlacklist = state.config.tag_blacklist
    if __TS__ArrayIndexOf(tagBlacklist, "no_rerun") == -1 then
        tagBlacklist[#tagBlacklist + 1] = "no_rerun"
    end
    return self:startTestRun()
end
function TestRunnerImpl.prototype.enterDescribe(self, block)
    self.state:raiseTestEvent({type = "describeBlockEntered", block = block})
    if #block.errors ~= 0 then
        return {task = "leaveDescribeBlock", data = block}
    end
    if #block.children == 0 then
        local ____block_errors_14 = block.errors
        ____block_errors_14[#____block_errors_14 + 1] = "No tests defined"
    end
    if shouldReorderFailedFirst(self.state) then
        reorderChildren(block)
    end
    if self:hasAnyTest(block) then
        local hooks = __TS__ArrayFilter(
            block.hooks,
            function(____, x) return x.type == "beforeAll" end
        )
        for ____, hook in ipairs(hooks) do
            local success, message = __factorio_test__pcallWithStacktrace(hook.func)
            if not success then
                local ____block_errors_15 = block.errors
                ____block_errors_15[#____block_errors_15 + 1] = (("Error running " .. hook.type) .. ": ") .. tostring(message)
            end
        end
    end
    return TestRunnerImpl:getNextDescribeBlockTask(block, 0)
end
function TestRunnerImpl.prototype.enterTest(self, test)
    self.state:raiseTestEvent({type = "testEntered", test = test})
    if isSkippedTest(test, self.state) then
        if test.mode == "todo" then
            self.state:raiseTestEvent({type = "testTodo", test = test})
        else
            self.state:raiseTestEvent({type = "testSkipped", test = test})
        end
        return TestRunnerImpl:getNextDescribeBlockTask(test.parent, test.indexInParent + 1)
    end
    return {task = "startTest", data = test, waitTicks = test.ticksBefore}
end
function TestRunnerImpl.prototype.startTest(self, test)
    test.profiler = helpers.create_profiler()
    local testRun = TestRunnerImpl:newTestRun(test, 0)
    self.state.currentTestRun = testRun
    self.state:raiseTestEvent({type = "testStarted", test = test})
    local beforeEach = collectHooks(test.parent, "beforeEach", "ancestors-first")
    for ____, hook in ipairs(beforeEach) do
        if #test.errors ~= 0 then
            break
        end
        local success, ____error = __factorio_test__pcallWithStacktrace(hook)
        if not success then
            local ____test_errors_16 = test.errors
            ____test_errors_16[#____test_errors_16 + 1] = ____error
        end
    end
    return {task = "runTestPart", data = testRun}
end
function TestRunnerImpl.prototype.runTestPart(self, testRun)
    local ____testRun_17 = testRun
    local test = ____testRun_17.test
    local partIndex = ____testRun_17.partIndex
    local part = test.parts[partIndex + 1]
    self.state.currentTestRun = testRun
    if #test.errors == 0 then
        local success, ____error = __factorio_test__pcallWithStacktrace(part.func)
        if not success then
            local ____test_errors_18 = test.errors
            ____test_errors_18[#____test_errors_18 + 1] = ____error
        end
    end
    return TestRunnerImpl:nextTestTask(testRun)
end
function TestRunnerImpl.prototype.waitForTestPart(self, testRun)
    local ____testRun_19 = testRun
    local test = ____testRun_19.test
    local partIndex = ____testRun_19.partIndex
    local tickNumber = game.tick - testRun.tickStarted
    local timeout = testRun.timeout
    if tickNumber > timeout then
        local ____test_errors_20 = test.errors
        ____test_errors_20[#____test_errors_20 + 1] = (("Test timed out after " .. tostring(timeout)) .. " ticks:\n") .. formatSource(test.parts[partIndex + 1].source)
    end
    if #test.errors == 0 then
        for ____, func in ipairs(__TS__ObjectKeys(testRun.onTickFuncs)) do
            local success, result = __factorio_test__pcallWithStacktrace(func, tickNumber)
            if not success then
                local ____test_errors_21 = test.errors
                ____test_errors_21[#____test_errors_21 + 1] = result
                break
            elseif result == false then
                testRun.onTickFuncs[func] = nil
            end
        end
    end
    return TestRunnerImpl:nextTestTask(testRun)
end
function TestRunnerImpl.prototype.leaveTest(self, testRun)
    local ____testRun_22 = testRun
    local test = ____testRun_22.test
    local afterTestFuncs = ____testRun_22.afterTestFuncs
    local ____array_23 = __TS__SparseArrayNew(table.unpack(afterTestFuncs))
    __TS__SparseArrayPush(
        ____array_23,
        table.unpack(collectHooks(test.parent, "afterEach", "descendants-first"))
    )
    local afterEach = {__TS__SparseArraySpread(____array_23)}
    for ____, hook in ipairs(afterEach) do
        local success, ____error = __factorio_test__pcallWithStacktrace(hook)
        if not success then
            local ____test_errors_24 = test.errors
            ____test_errors_24[#____test_errors_24 + 1] = ____error
        end
    end
    self.state.currentTestRun = nil
    test.profiler.stop()
    if #test.errors > 0 then
        self.state:raiseTestEvent({type = "testFailed", test = test})
        if self.state.config.bail ~= nil then
            local ____self_state_25, ____failureCount_26 = self.state, "failureCount"
            ____self_state_25[____failureCount_26] = ____self_state_25[____failureCount_26] + 1
            if self.state.failureCount >= self.state.config.bail then
                self.state.bailedOut = true
                self:requestCancel()
            end
        end
    else
        self.state:raiseTestEvent({type = "testPassed", test = test})
    end
    return TestRunnerImpl:getNextDescribeBlockTask(test.parent, test.indexInParent + 1)
end
function TestRunnerImpl.prototype.leaveDescribeBlock(self, block)
    local hasTests = self:hasAnyTest(block)
    if hasTests then
        local hooks = __TS__ArrayFilter(
            block.hooks,
            function(____, x) return x.type == "afterAll" end
        )
        for ____, hook in ipairs(hooks) do
            local success, message = __factorio_test__pcallWithStacktrace(hook.func)
            if not success then
                local ____block_errors_27 = block.errors
                ____block_errors_27[#____block_errors_27 + 1] = (("Error running " .. hook.type) .. ": ") .. tostring(message)
            end
        end
    end
    if #block.errors > 0 then
        self.state:raiseTestEvent({type = "describeBlockFailed", block = block})
    else
        self.state:raiseTestEvent({type = "describeBlockFinished", block = block})
    end
    return block.parent and TestRunnerImpl:getNextDescribeBlockTask(block.parent, block.indexInParent + 1) or ({task = "finishTestRun"})
end
function TestRunnerImpl.prototype.finishTestRun(self)
    local state = self.state
    local ____opt_28 = state.profiler
    if ____opt_28 ~= nil then
        ____opt_28.stop()
    end
    state.setTestStage("Finished")
    state:raiseTestEvent({type = "testRunFinished"})
    return nil
end
function TestRunnerImpl.getNextDescribeBlockTask(self, block, index)
    if #block.errors > 0 then
        return {task = "leaveDescribeBlock", data = block}
    end
    local item = block.children[index + 1]
    if item then
        return item.type == "describeBlock" and ({task = "enterDescribe", data = item}) or ({task = "enterTest", data = item})
    end
    return {task = "leaveDescribeBlock", data = block}
end
function TestRunnerImpl.prototype.hasAnyTest(self, block)
    return __TS__ArraySome(
        block.children,
        function(____, child)
            local ____temp_30
            if child.type == "test" then
                ____temp_30 = not isSkippedTest(child, self.state)
            else
                ____temp_30 = self:hasAnyTest(child)
            end
            return ____temp_30
        end
    )
end
function TestRunnerImpl.prototype.createLoadError(self, message)
    setToLoadErrorState(self.state, message)
    self.state:raiseTestEvent({type = "loadError"})
    return nil
end
function TestRunnerImpl.nextTestTask(self, testRun)
    local ____testRun_31 = testRun
    local test = ____testRun_31.test
    local partIndex = ____testRun_31.partIndex
    if #test.errors ~= 0 or not testRun.async or testRun.asyncDone or not testRun.explicitAsync and (next(testRun.onTickFuncs)) == nil then
        if partIndex + 1 < #test.parts then
            return {
                task = "runTestPart",
                data = TestRunnerImpl:newTestRun(test, partIndex + 1)
            }
        end
        return {task = "leaveTest", data = testRun}
    end
    return {task = "waitForTestPart", data = testRun, waitTicks = 1}
end
function TestRunnerImpl.newTestRun(self, test, partIndex)
    return {
        test = test,
        async = false,
        timeout = 0,
        asyncDone = false,
        tickStarted = game.tick,
        onTickFuncs = {},
        afterTestFuncs = {},
        partIndex = partIndex
    }
end
return ____exports
 end,
["setup-globals"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__ArraySome = ____lualib.__TS__ArraySome
local __TS__StringSplit = ____lualib.__TS__StringSplit
local __TS__ArrayReduce = ____lualib.__TS__ArrayReduce
local __TS__StringIncludes = ____lualib.__TS__StringIncludes
local __TS__ArrayMap = ____lualib.__TS__ArrayMap
local __TS__ArrayIsArray = ____lualib.__TS__ArrayIsArray
local __TS__ArrayEvery = ____lualib.__TS__ArrayEvery
local ____exports = {}
local applyModeToAllChildren, markChildrenWithFocus, async
local util = require("util")
local _____util = require("_util")
local __factorio_test__pcallWithStacktrace = _____util.__factorio_test__pcallWithStacktrace
local ____reload_2Dresume = require("reload-resume")
local prepareReload = ____reload_2Dresume.prepareReload
local ____state = require("state")
local getCurrentBlock = ____state.getCurrentBlock
local getTestState = ____state.getTestState
local ____tests = require("tests")
local addDescribeBlock = ____tests.addDescribeBlock
local addTest = ____tests.addTest
local createSource = ____tests.createSource
function ____exports.getCurrentTestRun()
    return getTestState().currentTestRun or error("This can only be called within a test")
end
function applyModeToAllChildren(block, mode)
    for ____, child in ipairs(block.children) do
        do
            if child.declaredMode == "skip" then
                goto __continue24
            end
            if mode == "only" and child.declaredMode ~= nil then
                child.mode = child.declaredMode
            else
                child.mode = mode
            end
            if child.type == "describeBlock" then
                applyModeToAllChildren(child, mode)
            end
        end
        ::__continue24::
    end
end
function markChildrenWithFocus(state, block)
    for ____, child in ipairs(block.children) do
        if child.declaredMode == "only" then
            state.hasFocusedTests = true
        end
    end
end
function async(timeout)
    local testRun = ____exports.getCurrentTestRun()
    testRun.async = true
    testRun.explicitAsync = true
    if not timeout then
        timeout = getTestState().config.default_timeout
    end
    if timeout < 1 then
        error("test timeout must be greater than 0")
    end
    testRun.timeout = timeout
end
local function getCallerSource(upStack)
    if upStack == nil then
        upStack = 1
    end
    local info = debug.getinfo(upStack + 2, "Sl") or ({})
    return createSource(info.source, info.currentline)
end
local function addHook(____type, func)
    local state = getTestState()
    if state.currentTestRun then
        error(((("Hook (" .. ____type) .. ") cannot be nested inside test \"") .. state.currentTestRun.test.path) .. "\"")
    end
    local ____getCurrentBlock_result_hooks_0 = getCurrentBlock().hooks
    ____getCurrentBlock_result_hooks_0[#____getCurrentBlock_result_hooks_0 + 1] = {type = ____type, func = func}
end
local function afterTest(func)
    local ____exports_getCurrentTestRun_result_afterTestFuncs_1 = ____exports.getCurrentTestRun().afterTestFuncs
    ____exports_getCurrentTestRun_result_afterTestFuncs_1[#____exports_getCurrentTestRun_result_afterTestFuncs_1 + 1] = func
end
local function consumeTags()
    local state = getTestState()
    local result = state.currentTags
    state.currentTags = nil
    return result or ({})
end
local function createTest(name, func, mode, upStack)
    if upStack == nil then
        upStack = 1
    end
    local state = getTestState()
    if state.currentTestRun then
        error(((("Test \"" .. name) .. "\" cannot be nested inside test \"") .. state.currentTestRun.test.path) .. "\"")
    end
    local parent = getCurrentBlock()
    return addTest(
        parent,
        name,
        getCallerSource(upStack + 1),
        func,
        mode,
        util.merge({
            consumeTags(),
            parent.tags
        })
    )
end
local function addPart(test, func, funcForSource)
    if funcForSource == nil then
        funcForSource = func
    end
    local info = debug.getinfo(funcForSource, "Sl")
    local source = createSource(info.source, info.linedefined)
    local ____test_parts_2 = test.parts
    ____test_parts_2[#____test_parts_2 + 1] = {func = func, source = source}
end
local function createTestBuilder(addPart, addTag)
    local result
    local function reloadFunc(reload, what, tag)
        return function(func)
            addPart(function()
                async(1)
                prepareReload(getTestState())
                reload()
            end)
            addPart(func)
            addTag(tag)
            return result
        end
    end
    result = {
        after_reload_script = reloadFunc(
            function() return game.reload_script() end,
            "script",
            "after_reload_script"
        ),
        after_reload_mods = reloadFunc(
            function() return game.reload_mods() end,
            "mods",
            "after_reload_mods"
        )
    }
    return result
end
function ____exports.propagateTestMode(state, block, parentMode)
    if parentMode == "skip" then
        applyModeToAllChildren(block, "skip")
        return
    end
    if parentMode == "only" then
        state.hasFocusedTests = true
        local hasNestedOnly = __TS__ArraySome(
            block.children,
            function(____, child) return child.declaredMode == "only" end
        )
        if not hasNestedOnly then
            applyModeToAllChildren(block, "only")
        else
            markChildrenWithFocus(state, block)
        end
        return
    end
    markChildrenWithFocus(state, block)
end
local function getNestedProperty(obj, path)
    return __TS__ArrayReduce(
        __TS__StringSplit(path, "."),
        function(____, current, key)
            if current ~= nil and type(current) == "table" then
                return current[key]
            end
            return nil
        end,
        obj
    )
end
local function formatValue(value)
    if value == nil then
        return tostring(value)
    end
    if type(value) == "table" then
        return serpent.line(value)
    end
    return tostring(value)
end
local function formatTestName(template, row, index)
    local result = template
    result = (string.gsub(
        result,
        "%%#",
        tostring(index)
    ))
    result = (string.gsub(
        result,
        "%%%$",
        tostring(index + 1)
    ))
    if #row == 1 and type(row[1]) == "table" and row[1] ~= nil then
        local obj = row[1]
        result = (string.gsub(
            result,
            "%$([%w_][%w_%.]*)",
            function(path)
                local ____path_includes_result_3
                if __TS__StringIncludes(path, ".") then
                    ____path_includes_result_3 = getNestedProperty(obj, path)
                else
                    ____path_includes_result_3 = obj[path]
                end
                local value = ____path_includes_result_3
                return formatValue(value)
            end
        ))
    end
    local valueIndex = 0
    result = (string.gsub(
        result,
        "%%p",
        function()
            local ____row_5 = row
            local ____valueIndex_4 = valueIndex
            valueIndex = ____valueIndex_4 + 1
            local value = ____row_5[____valueIndex_4 + 1]
            local ____temp_7
            if type(value) == "table" and value ~= nil then
                ____temp_7 = serpent.block(value)
            else
                local ____value_6 = value
                if ____value_6 == nil then
                    ____value_6 = "nil"
                end
                ____temp_7 = tostring(____value_6)
            end
            return ____temp_7
        end
    ))
    if (string.match(result, "%%[disfoxXeEgGc]")) then
        local rowValues = __TS__ArrayMap(
            row,
            function(____, v) return type(v) == "table" and serpent.line(v) or v end
        )
        result = string.format(
            result,
            table.unpack(rowValues)
        )
    end
    return result
end
local function createDescribe(name, block, mode, upStack)
    if upStack == nil then
        upStack = 1
    end
    local state = getTestState()
    if state.currentTestRun then
        error(((("Describe block \"" .. name) .. "\" cannot be nested inside test \"") .. state.currentTestRun.test.path) .. "\"")
    end
    local source = getCallerSource(upStack + 1)
    local parent = getCurrentBlock()
    local describeBlock = addDescribeBlock(
        parent,
        name,
        source,
        mode,
        util.merge({
            parent.tags,
            consumeTags()
        })
    )
    state.currentBlock = describeBlock
    local success, msg = __factorio_test__pcallWithStacktrace(block)
    if not success then
        local ____describeBlock_errors_8 = describeBlock.errors
        ____describeBlock_errors_8[#____describeBlock_errors_8 + 1] = "Error in definition: " .. tostring(msg)
    end
    ____exports.propagateTestMode(state, describeBlock, mode)
    state.currentBlock = parent
    if state.currentTags then
        local ____describeBlock_errors_9 = describeBlock.errors
        ____describeBlock_errors_9[#____describeBlock_errors_9 + 1] = "Tags not added to any test or describe block: " .. serpent.line(state.currentTags)
        state.currentTags = nil
    end
    return describeBlock
end
local function createEachItems(values, name)
    if #values == 0 then
        error(".each called with no data")
    end
    local valuesAsRows = __TS__ArrayEvery(
        values,
        function(____, v) return __TS__ArrayIsArray(v) end
    ) and values or __TS__ArrayMap(
        values,
        function(____, v) return {v} end
    )
    return __TS__ArrayMap(
        valuesAsRows,
        function(____, row, index) return {
            name = formatTestName(name, row, index),
            row = row
        } end
    )
end
local function createTestEach(mode)
    local result = setmetatable(
        {},
        {__call = function(____, name, func)
            local test = createTest(name, func, mode)
            return createTestBuilder(
                function(func1) return addPart(test, func1) end,
                function(tag)
                    test.tags[tag] = true
                    return nil
                end
            )
        end}
    )
    result.each = function(values) return function(name, func)
        local items = createEachItems(values, name)
        local testBuilders = __TS__ArrayMap(
            items,
            function(____, item)
                local test = createTest(
                    item.name,
                    function() return func(table.unpack(item.row)) end,
                    mode,
                    3
                )
                return {test = test, row = item.row}
            end
        )
        return createTestBuilder(
            function(func)
                for ____, ____value in ipairs(testBuilders) do
                    local test = ____value.test
                    local row = ____value.row
                    addPart(
                        test,
                        function()
                            func(table.unpack(row))
                        end,
                        func
                    )
                end
            end,
            function(tag)
                for ____, ____value in ipairs(testBuilders) do
                    local test = ____value.test
                    test.tags[tag] = true
                end
            end
        )
    end end
    return result
end
local function createDescribeEach(mode)
    local result = setmetatable(
        {},
        {__call = function(____, name, func)
            local block = createDescribe(name, func, mode)
            return block
        end}
    )
    result.each = function(values) return function(name, func)
        local items = createEachItems(values, name)
        for ____, ____value in ipairs(items) do
            local row = ____value.row
            local name = ____value.name
            createDescribe(
                name,
                function() return func(table.unpack(row)) end,
                mode,
                2
            )
        end
    end end
    return result
end
local test = createTestEach(nil)
test.skip = createTestEach("skip")
test.only = createTestEach("only")
test.todo = function(name)
    createTest(
        name,
        function()
        end,
        "todo"
    )
end
local describe = createDescribeEach(nil)
describe.skip = createDescribeEach("skip")
describe.only = createDescribeEach("only")
local function tags(...)
    local tags = {...}
    local block = getCurrentBlock()
    local state = getTestState()
    if state.currentTags then
        local ____block_errors_10 = block.errors
        ____block_errors_10[#____block_errors_10 + 1] = "Double call to tags()"
    end
    state.currentTags = util.list_to_map(tags)
end
local function implicitAsync()
    local testRun = ____exports.getCurrentTestRun()
    testRun.async = true
    if not testRun.explicitAsync then
        testRun.timeout = getTestState().config.default_timeout
    end
end
____exports.globals = {
    test = test,
    it = test,
    describe = describe,
    tags = tags,
    before_all = function(func)
        addHook("beforeAll", func)
    end,
    after_all = function(func)
        addHook("afterAll", func)
    end,
    before_each = function(func)
        addHook("beforeEach", func)
    end,
    after_each = function(func)
        addHook("afterEach", func)
    end,
    after_test = function(func)
        afterTest(func)
    end,
    async = async,
    done = function()
        local testRun = ____exports.getCurrentTestRun()
        if not testRun.async then
            error("\"done\" can only be used when test is async")
        end
        testRun.asyncDone = true
    end,
    on_tick = function(func)
        implicitAsync()
        local testRun = ____exports.getCurrentTestRun()
        testRun.onTickFuncs[func] = true
    end,
    after_ticks = function(ticks, func)
        implicitAsync()
        local testRun = ____exports.getCurrentTestRun()
        local finishTick = game.tick - testRun.tickStarted + ticks
        if ticks < 1 then
            error("after_ticks amount must be positive")
        end
        on_tick(function(tick)
            if tick >= finishTick then
                func()
                return false
            end
        end)
    end,
    ticks_between_tests = function(ticks)
        if ticks < 0 then
            error("ticks between tests must be 0 or greater")
        end
        getCurrentBlock().ticksBetweenTests = ticks
    end
}
return ____exports
 end,
["load"] = function(...) 
local ____lualib = require("lualib_bundle")
local __TS__ArrayForEach = ____lualib.__TS__ArrayForEach
local isRunning, loadTests, tryContinueTests, runTests, cancelTestRun, doRunTests, tapEvent, revertTappedEvents, currentRunner, tappedHandlers, oldScript
local ____auto_2Dstart_2Dconfig = require("auto-start-config")
local getAutoStartMod = ____auto_2Dstart_2Dconfig.getAutoStartMod
local isHeadlessMode = ____auto_2Dstart_2Dconfig.isHeadlessMode
local _____util = require("_util")
local debugAdapterEnabled = _____util.debugAdapterEnabled
local ____builtin_2Dtest_2Devent_2Dlisteners = require("builtin-test-event-listeners")
local builtinTestEventListeners = ____builtin_2Dtest_2Devent_2Dlisteners.builtinTestEventListeners
local ____cli_2Devents = require("cli-events")
local cliEventEmitter = ____cli_2Devents.cliEventEmitter
local ____failed_2Dtest_2Dstorage = require("failed-test-storage")
local initializeFailedTestsFromConfig = ____failed_2Dtest_2Dstorage.initializeFailedTestsFromConfig
local ____config = require("config")
local fillConfig = ____config.fillConfig
local ____output = require("output")
local addMessageHandler = ____output.addMessageHandler
local debugAdapterLogger = ____output.debugAdapterLogger
local logLogger = ____output.logLogger
local ____test_2Dgui = require("test-gui")
local progressGuiListener = ____test_2Dgui.progressGuiListener
local progressGuiLogger = ____test_2Dgui.progressGuiLogger
local ____runner = require("runner")
local createTestRunner = ____runner.createTestRunner
local ____setup_2Dglobals = require("setup-globals")
local globals = ____setup_2Dglobals.globals
local ____state = require("state")
local getTestState = ____state.getTestState
local onTestStageChanged = ____state.onTestStageChanged
local resetTestState = ____state.resetTestState
local ____test_2Devents = require("test-events")
local addTestListener = ____test_2Devents.addTestListener
local clearTestListeners = ____test_2Devents.clearTestListeners
function isRunning()
    local stage = getTestState().getTestStage()
    return not (stage == "NotRun" or stage == "LoadError" or stage == "Finished")
end
function loadTests(files, partialConfig)
    local config = fillConfig(partialConfig)
    if config.load_luassert then
        debug.getmetatable = getmetatable
        require("__factorio-test__.luassert.init")
    end
    local defineGlobal = __DebugAdapter and __DebugAdapter.defineGlobal
    if defineGlobal then
        for key in pairs(globals) do
            defineGlobal(nil, key)
        end
    end
    for key, value in pairs(globals) do
        _G[key] = value
    end
    resetTestState(config)
    local state = getTestState()
    local autoStartMod = getAutoStartMod()
    local manualMod = settings.global["factorio-test-mod-to-test"].value
    local modToTest = autoStartMod or manualMod
    local _require = modToTest == "factorio-test" and require or ____originalRequire
    for ____, file in ipairs(files) do
        describe(
            file,
            function() return _require(file) end
        )
    end
    state.currentBlock = nil
end
function tryContinueTests()
    local testStage = getTestState().getTestStage()
    if testStage == "Running" or testStage == "ReloadingMods" then
        doRunTests()
    else
        revertTappedEvents()
    end
end
function runTests()
    if isRunning() then
        return
    end
    log("Running tests for " .. script.mod_name)
    getTestState().setTestStage("Ready")
    doRunTests()
end
function cancelTestRun()
    if currentRunner ~= nil then
        currentRunner:requestCancel()
    end
end
function doRunTests()
    local state = getTestState()
    initializeFailedTestsFromConfig()
    clearTestListeners()
    local headless = isHeadlessMode()
    if headless then
        addTestListener(nil, cliEventEmitter)
    end
    __TS__ArrayForEach(builtinTestEventListeners, addTestListener)
    if game ~= nil then
        game.tick_paused = false
    end
    if not headless then
        addTestListener(nil, progressGuiListener)
        addMessageHandler(progressGuiLogger)
    end
    if debugAdapterEnabled then
        addMessageHandler(debugAdapterLogger)
    elseif not headless then
        addMessageHandler(logLogger)
    end
    tapEvent(
        defines.events.on_tick,
        function()
            if not currentRunner then
                currentRunner = createTestRunner(state)
            end
            currentRunner:tick()
            if currentRunner:isDone() then
                currentRunner = nil
                revertTappedEvents()
            elseif game ~= nil then
                game.tick_paused = false
            end
        end
    )
end
function tapEvent(event, func)
    if not tappedHandlers[event] then
        tappedHandlers[event] = {
            script.get_event_handler(event),
            func
        }
        oldScript.on_event(
            event,
            function(data)
                local handlers = tappedHandlers[event]
                local ____opt_4 = handlers[1]
                if ____opt_4 ~= nil then
                    ____opt_4(data)
                end
                handlers[2]()
            end
        )
    else
        tappedHandlers[event][2] = func
    end
    if rawequal(script, oldScript) then
        local proxyScript = {on_event = function(event, func)
            local handler = tappedHandlers[event]
            if handler then
                handler[1] = func
            else
                oldScript.on_event(event, func)
            end
        end}
        setmetatable(proxyScript, {__index = oldScript, __newindex = oldScript})
        _G.script = proxyScript
    end
end
function revertTappedEvents()
    _G.script = oldScript
    for event, handler in pairs(tappedHandlers) do
        tappedHandlers[event] = nil
        script.on_event(event, handler[1])
    end
end
local function ____exports(files, config)
    loadTests(files, config)
    remote.add_interface(
        "factorio-test",
        {
            runTests = runTests,
            cancelTestRun = cancelTestRun,
            modName = function() return script.mod_name end,
            getTestStage = function() return getTestState().getTestStage() end,
            isRunning = isRunning,
            fireCustomEvent = function(name, data)
                getTestState():raiseTestEvent({type = "customEvent", name = name, data = data})
            end,
            onTestStageChanged = function() return onTestStageChanged end,
            getResults = function() return getTestState().results end,
            getConfig = function() return getTestState().config end
        }
    )
    tapEvent(defines.events.on_tick, tryContinueTests)
end
tappedHandlers = {}
oldScript = script
return ____exports
 end,
}
return require("load", ...)
