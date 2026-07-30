-- Cindra's petrochemical-free PLASTIC chain (DESIGN §8, ci-6vj reconciliation of
-- the ci-400 plastics prototype).
--
-- Cindra has no oil and no biology, so it cannot make plastic the vanilla way
-- (coal + petroleum). This chain gives the planet plastic in its OWN idiom:
-- rock, ice, metal, and the star's surplus -- modeled on China's real
-- Methanol-To-Olefins (MTO) route, but with CALCITE as the carbon source instead
-- of coal. All the wet chemistry runs in ordinary chemical plants; the two
-- catalysts and the solid crafts run in ordinary assemblers; only the roast lives
-- in the signature lava manufacturer. No new building is added here.
--
--   1. WATER ELECTROLYSIS   water + [power] -> hydrogen + oxygen
--        The star's power splits the nightside's water. Hydrogen is the reducer
--        that makes the calcite carbon usable; oxygen is a byproduct.
--        (2 H2O -> 2 H2 + O2.)
--   2. CALCITE CALCINATION  calcite + [heat] -> quicklime + carbon dioxide
--        Roasting the ice chain's calcite drives off CO2 -- the CARBON that will
--        become plastic -- and leaves quicklime (feeds the zeolite catalyst;
--        surplus is sinkable via disposal or the vent, §8.4).
--        (CaCO3 --heat--> CaO + CO2.)
--   3. METHANOL SYNTHESIS + MTO, via TWO distinct catalyst systems (DESIGN §8.3):
--        a. bridge:  CO2 + hydrogen --(methanol catalyst)--> methanol (+ water)
--           makes the calcite carbon usable. The methanol catalyst (copper on
--           alumina) is slow-consumed -- returned 70% intact, 20% spent per craft.
--           (CO2 + 3 H2 -> CH3OH + H2O.)
--        b. MTO + polymerise:  methanol --(zeolite catalyst)--> plastic (+ water)
--           one step: the zeolite cracks methanol to olefins and they polymerise
--           to the vanilla `plastic-bar` (so it plugs straight into vanilla
--           advanced circuits etc.). The zeolite catalyst is likewise slow-
--           consumed (70% intact, 20% spent). (n CH3OH -> ... -> polyethylene.)
--
-- TWO CATALYSTS, EACH A CLOSED LOOP (DESIGN §8.3). The methanol catalyst is made
-- from `10 copper + 2 alumina`; its spent form reprocesses with acid back to `6
-- copper + 1 alumina`. The zeolite catalyst is made from `8 stone + 3 alumina + 2
-- quicklime + 100 steam`; its spent form regenerates with oxygen back to a live
-- catalyst. Each returns 70% intact + 20% spent per craft (independent rolls), so
-- the ~10% net loss per craft is a small make-up feed from the make recipe -- a
-- real catalyst, never a 1:1 reagent. Productivity is OFF on every matter-
-- conversion step (matter honesty), so a prod bonus can never mint free carbon,
-- metal, or plastic (the same rule manufactured lava and aluminium follow).
--
-- BALANCE (vs vanilla `plastic-bar`, DESIGN.md §12 situational-not-strictly-
-- better). Vanilla makes plastic cheaply and fast. Cindra's route is a
-- deliberately LONGER, power-heavier multi-step chain -- the honest price of
-- having no oil -- but it is not absurd: the steps run in stock machines, and the
-- only ruinous-power inputs are the small, slow-consumed catalysts (which carry
-- the signature `cindra-aluminium`/`cindra-alumina`, the planet's most power-
-- hungry products). So plastic throughput ends up tied to the same power economy
-- as everything else on Cindra without gating red circuits behind the endgame.
--
-- BYPRODUCT SINKS (§8.4 -- the chain must never deadlock): oxygen (electrolysis),
-- CO2 (calcination), and quicklime (calcination) each get a dedicated vent recipe
-- that consumes them to nothing, so a backed-up byproduct pipe/box can always be
-- drained. Quicklime additionally has a real (non-vent) sink -- disposal back into
-- the lava melt (§8 #16) -- and a real consumer (the zeolite catalyst). Spent
-- catalysts are never dead items: each reprocesses/regenerates back to the live
-- catalyst. Water is PARTLY RECOVERED (methanol synthesis + MTO hand water back),
-- which trims the chain's water draw without ever creating matter.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is brand new. The shared
-- vanilla `water` / `calcite` / `copper-plate` / `stone` / `steam` / `sulfuric-
-- acid` / `plastic-bar` are read as ingredients/products only (never mutated); all
-- new recipes are Cindra-gated (`enabled = false`) and unlocked by a single new
-- Cindra tech, so nothing leaks into any other planet's progression. No
-- stone/metal exploit is opened (ci-669): the carbon comes from the ice chain's
-- calcite, not from rock, and the stone the zeolite catalyst consumes is a real
-- (net) draw.
--
-- v1 ART: placeholder art. The gases reuse the vanilla petroleum-gas cloud icon
-- (distinct tints per gas); methanol reuses the water icon tinted; quicklime
-- reuses the calcite icon tinted; the catalysts reuse the copper-plate / calcite
-- icon tinted (spent forms darker).

local util = require("util")

-- New fluids (gases + one liquid), all Cindra-prefixed so they cannot collide
-- with vanilla or leak; display names are clean ("Hydrogen" ...) via locale. The
-- ci-400 `cindra-olefins` intermediate is GONE: MTO+polymerisation is one step.
local H2       = "cindra-hydrogen"
local O2       = "cindra-oxygen"
local CO2      = "cindra-carbon-dioxide"
local METHANOL = "cindra-methanol"

-- New solids. QUICKLIME (CaO, ci-6vj rename of the old "lime"): the calcination
-- co-product and, in the authoritative graph (DESIGN §8), the zeolite-catalyst
-- feed. Named `cindra-quicklime` so the whole graph shares one interface.
local QUICKLIME = "cindra-quicklime"

-- The two catalyst systems (DESIGN §8, ci-6vj). Each has a live form and a spent
-- form; the ci-400 single `cindra-cu-al-catalyst` is REPLACED by this pair.
local MCAT       = "cindra-methanol-catalyst"        -- copper-on-alumina (methanol synthesis)
local MCAT_SPENT = "cindra-spent-methanol-catalyst"
local ZCAT       = "cindra-zeolite-catalyst"          -- aluminosilicate (MTO+polymerisation)
local ZCAT_SPENT = "cindra-spent-zeolite-catalyst"

-- Vanilla fluids/items the ci-6vj graph reads (never mutated).
local LAVA  = "lava"
local STONE = "stone"
local STEAM = "steam"
local SULFURIC_ACID = "sulfuric-acid"

-- The lava-manufacturer's private category (defined in prototypes/lava.lua, which
-- loads before this file). Calcination and quicklime disposal run here, in the
-- high-heat furnace.
local LAVA_CATEGORY = "cindra-lava-manufacturing"

-- The signature power feedstocks (prototypes/aluminium.lua) the catalysts carry.
local ALUMINA   = "cindra-alumina"
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
local MCAT_SECONDS         = 8
local ZCAT_SECONDS         = 8
local REPROCESS_SECONDS    = 4
local REGEN_SECONDS        = 4
-- Each catalyst survives 70% of crafts intact and is 20% spent (independent
-- rolls); the ~10% net loss is topped up by the make recipe (DESIGN §8.3).
local CAT_RETURN = 0.70
local CAT_SPENT  = 0.20

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
-- Solids: quicklime (calcination byproduct) + the two catalyst systems, each
-- with a live and a spent form. All Cindra-prefixed clones of vanilla items.
-- ---------------------------------------------------------------------------
local quicklime = util.table.deepcopy(data.raw.item["calcite"])
quicklime.name = QUICKLIME
quicklime.order = "z[cindra]-quicklime"
quicklime.stack_size = 100
set_icon(quicklime, CALCITE_ICON, { r = 0.95, g = 0.93, b = 0.85, a = 1.0 }) -- pale cream
quicklime.localised_name = { "item-name." .. QUICKLIME }
quicklime.localised_description = { "item-description." .. QUICKLIME }

-- Catalyst item factory: clone a vanilla item, retint, relabel. `spent` variants
-- get a darker/greyer tint to read as "used up".
local function catalyst_item(name, base_icon, tint, order)
  local it = util.table.deepcopy(data.raw.item["copper-plate"])
  it.name = name
  it.order = order
  it.stack_size = 50
  set_icon(it, base_icon, tint)
  it.localised_name = { "item-name." .. name }
  it.localised_description = { "item-description." .. name }
  return it
end

local methanol_catalyst = catalyst_item(MCAT, COPPER_ICON,
  { r = 0.85, g = 0.70, b = 0.55, a = 1.0 }, "z[cindra]-catalyst-a[methanol]") -- copper-on-alumina
local spent_methanol_catalyst = catalyst_item(MCAT_SPENT, COPPER_ICON,
  { r = 0.45, g = 0.40, b = 0.38, a = 1.0 }, "z[cindra]-catalyst-b[methanol-spent]") -- dulled
local zeolite_catalyst = catalyst_item(ZCAT, CALCITE_ICON,
  { r = 0.80, g = 0.88, b = 0.95, a = 1.0 }, "z[cindra]-catalyst-c[zeolite]") -- pale blue mineral
local spent_zeolite_catalyst = catalyst_item(ZCAT_SPENT, CALCITE_ICON,
  { r = 0.45, g = 0.48, b = 0.52, a = 1.0 }, "z[cindra]-catalyst-d[zeolite-spent]") -- greyed

-- ---------------------------------------------------------------------------
-- Recipes. Wet chemistry runs in the vanilla chemical plant (category
-- "chemistry"); the two catalyst make recipes are plain assembler crafts; and
-- calcination is a ROAST that runs in the lava manufacturer (its private
-- "cindra-lava-manufacturing" category). All gated off until the tech.
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

-- Calcination is a ROAST, so it lives in the high-heat lava manufacturer, not the
-- chemical plant (ci-6vj S3 / DESIGN §8.3). The LM's private
-- `cindra-lava-manufacturing` category confines it there (the shared foundry never
-- runs it). Electric heat (no lava input) and NO stone output, so calcination opens
-- no new stone vector -- the stone balance proof (§8.6) stays simple. The LM emits
-- the CO2 through its (unfiltered) output fluid box, the same box the lava recipe
-- uses for lava; verified at runtime in test_plastics.lua.
local calcination = {
  type = "recipe",
  name = "cindra-calcination",
  categories = { LAVA_CATEGORY },
  subgroup = "fluid-recipes",
  order = "z[cindra]-b[calcination]",
  enabled = false,
  energy_required = CALCINATION_SECONDS, -- the "heat": the longest craft
  ingredients = {
    { type = "item", name = "calcite", amount = 2 },
  },
  results = {
    { type = "item", name = QUICKLIME, amount = 2 },
    { type = "fluid", name = CO2, amount = 40 },
  },
  allow_productivity = false, -- fixed carbon budget: no free CO2
  main_product = CO2,
  icons = { { icon = GAS_ICON, icon_size = 64, tint = { r = 0.60, g = 0.60, b = 0.65, a = 1.0 } } },
}

-- #10 Methanol synthesis (CP): CO2 + hydrogen, over the methanol catalyst, become
-- methanol (+ recovered water). The catalyst is an ingredient AND a product
-- returned at 70% intact / 20% spent (independent rolls) -- slow-consumed, not a
-- 1:1 reagent. Water is handed back.
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
    { type = "item", name = MCAT, amount = 1 },
  },
  results = {
    { type = "fluid", name = METHANOL, amount = 20 },
    { type = "fluid", name = "water", amount = 20 }, -- recovered, loops back
    -- The catalyst survives most crafts (slow deactivation): 70% returned intact,
    -- 20% deactivated to the spent form (each rolled on its own). The ~10% net
    -- loss is topped up by the make recipe (#11).
    { type = "item", name = MCAT, amount = 1, independent_probability = CAT_RETURN },
    { type = "item", name = MCAT_SPENT, amount = 1, independent_probability = CAT_SPENT },
  },
  allow_productivity = false,
  main_product = METHANOL,
  crafting_machine_tint = { primary = { r = 0.9, g = 0.85, b = 0.55 } },
}

-- #11 Methanol catalyst (AM): copper (from the lava-cast copper chain) + the
-- signature alumina. Slow-consumed, so plastic rides the power economy without
-- being gated on it.
local methanol_catalyst_recipe = {
  type = "recipe",
  name = MCAT,
  -- default "crafting" category: any assembler makes it, belt-feeds cleanly.
  subgroup = "raw-material",
  order = "z[cindra]-catalyst-a[methanol]",
  enabled = false,
  energy_required = MCAT_SECONDS,
  ingredients = {
    { type = "item", name = "copper-plate", amount = 10 },
    { type = "item", name = ALUMINA, amount = 2 },
  },
  results = {
    { type = "item", name = MCAT, amount = 1 },
  },
  allow_productivity = false, -- a catalyst, not an intermediate: no prod shortcut
  main_product = MCAT,
}

-- #12 Methanol catalyst reprocessing (CP): the spent form + acid recovers most of
-- the copper and the alumina, closing the loop so spent catalyst is never dead.
local methanol_catalyst_reprocessing = {
  type = "recipe",
  name = "cindra-methanol-catalyst-reprocessing",
  categories = { "chemistry" }, -- consumes acid (a fluid): chemical plant
  subgroup = "raw-material",
  order = "z[cindra]-catalyst-b[methanol-reprocess]",
  enabled = false,
  energy_required = REPROCESS_SECONDS,
  ingredients = {
    { type = "item", name = MCAT_SPENT, amount = 1 },
    { type = "fluid", name = SULFURIC_ACID, amount = 20 },
  },
  results = {
    { type = "item", name = "copper-plate", amount = 6 },
    { type = "item", name = ALUMINA, amount = 1 },
  },
  allow_productivity = false,
  main_product = "copper-plate",
}

-- #13 MTO + polymerisation (CP): the zeolite-catalysed step. Methanol cracks and
-- polymerises straight to the vanilla `plastic-bar` in ONE recipe (the ci-400
-- separate olefins intermediate is gone). Water is handed back; the zeolite
-- catalyst is slow-consumed (70% intact / 20% spent), exactly like the methanol
-- catalyst.
local mto_polymerisation = {
  type = "recipe",
  name = "cindra-mto-polymerisation",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-d[mto-polymerisation]",
  enabled = false,
  energy_required = MTO_SECONDS,
  ingredients = {
    { type = "fluid", name = METHANOL, amount = 40 },
    { type = "item", name = ZCAT, amount = 1 },
  },
  results = {
    { type = "item", name = PLASTIC, amount = 2 },
    { type = "fluid", name = "water", amount = 40 }, -- recovered, loops back
    { type = "item", name = ZCAT, amount = 1, independent_probability = CAT_RETURN },
    { type = "item", name = ZCAT_SPENT, amount = 1, independent_probability = CAT_SPENT },
  },
  allow_productivity = false, -- no minting free plastic (balance vs vanilla)
  main_product = PLASTIC,
  crafting_machine_tint = { primary = { r = 0.65, g = 0.92, b = 0.70 } },
}

-- #14 Zeolite catalyst (AM): an aluminosilicate cooked from stone + alumina +
-- quicklime + steam. This is the real quicklime CONSUMER and a genuine stone draw.
local zeolite_catalyst_recipe = {
  type = "recipe",
  name = ZCAT,
  -- default "crafting" category (an assembler with a fluid box, for the steam).
  subgroup = "raw-material",
  order = "z[cindra]-catalyst-c[zeolite]",
  enabled = false,
  energy_required = ZCAT_SECONDS,
  ingredients = {
    { type = "item", name = STONE, amount = 8 },
    { type = "item", name = ALUMINA, amount = 3 },
    { type = "item", name = QUICKLIME, amount = 2 },
    { type = "fluid", name = STEAM, amount = 100 },
  },
  results = {
    { type = "item", name = ZCAT, amount = 1 },
  },
  allow_productivity = false, -- a catalyst, not an intermediate: no prod shortcut
  main_product = ZCAT,
}

-- #15 Zeolite catalyst regeneration (CP): the spent form + oxygen burns off the
-- coke and restores the live catalyst, closing the loop AND adding a real O2 sink.
local zeolite_catalyst_regeneration = {
  type = "recipe",
  name = "cindra-zeolite-catalyst-regeneration",
  categories = { "chemistry" }, -- consumes O2 (a fluid): chemical plant
  subgroup = "raw-material",
  order = "z[cindra]-catalyst-d[zeolite-regen]",
  enabled = false,
  energy_required = REGEN_SECONDS,
  ingredients = {
    { type = "item", name = ZCAT_SPENT, amount = 1 },
    { type = "fluid", name = O2, amount = 20 },
  },
  results = {
    { type = "item", name = ZCAT, amount = 1 },
  },
  allow_productivity = false,
  main_product = ZCAT,
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

local vent_quicklime = {
  type = "recipe",
  name = "cindra-vent-quicklime",
  -- default "crafting": an assembler can dump quicklime (a solid) with no fluid box.
  subgroup = "raw-material",
  order = "z[cindra]-y[vent-quicklime]",
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "item", name = QUICKLIME, amount = 10 },
  },
  results = {}, -- discarded: a pure sink
  allow_productivity = false,
  icons = { { icon = CALCITE_ICON, icon_size = 64, tint = { r = 0.95, g = 0.93, b = 0.85, a = 1.0 } } },
  localised_name = { "recipe-name.cindra-vent-quicklime" },
  localised_description = { "recipe-description.cindra-vent-quicklime" },
}

-- CO2 emergency vent (ci-6vj #18). Calcination frees CO2; if methanol demand
-- lags the CO2 supply the gas would back up and stall calcination. This drains
-- it to nothing, so a backed-up CO2 pipe never deadlocks the line.
local vent_co2 = {
  type = "recipe",
  name = "cindra-vent-co2",
  categories = { "chemistry" }, -- gas: needs a fluid box, so a chemical plant
  subgroup = "fluid-recipes",
  order = "z[cindra]-y[vent-co2]",
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "fluid", name = CO2, amount = 100 },
  },
  results = {}, -- vented to atmosphere: a pure sink
  allow_productivity = false,
  icons = { { icon = GAS_ICON, icon_size = 64, tint = { r = 0.60, g = 0.60, b = 0.65, a = 1.0 } } },
  localised_name = { "recipe-name.cindra-vent-co2" },
  localised_description = { "recipe-description.cindra-vent-co2" },
}

-- Quicklime DISPOSAL (ci-6vj #16): the designated SURPLUS quicklime sink. Runs in
-- the lava manufacturer (LAVA_CATEGORY, the high-heat furnace) -- fluxing surplus
-- quicklime back into the melt with lava. Deliberately net stone-NEGATIVE: it
-- returns 5 stone but consumes 50 lava, and 50 lava cost 10 stone to make (1 stone
-- -> 5 lava, prototypes/lava.lua), so the loop spends 10 stone to hand back 5. The
-- stone output is `ignored_by_productivity` and productivity is off, so that stays
-- fixed at every module tier -- it can never become a free-stone/free-lava source
-- (ci-669 invariant, DESIGN §8.6). Lava in -> uses the manufacturer's fluid box.
local quicklime_disposal = {
  type = "recipe",
  name = "cindra-quicklime-disposal",
  categories = { LAVA_CATEGORY }, -- lava-manufacturer only (never the shared foundry)
  subgroup = "raw-material",
  order = "z[cindra]-y[quicklime-disposal]",
  enabled = false,
  energy_required = 2,
  ingredients = {
    { type = "item", name = QUICKLIME, amount = 10 },
    { type = "fluid", name = LAVA, amount = 50 },
  },
  results = {
    -- Net-negative sink: 5 stone back for 10 stone-worth of lava consumed. Pinned
    -- out of any productivity bonus so it never mints stone (ci-669).
    { type = "item", name = STONE, amount = 5, ignored_by_productivity = 5 },
  },
  allow_productivity = false,
  main_product = STONE,
  icons = { { icon = CALCITE_ICON, icon_size = 64, tint = { r = 0.85, g = 0.80, b = 0.72, a = 1.0 } } },
  localised_name = { "recipe-name.cindra-quicklime-disposal" },
  localised_description = { "recipe-description.cindra-quicklime-disposal" },
}

-- ---------------------------------------------------------------------------
-- The gating tech. Prereq is the signature `cindra-aluminium` (which itself
-- needs BOTH the lava spine and the ice chain), because the catalysts consume
-- alumina -- so plastic is only reachable once the whole base economy (rock,
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
    { type = "unlock-recipe", recipe = MCAT },
    { type = "unlock-recipe", recipe = "cindra-methanol-catalyst-reprocessing" },
    { type = "unlock-recipe", recipe = "cindra-mto-polymerisation" },
    { type = "unlock-recipe", recipe = ZCAT },
    { type = "unlock-recipe", recipe = "cindra-zeolite-catalyst-regeneration" },
    { type = "unlock-recipe", recipe = "cindra-vent-oxygen" },
    { type = "unlock-recipe", recipe = "cindra-vent-quicklime" },
    { type = "unlock-recipe", recipe = "cindra-vent-co2" },
    { type = "unlock-recipe", recipe = "cindra-quicklime-disposal" },
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
  hydrogen, oxygen, carbon_dioxide, methanol,
  quicklime, methanol_catalyst, spent_methanol_catalyst,
  zeolite_catalyst, spent_zeolite_catalyst,
  electrolysis, calcination, methanol_synthesis,
  methanol_catalyst_recipe, methanol_catalyst_reprocessing,
  mto_polymerisation, zeolite_catalyst_recipe, zeolite_catalyst_regeneration,
  vent_oxygen, vent_quicklime, vent_co2, quicklime_disposal,
  technology,
})

-- Exposed for tests + downstream integration.
return {
  H2 = H2, O2 = O2, CO2 = CO2, METHANOL = METHANOL,
  QUICKLIME = QUICKLIME, PLASTIC = PLASTIC, TECH = TECH,
  MCAT = MCAT, MCAT_SPENT = MCAT_SPENT,
  ZCAT = ZCAT, ZCAT_SPENT = ZCAT_SPENT,
  CAT_RETURN = CAT_RETURN, CAT_SPENT = CAT_SPENT,
}
