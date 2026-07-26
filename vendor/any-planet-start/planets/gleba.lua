local utils = require("utils") --[[@as APS.utils]]

utils.remove_tech("oil-gathering", false, true)
utils.remove_tech("oil-processing", false, true)

utils.set_prerequisites("landfill", nil)
utils.set_prerequisites("steel-processing", {"steam-power"})
utils.set_prerequisites("agriculture", {"landfill", "steel-processing"})
utils.set_prerequisites("plastics", {"bioflux-processing", "logistic-science-pack"})
utils.set_prerequisites("sulfur-processing", {"bioflux-processing", "logistic-science-pack"})
utils.set_prerequisites("flammables", {"bioflux-processing", "logistic-science-pack"})
utils.set_prerequisites("lubricant", {"bioflux-processing", "chemical-science-pack"})

utils.add_prerequisites("military-science-pack", {"sulfur-processing"})
utils.add_prerequisites("chemical-science-pack", {"engine"})
utils.add_prerequisites("carbon-fiber", {"chemical-science-pack"})
utils.add_prerequisites("advanced-asteroid-processing", {"space-science-pack"})
utils.add_prerequisites("transport-belt-capacity-1", {"space-science-pack"})
utils.add_prerequisites("heating-tower", {"concrete"})
utils.add_prerequisites("planet-discovery-vulcanus", {"advanced-oil-processing"})
utils.add_prerequisites("planet-discovery-fulgora", {"advanced-oil-processing"})

utils.set_recipes("bioflux-processing", {})

utils.add_recipes("plastics", {"bioplastic"})
utils.add_recipes("sulfur-processing", {"biosulfur", "coal-synthesis"})
utils.add_recipes("lubricant", {"biolubricant"})
utils.add_recipes("rocket-fuel", {"rocket-fuel-from-jelly"})
utils.add_recipes("planet-discovery-nauvis", {"pumpjack", "oil-refinery", "basic-oil-processing", "advanced-oil-processing"})
utils.add_recipes("planet-discovery-vulcanus", {"pumpjack"})
utils.add_recipes("advanced-oil-processing", {"solid-fuel-from-petroleum-gas"})

utils.insert_recipe("sulfur-processing", "chemical-plant", 1)
utils.insert_recipe("calcite-processing", "oil-refinery", 1)

utils.remove_recipes("rocket-turret", {"coal-synthesis"})
utils.remove_recipes("advanced-oil-processing", {"advanced-oil-processing"})

utils.remove_packs("carbon-fiber", {"space-science-pack"})
utils.remove_packs("toolbelt-equipment", {"space-science-pack"})
utils.remove_packs("stack-inserter", {"space-science-pack"})
utils.remove_packs("rocket-turret", {"space-science-pack"})

utils.set_trigger("steam-power", {type = "mine-entity", entities = {"iron-stromatolite"}})
utils.set_trigger("electronics", {type = "mine-entity", entities = {"copper-stromatolite"}})
utils.set_trigger("landfill", {type = "mine-entity", entities = {"stone"}})
utils.set_trigger("steel-processing", {type = "craft-item", item = "iron-plate", count = 5})
utils.set_trigger("agriculture", {type = "craft-item", item = "steel-plate", count = 10})

utils.set_packs("heating-tower", {"automation-science-pack", "logistic-science-pack"}, 500, 30)

local spawn_points = {
    ["small-strafer-pentapod"] = {{0.1, 0}, {0.35, 0.4}, {0.6, 0}},
    ["small-stomper-pentapod"] = {{0.1, 0}, {0.35, 0.2}, {0.6, 0}},
    ["medium-strafer-pentapod"] = {{0.35, 0}, {0.6, 0.4}, {0.95, 0}},
    ["medium-stomper-pentapod"] = {{0.35, 0}, {0.6, 0.2}, {0.95, 0}},
}

for _, spawn_point in pairs(data.raw["unit-spawner"]["gleba-spawner"].result_units)  do
    local new = spawn_points[spawn_point[1]]
    if new then
        spawn_point[2] = new
    end
end