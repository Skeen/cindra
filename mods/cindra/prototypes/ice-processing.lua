-- Cindra ice processing (§15-4; DESIGN.md §1 "nightward edge = MATTER", §5).
--
-- The nightside yields `ice`; this is how the player turns that frozen matter
-- into the factory's water (and, at a cost, calcite). It REUSES the Space Age
-- asteroid-crushing model (a crusher that grinds a solid feedstock), relocated
-- from orbit to the ground:
--
--   * a Cindra-exclusive CRUSHER building (`cindra-ice-crusher`), and
--   * two recipes the player CHOOSES BETWEEN (the "pick the ratio" knob):
--       - `cindra-ice-crushing`          : ice -> water        (all matter to water)
--       - `cindra-ice-crushing-calcite`  : ice -> water + calcite (trade water for calcite)
--
-- WHY A NEW CRUSHER (not the vanilla one): the space-platform crusher is gated to
-- zero gravity (`surface_conditions` gravity 0..0) and has no fluid box, so it
-- can neither stand on Cindra's heavy-gravity ground nor emit water. We clone it
-- for the art (v1 art-reuse) and adapt: drop the space-only surface condition,
-- drop the space-platform heating draw, and add a water OUTPUT fluid box.
--
-- WHY A DEDICATED RECIPE CATEGORY (`cindra-ice-crushing`, not vanilla "crushing"):
-- putting these recipes in the vanilla "crushing" category would make them appear
-- in every space-platform crusher on every save, and would let vanilla asteroid
-- recipes appear in ours. A private category keeps ice processing on Cindra's
-- crusher only -- the never-mutate-other-planets invariant (DESIGN.md §6). We
-- likewise DEEP-COPY the shared vanilla crusher prototype before touching it.

local util = require("util")

-- (tune) §16. One batch grinds ICE_PER_BATCH ice; the plain recipe turns it all
-- into WATER_MAX water, the calcite recipe diverts some of that yield into 1
-- calcite (so the two recipes ARE the water<->calcite ratio the player picks).
local ICE_PER_BATCH = 5
local WATER_MAX = 100 -- plain recipe: all matter -> water
local WATER_WITH_CALCITE = 60 -- calcite recipe: less water...
local CALCITE_PER_BATCH = 1 -- ...in exchange for calcite
local BATCH_SECONDS = 1

-- A private recipe category so these recipes live ONLY in the Cindra crusher and
-- never leak into vanilla space crushers (and vice versa).
local RECIPE_CATEGORY = "cindra-ice-crushing"

data:extend({
  { type = "recipe-category", name = RECIPE_CATEGORY },
})

-- The crusher: a ground-standing, water-emitting clone of the space crusher.
local crusher = util.table.deepcopy(data.raw["assembling-machine"]["crusher"])
crusher.name = "cindra-ice-crusher"
crusher.minable = { mining_time = 0.2, result = "cindra-ice-crusher" }
crusher.fast_replaceable_group = nil -- not interchangeable with the space crusher
crusher.crafting_categories = { RECIPE_CATEGORY }

-- Drop the space-only gating so it can stand on Cindra's heavy-gravity ground,
-- and drop the space-platform heating draw (a platform mechanic, not Cindra's).
crusher.surface_conditions = nil
crusher.heating_energy = nil

-- Add a water OUTPUT fluid box (the vanilla crusher emits only solids). The
-- building is 2 wide x 3 tall; the two south-edge tiles carry the output pipes.
crusher.fluid_boxes = {
  {
    production_type = "output",
    volume = 1000,
    -- v1 art reuse: the vanilla crusher sprite has no pipe stub, so we omit
    -- pipe_covers (cosmetic). The connection still works; see PLAYTEST.md.
    pipe_connections = {
      { flow_direction = "output", direction = defines.direction.south, position = { -0.5, 1 } },
      { flow_direction = "output", direction = defines.direction.south, position = { 0.5, 1 } },
    },
  },
}

crusher.localised_name = { "entity-name.cindra-ice-crusher" }
crusher.localised_description = { "entity-description.cindra-ice-crusher" }

-- Item: clone the crusher item for a valid subgroup + vanilla icon (v1 art),
-- pointed at our entity.
local item = util.table.deepcopy(data.raw["item"]["crusher"])
item.name = "cindra-ice-crusher"
item.place_result = "cindra-ice-crusher"
item.order = "b[cindra]-b[ice-crusher]"
item.localised_name = { "item-name.cindra-ice-crusher" }
item.localised_description = { "item-description.cindra-ice-crusher" }

-- The two ice recipes. Both are disabled until the ice-processing tech; both
-- live in the private crushing category so only the Cindra crusher runs them.
local recipe_water = {
  type = "recipe",
  name = "cindra-ice-crushing",
  categories = { RECIPE_CATEGORY },
  subgroup = "raw-material",
  order = "c[cindra]-a[ice-water]",
  enabled = false,
  energy_required = BATCH_SECONDS,
  ingredients = {
    { type = "item", name = "ice", amount = ICE_PER_BATCH },
  },
  results = {
    { type = "fluid", name = "water", amount = WATER_MAX },
  },
  allow_productivity = true,
  icon = "__space-age__/graphics/icons/ice.png",
  icon_size = 64,
  localised_name = { "recipe-name.cindra-ice-crushing" },
}

local recipe_calcite = {
  type = "recipe",
  name = "cindra-ice-crushing-calcite",
  categories = { RECIPE_CATEGORY },
  subgroup = "raw-material",
  order = "c[cindra]-b[ice-calcite]",
  enabled = false,
  energy_required = BATCH_SECONDS,
  ingredients = {
    { type = "item", name = "ice", amount = ICE_PER_BATCH },
  },
  results = {
    { type = "fluid", name = "water", amount = WATER_WITH_CALCITE },
    { type = "item", name = "calcite", amount = CALCITE_PER_BATCH },
  },
  allow_productivity = true,
  icon = "__space-age__/graphics/icons/calcite.png",
  icon_size = 64,
  localised_name = { "recipe-name.cindra-ice-crushing-calcite" },
}

-- Recipe to BUILD the crusher (gated behind the ice-processing tech).
local build_recipe = {
  type = "recipe",
  name = "cindra-ice-crusher",
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 10 },
    { type = "item", name = "iron-gear-wheel", amount = 20 },
    { type = "item", name = "stone-brick", amount = 10 },
  },
  results = { { type = "item", name = "cindra-ice-crusher", amount = 1 } },
}

-- The technology that opens ice processing: unlocks the crusher and both recipes.
-- Gated behind Cindra's discovery (you learn to work Cindra ice once you can
-- reach Cindra). The full Cindra tech tree (§15-12) will later fold this in.
local technology = {
  type = "technology",
  name = "cindra-ice-processing",
  icon = "__space-age__/graphics/icons/crusher.png",
  icon_size = 64,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-ice-crusher" },
    { type = "unlock-recipe", recipe = "cindra-ice-crushing" },
    { type = "unlock-recipe", recipe = "cindra-ice-crushing-calcite" },
  },
  prerequisites = { "planet-discovery-cindra" },
  unit = {
    count = 100,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
    },
    time = 30,
  },
}

data:extend({ crusher, item, recipe_water, recipe_calcite, build_recipe, technology })
