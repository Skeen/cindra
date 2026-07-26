-- Mass-driver PoC prototypes.
--
-- The mass driver launches cargo to orbit on ELECTRICITY ONLY (plus an
-- optional native-metal projectile shell). It replaces the rocket, so there
-- is zero launch-driven chemistry: no rocket fuel, no plastic, no acid.
--
-- The launch building is a COMPOSITE of two prototypes:
--   * `mass-driver`         a visible container (holds the cargo payload and
--                           the projectile shells) that inserters/belts load.
--   * `mass-driver-charger` a HIDDEN accumulator, spawned by the runtime at the
--                           driver's tile, that charges from the electric grid
--                           and holds the per-shot energy. Its collision mask is
--                           empty so it overlaps the container. Script reads its
--                           `.energy` to know when the shot is charged.
-- Splitting inventory (container) from a script-readable electric buffer
-- (accumulator) is the only way to get both on one building: no single vanilla
-- entity type exposes an item inventory AND a chargeable, readable buffer.
--
-- The orbit side is a one-time `mass-driver-catcher` container (models a
-- cargo-landing-pad on a space platform). See README.md for the tuning table.

local util = require("util")

-- Tuning knobs (all PoC starting points -- see README.md "Tuning"). Exposed on
-- the module so the runtime and tests read the same numbers.
local M = {}
M.DRIVER = "mass-driver"
M.CHARGER = "mass-driver-charger"
M.CATCHER = "mass-driver-catcher"
M.SHELL = "mass-driver-shell"

M.SHOT_ENERGY = "500MJ"   -- energy per shot (the charger's buffer capacity)
M.CHARGE_RATE = "10MW"    -- how fast a shot charges from the grid
M.SHOT_CAPACITY = 100     -- cargo items delivered per shot
M.SHELL_PER_SHOT = 1      -- native projectile shells consumed per shot

local EMPTY_SPRITE = {
  filename = "__core__/graphics/empty.png",
  priority = "very-low",
  width = 1,
  height = 1,
}

-- === Visible launch building: a container that holds cargo + shells ==========
local driver = util.table.deepcopy(data.raw.container["steel-chest"])
driver.name = M.DRIVER
driver.minable = { mining_time = 0.5, result = M.DRIVER }
driver.inventory_size = 40
driver.next_upgrade = nil
-- Tint the chest so the launch building reads as distinct from a plain chest.
if driver.picture and driver.picture.layers then
  for _, layer in pairs(driver.picture.layers) do
    layer.tint = { r = 0.55, g = 0.75, b = 1.0, a = 1.0 }
  end
elseif driver.picture then
  driver.picture.tint = { r = 0.55, g = 0.75, b = 1.0, a = 1.0 }
end

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
if catcher.picture and catcher.picture.layers then
  for _, layer in pairs(catcher.picture.layers) do
    layer.tint = { r = 1.0, g = 0.75, b = 0.4, a = 1.0 }
  end
elseif catcher.picture then
  catcher.picture.tint = { r = 1.0, g = 0.75, b = 0.4, a = 1.0 }
end

-- === Items ===================================================================
local driver_item = util.table.deepcopy(data.raw.item["steel-chest"])
driver_item.name = M.DRIVER
driver_item.place_result = M.DRIVER
driver_item.order = "z[mass-driver]-a[driver]"

local catcher_item = util.table.deepcopy(data.raw.item["steel-chest"])
catcher_item.name = M.CATCHER
catcher_item.place_result = M.CATCHER
catcher_item.order = "z[mass-driver]-b[catcher]"

-- The projectile shell: option A -- a consumable made of native metal, so the
-- recurring launch cost lands on local metallurgy, NOT on chemistry. steel-plate
-- stands in for Cindra's cryo-hardened alloy in this standalone PoC.
local shell_item = util.table.deepcopy(data.raw.item["steel-plate"])
shell_item.name = M.SHELL
shell_item.place_result = nil
shell_item.stack_size = 100
shell_item.order = "z[mass-driver]-c[shell]"
if shell_item.icons then
  for _, ic in pairs(shell_item.icons) do ic.tint = { r = 0.7, g = 0.85, b = 1.0, a = 1.0 } end
end

-- === Recipes (all chemistry-free; enabled from the start for the PoC) ========
local driver_recipe = {
  type = "recipe",
  name = M.DRIVER,
  enabled = true,
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
  enabled = true,
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
  enabled = true,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 5 },
  },
  results = { { type = "item", name = M.SHELL, amount = 1 } },
}

data:extend({
  driver, charger, catcher,
  driver_item, catcher_item, shell_item,
  driver_recipe, catcher_recipe, shell_recipe,
})

return M
