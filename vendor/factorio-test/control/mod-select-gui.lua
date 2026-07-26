local ____lualib = require("lualib_bundle")
local __TS__ObjectKeys = ____lualib.__TS__ObjectKeys
local __TS__ArrayFilter = ____lualib.__TS__ArrayFilter
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["11"] = 20,["12"] = 1,["13"] = 3,["14"] = 3,["15"] = 4,["16"] = 4,["17"] = 5,["18"] = 5,["19"] = 37,["20"] = 38,["21"] = 38,["22"] = 38,["23"] = 38,["24"] = 38,["26"] = 38,["28"] = 41,["29"] = 42,["30"] = 42,["31"] = 42,["32"] = 42,["34"] = 43,["35"] = 43,["37"] = 43,["38"] = 43,["40"] = 46,["41"] = 47,["42"] = 51,["43"] = 53,["44"] = 54,["45"] = 55,["46"] = 56,["48"] = 65,["49"] = 70,["50"] = 71,["51"] = 72,["54"] = 76,["55"] = 76,["56"] = 76,["57"] = 76,["58"] = 76,["59"] = 76,["60"] = 76,["61"] = 76,["62"] = 76,["63"] = 76,["66"] = 97,["67"] = 98,["69"] = 101,["70"] = 102,["71"] = 106,["72"] = 112,["73"] = 117,["74"] = 119,["75"] = 127,["76"] = 129,["77"] = 130,["78"] = 132,["79"] = 132,["80"] = 132,["81"] = 132,["82"] = 132,["83"] = 132,["84"] = 132,["85"] = 143,["86"] = 144,["87"] = 145,["88"] = 146,["90"] = 148,["91"] = 149,["92"] = 150,["94"] = 152,["97"] = 155,["98"] = 156,["99"] = 157,["100"] = 158,["101"] = 159,["102"] = 160,["105"] = 189,["106"] = 190,["107"] = 190,["108"] = 191,["110"] = 193,["111"] = 194,["112"] = 203,["113"] = 205,["114"] = 206,["116"] = 214,["117"] = 215,["118"] = 216,["121"] = 217,["122"] = 218,["124"] = 241,["125"] = 242,["126"] = 244,["127"] = 249,["128"] = 254,["129"] = 258,["130"] = 258,["131"] = 258,["132"] = 258,["133"] = 258,["134"] = 258,["135"] = 258,["137"] = 267,["138"] = 268,["141"] = 269,["142"] = 271,["143"] = 272,["144"] = 274,["145"] = 276,["146"] = 278,["147"] = 279,["148"] = 281,["149"] = 282,["151"] = 293,["152"] = 294,["153"] = 295,["154"] = 296,["156"] = 298,["158"] = 298,["160"] = 299,["161"] = 301,["162"] = 306,["163"] = 308,["164"] = 310,["165"] = 311,["166"] = 312,["167"] = 313,["168"] = 314,["170"] = 317,["171"] = 318,["174"] = 319,["175"] = 320,["176"] = 321,["177"] = 322,["178"] = 323,["181"] = 352,["182"] = 353,["185"] = 354,["186"] = 355,["187"] = 356,["189"] = 356,["192"] = 20,["193"] = 21,["194"] = 23,["195"] = 92,["196"] = 93,["197"] = 94,["198"] = 92,["199"] = 164,["200"] = 164,["201"] = 164,["202"] = 165,["203"] = 165,["204"] = 166,["205"] = 168,["206"] = 169,["207"] = 171,["208"] = 172,["209"] = 173,["210"] = 174,["211"] = 175,["212"] = 176,["214"] = 178,["215"] = 179,["217"] = 181,["218"] = 182,["220"] = 184,["222"] = 186,["223"] = 164,["224"] = 164,["225"] = 209,["226"] = 209,["227"] = 209,["228"] = 210,["229"] = 211,["230"] = 209,["231"] = 209,["232"] = 221,["233"] = 222,["234"] = 222,["235"] = 222,["236"] = 223,["237"] = 224,["238"] = 222,["239"] = 222,["240"] = 227,["241"] = 227,["242"] = 227,["243"] = 228,["244"] = 229,["247"] = 232,["248"] = 227,["249"] = 227,["250"] = 235,["251"] = 235,["252"] = 235,["253"] = 236,["254"] = 237,["255"] = 238,["256"] = 235,["257"] = 235,["258"] = 285,["259"] = 286,["260"] = 286,["261"] = 287,["262"] = 288,["263"] = 289,["265"] = 285,["266"] = 327,["267"] = 329,["268"] = 329,["269"] = 329,["270"] = 330,["271"] = 331,["273"] = 333,["274"] = 329,["275"] = 329,["276"] = 336,["277"] = 337,["278"] = 338,["280"] = 338,["282"] = 339,["283"] = 339,["284"] = 339,["285"] = 339,["286"] = 339,["287"] = 339,["288"] = 339,["289"] = 339,["290"] = 336,["291"] = 359,["292"] = 360,["293"] = 361,["295"] = 359,["296"] = 365,["297"] = 366,["298"] = 367,["299"] = 368,["300"] = 366,["301"] = 370,["302"] = 370,["303"] = 370,["304"] = 370});
local ____exports = {}
local modSelectGuiValid, getModDropdownItems, TitleBar, getTestMod, ModSelect, createModTextField, destroyModTextField, TestStageBar, updateConfigGui, createConfigGui, destroyConfigGui, refreshConfigGui, ModSelectGuiName, ModSelectWidth, thisModName, OnModSelectionChanged, OnModTextfieldChanged, ReloadMods, RunTests, DestroyConfigGui
local modGui = require("mod-gui")
local ____guiAction = require("control.guiAction")
local guiAction = ____guiAction.guiAction
local ____post_2Dload_2Daction = require("control.post-load-action")
local postLoadAction = ____post_2Dload_2Daction.postLoadAction
local ____start_2Dtests = require("control.start-tests")
local startTests = ____start_2Dtests.startTests
function modSelectGuiValid()
    local ____opt_2 = storage.modSelectGui
    local ____opt_0 = ____opt_2 and ____opt_2.mainFrame
    local ____temp_4 = ____opt_0 and ____opt_0.valid
    if ____temp_4 == nil then
        ____temp_4 = false
    end
    return ____temp_4
end
function getModDropdownItems()
    local mods = __TS__ArrayFilter(
        __TS__ObjectKeys(script.active_mods),
        function(____, mod) return remote.interfaces["factorio-test-tests-available-for-" .. mod] end
    )
    local ____array_5 = __TS__SparseArrayNew(
        {"factorio-test.config-gui.none"},
        table.unpack(mods)
    )
    __TS__SparseArrayPush(____array_5, {"factorio-test.config-gui.other"})
    return {__TS__SparseArraySpread(____array_5)}
end
function TitleBar(parent, title)
    local titleBar = parent.add({type = "flow", direction = "horizontal"})
    titleBar.drag_target = parent
    local style = titleBar.style
    style.horizontal_spacing = 8
    style.height = 28
    titleBar.add({type = "label", caption = title, style = "frame_title", ignored_by_interaction = true})
    do
        local element = titleBar.add({type = "empty-widget", ignored_by_interaction = true, style = "draggable_space"})
        local style = element.style
        style.horizontally_stretchable = true
        style.height = 24
    end
    do
        titleBar.add({
            type = "sprite-button",
            style = "frame_action_button",
            sprite = "utility/close",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            tooltip = {"gui.close"},
            mouse_button_filter = {"left"},
            tags = {modName = thisModName, on_gui_click = DestroyConfigGui}
        })
    end
end
function getTestMod()
    return settings.global["factorio-test-mod-to-test"].value
end
function ModSelect(parent)
    local mainFlow = parent.add({type = "flow", direction = "horizontal"})
    mainFlow.add({type = "label", style = "caption_label", caption = {"factorio-test.config-gui.load-tests-for"}})
    local selectFlow = mainFlow.add({type = "flow", direction = "vertical"})
    local modSelectItems = getModDropdownItems()
    local modSelect = selectFlow.add({type = "drop-down", items = modSelectItems, tags = {modName = thisModName, on_gui_selection_state_changed = OnModSelectionChanged}})
    modSelect.style.minimal_width = ModSelectWidth
    local configGui = storage.modSelectGui
    configGui.modSelect = modSelect
    configGui.refreshButton = mainFlow.add({
        type = "sprite-button",
        style = "tool_button",
        sprite = "utility/refresh",
        tooltip = {"factorio-test.config-gui.reload-mods"},
        tags = {modName = thisModName, on_gui_click = ReloadMods}
    })
    local modSelectedIndex
    local testMod = getTestMod()
    if testMod == "" then
        modSelectedIndex = 1
    else
        local foundIndex = __TS__ArrayIndexOf(modSelectItems, testMod)
        if foundIndex ~= -1 then
            modSelectedIndex = foundIndex + 1
        else
            modSelectedIndex = #modSelectItems
        end
    end
    modSelect.items = modSelectItems
    modSelect.selected_index = modSelectedIndex
    local modTextField
    if modSelectedIndex == #modSelectItems then
        modTextField = createModTextField()
        modTextField.text = testMod
    end
end
function createModTextField()
    local ____opt_7 = storage.modSelectGui.modTextField
    if ____opt_7 and ____opt_7.valid then
        return storage.modSelectGui.modTextField
    end
    local modSelect = storage.modSelectGui.modSelect
    local textfield = modSelect.parent.add({type = "textfield", lose_focus_on_confirm = true, tags = {modName = thisModName, on_gui_text_changed = OnModTextfieldChanged}, index = 2})
    textfield.style.width = ModSelectWidth
    storage.modSelectGui.modTextField = textfield
    return textfield
end
function destroyModTextField()
    local configGui = storage.modSelectGui
    if not configGui.modTextField then
        return
    end
    configGui.modTextField.destroy()
    configGui.modTextField = nil
end
function TestStageBar(parent)
    local configGui = storage.modSelectGui
    local mainFlow = parent.add({type = "flow", direction = "vertical"})
    local buttonFlow = mainFlow.add({type = "flow", direction = "horizontal"})
    buttonFlow.add({type = "empty-widget"}).style.horizontally_stretchable = true
    configGui.runButton = buttonFlow.add({
        type = "button",
        name = "runTests",
        style = "green_button",
        caption = {"factorio-test.config-gui.run-tests"},
        tags = {modName = thisModName, on_gui_click = RunTests}
    })
end
function updateConfigGui()
    if not modSelectGuiValid() then
        return
    end
    local configGui = storage.modSelectGui
    local testModIsRegistered = remote.interfaces["factorio-test-tests-available-for-" .. getTestMod()] ~= nil
    local testModLoaded = remote.interfaces["factorio-test"] ~= nil and remote.call("factorio-test", "modName") == getTestMod()
    local stage = testModLoaded and remote.call("factorio-test", "getTestStage") or nil
    local running = stage == "Running" or stage == "ReloadingMods"
    configGui.modSelect.enabled = not running
    configGui.refreshButton.enabled = not running
    configGui.runButton.enabled = testModIsRegistered and not running
    configGui.runButton.tooltip = testModIsRegistered and "" or ({"factorio-test.config-gui.mod-not-registered"})
end
function createConfigGui(player)
    if game.is_multiplayer() then
        game.print("Cannot run tests in multiplayer")
        return nil
    end
    local ____opt_11 = player.gui.screen[ModSelectGuiName]
    if ____opt_11 ~= nil then
        ____opt_11.destroy()
    end
    storage.modSelectGui = {player = player}
    local frame = player.gui.screen.add({type = "frame", name = ModSelectGuiName, direction = "vertical"})
    frame.auto_center = true
    storage.modSelectGui.mainFrame = frame
    TitleBar(frame, {"factorio-test.config-gui.title"})
    ModSelect(frame)
    TestStageBar(frame)
    updateConfigGui()
    return frame
end
function destroyConfigGui()
    if not modSelectGuiValid() then
        return
    end
    local configGui = storage.modSelectGui
    storage.modSelectGui = nil
    local element = configGui.player.gui.screen[ModSelectGuiName]
    if element and element.valid then
        element.destroy()
    end
end
function refreshConfigGui()
    if not modSelectGuiValid() then
        return
    end
    local previousPlayer = storage.modSelectGui.player
    destroyConfigGui()
    local ____opt_15 = createConfigGui(previousPlayer)
    if ____opt_15 ~= nil then
        ____opt_15.bring_to_front()
    end
end
ModSelectGuiName = "factorio-test:mod-select"
ModSelectWidth = 150
thisModName = script.mod_name
local function setTestMod(mod)
    settings.global["factorio-test-mod-to-test"] = {value = mod}
    updateConfigGui()
end
OnModSelectionChanged = guiAction(
    "OnModSelectionChanged",
    function()
        local ____storage_modSelectGui_6 = storage.modSelectGui
        local modSelect = ____storage_modSelectGui_6.modSelect
        local modSelectItems = modSelect.items
        local selectedIndex = modSelect.selected_index
        local selected = modSelectItems[selectedIndex]
        local selectedMod
        local isOther = false
        if type(selected) == "string" then
            selectedMod = selected
        elseif selectedIndex == 1 then
            selectedMod = ""
        else
            isOther = true
            selectedMod = ""
        end
        if isOther then
            createModTextField()
        else
            destroyModTextField()
        end
        setTestMod(selectedMod)
    end
)
OnModTextfieldChanged = guiAction(
    "OnModTextfieldChanged",
    function(e)
        local element = e.element
        setTestMod(element.text)
    end
)
local refreshAfterLoad = postLoadAction("afterRefresh", refreshConfigGui)
ReloadMods = guiAction(
    "refresh",
    function()
        game.reload_mods()
        refreshAfterLoad()
    end
)
local callRunTests = postLoadAction(
    "runTests",
    function()
        if not startTests() then
            game.print({"factorio-test.config-gui.mod-not-registered"})
            return
        end
        updateConfigGui()
    end
)
RunTests = guiAction(
    "start-tests",
    function()
        game.reload_mods()
        game.auto_save("beforeTest")
        callRunTests()
    end
)
script.on_load(function()
    local ____opt_9 = remote.interfaces["factorio-test"]
    local remoteExits = ____opt_9 and ____opt_9.onTestStageChanged
    if remoteExits then
        local eventId = remote.call("factorio-test", "onTestStageChanged")
        script.on_event(eventId, updateConfigGui)
    end
end)
DestroyConfigGui = guiAction("destroyConfigGui", destroyConfigGui)
local CreateConfigGui = guiAction(
    "createConfigGui",
    function(e)
        if modSelectGuiValid() then
            destroyConfigGui()
        end
        createConfigGui(game.players[e.player_index])
    end
)
local function createModButton(player)
    local flow = modGui.get_button_flow(player)
    local ____opt_13 = flow[ModSelectGuiName]
    if ____opt_13 ~= nil then
        ____opt_13.destroy()
    end
    flow.add({
        type = "sprite-button",
        name = ModSelectGuiName,
        style = modGui.button_style,
        sprite = "factorio-test-test-tube-sprite",
        tooltip = {"factorio-test.tests"},
        tags = {modName = thisModName, on_gui_click = CreateConfigGui}
    })
end
local function createModButtonForAllPlayers()
    for ____, player in pairs(game.players) do
        createModButton(player)
    end
end
script.on_init(createModButtonForAllPlayers)
script.on_configuration_changed(function()
    createModButtonForAllPlayers()
    refreshConfigGui()
end)
script.on_event(
    {defines.events.on_player_created},
    function(e) return createModButton(game.players[e.player_index]) end
)
return ____exports
