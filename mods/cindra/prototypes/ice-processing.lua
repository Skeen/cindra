-- Cindra ice processing (§15-4; DESIGN.md §1 "nightward edge = MATTER", §5).
--
-- The nightside's frozen matter is turned into the factory's water (and calcite)
-- entirely by REUSING the vanilla Space Age crushing/melting model -- no custom
-- ice item, no bespoke crush/melt maths, no ice-melter machine, no dedicated ice
-- tech (ci-3mx). The user was explicit: "ice crushing should just be oxide
-- asteroid crushing" and "the existing ice melting in the chemical plant"; stop
-- adding equivalent tech. The Cindra crushing recipes below are byte-for-byte
-- clones of the vanilla oxide recipes (same I/O), so the model is unchanged --
-- only their crafting CATEGORY differs (see the exploit note next).
--
-- 🚨 WHY A DEDICATED CATEGORY, NOT THE VANILLA `crushing` ONE (ci-8n6, exploit):
-- the vanilla `crushing` category holds NINE recipes, not just oxide crushing:
-- metallic/carbonic crushing (chunk -> free iron / free carbon) and the three
-- asteroid REPROCESSING recipes (which convert one chunk type into another).
-- If the ground crusher ran the vanilla `crushing` category, a player could take
-- the ice field's oxide chunks, REPROCESS them into metallic/carbonic chunks, and
-- crush THOSE into iron and carbon/coal -- free metal and free coal, bypassing the
-- whole power-manufactured, petrochemical-free economy (the lava->metal chain and
-- the no-oil design). A machine can only be restricted by crafting CATEGORY, so
-- the crusher gets its OWN `cindra-crushing` category that contains ONLY the
-- Cindra oxide-family recipes. The vanilla `crushing` recipes stay in the vanilla
-- category, physically uncraftable on the ground. Space-platform crushing (the
-- vanilla crusher, still on `crushing`) is untouched -- never-mutate-other-planets.
--
--   1. CRUSH (`cindra-crushing` category) -- the nightside deposit yields the
--      vanilla `oxide-asteroid-chunk` item (see resources.lua). The player crushes
--      it with the Cindra clones of the vanilla oxide recipes (same I/O):
--        - `cindra-oxide-asteroid-crushing`          : chunk -> ice
--        - `cindra-advanced-oxide-asteroid-crushing` : chunk -> ice + calcite
--      Picking between them IS the water<->calcite ratio knob (the vanilla model,
--      unchanged). Calcite for the aluminium refine + science pack comes from the
--      advanced recipe -- the ice chain stays the local calcite source.
--   2. MELT (vanilla `chemistry` category) -- the vanilla `ice-melting` recipe in
--      the vanilla CHEMICAL PLANT turns that `ice` into `water`. No custom melter,
--      and `chemistry` holds no exploitable recipe, so it needs no private category.
--   3. EXTRACT VOLATILES (ci-4xx; `cindra-crushing` category) -- a Cindra recipe:
--      crushing deep-nightside oxide chunks in the same ground crusher sublimes out
--      their frozen volatile fraction (`oxide-asteroid-chunk -> cindra-volatiles`).
--      This is where the science pack's volatiles come from now: a PROCESSING
--      output, not a mining yield of the ice field (DESIGN §11, "volatile ice ->
--      CO2/frozen gases"). Petrochemical-free (a solid chunk in, a solid volatiles
--      item out), unlocked by the same planet-discovery-cindra tech as the rest of
--      the chain, so by the time you can research the science pack the volatiles
--      are already producible (no chicken-and-egg).
--
-- WHY ONE CUSTOM ENTITY (the crusher) AND NOTHING ELSE: the vanilla `crusher` is
-- gated to zero gravity (`surface_conditions` gravity 0..0) so it cannot stand on
-- Cindra's heavy-gravity ground, and we can't re-scope the vanilla crusher without
-- changing it everywhere (never-mutate-other-planets, DESIGN §6). So we clone it
-- into a ground-standing `cindra-ice-crusher` locked to the `cindra-crushing`
-- category. The MELTER is not cloned at all -- the vanilla chemical plant already
-- melts ice and stands on any gravity.
--
-- WHY NO CINDRA ICE TECH: the whole ice chain is unlocked by the EXISTING
-- `planet-discovery-cindra` tech (we append the unlock effects below). In normal
-- play you research discovery to reach Cindra; on an any-planet-start Cindra run
-- APS removes that tech and enables its unlocked recipes from tick zero
-- (vendor/any-planet-start/data-final-fixes.lua), so the chain works on both paths
-- with no new/equivalent technology.

local util = require("util")

-- === Dedicated crafting category (ci-8n6) ====================================
-- A Cindra-only recipe category. It exists so the ground crusher can be locked to
-- exactly the Cindra oxide recipes below and CANNOT run the vanilla `crushing`
-- category's metallic/carbonic crushing or the reprocessing recipes (the exploit).
-- Adding a NEW category never mutates the vanilla `crushing` one, so space-platform
-- crushing is unaffected.
local CINDRA_CRUSHING = "cindra-crushing"

-- === The crusher (SOLID -> SOLID, `cindra-crushing` recipes only) =============
-- A ground-standing clone of the vanilla space crusher, locked to `cindra-crushing`
-- so it runs ONLY the Cindra oxide recipes -- never the vanilla metallic/carbonic
-- crushing or reprocessing recipes. It emits no fluid (the vanilla crusher has no
-- fluid boxes).
local crusher = util.table.deepcopy(data.raw["assembling-machine"]["crusher"])
crusher.name = "cindra-ice-crusher"
crusher.minable = { mining_time = 0.2, result = "cindra-ice-crusher" }
crusher.fast_replaceable_group = nil -- not interchangeable with the space crusher

-- Locked to the dedicated Cindra category (ci-8n6). NOT the vanilla `crushing`
-- category -- that would expose free iron/coal via metallic/carbonic crushing and
-- the reprocessing chunk-conversion recipes.
crusher.crafting_categories = { CINDRA_CRUSHING }

-- Drop the space-only gating so it can stand on Cindra's heavy-gravity ground,
-- and drop the space-platform heating draw (a platform mechanic, not Cindra's).
crusher.surface_conditions = nil
crusher.heating_energy = nil

crusher.localised_name = { "entity-name.cindra-ice-crusher" }
crusher.localised_description = { "entity-description.cindra-ice-crusher" }

-- Item: clone the crusher item for a valid def + vanilla icon (v1 art), pointed at
-- our entity. Placed in the PRODUCTION tab (not the vanilla "space-platform" one).
local crusher_item = util.table.deepcopy(data.raw["item"]["crusher"])
crusher_item.name = "cindra-ice-crusher"
crusher_item.place_result = "cindra-ice-crusher"
crusher_item.subgroup = "production-machine"
crusher_item.order = "b[cindra]-b[ice-crusher]"
crusher_item.localised_name = { "item-name.cindra-ice-crusher" }
crusher_item.localised_description = { "item-description.cindra-ice-crusher" }

-- Recipe to BUILD the crusher (gated; unlocked by planet-discovery-cindra below).
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

-- === Cindra oxide crushing (clones of the vanilla oxide recipes, ci-8n6) =======
-- Byte-for-byte clones of the vanilla oxide crushing recipes (same ingredients,
-- same products -- the ice chain is functionally unchanged), re-categorised into
-- the dedicated `cindra-crushing` category so ONLY the ground crusher runs them
-- and the crusher runs ONLY them. We clone (never mutate) the vanilla recipes:
-- the vanilla `oxide-asteroid-crushing` / `advanced-oxide-asteroid-crushing` keep
-- their vanilla `crushing` category for space-platform use. The clones reuse the
-- vanilla locale + icon (v1 art) via `localised_name`.
local function cindra_oxide_clone(vanilla_name, new_name)
  local r = util.table.deepcopy(data.raw.recipe[vanilla_name])
  r.name = new_name
  r.categories = { CINDRA_CRUSHING }
  r.localised_name = { "recipe-name." .. vanilla_name } -- reuse the vanilla name string
  r.enabled = false -- gated: unlocked by planet-discovery-cindra (below), never free.
  r.auto_recycle = false
  return r
end
local R_OXIDE = "cindra-oxide-asteroid-crushing"
local R_OXIDE_ADV = "cindra-advanced-oxide-asteroid-crushing"
local oxide_crushing = cindra_oxide_clone("oxide-asteroid-crushing", R_OXIDE)
local oxide_crushing_adv = cindra_oxide_clone("advanced-oxide-asteroid-crushing", R_OXIDE_ADV)

-- === Volatiles extraction (ci-4xx): the PROCESSING source of frozen volatiles ==
-- A NEW Cindra recipe (never a mutation of a vanilla one) in the `cindra-crushing`
-- category, so the ground crusher above runs it just like the oxide-crushing
-- recipes. It sublimes the frozen volatile fraction out of the deep-nightside oxide
-- chunk: `oxide-asteroid-chunk -> cindra-volatiles`. This REPLACES the old
-- mining-yield source (the ice field no longer drops volatiles, ci-4xx) with an
-- honest processing step. Petrochemical-free (solid in, solid out), gated by the
-- same discovery tech as the rest of the chain (unlock appended below).
-- (tune) §15-14: amounts/time are a balance decision -- kept a real cost so
-- volatiles stay a worked output, not free.
local VOLATILES = "cindra-volatiles"
local volatiles_recipe = {
  type = "recipe",
  name = VOLATILES,
  categories = { CINDRA_CRUSHING },
  enabled = false, -- gated: unlocked by planet-discovery-cindra (below), never free.
  energy_required = 2,
  ingredients = {
    { type = "item", name = "oxide-asteroid-chunk", amount = 2 },
  },
  results = {
    { type = "item", name = VOLATILES, amount = 1 },
  },
  allow_productivity = true,
  main_product = VOLATILES,
}

data:extend({
  { type = "recipe-category", name = CINDRA_CRUSHING },
  crusher,
  crusher_item,
  crusher_build,
  oxide_crushing,
  oxide_crushing_adv,
  volatiles_recipe,
})

-- === Unlock the chain via the existing Cindra discovery tech (no new tech) =====
-- Append the ice-chain unlocks to `planet-discovery-cindra` (defined in planet.lua,
-- required before this file). Normal play: researching discovery unlocks them.
-- APS Cindra-start: APS removes this tech and enables its unlocked recipes from
-- tick zero (data-final-fixes.lua), so the chain works there too. We unlock the
-- Cindra oxide clones (not the vanilla oxide recipes) -- unlocking them for the
-- force does NOT mutate any other planet's content.
local discovery = data.raw.technology["planet-discovery-cindra"]
assert(discovery, "planet-discovery-cindra must be defined before ice-processing")
for _, recipe in ipairs({
  "cindra-ice-crusher",  -- the ground crusher build
  R_OXIDE,               -- chunk -> ice (Cindra clone)
  R_OXIDE_ADV,           -- chunk -> ice + calcite (Cindra clone; the ratio knob)
  "ice-melting",         -- ice -> water in the chemical plant (vanilla; safe category)
  VOLATILES,             -- chunk -> volatiles (ci-4xx; the science-pack input)
}) do
  table.insert(discovery.effects, { type = "unlock-recipe", recipe = recipe })
end
