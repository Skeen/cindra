-- Cindra ice processing (§15-4; DESIGN.md §1 "nightward edge = MATTER", §5).
--
-- The nightside's frozen matter is turned into the factory's water (and calcite)
-- entirely by REUSING vanilla Space Age recipes -- no custom ice item, no custom
-- crush/melt recipe, no ice-melter machine, no dedicated ice tech (ci-3mx). The
-- user was explicit: "ice crushing should just be oxide asteroid crushing" and
-- "the existing ice melting in the chemical plant"; stop adding equivalent tech.
--
--   1. CRUSH (vanilla `crushing` category) -- the nightside deposit yields the
--      vanilla `oxide-asteroid-chunk` item (see resources.lua). The player crushes
--      it with the SAME vanilla recipes used in space:
--        - `oxide-asteroid-crushing`          : chunk -> ice
--        - `advanced-oxide-asteroid-crushing` : chunk -> ice + calcite
--      Picking between them IS the water<->calcite ratio knob (the vanilla model,
--      unchanged). Calcite for the aluminium refine + science pack comes from the
--      advanced recipe -- the ice chain stays the local calcite source.
--   2. MELT (vanilla `chemistry` category) -- the vanilla `ice-melting` recipe in
--      the vanilla CHEMICAL PLANT turns that `ice` into `water`. No custom melter.
--   3. EXTRACT VOLATILES (ci-4xx; vanilla `crushing` category) -- the ONE Cindra
--      recipe this file adds: crushing deep-nightside oxide chunks in the same
--      ground crusher sublimes out their frozen volatile fraction
--      (`oxide-asteroid-chunk -> cindra-volatiles`). This is where the science
--      pack's volatiles come from now: they are a PROCESSING output, not a mining
--      yield of the ice field (DESIGN §11, "volatile ice -> CO2/frozen gases"). It
--      is petrochemical-free (a solid chunk in, a solid volatiles item out) and is
--      unlocked by the same planet-discovery-cindra tech as the rest of the chain,
--      so by the time you can research the science pack the volatiles are already
--      producible (no chicken-and-egg).
--
-- WHY ONE CUSTOM ENTITY (the crusher) AND NOTHING ELSE: the vanilla `crusher` is
-- gated to zero gravity (`surface_conditions` gravity 0..0) so it cannot stand on
-- Cindra's heavy-gravity ground, and we can't re-scope the vanilla crusher without
-- changing it everywhere (never-mutate-other-planets, DESIGN §6). So we clone it
-- into a ground-standing `cindra-ice-crusher` that runs the SAME vanilla `crushing`
-- recipes (its build item lives in the production tab). The MELTER is not cloned
-- at all -- the vanilla chemical plant already melts ice and stands on any gravity.
--
-- WHY NO CINDRA ICE TECH: the whole ice chain is unlocked by the EXISTING
-- `planet-discovery-cindra` tech (we append the unlock effects below). In normal
-- play you research discovery to reach Cindra; on an any-planet-start Cindra run
-- APS removes that tech and enables its unlocked recipes from tick zero
-- (vendor/any-planet-start/data-final-fixes.lua), so the chain works on both paths
-- with no new/equivalent technology.

local util = require("util")

-- === The crusher (SOLID -> SOLID, vanilla `crushing` recipes) ================
-- A ground-standing clone of the vanilla space crusher. It runs the SAME vanilla
-- crushing recipes (category "crushing"); we only drop the space-only gating so it
-- works on Cindra. It emits no fluid (the vanilla crusher has no fluid boxes).
local crusher = util.table.deepcopy(data.raw["assembling-machine"]["crusher"])
crusher.name = "cindra-ice-crusher"
crusher.minable = { mining_time = 0.2, result = "cindra-ice-crusher" }
crusher.fast_replaceable_group = nil -- not interchangeable with the space crusher

-- Runs the vanilla crushing recipes (oxide-asteroid-crushing et al.) -- the SAME
-- recipes the space crusher runs. No private category: reuse-vanilla (ci-3mx).
crusher.crafting_categories = { "crushing" }

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

-- === Volatiles extraction (ci-4xx): the PROCESSING source of frozen volatiles ==
-- A NEW Cindra recipe (never a mutation of a vanilla one) in the vanilla `crushing`
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
  categories = { "crushing" },
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

data:extend({ crusher, crusher_item, crusher_build, volatiles_recipe })

-- === Unlock the chain via the existing Cindra discovery tech (no new tech) =====
-- Append the ice-chain unlocks to `planet-discovery-cindra` (defined in planet.lua,
-- required before this file). Normal play: researching discovery unlocks them.
-- APS Cindra-start: APS removes this tech and enables its unlocked recipes from
-- tick zero (data-final-fixes.lua), so the chain works there too. We reuse the
-- vanilla crush/melt recipes -- unlocking them for the force does NOT mutate the
-- recipes themselves or any other planet's content.
local discovery = data.raw.technology["planet-discovery-cindra"]
assert(discovery, "planet-discovery-cindra must be defined before ice-processing")
for _, recipe in ipairs({
  "cindra-ice-crusher",                 -- the ground crusher build
  "oxide-asteroid-crushing",            -- chunk -> ice (vanilla)
  "advanced-oxide-asteroid-crushing",   -- chunk -> ice + calcite (vanilla; the ratio knob)
  "ice-melting",                        -- ice -> water in the chemical plant (vanilla)
  "cindra-volatiles",                   -- chunk -> volatiles (ci-4xx; the science-pack input)
}) do
  table.insert(discovery.effects, { type = "unlock-recipe", recipe = recipe })
end
