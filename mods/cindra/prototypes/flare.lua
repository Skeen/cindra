-- The Cindra solar panel (§15-7 solar + flare; DESIGN.md §5). A high-output
-- solar tier: its output = PANEL_NOMINAL_W * solar_factor * surface multiplier,
-- so on Cindra (fixed ~100x multiplier, daytime driven along the flare curve) it
-- swings from ~1x baseline (the night floor that runs the factory) to ~100x at
-- the flare peak. This is the panel the disposal-deficit rule (§15-8) degrades
-- when its surplus has nowhere to go.
--
-- Integrated from the proven flare-poc (ci-zg3). We add ONLY new prototypes and
-- deep-copy the shared vanilla solar-panel before touching it, so no other
-- planet's solar behaviour changes (the never-mutate-other-planets invariant).
--
-- NATIVE-TECH GATE (provisional): like the electric heater (§15-10), this is
-- gated behind a placeholder tech using vanilla science packs until the Cindra
-- science tree lands. TODO(ci-3or): fold the unlock into the Cindra tech tree.

local util = require("util")
local C = require("scripts.flare-config")

local function watts(w) return string.format("%dW", math.floor(w)) end

-- Clone the vanilla solar panel; deep-copy guarantees we never alias the shared
-- prototype or its nested tables.
local panel = util.table.deepcopy(data.raw["solar-panel"]["solar-panel"])
panel.name = C.PANEL
panel.max_health = C.PANEL_MAX_HEALTH
panel.production = watts(C.PANEL_NOMINAL_W)
panel.next_upgrade = nil
panel.minable = { mining_time = 0.5, result = C.PANEL }
panel.placeable_by = { item = C.PANEL, count = 1 }

-- v1 art: the delivered Cindra solar-panel sprite (graphics/ART-MANIFEST.md).
panel.picture = {
  layers = {
    {
      filename = "__cindra__/graphics/entity/cindra-solar-panel/cindra-solar-panel.png",
      width = 256, height = 256, scale = 0.5, shift = { 0, -0.1 },
    },
    {
      filename = "__cindra__/graphics/entity/cindra-solar-panel/cindra-solar-panel-shadow.png",
      width = 256, height = 256, scale = 0.5, shift = { 0.3, 0 }, draw_as_shadow = true,
    },
  },
}
panel.overlay = nil -- drop the vanilla day/night overlay tint (v1 art).
panel.icon = "__cindra__/graphics/icons/cindra-solar-panel.png"
panel.icons = nil
panel.icon_size = 64
panel.icon_mipmaps = 4
panel.localised_name = { "entity-name." .. C.PANEL }
panel.localised_description = { "entity-description." .. C.PANEL }

-- Item: clone the vanilla solar-panel item for a valid subgroup, then point it
-- at our entity and swap in the Cindra icon.
local item = util.table.deepcopy(data.raw["item"]["solar-panel"])
item.name = C.PANEL
item.place_result = C.PANEL
item.icon = "__cindra__/graphics/icons/cindra-solar-panel.png"
item.icons = nil
item.icon_size = 64
item.icon_mipmaps = 4
item.order = "b[cindra]-a[solar-panel]"
item.localised_name = { "item-name." .. C.PANEL }
item.localised_description = { "item-description." .. C.PANEL }

-- Recipe: high-output solar built from steel + electronics + copper. Costs are
-- (tune); §15-14 (ci-63d) balances them against the lava energy cost.
local recipe = {
  type = "recipe",
  name = C.PANEL,
  enabled = false, -- gated: unlocked by cindra-flare-power below.
  energy_required = 10,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 15 },
    { type = "item", name = "electronic-circuit", amount = 15 },
    { type = "item", name = "copper-plate", amount = 20 },
  },
  results = { { type = "item", name = C.PANEL, amount = 1 } },
}

-- Provisional tech: gated behind vanilla solar-energy (this is the high-solar
-- tier). Vanilla science packs for now. TODO(ci-3or): move into the Cindra tree.
local technology = {
  type = "technology",
  name = "cindra-flare-power",
  icon = "__cindra__/graphics/icons/cindra-solar-panel.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = C.PANEL },
  },
  prerequisites = { "solar-energy" },
  unit = {
    count = 200,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  },
}

data:extend({ panel, item, recipe, technology })
