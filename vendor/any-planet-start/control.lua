local crash_site = require("crash-site")
local util = require("util")
local e = defines.events

remote.add_interface("APS", {
    get_planet = function()
        return storage.planet
    end,
    override_planet = function(name)
        storage.planet = name
        storage.overridden = true
    end,
    disable_warning = function()
        storage.disable_warning = true
    end,
    set_disable_crashsite = function(bool)
        storage.disable_crashsite = bool
    end,
    set_skip_intro = function(bool)
        storage.skip_intro = bool
    end,
})

local function correct_space_locations()
    storage.planet = storage.planet or settings.startup["aps-planet"].value --[[@as string]]
    if storage.planet == "none" then return end

    local force = game.forces.player
    force.unlock_space_location(storage.planet)
    local technology = force.technologies["planet-discovery-nauvis"]
    if technology and not technology.researched then
        force.lock_space_location("nauvis")
    end
end

script.on_init(function()
    if game.tick > 0 then
        storage.init = true
        game.print{"", "[Any Planet Start]: ", {"any-planet-start.start-new-game"}}
        return
    end

    if remote.interfaces.freeplay then
        if storage.disable_crashsite == nil then
            storage.disable_crashsite = remote.call("freeplay", "get_disable_crashsite")
        end
        if storage.skip_intro == nil then
            storage.skip_intro = remote.call("freeplay", "get_skip_intro")
        end

        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_skip_intro", true)
    end

    storage.crashed_ship_items = {["firearm-magazine"] = 8}
    storage.crashed_debris_items = {["iron-plate"] = 8}
    storage.crashed_ship_parts = crash_site.default_ship_parts()

    storage.planet = storage.planet or settings.startup["aps-planet"].value --[[@as string]]
end)

script.on_configuration_changed(function(data)
    if data.mod_startup_settings_changed and storage.planet and storage.planet ~= settings.startup["aps-planet"].value and not storage.overridden then
        game.print({"", "[Any Planet Start]: ", {"any-planet-start.mod-setting-changed"}})
    end
    correct_space_locations()
end)
script.on_event(e.on_technology_effects_reset, correct_space_locations)
script.on_event(e.on_research_reversed, correct_space_locations)

local function get_starting_message()
    if storage.custom_intro_message then
      return storage.custom_intro_message
    end
    if script.active_mods["space-age"] then
      return {"msg-intro-space-age"}
    end
    return {"msg-intro"}
  end

local function show_intro_message(player)
    if storage.skip_intro then return end

    if game.is_multiplayer() then
      player.print(get_starting_message())
    else
      game.show_message_dialog{text = get_starting_message()}
    end
end

local error_format_string = [[

Could not find non-colliding position on %s.

[color=red]Please ensure the planet has walkable tiles when the surface is created.[/color]
]]

local function respawn_player(player)
    local position = storage.surface.find_non_colliding_position("character", {0, 0}, 1000, 1)
    assert(position, string.format(error_format_string, storage.planet, storage.planet))

    player.teleport(position, storage.surface)
    if storage.planet ~= "none" and not storage.nauvis_visited then
        local nauvis = game.get_surface("nauvis") --[[@as LuaSurface]]
        nauvis.clear()
    end
end

script.on_event(e.on_player_created, function(event)
    if not storage.init then
        if storage.planet == "none" then
            storage.surface = game.get_surface("nauvis") --[[@as LuaSurface]]
        else
            storage.surface = storage.surface or game.planets[storage.planet].create_surface()
            storage.surface.request_to_generate_chunks({0, 0}, 3)
            storage.surface.force_generate_chunk_requests()

            correct_space_locations()
        end
    end

    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local surface = storage.surface
    if surface then
        respawn_player(player)
    end

    if not storage.init then
        storage.init = true
        if not storage.disable_warning and storage.planet == "none" then
            game.print{"", "[Any Planet Start]: ", {"any-planet-start.none-selected"}}
        end

        local r = 200
        local force = player.force
        local origin = force.get_spawn_position(surface)
        force.chart(surface, {{origin.x - r, origin.y - r}, {origin.x + r, origin.y + r}})

        if remote.interfaces["freeplay"] then
            storage.crashed_ship_items = remote.call("freeplay", "get_ship_items")
            storage.crashed_debris_items = remote.call("freeplay", "get_debris_items")
            storage.crashed_ship_parts = remote.call("freeplay", "get_ship_parts")
            storage.custom_intro_message = remote.call("freeplay", "get_custom_intro_message")
        end

        if not storage.disable_crashsite then
            surface.daytime = 0.7
            crash_site.create_crash_site(surface, {-5,-6}, util.copy(storage.crashed_ship_items), util.copy(storage.crashed_debris_items), util.copy(storage.crashed_ship_parts))
            util.remove_safe(player, storage.crashed_ship_items)
            util.remove_safe(player, storage.crashed_debris_items)
            player.get_main_inventory().sort_and_merge()
            if player.character then
                player.character.destructible = false
                storage.crash_site_cutscene_active = true
                crash_site.create_cutscene(player, {-5, -4})
            end
            return
        end

        script.raise_event("aps-post-init", {
            surface = surface
        })
    end

    show_intro_message(player)
end)

script.on_event(e.on_player_changed_surface, function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    if event.surface_index == nil and player.controller_type == defines.controllers.ghost then
        respawn_player(player)
    end
    if player.surface.name == "nauvis" then
        storage.nauvis_visited = true
    end
end)

script.on_event(e.on_cutscene_waypoint_reached, function(event)
    if not storage.crash_site_cutscene_active then return end
    if not crash_site.is_crash_site_cutscene(event) then return end

    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]

    player.exit_cutscene()
    show_intro_message(player)
end)

---@param event EventData.CustomInputEvent
script.on_event("crash-site-skip-cutscene", function(event)
    if not storage.crash_site_cutscene_active then return end
    if event.player_index ~= 1 then return end
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    if player.controller_type == defines.controllers.cutscene then
        player.exit_cutscene()
    end
end)

script.on_event(e.on_cutscene_cancelled, function(event)
    if not storage.crash_site_cutscene_active then return end
    if event.player_index ~= 1 then return end
    storage.crash_site_cutscene_active = nil
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    if player.gui.screen.skip_cutscene_label then
        player.gui.screen.skip_cutscene_label.destroy()
    end
    if player.character then
    player.character.destructible = true
        end
    player.zoom = 1.5
end)