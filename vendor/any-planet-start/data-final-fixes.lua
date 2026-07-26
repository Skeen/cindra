local planet = settings.startup["aps-planet"].value --[[@as string]]
if planet == "none" then return end

if APS.planets[planet].fixes_filename then
    require(APS.planets[planet].fixes_filename)
end

local utils = require("utils") --[[@as APS.utils]]

local planet_technology = APS.planets[planet].technology
if planet_technology then
    utils.remove_tech(planet_technology, true, false)
end

for _, technology in pairs(data.raw.technology) do
    local prerequisites = technology.prerequisites
    if prerequisites then
        for i = #prerequisites, 1, -1 do
            if prerequisites[i] == "planet-discovery-" .. planet then
                table.remove(prerequisites, i)
                break
            end
        end
    end
end

local technology = data.raw.technology[APS.planets[planet].technology]
if technology and technology.effects then
    for _, effect in pairs(technology.effects) do
        if effect.type == "unlock-recipe" then
            data.raw.recipe[effect.recipe].enabled = true
        end
    end
end

local item_blacklist = {
    -- biters
    ["biolab"] = true,
    ["biter-egg"] = true,
    ["captive-biter-spawner"] = true,
    ["productivity-module-3"] = true,

    -- fish
    ["raw-fish"] = true,
    ["spidertron"] = true,

    -- oil
    ["crude-oil-barrel"] = true,
    ["flamethrower-ammo"] = true,

    -- trees
    ["tree-seed"] = true,
    ["wood"] = true,

    -- uranium
    ["atomic-bomb"] = true,
    ["explosive-uranium-cannon-shell"] = true,
    ["fission-reactor-equipment"] = true,
    ["uranium-cannon-shell"] = true,
    ["uranium-ore"] = true,
    ["uranium-rounds-magazine"] = true,
}

for ptype in pairs(defines.prototypes.item) do
    for name, item in pairs(data.raw[ptype] or {}) do
        if item_blacklist[name] or item.subgroup == "uranium-processing" then
            item.default_import_location = "nauvis"
        elseif not item.default_import_location then
            item.default_import_location = planet
        end
    end
end