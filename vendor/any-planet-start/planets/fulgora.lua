local utils = require("utils") --[[@as APS.utils]]

utils.remove_tech("electric-energy-accumulators", true, true)

data.raw.recipe["iron-stick"].enabled = true
data.raw.recipe["medium-electric-pole"].enabled = true

utils.set_prerequisites("steel-processing", {"recycling"})
utils.set_prerequisites("concrete", {"recycling"})
utils.set_prerequisites("battery", {"recycling"})
utils.set_prerequisites("advanced-circuit", {"recycling"})
utils.set_prerequisites("processing-unit", {"recycling"})
utils.set_prerequisites("low-density-structure", {"recycling"})
utils.set_prerequisites("electronics", {"advanced-circuit", "processing-unit"})
utils.set_prerequisites("plastics", {"advanced-circuit", "low-density-structure"})
utils.set_prerequisites("steam-power", {"fluid-handling"})
utils.set_prerequisites("automation-science-pack", {"electronics"})
utils.set_prerequisites("modules", {"logistic-science-pack"})
utils.set_prerequisites("mining-productivity-1", {"logistic-science-pack", "electric-mining-drill"})

utils.add_prerequisites("electromagnetic-plant", {"automation-2"})
utils.add_prerequisites("plastic-bar-productivity", {"plastics"})
utils.add_prerequisites("processing-unit-productivity", {"processing-unit"})
utils.add_prerequisites("modular-armor", {"logistic-science-pack"})
utils.add_prerequisites("lightning-collector", {"chemical-science-pack"})
utils.add_prerequisites("military-science-pack", {"space-science-pack"})

utils.remove_recipes("oil-processing", {"oil-refinery", "chemical-plant", "basic-oil-processing",})
utils.insert_recipe("oil-processing", "heavy-oil-cracking", 1)
utils.insert_recipe("oil-processing", "light-oil-cracking", 2)
utils.remove_recipes("advanced-oil-processing", {"advanced-oil-processing", "heavy-oil-cracking", "light-oil-cracking"})

utils.add_recipes("battery", {"accumulator"})
utils.add_recipes("automation-2", {"chemical-plant", "pipe", "pipe-to-ground", "ice-melting"})
utils.add_recipes("oil-gathering", {"offshore-pump"})
utils.add_recipes("military-science-pack", {"coal-synthesis"})
utils.add_recipes("planet-discovery-nauvis", {"oil-refinery", "basic-oil-processing", "advanced-oil-processing"})

utils.insert_recipe("calcite-processing", "oil-refinery", 1)

utils.remove_recipes("steam-power", {"pipe", "pipe-to-ground", "offshore-pump"})
utils.remove_recipes("electric-energy-distribution-1", {"medium-electric-pole"})
utils.remove_recipes("space-platform-thruster", {"ice-melting"})
utils.remove_recipes("concrete", {"iron-stick"})
utils.remove_recipes("railway", {"iron-stick"})
utils.remove_recipes("circuit-network", {"iron-stick"})
utils.remove_recipes("electric-energy-distribution-1", {"iron-stick"})
utils.remove_recipes("rocket-turret", {"coal-synthesis"})

utils.remove_packs("battery-mk3-equipment", {"space-science-pack"})
utils.remove_packs("energy-shield-mk2-equipment", {"space-science-pack"})
utils.remove_packs("lightning-collector", {"space-science-pack"})
utils.remove_packs("mech-armor", {"space-science-pack"})
utils.remove_packs("personal-roboport-mk2-equipment", {"space-science-pack"})
utils.remove_packs("tesla-weapons", {"space-science-pack"})

utils.set_trigger("oil-processing", {type = "build-entity", entity = "offshore-pump"})
utils.set_trigger("electronics", {type = "craft-item", item = "electronic-circuit", count = 5})
utils.set_trigger("steel-processing", {type = "craft-item", item = "steel-plate", count = 5})
utils.set_trigger("concrete", {type = "craft-item", item = "concrete", count = 5})
utils.set_trigger("battery", {type = "craft-item", item = "battery", count = 5})
utils.set_trigger("advanced-circuit", {type = "craft-item", item = "advanced-circuit", count = 5})
utils.set_trigger("plastics", {type = "craft-item", item = "plastic-bar", count = 5})
utils.set_trigger("processing-unit", {type = "craft-item", item = "processing-unit", count = 5})
utils.set_trigger("low-density-structure", {type = "craft-item", item = "low-density-structure", count = 5})

utils.set_packs("steam-power", {"automation-science-pack", "logistic-science-pack"}, 50, 15)

local scrap_4 = data.raw.technology["scrap-recycling-productivity"]

local scrap_3 = table.deepcopy(scrap_4)
scrap_3.max_level = nil
scrap_3.unit.count_formula = nil
scrap_3.unit.ingredients[5] = nil

local scrap_2 = table.deepcopy(scrap_3)
scrap_2.unit.ingredients[4] = nil

local scrap_1 = table.deepcopy(scrap_2)
scrap_1.unit.ingredients[3] = nil
scrap_1.upgrade = nil

scrap_1.name = scrap_1.name .. "-1"
scrap_2.name = scrap_2.name .. "-2"
scrap_3.name = scrap_3.name .. "-3"

scrap_1.unit.count = 100
scrap_2.unit.count = 250
scrap_3.unit.count = 500

scrap_1.prerequisites = {"logistic-science-pack", "electric-mining-drill"}
scrap_2.prerequisites = {"chemical-science-pack", scrap_1.name}
scrap_3.prerequisites = {"production-science-pack", scrap_2.name}

scrap_4.unit.count_formula = "1.5^(L-3)*500"

utils.add_prerequisites("scrap-recycling-productivity", {scrap_3.name})

data:extend{scrap_1, scrap_2, scrap_3}

local tech = data.raw.technology["scrap-recycling-productivity"]
tech.name = tech.name .. "-4"
data.raw.technology["scrap-recycling-productivity"] = nil
data.raw.technology[tech.name] = tech

-- show recycling results in selection lists
local seen = {}
local function unlock_results(name)
    if seen[name] then return end
    seen[name] = true

    local recipe = data.raw.recipe[name .. "-recycling"]
    if not recipe then return end

    recipe.unlock_results = true
    for _, result in pairs(recipe.results or {}) do
        if result.type == "item" then
            unlock_results(result.name)
        end
    end
end

unlock_results("scrap")