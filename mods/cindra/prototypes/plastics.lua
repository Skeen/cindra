-- Calcite-To-Olefins: Cindra's petrochemical-free PLASTIC chain (ci-400).
--
-- Cindra has no oil and no biology, so it cannot make plastic the vanilla way
-- (coal + petroleum). This chain gives the planet plastic in its OWN idiom:
-- rock, ice, metal, and the star's surplus -- modeled on China's real CTO
-- (Coal-To-Olefins) route, but with CALCITE as the carbon source instead of
-- coal ("Calcite-To-Olefins"). Three linked chemistries connect into one belt-
-- and-pipe chain, all run in ordinary machines (no new building):
--
--   1. WATER ELECTROLYSIS   water + [power] -> hydrogen + oxygen
--        The star's power splits the nightside's water. Hydrogen is the reducer
--        that makes the calcite carbon usable; oxygen is a byproduct (vented).
--        (2 H2O -> 2 H2 + O2.)
--   2. CALCITE CALCINATION  calcite + [heat] -> lime + carbon dioxide
--        Roasting the ice chain's calcite drives off CO2 -- the CARBON that will
--        become plastic -- and leaves lime (a solid byproduct, vented).
--        (CaCO3 --heat--> CaO + CO2.)
--   3. METHANOL-TO-OLEFINS (the CTO route), via a copper-on-aluminium catalyst:
--        a. bridge:  CO2 + hydrogen -> methanol (+ water)   -- makes the calcite
--           carbon usable; this is what makes calcite the carbon source.
--           (CO2 + 3 H2 -> CH3OH + H2O.)
--        b. MTO:     methanol --(Cu/Al catalyst)--> olefins (+ water)
--           (2 CH3OH -> C2H4 + 2 H2O.) The catalyst is slow-consumed, not a 1:1
--           reagent (returned as product with high probability -- real catalyst
--           deactivation).
--        c. polymerise: olefins -> plastic (the vanilla `plastic-bar`, so it
--           plugs straight into vanilla advanced circuits etc.).
--           (n C2H4 -> polyethylene.)
--
-- BALANCE (vs vanilla `plastic-bar`, DESIGN.md §12 situational-not-strictly-
-- better). Vanilla makes plastic cheaply and fast (1 coal + 20 petroleum-gas ->
-- 2 plastic-bar in ~1 s). Cindra's route is a deliberately LONGER, power-heavier
-- multi-step chain -- the honest price of having no oil -- but it is not absurd:
-- the intermediate steps run in stock chemical plants, and the only ruinous-power
-- input is the small, slow-consumed Cu/Al catalyst (which carries the signature
-- `cindra-aluminium`, itself the planet's most power-hungry product). So plastic
-- throughput ends up tied to the same power economy as everything else on Cindra
-- without gating red circuits behind the endgame. Productivity is OFF on every
-- matter-conversion step so the calcite carbon budget stays honest -- a prod bonus
-- must never mint free carbon or free plastic (the same rule manufactured lava
-- and aluminium follow).
--
-- BYPRODUCT SINKS (bead requirement -- the chain must never deadlock): oxygen
-- (from electrolysis) and lime (from calcination) each get a dedicated vent
-- recipe that consumes them to nothing, so a backed-up byproduct pipe/box can
-- always be drained. Water is PARTLY RECOVERED (methanol + MTO hand water back),
-- which trims the chain's water draw without ever creating matter.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is brand new. The shared
-- vanilla `water` / `calcite` / `copper-plate` / `plastic-bar` are read as
-- ingredients/products only (never mutated); all new recipes are Cindra-gated
-- (`enabled = false`) and unlocked by a single new Cindra tech, so nothing leaks
-- into any other planet's progression. No stone/metal exploit is opened (ci-669):
-- the carbon comes from the ice chain's calcite, not from rock, and no step
-- returns stone or metal.
--
-- v1 ART: placeholder art. The gases reuse the vanilla petroleum-gas cloud icon
-- (distinct tints per gas); methanol reuses the water icon tinted; lime reuses
-- the calcite icon tinted; the catalyst reuses the copper-plate icon tinted.

local util = require("util")

-- New fluids (gases + two liquids), all Cindra-prefixed so they cannot collide
-- with vanilla or leak; display names are clean ("Hydrogen" ...) via locale.
local H2       = "cindra-hydrogen"
local O2       = "cindra-oxygen"
local CO2      = "cindra-carbon-dioxide"
local METHANOL = "cindra-methanol"
local OLEFINS  = "cindra-olefins"

-- New solids.
local LIME     = "cindra-lime"
local CATALYST = "cindra-cu-al-catalyst"

-- The signature power-metal (prototypes/aluminium.lua) the catalyst carries.
local ALUMINIUM = "cindra-aluminium"
local PLASTIC   = "plastic-bar" -- vanilla product: plugs into vanilla recipes

local TECH = "cindra-calcite-olefins"

-- === Tune block (all `(tune)`, DESIGN.md §7 / §15-14) ========================
-- Molar-consistent batches at "20 units = 1 mol-batch". Craft times are the
-- power lever (each second is chemical-plant kW spent); calcination is the
-- longest (it stands in for the roasting heat). Productivity is OFF everywhere
-- (matter honesty), so these ratios are fixed.
local ELECTROLYSIS_SECONDS = 2
local CALCINATION_SECONDS  = 4   -- "needs heat": paid as the longest craft
local METHANOL_SECONDS     = 3
local MTO_SECONDS          = 3
local POLYMERISE_SECONDS   = 2
local CATALYST_SECONDS     = 8
local CATALYST_RETURN      = 0.96 -- ~4% consumed per MTO craft (slow deactivation)

local function set_icon(proto, icon, tint)
  proto.icon = nil
  proto.icons = { { icon = icon, icon_size = 64, tint = tint } }
  proto.icon_size = 64
  proto.pictures = nil -- fall back to the (tinted) icon for belt/inventory art
end

local GAS_ICON  = "__base__/graphics/icons/fluid/petroleum-gas.png"
local LIQ_ICON  = "__base__/graphics/icons/fluid/water.png"
local CALCITE_ICON = "__space-age__/graphics/icons/calcite.png"
local COPPER_ICON  = "__base__/graphics/icons/copper-plate.png"

-- ---------------------------------------------------------------------------
-- Fluids. base_color/flow_color are what actually distinguish them in pipes.
-- ---------------------------------------------------------------------------
local function gas(name, base, flow, icon_tint)
  return {
    type = "fluid",
    name = name,
    subgroup = "fluid",
    default_temperature = 25,
    base_color = base,
    flow_color = flow,
    icons = { { icon = GAS_ICON, icon_size = 64, tint = icon_tint } },
    icon_size = 64,
    localised_name = { "fluid-name." .. name },
    localised_description = { "fluid-description." .. name },
    order = "z[cindra]-" .. name,
  }
end

local hydrogen = gas(H2,
  { r = 0.55, g = 0.75, b = 1.00 }, { r = 0.70, g = 0.85, b = 1.00 },
  { r = 0.60, g = 0.80, b = 1.00, a = 1.0 })
local oxygen = gas(O2,
  { r = 0.70, g = 0.95, b = 1.00 }, { r = 0.80, g = 0.98, b = 1.00 },
  { r = 0.75, g = 0.95, b = 1.00, a = 1.0 })
local carbon_dioxide = gas(CO2,
  { r = 0.55, g = 0.55, b = 0.60 }, { r = 0.65, g = 0.65, b = 0.70 },
  { r = 0.60, g = 0.60, b = 0.65, a = 1.0 })
local olefins = gas(OLEFINS,
  { r = 0.60, g = 0.90, b = 0.65 }, { r = 0.72, g = 0.95, b = 0.75 },
  { r = 0.65, g = 0.92, b = 0.70, a = 1.0 })

-- Methanol is a liquid; reuse the water icon tinted pale yellow.
local methanol = {
  type = "fluid",
  name = METHANOL,
  subgroup = "fluid",
  default_temperature = 25,
  base_color = { r = 0.90, g = 0.85, b = 0.55 },
  flow_color = { r = 0.95, g = 0.90, b = 0.60 },
  icons = { { icon = LIQ_ICON, icon_size = 64, tint = { r = 0.95, g = 0.90, b = 0.55, a = 1.0 } } },
  icon_size = 64,
  localised_name = { "fluid-name." .. METHANOL },
  localised_description = { "fluid-description." .. METHANOL },
  order = "z[cindra]-" .. METHANOL,
}

-- ---------------------------------------------------------------------------
-- Solids: lime (calcination byproduct) + the Cu/Al catalyst.
-- ---------------------------------------------------------------------------
local lime = util.table.deepcopy(data.raw.item["calcite"])
lime.name = LIME
lime.order = "z[cindra]-lime"
lime.stack_size = 100
set_icon(lime, CALCITE_ICON, { r = 0.95, g = 0.93, b = 0.85, a = 1.0 }) -- pale cream
lime.localised_name = { "item-name." .. LIME }
lime.localised_description = { "item-description." .. LIME }

local catalyst = util.table.deepcopy(data.raw.item["copper-plate"])
catalyst.name = CATALYST
catalyst.order = "z[cindra]-catalyst"
catalyst.stack_size = 50
set_icon(catalyst, COPPER_ICON, { r = 0.85, g = 0.70, b = 0.55, a = 1.0 }) -- copper-on-silver
catalyst.localised_name = { "item-name." .. CATALYST }
catalyst.localised_description = { "item-description." .. CATALYST }

-- ---------------------------------------------------------------------------
-- Recipes. All run in the vanilla chemical plant (category "chemistry") except
-- the catalyst (a plain assembler craft). All gated off until the tech.
-- ---------------------------------------------------------------------------
local electrolysis = {
  type = "recipe",
  name = "cindra-electrolysis",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-a[electrolysis]",
  enabled = false,
  energy_required = ELECTROLYSIS_SECONDS,
  ingredients = {
    { type = "fluid", name = "water", amount = 40 },
  },
  results = {
    { type = "fluid", name = H2, amount = 40 },
    { type = "fluid", name = O2, amount = 20 },
  },
  allow_productivity = false, -- power/matter honesty: no minting gas from nothing
  main_product = H2,
  crafting_machine_tint = { primary = { r = 0.6, g = 0.8, b = 1.0 } },
}

local calcination = {
  type = "recipe",
  name = "cindra-calcination",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-b[calcination]",
  enabled = false,
  energy_required = CALCINATION_SECONDS, -- the "heat": the longest craft
  ingredients = {
    { type = "item", name = "calcite", amount = 2 },
  },
  results = {
    { type = "item", name = LIME, amount = 2 },
    { type = "fluid", name = CO2, amount = 40 },
  },
  allow_productivity = false, -- fixed carbon budget: no free CO2
  main_product = CO2,
  icons = { { icon = GAS_ICON, icon_size = 64, tint = { r = 0.60, g = 0.60, b = 0.65, a = 1.0 } } },
}

local methanol_synthesis = {
  type = "recipe",
  name = "cindra-methanol-synthesis",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-c[methanol]",
  enabled = false,
  energy_required = METHANOL_SECONDS,
  ingredients = {
    { type = "fluid", name = CO2, amount = 20 },
    { type = "fluid", name = H2, amount = 60 },
  },
  results = {
    { type = "fluid", name = METHANOL, amount = 20 },
    { type = "fluid", name = "water", amount = 20 }, -- recovered, loops back
  },
  allow_productivity = false,
  main_product = METHANOL,
  crafting_machine_tint = { primary = { r = 0.9, g = 0.85, b = 0.55 } },
}

-- MTO: the Cu/Al-catalysed step. The catalyst is an ingredient AND a product
-- returned with high probability, so it is slow-consumed (a real catalyst),
-- never a 1:1 reagent. Water is handed back.
local mto = {
  type = "recipe",
  name = "cindra-mto",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-d[mto]",
  enabled = false,
  energy_required = MTO_SECONDS,
  ingredients = {
    { type = "fluid", name = METHANOL, amount = 40 },
    { type = "item", name = CATALYST, amount = 1 },
  },
  results = {
    { type = "fluid", name = OLEFINS, amount = 20 },
    { type = "fluid", name = "water", amount = 40 }, -- recovered, loops back
    -- The catalyst survives most crafts (slow deactivation): returned at high
    -- probability, so it is topped up occasionally rather than consumed 1:1.
    -- `independent_probability`: each catalyst product is rolled on its own (the
    -- 2.1 rename of the old per-product `probability`).
    { type = "item", name = CATALYST, amount = 1, independent_probability = CATALYST_RETURN },
  },
  allow_productivity = false,
  main_product = OLEFINS,
  crafting_machine_tint = { primary = { r = 0.65, g = 0.92, b = 0.70 } },
}

local polymerisation = {
  type = "recipe",
  name = "cindra-polymerisation",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-e[polymerisation]",
  enabled = false,
  energy_required = POLYMERISE_SECONDS,
  ingredients = {
    { type = "fluid", name = OLEFINS, amount = 20 },
  },
  results = {
    { type = "item", name = PLASTIC, amount = 2 },
  },
  allow_productivity = false, -- no minting free plastic (balance vs vanilla)
  main_product = PLASTIC,
}

-- Catalyst craft: copper (from the lava-cast copper chain) + the signature
-- aluminium. This is the only ruinous-power input to the plastic chain -- and it
-- is slow-consumed, so plastic rides the power economy without being gated on it.
local catalyst_recipe = {
  type = "recipe",
  name = CATALYST,
  -- default "crafting" category: any assembler makes it, belt-feeds cleanly.
  subgroup = "raw-material",
  order = "z[cindra]-catalyst",
  enabled = false,
  energy_required = CATALYST_SECONDS,
  ingredients = {
    { type = "item", name = "copper-plate", amount = 5 },
    { type = "item", name = ALUMINIUM, amount = 3 },
  },
  results = {
    { type = "item", name = CATALYST, amount = 1 },
  },
  allow_productivity = false, -- a catalyst, not an intermediate: no prod shortcut
  main_product = CATALYST,
}

-- ---------------------------------------------------------------------------
-- Byproduct vents (anti-deadlock). Each consumes a byproduct to nothing so a
-- backed-up pipe/box can always be drained; the player sets these on a spare
-- chemical plant / assembler only as needed.
-- ---------------------------------------------------------------------------
local vent_oxygen = {
  type = "recipe",
  name = "cindra-vent-oxygen",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-y[vent-oxygen]",
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "fluid", name = O2, amount = 100 },
  },
  results = {}, -- vented to atmosphere: a pure sink
  allow_productivity = false,
  icons = { { icon = GAS_ICON, icon_size = 64, tint = { r = 0.75, g = 0.95, b = 1.0, a = 1.0 } } },
  localised_name = { "recipe-name.cindra-vent-oxygen" },
  localised_description = { "recipe-description.cindra-vent-oxygen" },
}

local vent_lime = {
  type = "recipe",
  name = "cindra-vent-lime",
  -- default "crafting": an assembler can dump lime (a solid) with no fluid box.
  subgroup = "raw-material",
  order = "z[cindra]-y[vent-lime]",
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "item", name = LIME, amount = 10 },
  },
  results = {}, -- discarded: a pure sink
  allow_productivity = false,
  icons = { { icon = CALCITE_ICON, icon_size = 64, tint = { r = 0.95, g = 0.93, b = 0.85, a = 1.0 } } },
  localised_name = { "recipe-name.cindra-vent-lime" },
  localised_description = { "recipe-description.cindra-vent-lime" },
}

-- ---------------------------------------------------------------------------
-- The gating tech. Prereq is the signature `cindra-aluminium` (which itself
-- needs BOTH the lava spine and the ice chain), because the catalyst consumes
-- aluminium -- so plastic is only reachable once the whole base economy (rock,
-- ice, power-metal) is in hand. Researched with the brought vanilla packs, like
-- the aluminium tech, so it does not soft-lock behind the endgame science pack.
-- ---------------------------------------------------------------------------
local technology = {
  type = "technology",
  name = TECH,
  icon = GAS_ICON,
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-electrolysis" },
    { type = "unlock-recipe", recipe = "cindra-calcination" },
    { type = "unlock-recipe", recipe = "cindra-methanol-synthesis" },
    { type = "unlock-recipe", recipe = "cindra-mto" },
    { type = "unlock-recipe", recipe = "cindra-polymerisation" },
    { type = "unlock-recipe", recipe = CATALYST },
    { type = "unlock-recipe", recipe = "cindra-vent-oxygen" },
    { type = "unlock-recipe", recipe = "cindra-vent-lime" },
  },
  prerequisites = { "cindra-aluminium" },
  unit = {
    count = 150,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  },
}

data:extend({
  hydrogen, oxygen, carbon_dioxide, methanol, olefins,
  lime, catalyst,
  electrolysis, calcination, methanol_synthesis, mto, polymerisation,
  catalyst_recipe, vent_oxygen, vent_lime,
  technology,
})

-- Exposed for tests + downstream integration.
return {
  H2 = H2, O2 = O2, CO2 = CO2, METHANOL = METHANOL, OLEFINS = OLEFINS,
  LIME = LIME, CATALYST = CATALYST, PLASTIC = PLASTIC, TECH = TECH,
  CATALYST_RETURN = CATALYST_RETURN,
}
