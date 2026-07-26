---@class APS.utils
local utils = {}

local technologies = data.raw.technology

--- Overwrites the prerequisites of a technology.
---@param name string
---@param prerequisites string[]?
function utils.set_prerequisites(name, prerequisites)
    local technology = technologies[name]
    technology.prerequisites = prerequisites
end

--- Adds prerequisites to a technology's list of prerequisites.
---@param name string
---@param prerequisites string[]
function utils.add_prerequisites(name, prerequisites)
    local technology = technologies[name]
    if not technology.prerequisites then
        technology.prerequisites = prerequisites
        return
    end

    local map = {}
    for _, prerequisite in pairs(technology.prerequisites) do
        map[prerequisite] = true
    end
    for _, prerequisite in pairs(prerequisites) do
        if not map[prerequisite] then
            technology.prerequisites[#technology.prerequisites+1] = prerequisite
        end
    end
end

--- Sets the research trigger of a technology and removes the unit if there is one.
---@param name string
---@param trigger data.TechnologyTrigger
function utils.set_trigger(name, trigger)
    local technology = technologies[name]
    technology.research_trigger = trigger
    technology.unit = nil
end

--- Sets the unit of a technology and removes the research trigger if there is one.
---@param name string
---@param unit data.TechnologyUnit
function utils.set_unit(name, unit)
    local technology = technologies[name]
    technology.unit = unit
    technology.research_trigger = nil
end

--- Overwrites the recipes a technology unlocks.
---@param name string
---@param recipes string[]
function utils.set_recipes(name, recipes)
    local technology = technologies[name]
    technology.effects = {}
    for i, effect in pairs(recipes) do
        technology.effects[i] = {
            type = "unlock-recipe",
            recipe = effect,
        }
    end
end

--- Adds recipes to a technology's unlocks.
---@param name string
---@param recipes string[]
function utils.add_recipes(name, recipes)
    local technology = technologies[name]
    technology.effects = technology.effects or {}
    local len = #technology.effects
    for i = 1, #recipes do
        technology.effects[len + i] = {
            type = "unlock-recipe",
            recipe = recipes[i],
        }
    end
end

--- Removes recipes from a technology's unlocks.
---@param name string
---@param recipes string[]
function utils.remove_recipes(name, recipes)
    local map = {}
    for _, recipe in pairs(recipes) do
        map[recipe] = true
    end
    local effects = technologies[name].effects --[[@as TechnologyModifier]]
    for i = #effects, 1, -1 do
        if map[effects[i].recipe] then
            table.remove(effects, i)
        end
    end
end

--- Inserts a recipe unlock at a specific position in a technology's unlocks.
---@param name string
---@param recipe string
---@param position uint
function utils.insert_recipe(name, recipe, position)
    local technology = technologies[name]
    technology.effects = technology.effects or {}
    table.insert(technology.effects, position, {
        type = "unlock-recipe",
        recipe = recipe,
    })
end

--- Replaces specific properties of a technology's unit with only the ones specified, and leaves the rest alone.
---
--- For technologies without a unit, default ingredients are an empty table, default count is 100, and default time is 60 seconds.
---@param name string
---@param packs string[]?
---@param count uint?
---@param time double?
function utils.set_packs(name, packs, count, time)
    local technology = technologies[name]
    local unit = technology.unit or {}
    unit.count = count or unit.count or 100
    unit.time = time or unit.time or 60
    unit.ingredients = unit.ingredients or {}

    if packs then
        local ingredients = {}
        unit.ingredients = ingredients
        for _, pack in pairs(packs) do
            ingredients[#ingredients+1] = {pack, 1}
        end
    end

    utils.set_unit(name, unit)
end

--- Removes science packs from a technology's unit ingredients.
---@param name string
---@param packs string[]
function utils.remove_packs(name, packs)
    local map = {}
    for _, pack in pairs(packs) do
        map[pack] = true
    end
    local ingredients = technologies[name].unit.ingredients
    for i = #ingredients, 1, -1 do
        if map[ingredients[i][1]] then
            table.remove(ingredients, i)
        end
    end
end

--- Removes a technology from the tech tree without deleting it.
---@param name string
---@param effects boolean Automatically enable the recipes from the technology's recipe unlocks.
---@param stitch boolean Stitch together the surrounding prerequisites and dependants in the tech tree.
function utils.remove_tech(name, effects, stitch)
    local technology = technologies[name]
    technology.hidden = true

    if effects and technology.effects then
        for _, effect in pairs(technology.effects) do
            if effect.type == "unlock-recipe" then
                local recipe = data.raw.recipe[effect.recipe]
                assert(recipe, "Recipe " .. effect.recipe .. " is nil. Please add it before data-final-fixes.")
                recipe.enabled = true
            end
        end
    end

    for _, tech in pairs(technologies) do
        local prerequisites = tech.prerequisites
        if not prerequisites then goto continue end

        for i = #prerequisites, 1, -1 do
            if prerequisites[i] == name then
                table.remove(prerequisites, i)
                if stitch and technology.prerequisites then
                    for _, prereq in pairs(technology.prerequisites) do
                        prerequisites[#prerequisites+1] = prereq
                    end
                end
                break
            end
        end

        ::continue::
    end

    technology.prerequisites = nil
end

--- Makes a technology unaffected by the tech cost multiplier map setting.
---@param name string
function utils.ignore_multiplier(name)
    local technology = technologies[name]
    technology.ignore_tech_cost_multiplier = true
end

return utils