APS = {
    ---@type table<string, APS.PlanetData>
    planets = {},
}

---@param planet APS.PlanetData
function APS.add_planet(planet)
    APS.planets[planet.name] = {
        name = planet.name,
        filename = planet.filename,
        fixes_filename = planet.fixes_filename,
        technology = planet.technology,
    }
end

for _, planet in pairs{"vulcanus", "gleba", "fulgora"} do
    APS.add_planet{
        name = planet,
        filename = "planets/" .. planet,
        technology = "planet-discovery-" .. planet,
    }
end

---@class APS.PlanetData
---@field name string
---@field filename string the compatibility file to be ran in data-updates
---@field fixes_filename? string the compatibility file to be ran in data-final-fixes
---@field technology? string the technology that normally unlocks the starting planet

data:extend{{
    type = "custom-event",
    name = "aps-post-init",
}}

local planet = settings.startup["aps-planet"].value
if settings.startup["aps-vulcanus-fulgora"].value and (planet == "vulcanus" or planet == "fulgora") then
    local asteroid_util = require("__space-age__/prototypes/planet/asteroid-spawn-definitions")
    local other = planet == "vulcanus" and "fulgora" or "vulcanus"
    data:extend{{
        type = "space-connection",
        name = "vulcanus-fulgora",
        subgroup = "planet-connections",
        from = planet,
        to = other,
        order = "c-a",
        length = 30000,
        asteroid_spawn_definitions = asteroid_util.spawn_definitions{
            probability_on_range_chunk = {
                {position = 0.1, probability = asteroid_util.nauvis_chunks, angle_when_stopped = asteroid_util.chunk_angle},
                {position = 0.9, probability = asteroid_util[other .. "_chunks"], angle_when_stopped = asteroid_util.chunk_angle}
            },
            probability_on_range_medium = {
                {position = 0.1, probability = 0, angle_when_stopped = asteroid_util.medium_angle},
                {position = 0.5, probability = asteroid_util[other .. "_medium"] * 3, angle_when_stopped = asteroid_util.medium_angle},
                {position = 0.9, probability = asteroid_util[other .. "_medium"], angle_when_stopped = asteroid_util.medium_angle}
            },
            type_ratios = {
                {position = 0.1, ratios = asteroid_util[planet .. "_ratio"]},
                {position = 0.9, ratios = asteroid_util[other .. "_ratio"]},
            }
        }
    }}
end