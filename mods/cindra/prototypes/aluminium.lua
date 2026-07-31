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
-- MODELED ON REAL ACID LEACHING + HALL-HEROULT ELECTROLYSIS (ci-6vj S2, DESIGN
-- §8, recipes #5/#6). No oil, no coal, no plastic -- sulfuric acid is the one
-- honest chemical input, itself made from Cindra's own sulfur (a stone-melt
-- byproduct) via the vanilla acid recipe the lava tech unlocks:
--
--   1. LEACH  `20 stone + 30 sulfuric-acid + 20 water -> 10 alumina + 14 stone
--      + 2 sulfur`  in a vanilla CHEMICAL PLANT (category "chemistry"). Alumina is
--      the white feedstock. Stone is the ribbon's central raw; the leach is net
--      stone-NEGATIVE (20 in, only 14 back) and the acid ties alumina into the
--      sulfur/acid loop. The 14 stone + 2 sulfur returns are
--      `ignored_by_productivity` and productivity is OFF, so no module tier can
--      flip the leach stone-positive (matter honesty, ci-669 / DESIGN §8.6).
--
--   2. ELECTROLYSE  `4 alumina + [RUINOUS electricity] -> 2 aluminium + 30 O2`  in
--      the dedicated Cindra ELECTROLYSIS CELL (the §2 signature building). The cell
--      has a large uncapped electric draw and the recipe a long crafting time, so
--      per-unit energy dwarfs a lava craft (see the tune block). That energy IS the
--      cost. The step vents `cindra-oxygen` gas through an output fluid box -- the
--      O2 economy's dominant source (DESIGN §8.4); O2's early sink is the existing
--      vent-oxygen recipe. Productivity is ON: aluminium is an intermediate (a
--      plate-analog) so a prod bonus is a fair reward (per lava), and the O2
--      byproduct is `ignored_by_productivity` so prod can never mint free gas.
--
-- PURPOSE (so it is not a dead-end; DESIGN.md §5, §12):
--   * DEMAND: aluminium is consumed by the flare CAPACITOR (storage.lua) as its
--     plates -- a real, textbook use (aluminium electrolytic capacitor) and a
--     poetic one: the power-metal builds the thing that stores the power. The
--     capacitor is optional recoverable storage (the dissipator, not the
--     capacitor, is the panel-damage safety floor), so this creates demand
--     WITHOUT gating flare survival behind aluminium -- no soft-lock.
--   * EXPORT: aluminium is a clean, high-value bulk good, AND the very stuff the
--     mass driver (ci-o39, ci-loa) burns to launch -- raw aluminium is fed straight
--     into the silo's internal launch-vehicle build (no pre-pressed can), and it
--     also grinds into the nano-aluminium powder the "ALICE solid rocket fuel" recipe
--     reacts with ICE into VANILLA rocket-fuel (ci-519, ci-8g1). So the launch chain
--     lands its whole recurring cost back on this ruinous-power metal + power:
--     local metallurgy and the star, never chemistry.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is brand new or a fresh
-- deep-copy (util.table.deepcopy) before any nested edit. The shared vanilla
-- `stone` / `sulfuric-acid` / `water` / `sulfur` prototypes are read as recipe
-- ingredients/results only (never mutated), exactly as the lava and ice chains
-- already read them; the shared `cindra-oxygen` fluid lives in plastics.lua and is
-- referenced here by name only. A private recipe category keeps the electrolysis
-- recipe on the Cindra cell only, and vanilla smelting out of it.
--
-- ART: bespoke item icons (ci-6vj S6) for alumina (white refined-mineral render)
-- and aluminium (aluminium-plate render), from Malcolm Riley's `unused-renders`
-- (CC-BY-4.0); see graphics/ART-MANIFEST.md. The electrolysis CELL entity still
-- reuses the electric-furnace art (bespoke building art tracked in ci-wfv).

local util = require("util")

local ALUMINA = "cindra-alumina"
local ALUMINIUM = "cindra-aluminium"
local CELL = "cindra-electrolysis-cell"
local CATEGORY = "cindra-electrolysis"      -- private: cell-only, keeps vanilla smelting out
local TECH = "cindra-aluminium"
local OXYGEN = "cindra-oxygen"              -- shared fluid, defined in plastics.lua (§8)

-- === Tune block (all `(tune)`, DESIGN.md §7 / §15-14 ci-63d; §8 recipe #5/#6) =
-- The leach step is a matter-conversion in a chemical plant: power is NOT the
-- lever here (it is spent in electrolysis below, which is the whole point), so it
-- runs at a modest craft time. It is deliberately net stone-NEGATIVE and
-- productivity-immune (see the recipe) so no module tier can mint free stone.
local STONE_PER_LEACH = 20
local ACID_PER_LEACH = 30          -- sulfuric-acid (fluid), from the vanilla recipe cindra-lava unlocks
local WATER_PER_LEACH = 20         -- water (fluid), from ice-melting
local ALUMINA_PER_LEACH = 10
local STONE_BACK_PER_LEACH = 14    -- ignored_by_productivity: fixed return, keeps the leach net -6 stone
local SULFUR_BACK_PER_LEACH = 2    -- ignored_by_productivity: a second sulfur source feeding the acid loop
local LEACH_SECONDS = 4

-- THE POWER LEVER. Aluminium's cost is a LARGE building draw times a LONG craft:
--   CELL_DRAW (50 MW) * (ELECTROLYSIS_SECONDS / cell crafting_speed 2) = ~400 MJ
--   per craft => ~200 MJ per aluminium. That is ~5x a manufactured-lava craft, so
--   aluminium genuinely competes for flare energy with the other big sinks. 50 MW
--   is the largest CONTINUOUS single-building draw on Cindra (above the electric
--   heater's 40 MW); only the mass driver's bursty per-launch charge (ci-o39) costs
--   more, and briefly. Productivity is ON for aluminium (an intermediate), but the
--   O2 byproduct is ignored_by_productivity, so power stays the honest cost.
local CELL_DRAW = "50MW"
local ELECTROLYSIS_SECONDS = 16
local ALUMINA_PER_ELECTROLYSIS = 4
local ALUMINIUM_PER_ELECTROLYSIS = 2
local OXYGEN_PER_ELECTROLYSIS = 30      -- ignored_by_productivity: the O2 economy's dominant source (§8.4)

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
-- Bespoke render (ci-6vj S6): a white refined-mineral pile (silica-gel render) that
-- reads as alumina powder. Source + attribution in graphics/ART-MANIFEST.md.
set_icon(alumina, "__cindra__/graphics/icons/cindra-alumina.png")
alumina.localised_name = { "item-name.cindra-alumina" }
alumina.localised_description = { "item-description.cindra-alumina" }

-- === Aluminium: the ruinous-power metal (cloned from steel-plate) =============
local aluminium = util.table.deepcopy(data.raw.item["steel-plate"])
aluminium.name = ALUMINIUM
aluminium.order = "z[cindra]-b[aluminium]"
aluminium.stack_size = 100
-- Bespoke render (ci-6vj S6): a genuine aluminium plate render, distinct from steel.
-- Source + attribution in graphics/ART-MANIFEST.md.
set_icon(aluminium, "__cindra__/graphics/icons/cindra-aluminium.png")
aluminium.localised_name = { "item-name.cindra-aluminium" }
aluminium.localised_description = { "item-description.cindra-aluminium" }

-- Bespoke building art (ci-eb9): the electrolysis cell finally reads as its own
-- machine, not the reused electric-furnace sprite. Static single-frame body +
-- projected shadow from the ART-MANIFEST generator (scripts/gen-entity-art.py),
-- one visual family with the other delivered Cindra buildings
-- (graphics/ART-MANIFEST.md): a steel electrolytic pot, carbon anodes, a ruinous
-- violet power arc, an aluminium bath, and the O2 it vents.
local ART = "electrolysis-cell"
local ENTITY_GFX = "__cindra__/graphics/entity/" .. ART .. "/"
local ICON_GFX = "__cindra__/graphics/icons/" .. ART .. ".png"

-- Wear the bespoke 64px icon; drop any inherited layered electric-furnace icon.
local function bespoke_icon(proto)
  proto.icon = ICON_GFX
  proto.icons = nil
  proto.icon_size = 64
  proto.icon_mipmaps = 4
end

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
-- The electric furnace has no fluid box; electrolysis vents O2 gas, so give the
-- cell a single OUTPUT fluid box on its north edge. The furnace still auto-selects
-- the private-category recipe from its input item (alumina); the O2 leaves here.
-- pipe_covers/pipe_picture are omitted (v1 art reuse) -- the connection still works.
cell.fluid_boxes = {
  {
    production_type = "output",
    volume = 1000,
    pipe_connections = {
      { flow_direction = "output", direction = defines.direction.north, position = { 0, -1 } },
    },
  },
}
cell.fluid_boxes_off_when_no_fluid_recipe = true

-- Bespoke art wiring (ci-eb9). The deep-copied electric furnace brings its OWN
-- graphics_set; replace it wholesale with the Cindra electrolysis-cell sprite so
-- the cell no longer looks like an electric furnace. A furnace renders from
-- graphics_set.animation (see scripts/graphics-audit.lua RENDER_FIELDS), so the
-- sprite MUST live there or the cell would be invisible in world. A single
-- Animation (with layers) applies to every direction; v1 is a static frame (no
-- working animation, per the ART-MANIFEST scope note) -- body + projected shadow.
cell.graphics_set = {
  animation = {
    layers = {
      { -- static cell body
        filename = ENTITY_GFX .. ART .. ".png",
        width = 256, height = 256, scale = 0.5, shift = { 0, -0.1 },
      },
      { -- projected ground shadow
        filename = ENTITY_GFX .. ART .. "-shadow.png",
        width = 256, height = 256, scale = 0.5, shift = { 0.3, 0 }, draw_as_shadow = true,
      },
    },
  },
}
-- Drop electric-furnace overlays that would otherwise render the furnace's own
-- working effects on top of the bespoke body (graphics_set was replaced above, so
-- any nested working_visualisations are already gone; clear the top-level fields
-- too, defensively, matching lava.lua's foundry-clone cleanup).
cell.graphics_set_flipped = nil
cell.working_visualisations = nil
bespoke_icon(cell)

local cell_item = util.table.deepcopy(data.raw.item["electric-furnace"])
cell_item.name = CELL
cell_item.place_result = CELL
cell_item.order = "z[cindra]-c[electrolysis-cell]"
cell_item.pictures = nil -- drop any inherited electric-furnace item pictures/variants
bespoke_icon(cell_item)
cell_item.localised_name = { "item-name.cindra-electrolysis-cell" }
cell_item.localised_description = { "item-description.cindra-electrolysis-cell" }

-- === Recipes =================================================================
-- LEACH: 20 stone + 30 sulfuric-acid + 20 water -> 10 alumina + 14 stone + 2
-- sulfur, in a vanilla CHEMICAL PLANT ("chemistry" category -- it needs fluid
-- boxes for the acid + water in and no new building). The 14-stone + 2-sulfur
-- returns are `ignored_by_productivity` (fixed at every module tier) and
-- productivity is OFF, so the leach is provably net stone-NEGATIVE (20 in, 14
-- back = -6/craft) forever -- no prod tier can mint free stone (ci-669 / §8.6).
local alumina_recipe = {
  type = "recipe",
  name = ALUMINA,
  categories = { "chemistry" }, -- vanilla chemical plant: has the fluid boxes the acid + water need
  subgroup = "raw-material",
  order = "z[cindra]-a[alumina]",
  enabled = false, -- gated behind the aluminium tech, never free
  energy_required = LEACH_SECONDS,
  ingredients = {
    { type = "item", name = "stone", amount = STONE_PER_LEACH },
    { type = "fluid", name = "sulfuric-acid", amount = ACID_PER_LEACH },
    { type = "fluid", name = "water", amount = WATER_PER_LEACH },
  },
  results = {
    { type = "item", name = ALUMINA, amount = ALUMINA_PER_LEACH },
    -- Fixed matter returns: pinned out of any prod bonus so the leach stays net
    -- stone-negative and only ever tops the acid loop with a trickle of sulfur.
    { type = "item", name = "stone", amount = STONE_BACK_PER_LEACH, ignored_by_productivity = STONE_BACK_PER_LEACH },
    { type = "item", name = "sulfur", amount = SULFUR_BACK_PER_LEACH, ignored_by_productivity = SULFUR_BACK_PER_LEACH },
  },
  -- Productivity OFF: a matter-conversion step. A prod bonus would cut stone-in
  -- per alumina and could let the fixed 14-stone return overtake it -- the exact
  -- self-sustain the stone-negativity invariant closes (per the lava recipe).
  allow_productivity = false,
  main_product = ALUMINA,
}

-- ELECTROLYSE: 4 alumina + [RUINOUS power] -> 2 aluminium + 30 O2. The single item
-- ingredient + the cell's huge draw over a long craft is the dominant cost. The
-- O2 gas leaves via the cell's output fluid box (the O2 economy's dominant source,
-- §8.4; early sink = the vent-oxygen recipe in plastics.lua). Productivity ON:
-- aluminium is an intermediate (a plate-analog), so a prod bonus is a fair reward
-- and matches vanilla intermediate conventions (per lava); the O2 byproduct is
-- `ignored_by_productivity` so a prod bonus can never mint free oxygen.
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
    { type = "fluid", name = OXYGEN, amount = OXYGEN_PER_ELECTROLYSIS, ignored_by_productivity = OXYGEN_PER_ELECTROLYSIS },
  },
  allow_productivity = true, -- intermediate: prod is a fair reward (per lava); power stays the dominant cost
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
-- Gated behind `cindra-lava` (the metal economy + the power to run electrolysis).
-- The leach's sulfuric-acid input is exactly what `cindra-lava` unlocks (the
-- vanilla `sulfur + iron-plate + water -> sulfuric-acid` recipe, fed by the
-- stone-melt sulfur byproduct, ci-eat), and its water comes from ice-melting -- so
-- everything the leach needs is already in hand behind this one prereq. The gate
-- that keeps aluminium late is `cindra-lava` (rock + power + the acid loop), so
-- aluminium is still unreachable until the player commands both rock and ice. As
-- the signature apex (ci-84s) it gates the headline science tech, and the full
-- Cindra tree (ci-3or) folds it in.
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
  prerequisites = { "cindra-lava" },
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
