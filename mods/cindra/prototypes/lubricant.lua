-- Native lubricant + the Cindra-buildable foundry (§15 item, ci-arw).
--
-- THE PROBLEM this file solves (start-on-Cindra soft-lock):
-- Normal Cindra progression IMPORTS foundries from Vulcanus (DESIGN §8): the
-- vanilla `foundry` build recipe is surface-gated to `pressure = 4000` (Vulcanus)
-- AND consumes `lubricant` (oil chemistry). Cindra's pressure is 500 and it has
-- no oil, so that recipe can NEVER be crafted here -- which is fine, because you
-- carry finished foundries over. But a START-ON-CINDRA player (any-planet-start,
-- `mods/cindra-start`) has no Vulcanus to import from and no petrochemistry, so
-- with only the vanilla recipe they SOFT-LOCK: no foundry -> no lava->metal spine.
--
-- THE FIX, scoped so normal (imported-foundry) play is untouched:
--   1. cindra-crude-lubricant  -- coal -> lubricant. The BOOTSTRAP tier. Its coal
--      comes only from the FINITE, hand-mined bootstrap rocks (prototypes/
--      resources.lua); Cindra has no mineable coal, so this can build your first
--      foundry(ies) once and can never scale. A one-time durable cost, per §6.
--   2. cindra-mineral-lubricant -- stone + water -> lubricant. The renewable,
--      petrochemical-free SUSTAIN tier ("silica / silicone oil, from rock").
--      Deliberately effortful (heavy stone + water + power) so it is
--      situational-not-strictly-better than oil lubricant (§12) and normal play
--      still prefers imports.
--   3. cindra-field-foundry -- a recipe that yields the vanilla `foundry` ITEM
--      (the foundry ENTITY has no placement surface-condition, so it drops and
--      runs fine on Cindra) but WITHOUT the pressure gate, so it can actually be
--      crafted here. Deliberately costlier than the Vulcanus recipe, so a normal
--      post-Vulcanus player keeps importing rather than field-building.
--
-- All three are locked (`enabled = false`) and unlocked by ONE new tech,
-- `cindra-improvised-metallurgy` (prereq: Cindra discovery). In normal play a
-- player only ever reaches this tech AFTER Vulcanus (the discovery gate, §6), by
-- which point they already own real foundries -- so the field path is a costly
-- curiosity, not a shortcut. In a start-on-Cindra game, `cindra-start` pre-
-- researches the tech so the opening is playable from tick zero.
--
-- NEVER-MUTATE-OTHER-PLANETS: we add only NEW prototypes. The shared vanilla
-- `foundry` recipe and `lubricant` fluid are left exactly as they are, so nothing
-- leaks onto Vulcanus/Nauvis. All our recipes are Cindra-gated + disabled by
-- default; no free foundry appears in any other planet's progression.
--
-- v1 ART: reuse vanilla icons (lubricant fluid, foundry item).

local FOUNDRY_ICON = "__space-age__/graphics/icons/foundry.png"
local LUBRICANT_ICON = "__base__/graphics/icons/fluid/lubricant.png"

-- ---------------------------------------------------------------------------
-- 1. BOOTSTRAP lubricant: finite coal -> lubricant.
-- ---------------------------------------------------------------------------
-- Crude liquefaction, landing-tier. No water, no other infrastructure, so it is
-- the frictionless first step for a from-nothing start: hand-mine rocks for coal,
-- crude-liquefy it, build the first foundry. The poor ratio + the finiteness of
-- coal keep it strictly a bootstrap, never the main supply.
local crude_lubricant = {
  type = "recipe",
  name = "cindra-crude-lubricant",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-b[lubricant]-a[crude]",
  enabled = false,
  energy_required = 4,
  ingredients = {
    { type = "item", name = "coal", amount = 5 },
  },
  results = {
    { type = "fluid", name = "lubricant", amount = 20 },
  },
  -- Bootstrap only: no productivity minting free lubricant out of finite coal.
  allow_productivity = false,
  icons = {
    { icon = LUBRICANT_ICON, icon_size = 64 },
  },
  main_product = "lubricant",
  crafting_machine_tint = { primary = { r = 0.2, g = 0.2, b = 0.2 } },
}

-- ---------------------------------------------------------------------------
-- 2. RENEWABLE lubricant: stone + water -> lubricant.
-- ---------------------------------------------------------------------------
-- The sustainable, petrochemical-free local path: a silicone/silicon oil worked
-- out of common stone (silica) and the nightside's water. Deliberately EFFORTFUL
-- -- a lot of stone, a lot of water, real crafting time -- so it costs far more
-- than oil lubricant and never becomes a strictly-better substitute in normal
-- play (§12). On Cindra, where you have no oil, it is the renewable answer that
-- keeps you building foundries after the finite bootstrap coal is gone.
local mineral_lubricant = {
  type = "recipe",
  name = "cindra-mineral-lubricant",
  categories = { "chemistry" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-b[lubricant]-b[mineral]",
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "stone", amount = 10 },
    { type = "fluid", name = "water", amount = 50 },
  },
  results = {
    { type = "fluid", name = "lubricant", amount = 10 },
  },
  allow_productivity = false,
  icons = {
    { icon = LUBRICANT_ICON, icon_size = 64 },
  },
  main_product = "lubricant",
  crafting_machine_tint = { primary = { r = 0.6, g = 0.55, b = 0.4 } },
}

-- ---------------------------------------------------------------------------
-- 3. The Cindra-buildable foundry recipe.
-- ---------------------------------------------------------------------------
-- Produces the vanilla `foundry` item. Category `crafting-with-fluid` so an
-- ordinary assembling machine (the start-on-Cindra kit's, or an already-built
-- foundry) can craft it -- crucially it does NOT carry the vanilla recipe's
-- `pressure = 4000` surface condition, so it works on Cindra. It is deliberately
-- MORE expensive than the imported recipe (more structural material, more
-- lubricant, longer craft) so that whenever importing from Vulcanus is an option
-- it stays the better choice; this path exists to rescue the no-Vulcanus start.
local field_foundry = {
  type = "recipe",
  name = "cindra-field-foundry",
  categories = { "crafting-with-fluid" },
  subgroup = "production-machine",
  order = "z[cindra]-c[field-foundry]",
  enabled = false,
  energy_required = 30,
  ingredients = {
    { type = "item", name = "tungsten-carbide", amount = 50 },
    { type = "item", name = "steel-plate", amount = 80 },
    { type = "item", name = "electronic-circuit", amount = 40 },
    { type = "item", name = "refined-concrete", amount = 40 },
    { type = "fluid", name = "lubricant", amount = 40 },
  },
  results = {
    { type = "item", name = "foundry", amount = 1 },
  },
  -- A structural machine, not a metallurgical product: no productivity shortcut.
  allow_productivity = false,
  icons = {
    { icon = FOUNDRY_ICON, icon_size = 64 },
  },
  main_product = "foundry",
}

-- ---------------------------------------------------------------------------
-- The gating tech. One tech unlocks all three so the whole field path arrives
-- (or is pre-researched for a start-on-Cindra game) together. Prereq is Cindra
-- discovery only -- cheap and early, but discovery itself sits behind Vulcanus in
-- normal play (§6), so a normal player who reaches it already has real foundries.
local technology = {
  type = "technology",
  name = "cindra-improvised-metallurgy",
  icon = FOUNDRY_ICON,
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-crude-lubricant" },
    { type = "unlock-recipe", recipe = "cindra-mineral-lubricant" },
    { type = "unlock-recipe", recipe = "cindra-field-foundry" },
  },
  prerequisites = { "planet-discovery-cindra" },
  unit = {
    count = 50,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
    },
    time = 15,
  },
}

data:extend({ crude_lubricant, mineral_lubricant, field_foundry, technology })
