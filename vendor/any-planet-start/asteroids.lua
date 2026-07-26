if not settings.startup["aps-safe-orbit"].value then return end

local planet_name = settings.startup["aps-planet"].value --[[@as string]]
if planet_name == "nauvis" then return end
if not (planet_name == "vulcanus" or planet_name == "gleba" or planet_name == "fulgora") then return end

local planet = data.raw.planet[planet_name]
local nauvis = data.raw.planet.nauvis
local vanilla_planets = {nauvis = true, vulcanus = true, gleba = true, fulgora = true, aquilo = true}

local main_connection = (function()
    for _, connection in pairs(data.raw["space-connection"]) do
        local from = connection.from
        local to = connection.to
        if from == "nauvis" and to == planet_name then
            return connection
        end
    end
end)()

local function map_definitions(definitions)
    local map, indices = {}, {}
    for i, definition in pairs(definitions) do
        map[definition.asteroid] = definition
        indices[definition.asteroid] = i
    end
    return map, indices
end

local planet_map, planet_indices = map_definitions(planet.asteroid_spawn_definitions)
local nauvis_map = map_definitions(nauvis.asteroid_spawn_definitions)
local main_connection_map = main_connection and map_definitions(main_connection.asteroid_spawn_definitions)

local planet_total = 0
local nauvis_total = 0

for _, definition in pairs(planet.asteroid_spawn_definitions) do
    planet_total = planet_total + definition.probability
end
for _, definition in pairs(nauvis.asteroid_spawn_definitions) do
    nauvis_total = nauvis_total + definition.probability
end

local asteroid_types = {"metallic", "carbonic", "oxide"}
for _, asteroid_type in pairs(asteroid_types) do

    -- swapping planet probabilities
    local chunk_name = asteroid_type .. "-asteroid-chunk"
    local medium_name = "medium-" .. asteroid_type .. "-asteroid"

    local planet_chunk = planet_map[chunk_name]
    local planet_medium = planet_map[medium_name]
    local chunk_medium_ratio = planet_chunk.probability / (planet_chunk.probability + planet_medium.probability)

    local planet_chunk_ratio = (planet_chunk.probability + planet_medium.probability) / planet_total
    planet_chunk.probability = planet_chunk_ratio * nauvis_total

    local nauvis_chunk = nauvis_map[chunk_name]
    local nauvis_medium = table.deepcopy(nauvis_chunk)
    nauvis_medium.type = nil
    nauvis_medium.asteroid = medium_name

    local nauvis_chunk_ratio = nauvis_chunk.probability / nauvis_total
    nauvis_chunk.probability = nauvis_chunk_ratio * planet_total * chunk_medium_ratio
    local nauvis_medium_ratio = nauvis_medium.probability / nauvis_total
    nauvis_medium.probability = nauvis_medium_ratio * planet_total * (1 - chunk_medium_ratio)

    planet.asteroid_spawn_definitions[planet_indices[medium_name]] = nil
    table.insert(nauvis.asteroid_spawn_definitions, nauvis_medium)

    -- swapping main connection probabilities
    if main_connection then
        main_connection_map[chunk_name].spawn_points[1].probability = nauvis_chunk.probability
        main_connection_map[chunk_name].spawn_points[2].probability = planet_chunk.probability
        main_connection_map[medium_name].spawn_points[1].probability = nauvis_medium.probability
        main_connection_map[medium_name].spawn_points[2].probability = nauvis_medium.probability * 3
        main_connection_map[medium_name].spawn_points[3].probability = 0
    end

    -- changing other connection probabilities
    for _, connection in pairs(data.raw["space-connection"]) do
        if connection == main_connection then goto continue end

        local map = map_definitions(connection.asteroid_spawn_definitions or {})
        if connection.from == "nauvis" and vanilla_planets[connection.to] then
            local chunk = map[chunk_name].spawn_points
            local medium = map[medium_name].spawn_points
            chunk[1].probability = nauvis_chunk.probability
            medium[1].probability = nauvis_medium.probability
            medium[2].probability = (nauvis_medium.probability + medium[3].probability) * 1.5 -- (/ 2 * 3)

        elseif connection.from == planet_name and vanilla_planets[connection.to] then
            local chunk = map[chunk_name].spawn_points
            local medium = map[medium_name].spawn_points
            chunk[1].probability = planet_chunk.probability
            medium[1].probability = 0
            if connection.to == "aquilo" then goto continue end
            medium[2].probability = medium[3].probability * 3

        elseif connection.to == "nauvis" and vanilla_planets[connection.from] then
            local chunk = map[chunk_name].spawn_points
            local medium = map[medium_name].spawn_points
            chunk[2].probability = nauvis_chunk.probability
            medium[3].probability = nauvis_medium.probability
            medium[2].probability = (nauvis_medium.probability + medium[1].probability) * 1.5 -- (/ 2 * 3)

        elseif connection.to == planet_name and vanilla_planets[connection.from] then
            local chunk = map[chunk_name].spawn_points
            local medium = map[medium_name].spawn_points
            chunk[2].probability = planet_chunk.probability
            medium[3].probability = 0
            medium[2].probability = medium[1].probability * 3

        end

        ::continue::
    end
end