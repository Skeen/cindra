local planet = settings.startup["aps-planet"].value --[[@as string]]
if planet == "none" then return end

local utils = require("utils") --[[@as APS.utils]]

data:extend{{
    type = "technology",
    name = "planet-discovery-nauvis",
    icons = util.technology_icon_constant_planet("__any-planet-start__/nauvis.png"),
    icon_size = 256,
    essential = true,
    effects = {{
        type = "unlock-space-location",
        space_location = "nauvis",
        use_icon_overlay_constant = true
    }, {
        type = "unlock-travel-to-space-platforms",
        modifier = true,
    }},
    prerequisites = {"space-platform-thruster"},
    unit = {
        count = 1000,
        ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"chemical-science-pack", 1},
            {"space-science-pack", 1}
        },
        time = 60
    }
}}

utils.set_prerequisites("uranium-mining", {"planet-discovery-nauvis"})

utils.add_prerequisites("captivity", {"planet-discovery-nauvis"})
utils.add_prerequisites("fish-breeding", {"planet-discovery-nauvis"})
utils.add_prerequisites("tree-seeding", {"planet-discovery-nauvis"})
utils.add_prerequisites("planet-discovery-aquilo", {"planet-discovery-nauvis"})

require(APS.planets[planet].filename)
require("asteroids")