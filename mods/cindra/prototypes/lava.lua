-- Manufactured lava, the central economy spine (§15-5; DESIGN.md §1, §2, §5, §7).
--
-- Cindra has no lava lakes to pump (that is Vulcanus). Here lava is MADE from
-- stone with ruinous electric power at the fixed spec ratio `1 stone -> 5 lava`.
-- That fluid then feeds the Vulcanus foundry chain (molten iron / copper), so
-- the whole metal economy routes through a recipe whose real cost is the star's
-- surplus.
--
-- THROUGHPUT RESCALE (ci-e8a, follow-up to ci-095). The problem was USABILITY,
-- not the ratio: at the old `1 stone -> 5 lava` on the shared 2.5 MW / speed-4
-- foundry it took ~100 lava-crafting foundries to keep ONE melting foundry fed
-- (unusable; the user was rightly angry). The fix, per the mayor's resolution,
-- is NOT to cheapen lava (do not touch energy-per-lava) but to CONCENTRATE the
-- draw: craft lava on a DEDICATED, HIGH-SPEED, HIGH-DRAW Cindra machine (the
-- `cindra-lava-manufacturer` below) instead of the shared foundry. A few hungry
-- machines replace a hundred tiny ones; the TOTAL grid power to sustain foundry-
-- scale lava is UNCHANGED (still ruinous), just delivered by single-digit
-- buildings. Machine count is set by the machine's crafting_speed; energy-per-
-- lava is set by the recipe, and stays fixed. See MACHINE-COUNT vs POWER below.
--
-- FOUR PARTS:
--
-- 1. THE LAVA RECIPE. `1 stone -> 5 lava` (ratio + energy fixed by spec, §7).
--    Its own private category `cindra-lava-manufacturing`, so ONLY the Cindra
--    lava-manufacturer crafts it -- the shared Vulcanus foundry does NOT (that
--    is the whole point: we own our machine, we never touch theirs). "Power is
--    the lever": the stone/lava amounts are fixed, and the cost knob is
--    `energy_required` against the manufacturer's electric draw. Productivity is
--    ALLOWED: lava is the central intermediate and its cost is ruinous power, so
--    a productivity bonus is a fair reward and matches vanilla intermediate
--    conventions (the downstream molten recipes allow it too).
--
-- 2. THE LAVA-MANUFACTURER MACHINE. A dedicated Cindra building (a foundry clone
--    for v1 art reuse) with a BIG crafting_speed and a PROPORTIONALLY big
--    electric draw, so `energy_usage / crafting_speed` EQUALS the foundry's --
--    i.e. the same energy per unit lava, just concentrated. A single-digit count
--    of these sustains one melting foundry (usable), while the aggregate draw
--    stays a serious sink (ruinous). We DEEP-COPY the shared foundry prototype
--    before touching it, and give the machine its own recipe category, so we
--    never mutate Vulcanus content (the never-mutate-other-planets invariant).
--
-- 3. FOUNDRY INTEGRATION -- BROUGHT, NOT RE-UNLOCKED. The foundry and its
--    `molten-iron-from-lava` / `molten-copper-from-lava` recipes are Vulcanus
--    content the player already owns by the time Cindra is reachable (§6 gates
--    Cindra after Vulcanus). We do NOT clone or re-unlock them; the manufactured
--    `lava` fluid simply IS the fluid they consume. That is the integration.
--
-- 4. STONE LOOP-BACK. The Vulcanus molten recipes return stone as a BYPRODUCT
--    (10 stone per 250 molten iron, 15 per 250 molten copper -- an OUTPUT, not
--    an input). That returned stone loops back into fresh lava, so mining is a
--    top-up, not the whole supply. We rely on the vanilla byproduct and MUST NOT
--    touch those shared recipes (mutating them would leak onto Vulcanus). See
--    BALANCE NOTE below.
--
-- MACHINE-COUNT vs POWER (the ci-e8a tension, resolved). On the SHARED foundry
-- the two are ONE knob: the count of lava foundries to feed one melt and the
-- energy spent per lava are both proportional to `energy_required / LAVA_OUT`,
-- so you cannot cut the count without cheapening lava. The fix DECOUPLES them by
-- giving lava its own machine:
--     count N  = (500 lava/melt / melt_rate) / (LAVA_OUT * manufacturer_speed
--                                               / energy_required)
--     energy-per-lava = manufacturer_draw * energy_required
--                       / manufacturer_speed / LAVA_OUT
-- Raising `manufacturer_speed` cuts N; keeping `manufacturer_draw / speed` equal
-- to the foundry's keeps energy-per-lava fixed. Both goals, one machine.
--
-- BALANCE NOTE (deferred to §15-14, ci-63d): the spec wants the loop "net
-- SLIGHTLY consuming" so fresh mining stays a slow activity. With the values
-- fixed here (1:5 stone:lava, and vanilla's ~10-15 stone back per 500 lava
-- consumed) the loop is in fact net-heavily-consuming. Both sides are locked --
-- the ratio is "fixed per spec" and the foundry byproduct is a shared Vulcanus
-- prototype we cannot edit -- so reconciling the aspiration is a balance-pass
-- decision, flagged, not silently shipped.
--
-- v1 ART: the vanilla lava fluid icon, color-layered warmer on the RECIPE so the
-- manufactured pour reads distinct from natural Vulcanus lava
-- (prototypes/lava-icon.lua). The machine reuses the foundry art.
local util = require("util")
local lava_icon = require("prototypes.lava-icon")

-- The ratio + energy are fixed by spec (§7): 1 stone in, 5 lava out, at a real
-- crafting time. UNCHANGED by the ci-e8a rescale -- usability comes from the
-- machine, never from cheapening lava (energy-per-lava must stay ruinous).
local STONE_IN = 1
local LAVA_OUT = 5
local ENERGY_REQUIRED = 15

-- Private recipe category: lava manufacturing lives ONLY in the Cindra
-- lava-manufacturer, never in the shared Vulcanus foundry (which keeps its
-- vanilla `metallurgy` recipes). Neither leaks into the other.
local LAVA_CATEGORY = "cindra-lava-manufacturing"

-- THE MACHINE knobs (tune, §7). crafting_speed sets the machine COUNT; the draw
-- is pinned PROPORTIONAL to it so energy-per-lava is identical to the pre-rescale
-- foundry value. The foundry is speed 4 at 2500 kW -> 625 kW per speed unit; we
-- match that ratio exactly, then scale up. At speed 64 the machine draws 40 MW
-- (like the electric heater, an established Cindra flare-scale sink), and a
-- SINGLE-DIGIT count (~6 nominal, fewer with the inherited base productivity)
-- feeds one melting foundry. Raising speed cuts the count but not the per-lava
-- energy (draw rises with it), so power stays ruinous however few machines run.
local MANUFACTURER_SPEED = 64
local MANUFACTURER_DRAW = "40000kW" -- 40 MW = 625 kW/speed * 64, foundry-matched.

data:extend({ { type = "recipe-category", name = LAVA_CATEGORY } })

-- === The lava-manufacturer machine =========================================
-- A dedicated Cindra caster: a deep-copied foundry (v1 art reuse) retuned to a
-- big speed + proportionally big draw, moved onto the private lava category so
-- the shared foundry no longer crafts lava. Deep-copy guarantees we never alias
-- or mutate the shared space-age foundry or its nested tables.
local manufacturer = util.table.deepcopy(data.raw["assembling-machine"]["foundry"])
manufacturer.name = "cindra-lava-manufacturer"
manufacturer.minable = { mining_time = 0.2, result = "cindra-lava-manufacturer" }
manufacturer.fast_replaceable_group = nil -- not interchangeable with the foundry
manufacturer.next_upgrade = nil
manufacturer.crafting_categories = { LAVA_CATEGORY }
manufacturer.crafting_speed = MANUFACTURER_SPEED
manufacturer.energy_usage = MANUFACTURER_DRAW
-- Drop the Aquilo cold-planet heating draw carried by the foundry art: this is a
-- Cindra ground machine, not a heated one.
manufacturer.heating_energy = nil
manufacturer.localised_name = { "entity-name.cindra-lava-manufacturer" }
manufacturer.localised_description = { "entity-description.cindra-lava-manufacturer" }

-- Item: clone the foundry item for a valid subgroup + vanilla icon (v1 art),
-- pointed at our entity.
local manufacturer_item = util.table.deepcopy(data.raw["item"]["foundry"])
manufacturer_item.name = "cindra-lava-manufacturer"
manufacturer_item.place_result = "cindra-lava-manufacturer"
manufacturer_item.order = "b[cindra]-d[lava-manufacturer]"
manufacturer_item.localised_name = { "item-name.cindra-lava-manufacturer" }
manufacturer_item.localised_description = { "item-description.cindra-lava-manufacturer" }

-- Recipe to BUILD the manufacturer (gated behind the cindra-lava tech). Built
-- from BOOTSTRAP-LOCAL materials (steel-plate + gears + stone-brick), all of
-- which the Cindra loop renews (cast iron -> plate -> gears; stone -> brick), so
-- the manufacturer is a one-time build the from-stone economy can afford. It is
-- deliberately NOT tungsten/lubricant-gated: lava is the FIRST metal step, so its
-- machine must be reachable before the deep Vulcanus intermediates exist (keeps
-- the start-on-Cindra bootstrap solvable -- see tests/test_bootstrap.lua).
local manufacturer_build = {
  type = "recipe",
  name = "cindra-lava-manufacturer",
  enabled = false,
  energy_required = 10,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 30 },
    { type = "item", name = "iron-gear-wheel", amount = 20 },
    { type = "item", name = "stone-brick", amount = 20 },
  },
  results = { { type = "item", name = "cindra-lava-manufacturer", amount = 1 } },
}

-- === The lava recipe ========================================================
local recipe = {
  type = "recipe",
  name = "cindra-lava",
  -- Private category: only the Cindra lava-manufacturer crafts this, never the
  -- shared foundry. (2.1 merged `category`/`additional_categories` into
  -- `categories`.)
  categories = { LAVA_CATEGORY },
  subgroup = "fluid-recipes",
  order = "z[cindra]-a[lava]",
  enabled = false, -- gated: unlocked by cindra-lava tech below, never free.
  energy_required = ENERGY_REQUIRED,
  ingredients = {
    { type = "item", name = "stone", amount = STONE_IN },
  },
  results = {
    { type = "fluid", name = "lava", amount = LAVA_OUT },
  },
  -- Central intermediate + ruinous power cost: productivity is a fair reward and
  -- matches vanilla intermediate conventions. Power stays the dominant cost.
  allow_productivity = true,
  -- Single fluid product, shown color-layered warmer so manufactured lava reads
  -- distinct from the natural Vulcanus pour. The tint lives on the RECIPE icon
  -- ONLY -- never on the shared `lava` fluid the Vulcanus chain consumes, which
  -- would leak onto Vulcanus.
  icons = lava_icon.build(),
  main_product = "lava",
}

-- Its own tech, gated behind BOTH the foundry (you need the Vulcanus metal path
-- the manufactured lava feeds) and Cindra discovery (so the recipe is Cindra-
-- progression content, never an option a Vulcanus-only player stumbles into).
-- Unlocks the manufacturer AND the recipe together. Purely additive.
local technology = {
  type = "technology",
  name = "cindra-lava",
  icon = "__space-age__/graphics/icons/fluid/lava.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-lava-manufacturer" },
    { type = "unlock-recipe", recipe = "cindra-lava" },
  },
  prerequisites = { "foundry", "planet-discovery-cindra" },
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

data:extend({ manufacturer, manufacturer_item, manufacturer_build, recipe, technology })
