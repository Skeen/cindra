-- Manufactured lava, the central economy spine (§15-5; DESIGN.md §1, §2, §5, §7),
-- carrying the ci-669 balance fix (the stone loop-back must NEVER self-sustain).
--
-- Cindra has no lava lakes to pump (that is Vulcanus). Here lava is MADE from
-- stone with ruinous electric power at `1 stone -> 10 lava` (ci-669). That fluid
-- then feeds a Vulcanus-foundry casting chain into molten iron / copper, so the
-- whole metal economy routes through a recipe whose real cost is the star's
-- surplus.
--
-- === ci-669 BALANCE FIX: the stone loop-back must net-consume at every tier ===
-- The playtest bug: casting lava into metal returns a STONE byproduct, and at
-- LEGENDARY productivity that byproduct nearly equalled the stone spent to make
-- the lava, so the stone->lava->metal loop almost self-sustained and stone (thus
-- the whole power economy) became effectively free. The root is COMPOUNDING
-- productivity: a prod bonus on the lava recipe makes each stone yield more lava,
-- while a prod bonus on the casting recipe multiplies the returned stone -- both
-- pull toward self-sustain at once.
--
-- Two vanilla facts box us in:
--   * The Vulcanus `molten-iron/copper-from-lava` recipes return 10 / 15 stone and
--     let productivity scale it. They are SHARED prototypes; editing them would
--     leak onto Vulcanus (never-mutate-other-planets), so we cannot cut it there.
--   * Recipe availability is per-FORCE, not per-surface: leaving the generous
--     vanilla recipe reachable means a legendary player just uses it. So a nerfed
--     clone only bites if its INPUT fluid differs.
--
-- The fix, foreseen by the old §15-5 balance note ("a Cindra casting tier",
-- §15-14 / ci-63d):
--   1. The lava recipe outputs a Cindra-EXCLUSIVE `cindra-lava` fluid (a tinted
--      clone of vanilla lava), never the shared `lava` the Vulcanus chain eats.
--   2. Cindra-exclusive `cindra-molten-iron/copper-from-lava` recipes consume
--      `cindra-lava` and return only a SMALL stone byproduct that is
--      `ignored_by_productivity` -- productivity can never inflate it. They still
--      output the vanilla 250 molten-iron/copper, so the downstream casting chain
--      is unchanged. They live in `metallurgy`, so the brought-not-re-unlocked
--      Vulcanus foundry crafts them (no new melting machine).
-- The shared vanilla `lava` fluid and molten recipes are left COMPLETELY untouched
-- (guarded in tests); Vulcanus is unaffected. On Cindra the vanilla molten recipes
-- simply have no input (no vanilla lava is produced there), so the player casts
-- through the Cindra recipes.
--
-- STONE INVARIANT (ci-669, asserted in tests/test_lava.lua): across the full
-- stone->lava->molten-iron and ->molten-copper chains the loop NET-CONSUMES stone
-- at no-modules AND legendary prod, with returned stone <= ~1/3 of consumed at
-- legendary, and NO module tier makes it stone-neutral/positive. With
-- `1 stone -> 10 lava`, 500 lava per cast, byproduct 4 (ignored_by_productivity):
-- stone-in per cast = 500 / (10 * (1 + P_lava)); legendary P_lava=1.5 -> 20 in vs
-- 4 back (ratio 0.20); no-modules P_lava=0.5 -> 33.3 in vs 4 (0.12); the fixed 4
-- back can never exceed even the >=12.5 stone-in of the theoretical +300% cap.
--
-- THROUGHPUT RESCALE (ci-e8a, follow-up to ci-095). The other problem was
-- USABILITY, not the ratio: at the old rate on the shared 2.5 MW / speed-4 foundry
-- it took ~100 lava-crafting foundries to keep ONE melting foundry fed (unusable;
-- the user was rightly angry). The fix, per the mayor's resolution, is NOT to
-- cheapen lava (do not touch energy-per-lava) but to CONCENTRATE the draw: craft
-- lava on a DEDICATED, HIGH-SPEED, HIGH-DRAW Cindra machine (the
-- `cindra-lava-manufacturer` below) instead of the shared foundry. A few hungry
-- machines replace a hundred tiny ones; the TOTAL grid power to sustain foundry-
-- scale lava is UNCHANGED (still ruinous), just delivered by single-digit
-- buildings. Machine count is set by the machine's crafting_speed; energy-per-lava
-- is set by the recipe, and stays fixed. See MACHINE-COUNT vs POWER below.
--
-- FIVE PARTS:
--
-- 1. THE LAVA RECIPE. `1 stone -> 10 lava` (ci-669), outputting the Cindra-only
--    `cindra-lava` fluid. Its own private category `cindra-lava-manufacturing`, so
--    ONLY the Cindra lava-manufacturer crafts it -- the shared Vulcanus foundry
--    does NOT. "Power is the lever": the stone/lava amounts are fixed, and the
--    cost knob is `energy_required` against the manufacturer's electric draw
--    (doubled alongside the doubled lava output, so energy-per-lava is UNCHANGED
--    and ruinous). Productivity is ALLOWED: lava is the central intermediate and
--    its cost is ruinous power, so a productivity bonus is a fair reward.
--
-- 2. THE `cindra-lava` FLUID. A Cindra-exclusive tinted clone of vanilla lava
--    (deep-copied so we never alias/mutate the shared fluid). The tint carries the
--    "manufactured, not natural" identity, and -- crucially for ci-669 -- being a
--    DISTINCT fluid is what lets the Cindra casting recipes replace the generous
--    vanilla ones without leaving the vanilla ones exploitable.
--
-- 3. THE LAVA-MANUFACTURER MACHINE. A dedicated Cindra building (a foundry clone
--    for v1 art reuse) with a BIG crafting_speed and a PROPORTIONALLY big electric
--    draw, so `energy_usage / crafting_speed` EQUALS the foundry's -- i.e. the same
--    energy per unit lava, just concentrated. We DEEP-COPY the shared foundry
--    prototype before touching it, and give the machine its own recipe category,
--    so we never mutate Vulcanus content.
--
-- 4. CINDRA CASTING RECIPES + STONE LOOP-BACK. Cindra-exclusive
--    `cindra-molten-iron/copper-from-lava` cast `cindra-lava` into the vanilla
--    250 molten-iron/copper, returning a SMALL `ignored_by_productivity` stone
--    byproduct (the ci-669 loop-back that can never self-sustain). They sit in the
--    shared `metallurgy` category so the foundry the player already owns crafts
--    them -- brought, not re-unlocked -- and are additive: the vanilla recipes are
--    untouched and Vulcanus never sees `cindra-lava`.
--
-- 5. THE TECH. Unlocks the recipe, the manufacturer, AND the two Cindra casting
--    recipes together, gated behind the foundry + Cindra discovery.
--
-- MACHINE-COUNT vs POWER (the ci-e8a tension, resolved). On the SHARED foundry the
-- two are ONE knob: the count of lava foundries to feed one melt and the energy
-- spent per lava are both proportional to `energy_required / LAVA_OUT`, so you
-- cannot cut the count without cheapening lava. The fix DECOUPLES them by giving
-- lava its own machine:
--     count N  = (500 lava/melt / melt_rate) / (LAVA_OUT * manufacturer_speed
--                                               / energy_required)
--     energy-per-lava = manufacturer_draw * energy_required
--                       / manufacturer_speed / LAVA_OUT
-- Raising `manufacturer_speed` cuts N; keeping `manufacturer_draw / speed` equal
-- to the foundry's keeps energy-per-lava fixed. Both goals, one machine. (ci-669
-- doubled LAVA_OUT and energy_required together, so N and energy-per-lava are both
-- exactly as ci-e8a left them; only the stone:lava material ratio changed.)
--
-- ART. The manufactured-lava RECIPE uses the vanilla lava fluid icon, color-
-- layered warmer so the pour reads distinct from natural Vulcanus lava
-- (prototypes/lava-icon.lua), on BOTH the recipe and the Cindra fluid. The
-- MACHINE (cindra-lava-manufacturer) wears the user-supplied "glass-furnace" set
-- by Hurricane046 (CC-BY) -- an animated body, a ground shadow, and an emissive
-- molten glow that fits a stone->lava melter. See
-- graphics/entity/lava-manufacturer/ATTRIBUTION.md (and CREDITS.md) for the
-- per-asset record; wiring is in the "glass-furnace art" block below.
local util = require("util")
local lava_icon = require("prototypes.lava-icon")

-- The ratio + energy are the ci-669 balance values: 1 stone in, 10 lava out, at a
-- real crafting time. LAVA_OUT and ENERGY_REQUIRED were doubled together from the
-- pre-ci-669 (1:5 / 15) values so energy-per-lava stays IDENTICAL and ruinous --
-- only the stone-per-lava material cost fell (the user's `1 stone -> 10 lava`).
local STONE_IN = 1
local LAVA_OUT = 10
local ENERGY_REQUIRED = 30

-- The Cindra-exclusive fluid the lava recipe outputs and the Cindra casting
-- recipes consume. NOT the shared vanilla `lava` (see ci-669 fix above).
local LAVA_FLUID = "cindra-lava"

-- ci-669 loop-back byproduct: the stone each Cindra cast returns. Small and
-- `ignored_by_productivity`, so the returned stone is FIXED at this value at every
-- module tier and can never approach the (>=12.5) stone spent to make the 500
-- lava a cast consumes. Chosen so returned <= ~1/3 of consumed even at legendary.
local CAST_STONE_BYPRODUCT = 4

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

-- === The cindra-lava fluid ==================================================
-- A Cindra-exclusive, tinted clone of vanilla lava. Deep-copied so we never alias
-- or mutate the shared `lava` fluid the Vulcanus chain consumes. Being a DISTINCT
-- fluid is load-bearing for ci-669: only the Cindra casting recipes eat it, so the
-- generous vanilla molten recipes have no input on Cindra and stay unexploitable.
local lava_fluid = util.table.deepcopy(data.raw["fluid"]["lava"])
lava_fluid.name = LAVA_FLUID
lava_fluid.icons = lava_icon.build()
lava_fluid.icon = nil -- superseded by the layered `icons`
-- Warmer/brighter in pipes + tanks than the natural Vulcanus pour, so manufactured
-- lava reads distinct at a glance while still obviously being lava.
lava_fluid.base_color = { r = 1.0, g = 0.55, b = 0.15 }
lava_fluid.flow_color = { r = 0.5, g = 0.18, b = 0.02 }
lava_fluid.localised_name = { "fluid-name.cindra-lava" }

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

-- === Glass-furnace art (user-supplied; Hurricane046 / CC-BY) ================
-- The deep-copied foundry brings the foundry's OWN graphics_set (and directional
-- working_visualisations). Replace it wholesale with the glass-furnace set so the
-- lava-manufacturer reads as its own machine, not a reskinned foundry. Attribution:
-- graphics/entity/lava-manufacturer/ATTRIBUTION.md + mods/cindra/CREDITS.md.
local ENTITY_GFX = "__cindra__/graphics/entity/lava-manufacturer/"
local ICON = "__cindra__/graphics/icons/glass-furnace-icon.png"

-- The body + emission are a TWO-PART animation sheet: 80 frames of 270x310 px
-- laid out 8-per-row. Part 1 (2160x2480) holds 8 rows = 64 frames; part 2
-- (2160x620) holds the final 2 rows = 16 frames. Factorio stitches the two files
-- via `filenames` + `lines_per_file` (rows read from each file before spilling
-- into the next), so the pair renders as one continuous 80-frame animation.
local FRAME_W, FRAME_H = 270, 310
local FRAME_COUNT = 80
local LINE_LENGTH = 8   -- frames per row
local LINES_PER_FILE = 8 -- rows in part 1; the remainder spill into part 2
-- HR (double-resolution) art: scale ~0.5 is the HR convention. Exact scale/shift
-- against the foundry-sized footprint is a visual tune -- see PLAYTEST.md.
local BODY_SCALE = 0.5
local BODY_SHIFT = util.by_pixel(0, -24)

local body_animation_files = {
  ENTITY_GFX .. "glass-furnace-hr-animation-1.png",
  ENTITY_GFX .. "glass-furnace-hr-animation-2.png",
}
local emission_animation_files = {
  ENTITY_GFX .. "glass-furnace-hr-emission1-1.png",
  ENTITY_GFX .. "glass-furnace-hr-emission1-2.png",
}

-- A single Animation (with layers) applies to every direction: the glass furnace
-- reads the same from all sides, matching the foundry-clone footprint. Body +
-- shadow + always-on emissive molten glow.
manufacturer.graphics_set = {
  animation = {
    layers = {
      { -- animated furnace body
        filenames = body_animation_files,
        width = FRAME_W,
        height = FRAME_H,
        frame_count = FRAME_COUNT,
        line_length = LINE_LENGTH,
        lines_per_file = LINES_PER_FILE,
        scale = BODY_SCALE,
        shift = BODY_SHIFT,
        animation_speed = 0.5,
      },
      { -- ground shadow: one static image. All layers of a layered Animation
        -- must share a frame count, so repeat_count holds this single frame for
        -- the body's whole 80-frame cycle (1 * repeat_count == FRAME_COUNT).
        filename = ENTITY_GFX .. "glass-furnace-hr-shadow.png",
        width = 500,
        height = 350,
        frame_count = 1,
        repeat_count = FRAME_COUNT,
        scale = BODY_SCALE,
        shift = util.by_pixel(24, 8),
        draw_as_shadow = true,
      },
      { -- emissive molten glow: stays lit in the dark (fits a lava melter)
        filenames = emission_animation_files,
        width = FRAME_W,
        height = FRAME_H,
        frame_count = FRAME_COUNT,
        line_length = LINE_LENGTH,
        lines_per_file = LINES_PER_FILE,
        scale = BODY_SCALE,
        shift = BODY_SHIFT,
        animation_speed = 0.5,
        draw_as_glow = true,
      },
    },
  },
}
-- Drop foundry-specific overlays that would render the foundry's own working
-- effects on top of the glass-furnace body.
manufacturer.graphics_set_flipped = nil
manufacturer.working_visualisations = nil
-- The inherited foundry fluid_boxes enable working visualisations BY NAME
-- ("input-pipe"/"output-pipe"); those live in the graphics_set we just replaced,
-- so the names now dangle and the load errors. Drop the references (the pipes,
-- covers, and connections still render and function -- only the foundry-shaped
-- pipe glow overlay goes).
if manufacturer.fluid_boxes then
  for _, fb in pairs(manufacturer.fluid_boxes) do
    if type(fb) == "table" then fb.enable_working_visualisations = nil end
  end
end
manufacturer.icon = ICON
manufacturer.icon_size = 64
manufacturer.icons = nil -- clear any inherited layered icon; single icon above

-- Item: clone the foundry item for a valid subgroup, then wear the glass-furnace
-- icon (matching the entity) instead of the inherited foundry icon.
local manufacturer_item = util.table.deepcopy(data.raw["item"]["foundry"])
manufacturer_item.name = "cindra-lava-manufacturer"
manufacturer_item.place_result = "cindra-lava-manufacturer"
manufacturer_item.order = "b[cindra]-d[lava-manufacturer]"
manufacturer_item.icon = ICON
manufacturer_item.icon_size = 64
manufacturer_item.icons = nil -- clear inherited layered icon; single icon above
manufacturer_item.pictures = nil -- drop foundry belt-immunity/pictures variants
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
    { type = "fluid", name = LAVA_FLUID, amount = LAVA_OUT },
  },
  -- Central intermediate + ruinous power cost: productivity is a fair reward and
  -- matches vanilla intermediate conventions. Power stays the dominant cost.
  allow_productivity = true,
  -- Single fluid product, shown color-layered warmer so manufactured lava reads
  -- distinct from the natural Vulcanus pour. The tint lives on the RECIPE icon and
  -- the Cindra-exclusive fluid, NEVER on the shared `lava` the Vulcanus chain
  -- consumes.
  icons = lava_icon.build(),
  main_product = LAVA_FLUID,
}

-- === Cindra casting recipes (ci-669) ========================================
-- Cindra-exclusive clones of the Vulcanus molten recipes: same 250 molten-metal
-- output (so the downstream casting chain is unchanged) and same calcite cost, but
-- they consume the Cindra-only `cindra-lava` fluid and return only a SMALL stone
-- byproduct that productivity can NEVER inflate (`ignored_by_productivity`). This
-- is the ci-669 loop-back: net stone consumption stays strongly positive at every
-- module tier. Built by deep-copying the shared Vulcanus recipe (never mutating
-- it), then retargeting its lava input and stone byproduct.
local function cindra_cast_recipe(vanilla_name, cindra_name, molten_fluid)
  local r = util.table.deepcopy(data.raw["recipe"][vanilla_name])
  r.name = cindra_name
  r.localised_name = { "recipe-name." .. cindra_name }
  r.enabled = false
  r.order = "z[cindra]-b[" .. molten_fluid .. "]"
  -- Consume the Cindra-exclusive fluid, not the shared vanilla lava.
  r.ingredients = {
    { type = "fluid", name = LAVA_FLUID, amount = 500 },
    { type = "item", name = "calcite", amount = 1 },
  }
  -- Vanilla 250 molten metal (unchanged) + the small, prod-immune stone loop-back.
  r.results = {
    { type = "fluid", name = molten_fluid, amount = 250 },
    {
      type = "item",
      name = "stone",
      amount = CAST_STONE_BYPRODUCT,
      -- The whole byproduct is excluded from productivity: no module tier can grow
      -- the returned stone, so the loop can never approach self-sustain (ci-669).
      ignored_by_productivity = CAST_STONE_BYPRODUCT,
    },
  }
  r.main_product = molten_fluid
  return r
end

local molten_iron = cindra_cast_recipe("molten-iron-from-lava", "cindra-molten-iron-from-lava", "molten-iron")
local molten_copper = cindra_cast_recipe("molten-copper-from-lava", "cindra-molten-copper-from-lava", "molten-copper")

-- Its own tech, gated behind BOTH the foundry (you need the Vulcanus metal path
-- the manufactured lava feeds) and Cindra discovery (so the recipe is Cindra-
-- progression content, never an option a Vulcanus-only player stumbles into).
-- Unlocks the manufacturer, the recipe, AND the two Cindra casting recipes
-- together. Purely additive.
local technology = {
  type = "technology",
  name = "cindra-lava",
  icon = "__space-age__/graphics/icons/fluid/lava.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-lava-manufacturer" },
    { type = "unlock-recipe", recipe = "cindra-lava" },
    { type = "unlock-recipe", recipe = "cindra-molten-iron-from-lava" },
    { type = "unlock-recipe", recipe = "cindra-molten-copper-from-lava" },
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

data:extend({
  lava_fluid,
  manufacturer,
  manufacturer_item,
  manufacturer_build,
  recipe,
  molten_iron,
  molten_copper,
  technology,
})
