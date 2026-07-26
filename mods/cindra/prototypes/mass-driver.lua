-- The Cindra mass driver (§15-11; DESIGN.md §5, §11). Integrated from the proven
-- standalone PoC (mods/mass-driver, ci-epp).
--
-- Goods leave Cindra by ELECTRICITY, not chemistry. The mass driver flings cargo
-- to an orbital catcher spending only a charged electric buffer plus one optional
-- native-metal projectile shell -- no rocket fuel, no plastic, no acid. That is
-- what makes the planet's launch footprint zero (the whole point of §11): the
-- recurring launch cost lands on local metallurgy + power, never petrochemistry.
--
-- The launch building is a COMPOSITE of two prototypes:
--   * cindra-mass-driver          a visible container (holds the cargo payload and
--                                 the projectile shells) that inserters/belts load.
--   * cindra-mass-driver-charger  a HIDDEN accumulator, spawned by the runtime at
--                                 the driver's tile, that charges from the grid and
--                                 holds the per-shot energy. Empty collision mask so
--                                 it overlaps the container; the runtime reads its
--                                 .energy to know when the shot is charged, and its
--                                 output_flow_limit is 0 so energy only ever leaves
--                                 as a launch, never back to the grid.
-- Splitting inventory (container) from a script-readable electric buffer
-- (accumulator) is the only way to get both on one building: no single vanilla
-- entity type exposes an item inventory AND a chargeable, readable buffer.
--
-- The orbit side is a one-time cindra-mass-driver-catcher container (models a
-- cargo-landing-pad on a space platform).
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is a fresh clone (deep-copied
-- via util.table.deepcopy before any nested edit); no shared vanilla table is
-- touched. These are Cindra-exclusive entities/items/recipes.
--
-- SITUATIONAL-NOT-STRICTLY-BETTER (§12 guardrail): the driver is not a free rocket.
-- Its cost is bursty power (charge a 500 MJ buffer, then fire) plus a native shell,
-- so it is superb only where power overflows (Cindra at flare) and clumsy where you
-- would rather burn fuel and launch continuously.
--
-- NATIVE-INGREDIENT GATE (partial): the design wants the shell forged from Cindra's
-- signature cryo-hardened alloy. That material (ci-gd4) does not exist yet, so the
-- shell is steel-plate for now (still pure native metal, zero chemistry).
-- TODO(ci-gd4): swap the shell recipe input to cryo-hardened-alloy once it lands.

local util = require("util")

-- Tuning knobs (all `(tune)` starting points, DESIGN.md §7 / PoC README). Exposed
-- on the returned module so the runtime + tests can read the same numbers.
-- 🚨 The runtime (scripts/mass-driver.lua) mirrors the NAMES + SHOT_CAPACITY /
-- SHELL_PER_SHOT constants; keep the two in sync (a test cross-checks them).
local M = {}
M.DRIVER = "cindra-mass-driver"
M.CHARGER = "cindra-mass-driver-charger"
M.CATCHER = "cindra-mass-driver-catcher"
M.SHELL = "cindra-mass-driver-shell"
M.TECH = "cindra-orbital-launch"

M.SHOT_ENERGY = "500MJ"   -- energy per shot (the charger's buffer capacity)
M.CHARGE_RATE = "10MW"    -- how fast a shot charges from the grid (~50 s => bursty)
M.SHOT_CAPACITY = 100     -- cargo items delivered per shot
M.SHELL_PER_SHOT = 1      -- native projectile shells consumed per shot

local EMPTY_SPRITE = {
  filename = "__core__/graphics/empty.png",
  priority = "very-low",
  width = 1,
  height = 1,
}

-- Delivered art (graphics/ART-MANIFEST.md, ci-pru): a 64px mipmap icon strip and a
-- 256x256 static entity sprite + shadow for the driver. The catcher has an icon but
-- no bespoke entity sprite yet, so it keeps a tinted-chest in-world look.
local function set_icon(proto, name)
  proto.icon = "__cindra__/graphics/icons/" .. name .. ".png"
  proto.icon_size = 64
  proto.icon_mipmaps = 4
  proto.icons = nil  -- drop any inherited layered icon so our single icon wins
end

-- === Visible launch building: a container that holds cargo + shells ==========
local driver = util.table.deepcopy(data.raw.container["steel-chest"])
driver.name = M.DRIVER
driver.minable = { mining_time = 0.5, result = M.DRIVER }
driver.inventory_size = 40
driver.next_upgrade = nil
set_icon(driver, "mass-driver")
-- Wear the delivered mass-driver sprite (idle base layer + soft ground shadow).
driver.picture = {
  layers = {
    {
      filename = "__cindra__/graphics/entity/mass-driver/mass-driver.png",
      width = 256, height = 256, scale = 0.5, shift = { 0, -0.3 },
    },
    {
      filename = "__cindra__/graphics/entity/mass-driver/mass-driver-shadow.png",
      width = 256, height = 256, scale = 0.5, shift = { 0.3, 0 }, draw_as_shadow = true,
    },
  },
}
driver.localised_name = { "entity-name.cindra-mass-driver" }
driver.localised_description = { "entity-description.cindra-mass-driver" }

-- === Hidden per-shot energy buffer: an accumulator overlapping the driver ====
local charger = util.table.deepcopy(data.raw.accumulator["accumulator"])
charger.name = M.CHARGER
charger.hidden = true
charger.flags = {
  "not-blueprintable", "not-deconstructable", "not-on-map",
  "placeable-off-grid", "not-upgradable", "hide-alt-info",
}
charger.selectable_in_game = false
charger.minable = nil
charger.next_upgrade = nil
charger.collision_mask = { layers = {} }  -- overlap the container tile
charger.energy_source = {
  type = "electric",
  usage_priority = "tertiary",
  buffer_capacity = M.SHOT_ENERGY,
  input_flow_limit = M.CHARGE_RATE,
  output_flow_limit = "0W",  -- energy goes into the shot, never back to the grid
}
charger.chargable_graphics = { picture = EMPTY_SPRITE }
charger.water_reflection = nil
charger.default_output_signal = nil

-- === Orbit-side catcher: a one-time container on the space platform ==========
local catcher = util.table.deepcopy(data.raw.container["steel-chest"])
catcher.name = M.CATCHER
catcher.minable = { mining_time = 0.5, result = M.CATCHER }
catcher.inventory_size = 80
catcher.next_upgrade = nil
set_icon(catcher, "mass-driver-catcher")
-- No bespoke entity sprite for the catcher yet: tint the chest amber so it reads
-- as the landing side of the launch pair.
if catcher.picture and catcher.picture.layers then
  for _, layer in pairs(catcher.picture.layers) do
    layer.tint = { r = 1.0, g = 0.75, b = 0.4, a = 1.0 }
  end
elseif catcher.picture then
  catcher.picture.tint = { r = 1.0, g = 0.75, b = 0.4, a = 1.0 }
end
catcher.localised_name = { "entity-name.cindra-mass-driver-catcher" }
catcher.localised_description = { "entity-description.cindra-mass-driver-catcher" }

-- === Items ===================================================================
local driver_item = util.table.deepcopy(data.raw.item["steel-chest"])
driver_item.name = M.DRIVER
driver_item.place_result = M.DRIVER
driver_item.order = "z[cindra-mass-driver]-a[driver]"
set_icon(driver_item, "mass-driver")
driver_item.localised_name = { "item-name.cindra-mass-driver" }
driver_item.localised_description = { "item-description.cindra-mass-driver" }

local catcher_item = util.table.deepcopy(data.raw.item["steel-chest"])
catcher_item.name = M.CATCHER
catcher_item.place_result = M.CATCHER
catcher_item.order = "z[cindra-mass-driver]-b[catcher]"
set_icon(catcher_item, "mass-driver-catcher")
catcher_item.localised_name = { "item-name.cindra-mass-driver-catcher" }
catcher_item.localised_description = { "item-description.cindra-mass-driver-catcher" }

-- The projectile shell (option A): a consumable made of native metal, so the
-- recurring launch cost lands on local metallurgy, NOT on chemistry. steel-plate
-- stands in for the cryo-hardened alloy until ci-gd4 lands. No bespoke icon yet;
-- tint the steel-plate icon cool so it reads as a launch shell.
local shell_item = util.table.deepcopy(data.raw.item["steel-plate"])
shell_item.name = M.SHELL
shell_item.place_result = nil
shell_item.stack_size = 100
shell_item.order = "z[cindra-mass-driver]-c[shell]"
if shell_item.icons then
  for _, ic in pairs(shell_item.icons) do ic.tint = { r = 0.7, g = 0.85, b = 1.0, a = 1.0 } end
end
shell_item.localised_name = { "item-name.cindra-mass-driver-shell" }
shell_item.localised_description = { "item-description.cindra-mass-driver-shell" }

-- === Recipes (all chemistry-free; GATED behind the tech below, not free) ======
local driver_recipe = {
  type = "recipe",
  name = M.DRIVER,
  enabled = false,  -- unlocked by cindra-orbital-launch
  energy_required = 5,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 50 },
    { type = "item", name = "iron-gear-wheel", amount = 20 },
    { type = "item", name = "copper-cable", amount = 40 },
  },
  results = { { type = "item", name = M.DRIVER, amount = 1 } },
}

local catcher_recipe = {
  type = "recipe",
  name = M.CATCHER,
  enabled = false,  -- unlocked by cindra-orbital-launch
  energy_required = 5,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 50 },
    { type = "item", name = "iron-gear-wheel", amount = 10 },
  },
  results = { { type = "item", name = M.CATCHER, amount = 1 } },
}

-- Shell recipe: pure native metal. No plastic, no sulfuric acid, no rocket fuel.
local shell_recipe = {
  type = "recipe",
  name = M.SHELL,
  enabled = false,  -- unlocked by cindra-orbital-launch
  energy_required = 2,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 5 },
  },
  results = { { type = "item", name = M.SHELL, amount = 1 } },
}

-- === Technology: an ADVANCED unlock in the folded Cindra science tree =========
-- FOLDED INTO THE CINDRA TREE (ci-3or, §15-12): orbital launch is an advanced
-- capability, so it now (a) branches off `cindra-science` -- you must master the
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
    { type = "unlock-recipe", recipe = M.CATCHER },
    { type = "unlock-recipe", recipe = M.SHELL },
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
  driver, charger, catcher,
  driver_item, catcher_item, shell_item,
  driver_recipe, catcher_recipe, shell_recipe,
  technology,
})

return M
