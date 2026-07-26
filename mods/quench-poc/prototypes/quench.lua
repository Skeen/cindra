-- Cryo-quench PoC prototypes: the two-temperature recipe made concrete.
--
-- This proves Cindra's SIGNATURE mechanic (planet_design.md §8 "Signature
-- product - cryo-hardened alloy") in isolation: a single craft that requires a
-- HOT input and a COLD input at the same time. Everything here is a STUB — the
-- hot fluid stands in for the eventual lava/foundry molten-metal output, and the
-- coolant item stands in for nightside-chilled cryo-coolant. The PoC does NOT
-- build the lava chain; it only answers the modeling question (see DESIGN.md).
--
-- Modeling choice proven here (DESIGN.md records the full trade-off):
--   * HOT input  = a FLUID ingredient, temperature-gated with
--     `minimum_temperature` (approach "b"). This makes "hot" a real, engine-
--     enforced property, not a name: molten metal below the threshold will not
--     craft.
--   * COLD input = a CONSUMED ITEM (approach "c"), matching the spec's
--     "start simple: cryo-coolant as a consumed material input".
--   * Combined the recipe is item + fluid (c) with a temperature gate (b).
--
-- All prototypes are cloned from base-game prototypes via util.table.deepcopy
-- so the PoC ships with ZERO external assets (every icon/sprite is inherited
-- and guaranteed valid) and loads clean next to Space Age.

local util = require("util")

local HOT = "quench-poc-molten-metal" -- stub hot fluid (future: molten metal)
local COOLANT = "quench-poc-cryo-coolant" -- stub cold consumed item
local ALLOY = "quench-poc-cryo-alloy" -- the signature output
local QUENCH = "quench-poc-cryo-quench" -- the two-temperature building
local CATEGORY = "quench-poc-quenching" -- isolated recipe category
local HOT_MIN = 500 -- °C: molten metal must be at least this hot to quench

-- Recipe category so ONLY the quench recipe runs in the quench building (keeps
-- the PoC from silently accepting vanilla recipes).
local category = { type = "recipe-category", name = CATEGORY }

-- Hot fluid stub. Cloned from water for a valid icon/definition, then widened
-- to a 15..1000 °C range so it can exist both "cold" (below the gate, for the
-- negative test) and "hot" (above the gate, for the real craft). Recoloured so
-- it reads as molten in-game.
local molten = util.table.deepcopy(data.raw.fluid["water"])
molten.name = HOT
molten.default_temperature = 15
molten.max_temperature = 1000
molten.base_color = { r = 0.90, g = 0.35, b = 0.10 }
molten.flow_color = { r = 1.00, g = 0.55, b = 0.20 }
molten.order = "z[quench-poc]-a[molten-metal]"

-- Cold consumed item stub (cryo-coolant). Cloned from iron-ore for a valid icon.
local coolant = util.table.deepcopy(data.raw.item["iron-ore"])
coolant.name = COOLANT
coolant.order = "z[quench-poc]-b[cryo-coolant]"
coolant.stack_size = 100

-- Signature output: cryo-hardened alloy. Cloned from steel-plate for a valid icon.
local alloy = util.table.deepcopy(data.raw.item["steel-plate"])
alloy.name = ALLOY
alloy.order = "z[quench-poc]-c[cryo-alloy]"

-- The two-temperature recipe: HOT fluid (temperature-gated) + COLD item -> alloy.
-- The `minimum_temperature` on the fluid ingredient is the whole point: it is
-- what makes "hot" real. Remove it and the recipe still needs two inputs, but
-- the hot input would be hot in name only.
local recipe = {
  type = "recipe",
  name = ALLOY,
  -- Factorio 2.1 merged recipe `category`/`additional_categories` into a single
  -- `categories` table.
  categories = { CATEGORY },
  enabled = true,
  energy_required = 0.5,
  ingredients = {
    { type = "fluid", name = HOT, amount = 50, minimum_temperature = HOT_MIN },
    { type = "item", name = COOLANT, amount = 5 },
  },
  results = {
    { type = "item", name = ALLOY, amount = 1 },
  },
}

-- The quench building. Cloned from the chemical plant because it already has a
-- correct electric energy source and input fluidbox(es) for the hot fluid, so
-- we inherit a known-good fluid-crafting machine instead of hand-rolling
-- fluidbox pipe connections. Restricted to the isolated quench category.
local machine = util.table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])
machine.name = QUENCH
machine.crafting_categories = { CATEGORY }
machine.minable = { mining_time = 0.2, result = QUENCH }
machine.next_upgrade = nil
machine.fast_replaceable_group = nil
machine.placeable_by = { item = QUENCH, count = 1 }

local machine_item = util.table.deepcopy(data.raw.item["chemical-plant"])
machine_item.name = QUENCH
machine_item.place_result = QUENCH
machine_item.order = "z[quench-poc]-d[cryo-quench]"

data:extend({ category, molten, coolant, alloy, recipe, machine, machine_item })
