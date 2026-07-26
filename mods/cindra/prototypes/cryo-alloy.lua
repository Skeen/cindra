-- Cindra's SIGNATURE product: the cryo-hardened alloy, forged in a
-- TWO-TEMPERATURE quench (§15-6; DESIGN.md §1, §5 "Signature product", §12).
--
-- This is the mechanic that makes Cindra Cindra: a SINGLE craft that requires a
-- HOT input and a COLD input at the same time. It is impossible on Vulcanus (no
-- cold) or Aquilo (no lava) -- only the ribbon world routes fire and ice into
-- the same machine. Both halves are now available on main: the hot half from the
-- lava spine (ci-8mw), the cold half from the ice chain (ci-rgv).
--
-- MODELING (proven in the quench PoC, mods/quench-poc / ci-o4r; its DESIGN.md
-- records the full trade-off study). Ship approach (c) + (b):
--   * HOT half  = a FLUID ingredient (`lava`), temperature-gated with
--     `minimum_temperature`. The gate is what makes "hot" REAL and engine-
--     enforced rather than a name: sub-threshold molten stock will not craft.
--     We use the manufactured `lava` fluid itself (the fire-side spine, 1500 C),
--     so the alloy branches straight off the lava economy without competing with
--     the foundry's molten-metal plate chain.
--   * COLD half = a CONSUMED ITEM (`cindra-cryo-coolant`), matching the spec's
--     "start simple: cryo-coolant as a consumed material". An item keeps the
--     quench to a single (hot) fluid input and belt-feeds the cold side cleanly.
-- The advanced circulating-coolant variant (a second, max-temperature-gated cold
-- FLUID that warms as it works and must be re-chilled nightside) is deferred; the
-- PoC's temperature-gating proof already covers that cold-side gate when it lands.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is a fresh clone (deep-
-- copied via util.table.deepcopy before any nested edit) or brand new. The one
-- shared reference is the vanilla `lava` fluid used as an INGREDIENT (read, not
-- mutated) -- exactly as the lava spine (ci-8mw) already consumes it. A private
-- recipe category keeps the quench recipe off vanilla chemical plants and vice
-- versa.
--
-- v1 ART: the delivered signature art (graphics/ART-MANIFEST.md, ci-pru) -- a
-- 256x256 static entity sprite + shadow for the quench, and mipmap icons for the
-- machine and the alloy. The animated "quench flash" is deferred (PLAYTEST.md).

local util = require("util")

local HOT = "lava"                            -- hot half: the fire-side spine fluid
local COOLANT = "cindra-cryo-coolant"         -- cold half: consumed nightside material
local ALLOY = "cindra-cryo-hardened-alloy"    -- the signature export
local QUENCH = "cindra-cryo-quench"           -- the two-temperature building
local CATEGORY = "cindra-quenching"           -- private category: quench recipe only
local TECH = "cindra-cryo-quenching"

-- (tune) §15-14. Hot-gate: molten stock must be at least this hot to quench.
-- Below Space Age's molten metals (molten-copper 1100 / lava & molten-iron 1500)
-- and the reactor (1000), above the steam threshold (~500) -- so it is satisfied
-- by any real molten stream yet still an engine-enforced "hot" property.
local HOT_MIN = 500
-- (tune) §15-14. Per-craft amounts. 50 lava == 10 stone-equivalents of fire; 5
-- coolant == the cold charge; 1 alloy out. The signature product is deliberately
-- expensive in both fire and ice.
local LAVA_PER_CRAFT = 50
local COOLANT_PER_CRAFT = 5
local ALLOY_PER_CRAFT = 1
local QUENCH_SECONDS = 3.2
-- (tune) §15-14. Coolant: pack raw nightside `ice` into a cold charge. Ice IS the
-- cold, so no chill step is modelled in v1; a plain crafting recipe keeps it
-- belt-feedable (and hand-craftable, which helps the bootstrap traversal, ci-uex).
local ICE_PER_COOLANT = 5
local COOLANT_PER_BATCH = 5

local function set_icon(proto, name)
  proto.icon = "__cindra__/graphics/icons/" .. name .. ".png"
  proto.icon_size = 64
  proto.icon_mipmaps = 4
  proto.icons = nil -- drop any inherited layered icon so our single icon wins
end

-- Private recipe category: ONLY the quench building runs the quench recipe, and
-- the quench building runs nothing else. Keeps the signature craft off vanilla
-- chemical plants (never-mutate-other-planets) and vanilla chemistry out of ours.
local category = { type = "recipe-category", name = CATEGORY }

-- === Cold half: the cryo-coolant consumed item ==============================
-- Cloned from Aquilo `ice` for a valid icon/subgroup/sounds, retinted cyan so it
-- reads as a cold coolant charge (no bespoke coolant art in the manifest yet).
local coolant = util.table.deepcopy(data.raw.item["ice"])
coolant.name = COOLANT
coolant.icon = nil
coolant.icons = {
  { icon = "__space-age__/graphics/icons/ice.png", icon_size = 64,
    tint = { r = 0.55, g = 0.85, b = 1.0, a = 1.0 } },
}
coolant.order = "z[cindra]-a[cryo-coolant]"
coolant.stack_size = 100
coolant.localised_name = { "item-name.cindra-cryo-coolant" }
coolant.localised_description = { "item-description.cindra-cryo-coolant" }

-- === Output: the cryo-hardened alloy ========================================
-- Cloned from steel-plate for a valid definition, then wearing the delivered
-- signature icon.
local alloy = util.table.deepcopy(data.raw.item["steel-plate"])
alloy.name = ALLOY
alloy.order = "z[cindra]-b[cryo-hardened-alloy]"
alloy.stack_size = 100
set_icon(alloy, "cryo-hardened-alloy")
alloy.localised_name = { "item-name.cindra-cryo-hardened-alloy" }
alloy.localised_description = { "item-description.cindra-cryo-hardened-alloy" }

-- === The two-temperature building ===========================================
-- Cloned from the chemical plant: it already has a correct electric energy
-- source and input fluidbox(es) for the hot fluid, so we inherit a known-good
-- electric fluid-crafter instead of hand-rolling pipe connections. Restricted to
-- the private quench category, and re-skinned with the delivered signature art
-- (the chemical-plant animation/foam/smoke visuals are dropped so it does not
-- read as a chemistry building).
local quench = util.table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])
quench.name = QUENCH
quench.minable = { mining_time = 0.5, result = QUENCH }
quench.crafting_categories = { CATEGORY }
quench.fast_replaceable_group = nil -- not interchangeable with the chemical plant
quench.next_upgrade = nil
quench.placeable_by = { item = QUENCH, count = 1 }
quench.use_mirroring = false
set_icon(quench, "cryo-quench")
-- Replace the whole graphics_set: a single static sprite for every direction
-- (idle base layer + soft ground shadow), dropping the inherited chemistry
-- animation and its recipe-tinted foam/smoke working visualisations.
quench.graphics_set = {
  animation = {
    layers = {
      {
        filename = "__cindra__/graphics/entity/cryo-quench/cryo-quench.png",
        width = 256, height = 256, frame_count = 1, scale = 0.5, shift = { 0, -0.3 },
      },
      {
        filename = "__cindra__/graphics/entity/cryo-quench/cryo-quench-shadow.png",
        width = 256, height = 256, frame_count = 1, scale = 0.5, shift = { 0.3, 0 },
        draw_as_shadow = true,
      },
    },
  },
}
quench.localised_name = { "entity-name.cindra-cryo-quench" }
quench.localised_description = { "entity-description.cindra-cryo-quench" }

local quench_item = util.table.deepcopy(data.raw.item["chemical-plant"])
quench_item.name = QUENCH
quench_item.place_result = QUENCH
quench_item.order = "z[cindra]-c[cryo-quench]"
set_icon(quench_item, "cryo-quench")
quench_item.localised_name = { "item-name.cindra-cryo-quench" }
quench_item.localised_description = { "item-description.cindra-cryo-quench" }

-- === Recipes ================================================================
-- The SIGNATURE recipe: HOT fluid (temperature-gated) + COLD item -> alloy. The
-- `minimum_temperature` on the lava ingredient is the whole point -- remove it
-- and the recipe still needs two inputs, but "hot" would be nominal, not real.
local alloy_recipe = {
  type = "recipe",
  name = ALLOY,
  categories = { CATEGORY },
  enabled = false, -- gated: unlocked by the cindra-cryo-quenching tech, never free
  energy_required = QUENCH_SECONDS,
  ingredients = {
    { type = "fluid", name = HOT, amount = LAVA_PER_CRAFT, minimum_temperature = HOT_MIN },
    { type = "item", name = COOLANT, amount = COOLANT_PER_CRAFT },
  },
  results = {
    { type = "item", name = ALLOY, amount = ALLOY_PER_CRAFT },
  },
  allow_productivity = true,
  main_product = ALLOY,
}

-- Cold-half recipe: pack raw nightside ice into a coolant charge. Plain crafting
-- category so an assembler (or the player's hands) makes it -- belt-feedable and
-- bootstrap-friendly.
local coolant_recipe = {
  type = "recipe",
  name = COOLANT,
  enabled = false, -- gated with the rest of the quench chain
  energy_required = 0.5,
  ingredients = {
    { type = "item", name = "ice", amount = ICE_PER_COOLANT },
  },
  results = {
    { type = "item", name = COOLANT, amount = COOLANT_PER_BATCH },
  },
  allow_productivity = true,
}

-- Recipe to BUILD the quench (gated behind the tech). Native metal + pipes.
local build_recipe = {
  type = "recipe",
  name = QUENCH,
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "iron-gear-wheel", amount = 20 },
    { type = "item", name = "pipe", amount = 10 },
  },
  results = { { type = "item", name = QUENCH, amount = 1 } },
}

-- === Technology =============================================================
-- The signature unlock. Gated behind BOTH parent chains -- `cindra-lava` (the
-- hot half) AND `cindra-ice-processing` (the cold half) -- so the two-temperature
-- craft is literally unreachable until the player commands both fire and ice.
-- That "needs 4 + 5" gate is the mechanic expressed as a tech dependency. The
-- full Cindra science tree (ci-3or) folds this in later.
local technology = {
  type = "technology",
  name = TECH,
  icon = "__cindra__/graphics/icons/cryo-quench.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = QUENCH },
    { type = "unlock-recipe", recipe = COOLANT },
    { type = "unlock-recipe", recipe = ALLOY },
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
  coolant, alloy, quench, quench_item,
  alloy_recipe, coolant_recipe, build_recipe,
  technology,
})
