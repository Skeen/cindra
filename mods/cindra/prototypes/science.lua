-- Cindra's HEADLINE science: the Cindra science pack + the tech tree it gates
-- (§15-12; DESIGN.md §2 "well-formed planet" checklist, §5).
--
-- The four-part planet checklist (§2) names the "headline science" as the Cindra
-- science pack, and requires it be PETROCHEMICAL-FREE. This file delivers that,
-- plus the machine that makes it and the tech that unlocks it, and folds the
-- launch tech into the Cindra tree so the pack has real downstream unlocks.
--
-- THREE properties the pack MUST have (locked by tests in tests/test_science.lua):
--
-- 1. PETROCHEMICAL-FREE, NATIVE INPUTS ONLY. No oil/coal/plastic/sulfur anywhere
--    in the recipe. It is built from Cindra's own materials: the signature
--    cryo-hardened alloy (fire+ice in one item), deep-nightside frozen volatiles,
--    and calcite from the ice chain. This is the planet's whole identity distilled
--    into one item -- you cannot make Cindra science without commanding both
--    lethal edges.
--
-- 2. A SIGNIFICANT POWER SINK. Power is Cindra's real resource (§1), so its
--    largest continuous activity -- researching -- must be another flare-timed
--    power sink. Two levers, both here: a LONG craft (`energy_required`) run in a
--    DEDICATED HIGH-DRAW machine (the starforge, ~10 MW active). One pack costs on
--    the order of the flare's own scale in energy, so science throughput scales
--    with captured flare / baseline power (ties to ci-9k6 / ci-63d).
--
-- 3. A REAL SCIENCE PACK. It is a `tool` (like every vanilla pack) and is appended
--    to the shared labs' accepted inputs so the force can actually research with
--    it. See the lab note below for why that shared-prototype touch is safe.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: the pack (cloned from automation-science-pack),
-- the starforge (cloned from assembling-machine-3) and its recipe are all fresh
-- prototypes in a PRIVATE crafting category, so the recipe never appears in a
-- vanilla assembler and vanilla recipes never appear in the starforge. The ONE
-- shared touch is appending our pack name to the labs' `inputs` (below) -- purely
-- ADDITIVE, and it changes no other planet's gameplay (no other planet can make
-- or needs the pack).

local util = require("util")

local PACK = "cindra-science-pack"    -- the tool item (a real science pack)
local FORGE = "cindra-starforge"      -- the dedicated high-draw crafting machine
local CATEGORY = "cindra-science"     -- private category: only the starforge runs it
local TECH = "cindra-science"         -- unlocks the pack + the forge

-- (tune) §15-14. THE POWER SINK, expressed in the two honest levers:
--   * FORGE_DRAW -- the machine's active electric draw. Set far above a normal
--     assembler (~375 kW) so running one starforge is a real load on the grid,
--     and an array of them is a flare-scale sink. This is the "power is the real
--     resource" identity made literal.
--   * PACK_SECONDS -- a long craft, so each pack also costs a lot of ENERGY
--     (FORGE_DRAW x PACK_SECONDS ~= 600 MJ/pack at the start values), not just a
--     lot of instantaneous power. Both are (tune) against the flare numbers.
local FORGE_DRAW = "10MW"
local PACK_SECONDS = 60

-- (tune) §15-14. Per-craft native inputs. Every one is a Cindra material with no
-- petrochemical anywhere in its own lineage:
--   * cryo-hardened alloy -- the signature product (fire quenched by ice).
--   * frozen volatiles     -- harvested from the deep, cold-lethal nightside.
--   * calcite              -- the ice chain's mineral output.
local ALLOY = "cindra-cryo-hardened-alloy"
local VOLATILES = "cindra-volatiles"
local ALLOY_PER_PACK = 1
local VOLATILES_PER_PACK = 3
local CALCITE_PER_PACK = 4
local PACK_PER_CRAFT = 1

local function set_icon(proto, filename, size, mipmaps)
  proto.icon = filename
  proto.icon_size = size
  proto.icon_mipmaps = mipmaps
  proto.icons = nil -- drop any inherited layered icon so our single icon wins
end

-- === The science pack (a real science-pack item) ===========================
-- Cloned from automation-science-pack so we inherit every field the engine and
-- the labs expect of a science pack (the `science-pack` subgroup, stack + sound
-- behaviour). Factorio 2.1 defines science packs as plain `item`s (the old `tool`
-- type is gone), so we clone from data.raw.item.
-- v1 ART: reuse the vanilla automation-pack sprite, tinted a hot amber so it
-- reads as Cindra's own pack (no bespoke pack art yet -- see PLAYTEST.md).
local pack = util.table.deepcopy(data.raw.item["automation-science-pack"])
pack.name = PACK
pack.order = "z[cindra]-z[science-pack]"
pack.icon = nil
pack.icons = {
  {
    icon = "__base__/graphics/icons/automation-science-pack.png",
    icon_size = 64,
    tint = { r = 1.0, g = 0.72, b = 0.35, a = 1.0 },
  },
}
pack.localised_name = { "item-name.cindra-science-pack" }
pack.localised_description = { "item-description.cindra-science-pack" }

-- === The starforge: the dedicated, power-hungry crafting machine ============
-- Cloned from assembling-machine-3 (a known-good electric crafter). We crank its
-- active draw far up so it is a genuine power SINK, and lock it to the private
-- Cindra science category so nothing else runs here and this runs nowhere else.
local forge = util.table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
forge.name = FORGE
forge.minable = { mining_time = 0.5, result = FORGE }
forge.crafting_categories = { CATEGORY }
forge.energy_usage = FORGE_DRAW -- the power sink: ~10 MW active draw
forge.fast_replaceable_group = nil -- not interchangeable with vanilla assemblers
forge.next_upgrade = nil
forge.placeable_by = { item = FORGE, count = 1 }
forge.localised_name = { "entity-name.cindra-starforge" }
forge.localised_description = { "entity-description.cindra-starforge" }

local forge_item = util.table.deepcopy(data.raw.item["assembling-machine-3"])
forge_item.name = FORGE
forge_item.place_result = FORGE
forge_item.order = "z[cindra]-y[starforge]"
forge_item.localised_name = { "item-name.cindra-starforge" }
forge_item.localised_description = { "item-description.cindra-starforge" }

-- Private crafting category: only the starforge crafts Cindra science, and the
-- starforge crafts nothing else.
local category = { type = "recipe-category", name = CATEGORY }

-- === Recipes ================================================================
-- The headline recipe: native inputs only, deliberately expensive in TIME so the
-- high-draw starforge turns it into a large ENERGY cost per pack. No fluid, no
-- fuel, no petrochemical -- the whole point.
local pack_recipe = {
  type = "recipe",
  name = PACK,
  categories = { CATEGORY },
  enabled = false, -- gated: unlocked by the cindra-science tech, never free.
  energy_required = PACK_SECONDS,
  ingredients = {
    { type = "item", name = ALLOY, amount = ALLOY_PER_PACK },
    { type = "item", name = VOLATILES, amount = VOLATILES_PER_PACK },
    { type = "item", name = "calcite", amount = CALCITE_PER_PACK },
  },
  results = {
    { type = "item", name = PACK, amount = PACK_PER_CRAFT },
  },
  allow_productivity = true,
  main_product = PACK,
}

-- Recipe to BUILD the starforge (gated behind the tech). Native/brought metal +
-- a little of the signature alloy, so the machine itself is a Cindra artifact.
local forge_build_recipe = {
  type = "recipe",
  name = FORGE,
  enabled = false,
  energy_required = 15,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 30 },
    { type = "item", name = "iron-gear-wheel", amount = 30 },
    { type = "item", name = ALLOY, amount = 5 },
  },
  results = { { type = "item", name = FORGE, amount = 1 } },
}

-- === Technology =============================================================
-- The unlock for the headline science. Gated behind the SIGNATURE apex
-- (cindra-cryo-quenching), which itself needs BOTH the lava spine and ice
-- processing -- so you cannot make Cindra science until you already command both
-- fire and ice. Researched with the BROUGHT vanilla packs (you cannot pay for the
-- pack-unlock with the pack itself -- that would be a soft-lock, §15-13); every
-- DEEPER Cindra unlock then costs the Cindra pack (see the fold in mass-driver.lua).
local technology = {
  type = "technology",
  name = TECH,
  icon = "__base__/graphics/icons/automation-science-pack.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = PACK },
    { type = "unlock-recipe", recipe = FORGE },
  },
  prerequisites = { "cindra-cryo-quenching" },
  unit = {
    count = 300,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 45,
  },
}

data:extend({
  category,
  pack, forge, forge_item,
  pack_recipe, forge_build_recipe,
  technology,
})

-- === Make it a REAL science pack: append to the labs' accepted inputs ========
-- A `tool` is only researchable if some lab lists it in `inputs`. The base game
-- does exactly this for every vanilla pack; a new pack must be appended the same
-- way. This is the ONE shared-prototype touch in this file, and it is safe under
-- the never-mutate-other-planets invariant because it is purely ADDITIVE and
-- changes NO other planet's gameplay: no other planet can produce the Cindra pack,
-- and no existing technology requires it, so labs elsewhere behave identically --
-- they merely gain the ability to accept a pack that only Cindra can make. There
-- is no per-surface lab-inputs API (research is force-wide, and the player will
-- carry Cindra packs to whatever labs they already own), so appending here is the
-- only way the pack can function at all. Guarded against a double-add.
for _, lab in pairs(data.raw.lab or {}) do
  if lab.inputs then
    local present = false
    for _, input in pairs(lab.inputs) do
      if input == PACK then present = true break end
    end
    if not present then
      table.insert(lab.inputs, PACK)
    end
  end
end
