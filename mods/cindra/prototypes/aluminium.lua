-- Manufactured aluminium: the ruinous-power material (ci-txh; DESIGN.md §1, §5,
-- §7; sub-bead of the economy epic ci-4xj).
--
-- Cindra has NO native metal ores and NO petrochemistry -- everything is made
-- from rock, ice, and the star's surplus. Aluminium leans all the way into that
-- identity: it is the most POWER-EXPENSIVE thing the planet makes, so it slots in
-- as another big flare-timed POWER SINK next to manufactured lava (ci-8mw), the
-- mass driver (ci-epp), and water boil-off. Where the flare overflows, aluminium
-- is where that overflow goes.
--
-- MODELED ON REAL HALL-HEROULT ELECTROLYSIS, kept petrochemical-free (no plastic,
-- no sulfur, no oil, no acid):
--
--   1. REFINE  `stone + calcite -> alumina`  (a plain assembler craft). Alumina
--      is the white feedstock. Stone is the ribbon's central raw; calcite comes
--      from the ice chain (cindra-ice-crushing-calcite, ci-rgv), so aluminium
--      pulls demand back onto BOTH sides of the economy -- rock and ice.
--
--   2. ELECTROLYSE  `alumina + [RUINOUS electricity] -> aluminium`  in a dedicated
--      Cindra ELECTROLYSIS CELL. The cell has a large uncapped electric draw and
--      the recipe a long crafting time, so per-unit energy dwarfs a lava craft
--      (see the tune block). That energy IS the cost -- there is no fuel, no
--      carrier, no chemistry. Productivity is OFF so a prod bonus can never mint
--      cheap aluminium and undo the "power is the honest cost" identity (the same
--      rule manufactured lava follows).
--
-- PURPOSE (so it is not a dead-end; DESIGN.md §5, §12):
--   * DEMAND: aluminium is consumed by the flare CAPACITOR (storage.lua) as its
--     plates -- a real, textbook use (aluminium electrolytic capacitor) and a
--     poetic one: the power-metal builds the thing that stores the power. The
--     capacitor is optional recoverable storage (the dissipator, not the
--     capacitor, is the panel-damage safety floor), so this creates demand
--     WITHOUT gating flare survival behind aluminium -- no soft-lock.
--   * EXPORT: aluminium is a clean, high-value bulk good the mass driver can fling
--     to orbit on pure power + a native shell (ci-epp) -- a petrochemical-free
--     export that lands its whole cost on local metallurgy and the star. No recipe
--     is needed for that; the driver ships any item. Documented here as intent.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is brand new or a fresh
-- deep-copy (util.table.deepcopy) before any nested edit. The shared vanilla
-- `stone` / `calcite` items are read as INGREDIENTS only (never mutated), exactly
-- as the lava and ice chains already read them. A private recipe category keeps
-- the electrolysis recipe on the Cindra cell only, and vanilla smelting out of it.
--
-- v1 ART: placeholder art (bespoke icons filed as a follow-up, ci-txh art bead).
-- Alumina reuses the calcite icon tinted white; aluminium reuses the steel-plate
-- icon tinted a cool silver; the cell reuses the electric-furnace art.

local util = require("util")

local ALUMINA = "cindra-alumina"
local ALUMINIUM = "cindra-aluminium"
local CELL = "cindra-electrolysis-cell"
local CATEGORY = "cindra-electrolysis"      -- private: cell-only, keeps vanilla smelting out
local TECH = "cindra-aluminium"

-- === Tune block (all `(tune)`, DESIGN.md §7 / §15-14 ci-63d) =================
-- The refine step is cheap: it only assembles the feedstock. Power is NOT spent
-- here -- it is spent in electrolysis below, which is the whole point.
local STONE_PER_ALUMINA = 3
local CALCITE_PER_ALUMINA = 1
local ALUMINA_PER_REFINE = 2
local REFINE_SECONDS = 2

-- THE POWER LEVER. Aluminium's cost is a LARGE building draw times a LONG craft:
--   CELL_DRAW (50 MW) * (ELECTROLYSIS_SECONDS / cell crafting_speed 2) = ~400 MJ
--   per craft => ~200 MJ per aluminium. That is ~5x a manufactured-lava craft and
--   comparable to a mass-driver shot (500 MJ), so aluminium genuinely competes for
--   flare energy with the other big sinks. 50 MW is the largest single-building
--   draw on Cindra (above the electric heater's 40 MW), so it reads as the ruinous
--   one. Productivity is OFF (see recipe): power stays the honest cost.
local CELL_DRAW = "50MW"
local ELECTROLYSIS_SECONDS = 16
local ALUMINA_PER_ELECTROLYSIS = 4
local ALUMINIUM_PER_ELECTROLYSIS = 2

local function set_icon(proto, icon, tint)
  proto.icon = nil
  proto.icons = { { icon = icon, icon_size = 64, tint = tint } }
  proto.icon_size = 64
end

-- Private recipe category: ONLY the electrolysis cell runs the electrolysis
-- recipe, and nothing vanilla can (never-mutate-other-planets / no category leak).
local category = { type = "recipe-category", name = CATEGORY }

-- === Alumina: the white feedstock (cloned from calcite for a valid item def) ==
local alumina = util.table.deepcopy(data.raw.item["calcite"])
alumina.name = ALUMINA
alumina.order = "z[cindra]-a[alumina]"
alumina.stack_size = 100
-- Tint the calcite icon bright white so it reads as refined alumina powder.
set_icon(alumina, "__space-age__/graphics/icons/calcite.png", { r = 1.0, g = 1.0, b = 1.0, a = 1.0 })
alumina.localised_name = { "item-name.cindra-alumina" }
alumina.localised_description = { "item-description.cindra-alumina" }

-- === Aluminium: the ruinous-power metal (cloned from steel-plate) =============
local aluminium = util.table.deepcopy(data.raw.item["steel-plate"])
aluminium.name = ALUMINIUM
aluminium.order = "z[cindra]-b[aluminium]"
aluminium.stack_size = 100
-- Cool silver tint so it reads as light metal, distinct from steel.
set_icon(aluminium, "__base__/graphics/icons/steel-plate.png", { r = 0.80, g = 0.86, b = 0.95, a = 1.0 })
aluminium.localised_name = { "item-name.cindra-aluminium" }
aluminium.localised_description = { "item-description.cindra-aluminium" }

-- === The electrolysis cell: the big power sink ================================
-- Cloned from the electric furnace: it already has a correct electric energy
-- source and a smelting-style single-input flow, so feeding it alumina yields
-- aluminium. We restrict it to the private category and crank the electric draw.
local cell = util.table.deepcopy(data.raw["furnace"]["electric-furnace"])
cell.name = CELL
cell.minable = { mining_time = 0.5, result = CELL }
cell.crafting_categories = { CATEGORY }
cell.energy_usage = CELL_DRAW           -- the ruinous draw (uncapped, far above lava)
cell.fast_replaceable_group = nil       -- not interchangeable with the electric furnace
cell.next_upgrade = nil
cell.localised_name = { "entity-name.cindra-electrolysis-cell" }
cell.localised_description = { "entity-description.cindra-electrolysis-cell" }
-- v1 art reuse: keep the cloned electric-furnace sprite + icon (bespoke art TODO).

local cell_item = util.table.deepcopy(data.raw.item["electric-furnace"])
cell_item.name = CELL
cell_item.place_result = CELL
cell_item.order = "z[cindra]-c[electrolysis-cell]"
cell_item.localised_name = { "item-name.cindra-electrolysis-cell" }
cell_item.localised_description = { "item-description.cindra-electrolysis-cell" }

-- === Recipes =================================================================
-- REFINE: stone + calcite -> alumina. Plain "crafting" (assembler) category, so
-- no new building is needed and it belt-feeds cleanly. Native inputs only.
local alumina_recipe = {
  type = "recipe",
  name = ALUMINA,
  -- Default "crafting" category (omitted, like the coolant/build recipes): any
  -- assembler makes it, so no new building is needed and it belt-feeds cleanly.
  subgroup = "raw-material",
  order = "z[cindra]-a[alumina]",
  enabled = false, -- gated behind the aluminium tech, never free
  energy_required = REFINE_SECONDS,
  ingredients = {
    { type = "item", name = "stone", amount = STONE_PER_ALUMINA },
    { type = "item", name = "calcite", amount = CALCITE_PER_ALUMINA },
  },
  results = {
    { type = "item", name = ALUMINA, amount = ALUMINA_PER_REFINE },
  },
  allow_productivity = true,
  main_product = ALUMINA,
}

-- ELECTROLYSE: alumina + [RUINOUS power] -> aluminium. The single ingredient +
-- the cell's huge draw over a long craft is the whole cost. Productivity OFF so a
-- prod bonus can never mint cheap aluminium (power is the honest cost, per lava).
local aluminium_recipe = {
  type = "recipe",
  name = ALUMINIUM,
  categories = { CATEGORY },
  subgroup = "raw-material",
  order = "z[cindra]-b[aluminium]",
  enabled = false,
  energy_required = ELECTROLYSIS_SECONDS,
  ingredients = {
    { type = "item", name = ALUMINA, amount = ALUMINA_PER_ELECTROLYSIS },
  },
  results = {
    { type = "item", name = ALUMINIUM, amount = ALUMINIUM_PER_ELECTROLYSIS },
  },
  allow_productivity = false, -- power, not a prod bonus, is what aluminium costs
  main_product = ALUMINIUM,
}

-- Recipe to BUILD the cell (gated behind the tech). Native metal + electronics.
local cell_recipe = {
  type = "recipe",
  name = CELL,
  enabled = false,
  energy_required = 10,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "copper-plate", amount = 20 },
    { type = "item", name = "copper-cable", amount = 20 },
  },
  results = { { type = "item", name = CELL, amount = 1 } },
}

-- === Technology ==============================================================
-- Gated behind BOTH parent chains -- `cindra-lava` (the metal economy + the power
-- to run electrolysis) AND `cindra-ice-processing` (the calcite the refine step
-- needs) -- so aluminium is unreachable until the player commands both rock and
-- ice, exactly like the signature quench. The full Cindra tree (ci-3or) folds it
-- in later.
local technology = {
  type = "technology",
  name = TECH,
  -- v1 art reuse: the vanilla electric-furnace tech icon.
  icon = "__base__/graphics/technology/electronics.png",
  icon_size = 256,
  effects = {
    { type = "unlock-recipe", recipe = CELL },
    { type = "unlock-recipe", recipe = ALUMINA },
    { type = "unlock-recipe", recipe = ALUMINIUM },
  },
  prerequisites = { "cindra-lava", "cindra-ice-processing" },
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

data:extend({
  category,
  alumina, aluminium, cell, cell_item,
  alumina_recipe, aluminium_recipe, cell_recipe,
  technology,
})

-- Exposed for tests + downstream integration (storage.lua reads ALUMINIUM).
return {
  ALUMINA = ALUMINA,
  ALUMINIUM = ALUMINIUM,
  CELL = CELL,
  CATEGORY = CATEGORY,
  TECH = TECH,
  CELL_DRAW = CELL_DRAW,
  ELECTROLYSIS_SECONDS = ELECTROLYSIS_SECONDS,
  ALUMINIUM_PER_ELECTROLYSIS = ALUMINIUM_PER_ELECTROLYSIS,
}
