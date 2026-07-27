-- Cindra ice processing (§15-4; DESIGN.md §1 "nightward edge = MATTER", §5).
--
-- The nightside yields `ice`; this is how the player turns that frozen matter
-- into the factory's water (and, at a cost, calcite). It is a TWO-STAGE chain,
-- mirroring the Space Age asteroid model faithfully: the crusher is a SOLID ->
-- SOLID machine (like the space-platform crusher, which is item-only), and the
-- fluid appears only at a later MELT step.
--
--   1. CRUSHER (`cindra-ice-crusher`) -- ice -> crushed-ice (SOLID ITEMS only,
--      no fluid). Two recipes the player CHOOSES BETWEEN (the "pick the ratio"
--      knob):
--        - `cindra-ice-crushing`         : ice -> crushed-ice
--        - `cindra-ice-crushing-calcite` : ice -> crushed-ice + calcite
--      Choosing the calcite recipe trades some crushed-ice (hence downstream
--      water) for a calcite item -- the water<->calcite ratio the player picks.
--   2. MELTER (`cindra-ice-melter`) -- crushed-ice (item) -> water (fluid). A
--      separate heat/melt step is the ONLY place the fluid is born.
--
-- WHY TWO STAGES: a crusher is a grinder, not a boiler. The space-platform
-- crusher is strictly item-only; emitting water straight out of it broke that
-- model (ci-4or). Splitting crush (solid) from melt (fluid) keeps the crusher
-- honest and puts the phase change where it belongs -- under applied heat.
--
-- WHY NEW MACHINES (not the vanilla crusher / chemical plant): the space-platform
-- crusher is gated to zero gravity (`surface_conditions` gravity 0..0) so it
-- cannot stand on Cindra's heavy-gravity ground; we clone it for the art (v1
-- art-reuse) and drop the space-only gating and the space-platform heating draw.
-- The melter is a chemical-plant clone, so it already emits fluid.
--
-- WHY DEDICATED RECIPE CATEGORIES (`cindra-ice-crushing` / `cindra-ice-melting`,
-- not vanilla `"crushing"` / `"chemistry"`): a private category keeps each recipe
-- on its Cindra machine only and never leaks it into every space crusher /
-- chemical plant on every save (and keeps vanilla recipes out of ours) -- the
-- never-mutate-other-planets invariant (DESIGN.md §6). We likewise DEEP-COPY the
-- shared vanilla prototypes before touching them.

local util = require("util")

-- (tune) §16. One crush batch grinds ICE_PER_BATCH ice into crushed-ice; the
-- plain recipe turns it all into CRUSHED_MAX shards, the calcite recipe diverts
-- some of that yield into 1 calcite (so the two crush recipes ARE the
-- water<->calcite ratio the player picks). The melter then turns each shard into
-- WATER_PER_SHARD water, so a full plain batch still yields the historic 100
-- water (5 shards x 20), keeping downstream ratios unchanged.
local ICE_PER_BATCH = 5
local CRUSHED_MAX = 5 -- plain crush: all matter -> crushed ice
local CRUSHED_WITH_CALCITE = 3 -- calcite crush: fewer shards...
local CALCITE_PER_BATCH = 1 -- ...in exchange for calcite
local WATER_PER_SHARD = 20 -- melt: each crushed-ice shard -> this much water
local CRUSH_SECONDS = 1
local MELT_SECONDS = 1

-- Private recipe categories: crushing lives ONLY in the Cindra crusher, melting
-- ONLY in the Cindra melter. Neither leaks into vanilla space crushers or
-- chemical plants (and vice versa).
local CRUSH_CATEGORY = "cindra-ice-crushing"
local MELT_CATEGORY = "cindra-ice-melting"

data:extend({
  { type = "recipe-category", name = CRUSH_CATEGORY },
  { type = "recipe-category", name = MELT_CATEGORY },
})

-- The crushed-ice intermediate: a solid the crusher emits and the melter eats.
-- v1 art reuse: clone the vanilla ice item for a valid subgroup + icon.
local crushed_ice = util.table.deepcopy(data.raw["item"]["ice"])
crushed_ice.name = "cindra-crushed-ice"
crushed_ice.order = "b[cindra]-a[crushed-ice]"
crushed_ice.localised_name = { "item-name.cindra-crushed-ice" }
crushed_ice.localised_description = { "item-description.cindra-crushed-ice" }

-- === Stage 1: the crusher (SOLID -> SOLID, no fluid) ========================
-- A ground-standing clone of the space crusher. It grinds ice into crushed-ice;
-- it emits NO fluid (a crusher is not a boiler -- ci-4or).
local crusher = util.table.deepcopy(data.raw["assembling-machine"]["crusher"])
crusher.name = "cindra-ice-crusher"
crusher.minable = { mining_time = 0.2, result = "cindra-ice-crusher" }
crusher.fast_replaceable_group = nil -- not interchangeable with the space crusher
crusher.crafting_categories = { CRUSH_CATEGORY }

-- Drop the space-only gating so it can stand on Cindra's heavy-gravity ground,
-- and drop the space-platform heating draw (a platform mechanic, not Cindra's).
crusher.surface_conditions = nil
crusher.heating_energy = nil

-- Solid -> solid: NO fluid boxes. The vanilla space crusher has none; we add
-- none. Water is born at the melt step, never here.
crusher.fluid_boxes = nil

crusher.localised_name = { "entity-name.cindra-ice-crusher" }
crusher.localised_description = { "entity-description.cindra-ice-crusher" }

-- Item: clone the crusher item for a valid subgroup + vanilla icon (v1 art),
-- pointed at our entity.
local crusher_item = util.table.deepcopy(data.raw["item"]["crusher"])
crusher_item.name = "cindra-ice-crusher"
crusher_item.place_result = "cindra-ice-crusher"
crusher_item.order = "b[cindra]-b[ice-crusher]"
crusher_item.localised_name = { "item-name.cindra-ice-crusher" }
crusher_item.localised_description = { "item-description.cindra-ice-crusher" }

-- The two crush recipes. Both are disabled until the ice-processing tech; both
-- live in the private crushing category so only the Cindra crusher runs them.
-- Both output SOLID crushed-ice only -- no fluid.
local recipe_crush = {
  type = "recipe",
  name = "cindra-ice-crushing",
  categories = { CRUSH_CATEGORY },
  subgroup = "raw-material",
  order = "c[cindra]-a[ice-crush]",
  enabled = false,
  energy_required = CRUSH_SECONDS,
  ingredients = {
    { type = "item", name = "ice", amount = ICE_PER_BATCH },
  },
  results = {
    { type = "item", name = "cindra-crushed-ice", amount = CRUSHED_MAX },
  },
  allow_productivity = true,
  icon = "__space-age__/graphics/icons/ice.png",
  icon_size = 64,
  localised_name = { "recipe-name.cindra-ice-crushing" },
}

local recipe_crush_calcite = {
  type = "recipe",
  name = "cindra-ice-crushing-calcite",
  categories = { CRUSH_CATEGORY },
  subgroup = "raw-material",
  order = "c[cindra]-b[ice-calcite]",
  enabled = false,
  energy_required = CRUSH_SECONDS,
  ingredients = {
    { type = "item", name = "ice", amount = ICE_PER_BATCH },
  },
  results = {
    { type = "item", name = "cindra-crushed-ice", amount = CRUSHED_WITH_CALCITE },
    { type = "item", name = "calcite", amount = CALCITE_PER_BATCH },
  },
  allow_productivity = true,
  icon = "__space-age__/graphics/icons/calcite.png",
  icon_size = 64,
  localised_name = { "recipe-name.cindra-ice-crushing-calcite" },
}

-- Recipe to BUILD the crusher (gated behind the ice-processing tech).
local crusher_build = {
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

-- === Stage 2: the melter (SOLID -> FLUID) ===================================
-- A chemical-plant clone that turns crushed-ice into water. This is the ONLY
-- step that produces the fluid: the phase change happens under applied heat, not
-- in the grinder. We deep-copy the shared vanilla prototype and keep its fluid
-- boxes (the output box carries the water); we only retarget category/art.
local melter = util.table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])
melter.name = "cindra-ice-melter"
melter.minable = { mining_time = 0.3, result = "cindra-ice-melter" }
melter.fast_replaceable_group = nil -- not interchangeable with the chemical plant
melter.next_upgrade = nil
melter.crafting_categories = { MELT_CATEGORY }
melter.localised_name = { "entity-name.cindra-ice-melter" }
melter.localised_description = { "entity-description.cindra-ice-melter" }

-- Item: clone the chemical-plant item for a valid subgroup + vanilla icon (v1
-- art), pointed at our entity.
local melter_item = util.table.deepcopy(data.raw["item"]["chemical-plant"])
melter_item.name = "cindra-ice-melter"
melter_item.place_result = "cindra-ice-melter"
melter_item.order = "b[cindra]-c[ice-melter]"
melter_item.localised_name = { "item-name.cindra-ice-melter" }
melter_item.localised_description = { "item-description.cindra-ice-melter" }

-- The melt recipe: crushed-ice (item) -> water (fluid). Private melt category.
local recipe_melt = {
  type = "recipe",
  name = "cindra-ice-melting",
  categories = { MELT_CATEGORY },
  subgroup = "raw-material",
  order = "c[cindra]-c[ice-melt]",
  enabled = false,
  energy_required = MELT_SECONDS,
  ingredients = {
    { type = "item", name = "cindra-crushed-ice", amount = 1 },
  },
  results = {
    { type = "fluid", name = "water", amount = WATER_PER_SHARD },
  },
  allow_productivity = true,
  icon = "__space-age__/graphics/icons/ice.png",
  icon_size = 64,
  localised_name = { "recipe-name.cindra-ice-melting" },
}

-- Recipe to BUILD the melter (gated behind the ice-processing tech).
local melter_build = {
  type = "recipe",
  name = "cindra-ice-melter",
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 10 },
    { type = "item", name = "iron-gear-wheel", amount = 10 },
    { type = "item", name = "pipe", amount = 10 },
  },
  results = { { type = "item", name = "cindra-ice-melter", amount = 1 } },
}

-- The technology that opens ice processing: unlocks BOTH machines and all three
-- recipes (two crush + one melt). Gated behind Cindra's discovery. The full
-- Cindra tech tree (§15-12) will later fold this in.
local technology = {
  type = "technology",
  name = "cindra-ice-processing",
  icon = "__space-age__/graphics/icons/crusher.png",
  icon_size = 64,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-ice-crusher" },
    { type = "unlock-recipe", recipe = "cindra-ice-melter" },
    { type = "unlock-recipe", recipe = "cindra-ice-crushing" },
    { type = "unlock-recipe", recipe = "cindra-ice-crushing-calcite" },
    { type = "unlock-recipe", recipe = "cindra-ice-melting" },
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

data:extend({
  crushed_ice,
  crusher, crusher_item, recipe_crush, recipe_crush_calcite, crusher_build,
  melter, melter_item, recipe_melt, melter_build,
  technology,
})
