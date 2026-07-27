-- The Cindra mass driver (§15-11; DESIGN.md §5, §11). DEFINITIVE SPEC (ci-o39):
-- the mass driver is a RESKINNED ROCKET-SILO, not a chest.
--
-- WHY A ROCKET-SILO TYPE. The earlier composite (a container + a hidden
-- accumulator + a scripted fire loop, ci-epp/ci-98r) hand-rolled cross-surface
-- delivery. A `rocket-silo` prototype gives that delivery NATIVELY: the vanilla
-- launch path lifts cargo to an orbiting space platform's hub with no bespoke
-- catcher and no runtime loop to maintain. So the driver is a full deep-copy of
-- the vanilla rocket-silo -- keeping its `rocket_entity` (and therefore the
-- hub-accepted vanilla cargo pod) intact -- reskinned with the mass-driver icon
-- and re-fuelled on Cindra's own economy.
--
-- WHAT A LAUNCH COSTS (still PETROCHEMICAL-FREE, the whole point of §11). Like the
-- vanilla silo builds its rocket from rocket-PARTS out of raw LDS/fuel/chips, this
-- driver assembles ONE launch vehicle INTERNALLY (its `fixed_recipe`, the launch
-- charge) from RAW MATERIALS fed straight in -- there is NO pre-crafted "can" item
-- to press elsewhere (ci-loa). The internal build consumes:
--   * RAW ALUMINIUM           the launch-vehicle body, fed directly as Cindra's
--                             signature metal (not a hand-pressed can). The silo
--                             presses/assembles the vehicle in place before firing.
--   * ROCKET FUEL             the VANILLA rocket-fuel item (ci-519), but minted the
--                             Cindra way: the "Solid rocket fuel" recipe below turns
--                             aluminium POWDER into vanilla rocket-fuel -- metallic
--                             aluminium is the energetic base, so the propellant is
--                             native metal, NOT oil/coal/plastic. There is NO custom
--                             fuel item; anything needing rocket fuel uses the vanilla
--                             one made via this aluminium recipe.
--   * a SHITTON of POWER      the silo's crafting draw (a large continuous load)
--                             times a long charge craft => a huge per-launch energy.
-- That drops vanilla rocket-parts / LDS / processing-units and the oil route to
-- rocket fuel entirely: the recurring launch cost lands on local metallurgy + power,
-- never petrochemistry. The materials + fuel chain is added here (aluminium fed raw;
-- aluminium -> powder -> vanilla rocket-fuel), gated behind the same launch tech.
--
-- PRODUCTIVITY MODULES (ci-loa). A mass driver is a real rocket-silo, so it keeps
-- the vanilla silo's module slots and PERMITS PRODUCTIVITY on the internal launch
-- build: a prod bonus yields bonus launch charges => more launches per unit of
-- aluminium + fuel, a fair reward where you have spare module capacity. (Contrast
-- the aluminium/lava chains, where productivity is deliberately OFF so power stays
-- the honest cost of the METAL itself; here productivity discounts the LAUNCH, not
-- the metal, and the dominant per-launch cost remains the silo's raw power draw.)
--
-- CARGO DELIVERY. A launch behaves like a vanilla rocket: the payload lands in the
-- space platform hub (the standard rocket destination). There is NO platform-side
-- catcher building (ci-98r) -- that trait is inherited for free from the silo type.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is a fresh clone (deep-copied
-- via util.table.deepcopy before any nested edit) or brand new; no shared vanilla
-- table is touched. The launch charge lives in a PRIVATE recipe category so only
-- this driver ever crafts it -- vanilla Nauvis silos (fixed_recipe = rocket-part)
-- are completely unaffected.
--
-- SITUATIONAL-NOT-STRICTLY-BETTER (§12 guardrail): it is not a free rocket. It eats
-- a huge slug of power per launch, so it is superb only where power overflows
-- (Cindra at flare) and clumsy where you would rather burn cheap fuel elsewhere.
--
-- v1 ART: the driver reuses the vanilla rocket-silo animation set (a full silo
-- reskin is a later art pass -- see PLAYTEST.md); only its inventory ICON is the
-- delivered mass-driver art. The launch consumables reuse tinted vanilla icons.

local util = require("util")

-- Tuning knobs (all `(tune)` starting points, DESIGN.md §7). Exposed on the
-- returned module so tests can read the same numbers.
local M = {}
M.DRIVER = "cindra-mass-driver"            -- the reskinned rocket-silo
M.TECH = "cindra-orbital-launch"           -- the unlock tech (folded into the Cindra tree)
M.POWDER = "cindra-aluminium-powder"       -- metallic aluminium powder (the fuel base)
M.ALUMINIUM = "cindra-aluminium"           -- the launch-vehicle body, fed RAW (no pre-made can, ci-loa)
M.ROCKET_FUEL = "rocket-fuel"              -- VANILLA rocket-fuel: Cindra makes it from aluminium (ci-519)
M.FUEL_RECIPE = "cindra-solid-rocket-fuel" -- recipe "Solid rocket fuel": aluminium-powder -> vanilla rocket-fuel
M.CHARGE = "cindra-launch-charge"          -- the silo's rocket-part analog (the internal launch vehicle)
M.CHARGE_CATEGORY = "cindra-mass-driver-charge"  -- PRIVATE: only the driver crafts the charge

M.SILO_DRAW = "60MW"        -- crafting draw while building a launch charge (a large load)
M.SILO_LAUNCH_DRAW = "100MW" -- extra draw during the launch sequence (the burst)
M.CHARGE_SECONDS = 30       -- long charge craft: SILO_DRAW * CHARGE_SECONDS ~= 1.8 GJ / launch
M.ALUMINIUM_PER_LAUNCH = 5  -- raw aluminium the silo assembles into the launch vehicle (was a pre-pressed can)
M.FUEL_PER_LAUNCH = 10      -- vanilla rocket-fuel (Cindra's aluminium-made "Solid rocket fuel") per launch
M.MODULE_SLOTS = 4          -- keep the vanilla silo's module bay (supports productivity, ci-loa)

-- Delivered mass-driver icon (graphics/ART-MANIFEST.md, ci-pru): a 64px mipmap strip.
local function set_driver_icon(proto)
  proto.icon = "__cindra__/graphics/icons/mass-driver.png"
  proto.icon_size = 64
  proto.icon_mipmaps = 4
  proto.icons = nil  -- drop any inherited layered icon so our single icon wins
end

-- Retint a reused vanilla icon so a launch consumable reads distinctly.
local function set_icon(proto, icon, tint)
  proto.icon = nil
  proto.icons = { { icon = icon, icon_size = 64, tint = tint } }
  proto.icon_size = 64
  proto.icon_mipmaps = nil
end

-- === The launch building: a reskinned rocket-silo ============================
-- Full deep-copy keeps every silo field the engine needs (rocket_entity, cargo
-- pod, launch graphics, cargo_station_parameters, launch_to_space_platforms), so
-- delivery-to-platform is inherited unchanged. We only re-point the recipe, crank
-- the power, and swap the inventory icon.
local driver = util.table.deepcopy(data.raw["rocket-silo"]["rocket-silo"])
driver.name = M.DRIVER
driver.minable = { mining_time = 1, result = M.DRIVER }
driver.next_upgrade = nil
driver.fast_replaceable_group = nil
-- Fire on ONE charge craft: a mass driver flings a single payload, then rebuilds
-- its charge. The private category means only this driver runs the charge recipe.
driver.crafting_categories = { M.CHARGE_CATEGORY }
driver.fixed_recipe = M.CHARGE
driver.rocket_parts_required = 1
driver.rocket_parts_storage_cap = 1
driver.energy_usage = M.SILO_DRAW
driver.active_energy_usage = M.SILO_LAUNCH_DRAW
driver.launch_to_space_platforms = true  -- deliver cargo to platforms (Space Age)
-- Support productivity modules (ci-loa). The deep-copy already carries the vanilla
-- silo's module bay, but we pin the slots + allowed effects EXPLICITLY so the
-- productivity capability survives any upstream silo change and is unambiguous in
-- tests. Productivity discounts the LAUNCH (bonus charges), not the metal.
driver.module_slots = M.MODULE_SLOTS
driver.allowed_effects = { "consumption", "speed", "productivity", "pollution" }
set_driver_icon(driver)
driver.localised_name = { "entity-name.cindra-mass-driver" }
driver.localised_description = { "entity-description.cindra-mass-driver" }

-- === Items ===================================================================
local driver_item = util.table.deepcopy(data.raw.item["rocket-silo"])
driver_item.name = M.DRIVER
driver_item.place_result = M.DRIVER
driver_item.order = "z[cindra-mass-driver]"
set_driver_icon(driver_item)
-- Inherit the rocket-silo item's SUBGROUP so the driver lands in the SPACE
-- crafting tab (where the vanilla silo lives), not Logistics.
driver_item.localised_name = { "item-name.cindra-mass-driver" }
driver_item.localised_description = { "item-description.cindra-mass-driver" }

-- NO aluminium-can item (ci-loa). The launch vehicle is assembled INSIDE the silo
-- from raw aluminium fed straight in (see the launch-charge recipe below), exactly
-- as a vanilla silo builds its rocket from raw materials -- there is no pre-crafted
-- cargo container the player presses elsewhere.

-- Aluminium powder: metallic aluminium ground fine -- the energetic fuel base.
local powder_item = util.table.deepcopy(data.raw.item["calcite"])
powder_item.name = M.POWDER
powder_item.stack_size = 100
powder_item.order = "z[cindra-mass-driver]-b[powder]"
set_icon(powder_item, "__space-age__/graphics/icons/calcite.png", { r = 0.72, g = 0.78, b = 0.88, a = 1.0 })
powder_item.localised_name = { "item-name.cindra-aluminium-powder" }
powder_item.localised_description = { "item-description.cindra-aluminium-powder" }

-- NO custom "solid rocket fuel" ITEM (ci-519). Cindra's petrochemical-free
-- propellant IS the VANILLA rocket-fuel item, minted from aluminium by the "Solid
-- rocket fuel" recipe below. The mass driver (and anything else needing rocket
-- fuel) uses that vanilla item, so there is no new fuel type to carry around.

-- The launch charge: the silo's internal "rocket part". Hidden -- the player never
-- handles it; the driver builds one from a can + fuel, then launches.
local charge_item = util.table.deepcopy(data.raw.item["rocket-part"])
charge_item.name = M.CHARGE
charge_item.hidden = true
charge_item.order = "z[cindra-mass-driver]-d[charge]"
charge_item.localised_name = { "item-name.cindra-launch-charge" }
charge_item.localised_description = { "item-description.cindra-launch-charge" }

-- === Recipe category (PRIVATE: only the driver crafts the charge) ============
local charge_category = { type = "recipe-category", name = M.CHARGE_CATEGORY }

-- === Recipes (all PETROCHEMICAL-FREE; gated behind the launch tech) ==========
-- NO can recipe (ci-loa): raw aluminium is fed straight into the launch charge.

-- Aluminium -> powder (grind metallic aluminium fine).
local powder_recipe = {
  type = "recipe",
  name = M.POWDER,
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "item", name = "cindra-aluminium", amount = 1 },
  },
  results = { { type = "item", name = M.POWDER, amount = 2 } },
}

-- "Solid rocket fuel": aluminium powder -> VANILLA rocket-fuel (ci-519). This is
-- Cindra's petrochemical-free ROUTE to rocket fuel -- it PRODUCES the vanilla
-- rocket-fuel item (no bespoke fuel type) from a single native input: no oil, no
-- coal, no plastic, no acid, the propellant is the metal itself. The recipe name
-- differs from its product (localised "Solid rocket fuel"), so it reads as an
-- alternative recipe sitting next to vanilla rocket-fuel in the crafting menu.
local fuel_recipe = {
  type = "recipe",
  name = M.FUEL_RECIPE,
  enabled = false,
  energy_required = 2,
  ingredients = {
    { type = "item", name = M.POWDER, amount = 3 },
  },
  results = { { type = "item", name = M.ROCKET_FUEL, amount = 1 } },
  main_product = M.ROCKET_FUEL,
}

-- The launch charge (the silo's fixed_recipe): the launch vehicle assembled INSIDE
-- the silo from RAW MATERIALS -- { raw aluminium + solid rocket fuel } over a LONG
-- craft (ci-loa). `enabled=false` is fine -- a rocket-silo always runs its
-- fixed_recipe regardless, so this is never hand/assembler craftable. The dominant
-- cost is the silo's power draw across the long craft (SILO_DRAW * CHARGE_SECONDS
-- per launch). Productivity is ALLOWED: a prod bonus yields bonus charges (more
-- launches per unit of material), the fair reward for spending module capacity here.
local charge_recipe = {
  type = "recipe",
  name = M.CHARGE,
  categories = { M.CHARGE_CATEGORY },
  enabled = false,
  hidden = true,
  energy_required = M.CHARGE_SECONDS,
  ingredients = {
    { type = "item", name = M.ALUMINIUM, amount = M.ALUMINIUM_PER_LAUNCH },
    { type = "item", name = M.ROCKET_FUEL, amount = M.FUEL_PER_LAUNCH },
  },
  results = { { type = "item", name = M.CHARGE, amount = 1 } },
  allow_productivity = true,   -- productivity discounts the LAUNCH (bonus charges), ci-loa
}

-- Recipe to BUILD the driver (gated behind the tech). Native metal + electronics +
-- Cindra aluminium; deliberately no plastic/processing-units (petrochemical-free).
local driver_recipe = {
  type = "recipe",
  name = M.DRIVER,
  enabled = false,
  energy_required = 30,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 200 },
    { type = "item", name = "concrete", amount = 100 },
    { type = "item", name = "cindra-aluminium", amount = 50 },
    { type = "item", name = "iron-gear-wheel", amount = 100 },
    { type = "item", name = "copper-cable", amount = 100 },
  },
  results = { { type = "item", name = M.DRIVER, amount = 1 } },
}

-- === Technology: an ADVANCED unlock in the folded Cindra science tree =========
-- FOLDED INTO THE CINDRA TREE (ci-3or, §15-12): orbital launch is an advanced
-- capability, so it (a) branches off `cindra-science` -- you must master the
-- headline science before you can export -- and (b) is RESEARCHED WITH the Cindra
-- science pack, making the pack's downstream unlocks real. The `planet-discovery-
-- cindra` prereq is kept so the tech still reads as Cindra's own signature
-- infrastructure and stays a valid root under any-planet-start (APS hides
-- planet-discovery-cindra and strips it from every dependent's prerequisite list,
-- so this tech simply becomes rooted at cindra-science -- no dangling reference).
local technology = {
  type = "technology",
  name = M.TECH,
  -- v1 art reuse: the delivered mass-driver icon (64px mipmap strip).
  icon = "__cindra__/graphics/icons/mass-driver.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = M.DRIVER },
    { type = "unlock-recipe", recipe = M.POWDER },
    { type = "unlock-recipe", recipe = M.FUEL_RECIPE },
  },
  prerequisites = { "planet-discovery-cindra", "cindra-science" },
  unit = {
    count = 200,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
      -- The fold made real: exporting off Cindra costs Cindra's headline science.
      { "cindra-science-pack", 1 },
    },
    time = 30,
  },
}

data:extend({
  charge_category,
  driver,
  driver_item, powder_item, charge_item,
  driver_recipe, powder_recipe, fuel_recipe, charge_recipe,
  technology,
})

return M
