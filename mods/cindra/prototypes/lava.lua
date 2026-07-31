-- Manufactured lava, the central economy spine (§15-5; DESIGN.md §1, §2, §5, §7).
--
-- Cindra has no lava lakes to pump (that is Vulcanus). Here lava is MADE from
-- stone with ruinous electric power, then cast through the vanilla Vulcanus
-- foundry chain into molten iron / copper, so the whole metal economy routes
-- through a recipe whose real cost is the star's surplus.
--
-- === ci-9yg REDO: ONE true vanilla lava + a stone-NEGATIVE loop ==============
-- This replaces the ci-a0y / ci-669 approach (a separate `cindra-lava` fluid).
-- The user rejected the invisible second fluid; the fix now is a SINGLE fluid
-- plus pure recipe economics:
--
--   1. ONE FLUID. There is no `cindra-lava` prototype. The lava recipe outputs
--      vanilla `lava`, and Cindra casts it through the vanilla
--      `molten-iron/copper-from-lava` recipes (unlocked by the `foundry` tech,
--      which this tech requires). Exactly one "Lava" exists, everywhere.
--
--   2. THE EXPLOIT IS CLOSED BY ECONOMICS, NOT GATING. The vanilla casts stay
--      fully usable on Cindra (we do NOT try to disable them). The old danger
--      was the loop `stone -> lava -> cast -> metal + stone(byproduct)` almost
--      self-sustaining at legendary productivity. We make it net stone-NEGATIVE
--      on EVERY surface at EVERY module tier by pure recipe math:
--        * The stone->lava recipe DISALLOWS productivity, so the stone spent to
--          make a fixed amount of lava is CONSTANT (no compounding). This is the
--          key: with productivity on, each stone would yield more lava, cutting
--          stone-in per cast until the returned byproduct overtook it. Off, the
--          stone-in floor never moves.
--        * The material ratio is nerfed to `1 stone -> 5 lava` (was 1:10). One
--          vanilla cast consumes 500 lava, i.e. 100 stone in -- FIXED at all
--          tiers. The vanilla casts return 10 (iron) / 15 (copper) stone, and
--          productivity scales THAT byproduct: at the engine's +300% cap the
--          most stone any cast can hand back is 15 * 4 = 60 (copper) or
--          10 * 4 = 40 (iron), both strictly below the 100 spent. So the loop
--          net-CONSUMES stone at 0% and at +300% (and everywhere between).
--      That is provable pure math with no conditional, so it "always applies"
--      on all surfaces (see tests/test_lava.lua). Vulcanus is untouched: it
--      PUMPS lava from lakes and has no stone->lava recipe, so nerfing this
--      recipe changes nothing there.
--
--   3. NO SURFACE_CONDITIONS, NO SHARED-PROTOTYPE MUTATION. The vanilla `lava`
--      fluid and the vanilla molten recipes are left COMPLETELY untouched
--      (guarded in tests); we only ADD a Cindra recipe + machine + tech. The
--      lava recipe lives in its own private `cindra-lava-manufacturing`
--      category so ONLY the Cindra lava-manufacturer crafts it (the shared
--      foundry never makes lava from stone) -- but that is a machine-routing
--      choice, never a fluid gate.
--
-- === THE SPAZZ FIX (was ci-4ee) =============================================
-- The manufacturer ran at crafting_speed 64. The working animation and sound
-- scale with crafting_speed, so at 64 the machine visibly/audibly spazzed. Drop
-- it to crafting_speed 2 (a calm animation) and scale the recipe BATCH up by the
-- same factor (32x: 10->320 lava, 1->64 stone before the nerf, energy kept) so
-- per-machine throughput is UNCHANGED -- a big slow batch instead of a blur of
-- tiny fast ones. The draw stays 40 MW, so energy-per-lava is also unchanged and
-- still ruinous (more power per running machine is expected and fine). See the
-- THROUGHPUT note by the constants below.
--
-- === SULFUR FROM ROASTING (ci-eat) ==========================================
-- Real-world flavor: crushing and ROASTING sulfide/pyrite-bearing stone liberates
-- its sulfur (FeS2 --roast--> oxide + SO2 -> sulfur). Cindra has no oil to run the
-- vanilla petroleum->sulfur recipe, so the melt IS the roast: the stone->lava
-- recipe also yields a SMALL sulfur byproduct, and that sulfur feeds the vanilla
-- `sulfur + water -> sulfuric-acid` recipe (unlocked by this tech, run in the same
-- chemical plant Cindra already uses for ice-melting).
--
-- BALANCE / no free-sulfur exploit (respects ci-669 + the ci-9yg/ci-a0y economy):
--   * Productivity is already DISABLED on this recipe (the load-bearing ci-9yg
--     invariant), so sulfur can NEVER scale with prod modules. We ALSO mark the
--     sulfur result `ignored_by_productivity` (belt-and-suspenders + intent).
--   * The byproduct is small (8 sulfur : 320 lava per 64-stone batch), so lava
--     stays unambiguously the main product; `main_product = lava` keeps the recipe
--     reading as "Lava" in the UI.
--   * You cannot farm lava purely for sulfur: the manufacturer's 40 MW draw makes
--     each sulfur cost ~75 MJ of grid power plus 8 stone AND 40 lava you must sink
--     -- ruinous, exactly the "power is the real cost" thesis. Sulfur is a bonus
--     off the metal economy you already run, never a cheap standalone source.
--   * No shared-recipe mutation: the vanilla `sulfuric-acid` recipe is only
--     UNLOCKED (a tech effect), never edited. Vulcanus/other planets untouched.
--
-- FOUR PARTS:
--
-- 1. THE LAVA RECIPE. `1 stone -> 5 lava` (nerfed from 1:10), cast as a 64:320
--    batch, outputting VANILLA `lava` PLUS a small sulfur byproduct (ci-eat). Its
--    own private category `cindra-lava-manufacturing`, so ONLY the Cindra
--    lava-manufacturer crafts it. Productivity is DISABLED (the ci-9yg
--    stone-negativity invariant depends on a fixed stone-in; it also pins the
--    sulfur byproduct). "Power is the lever": the cost knob is `energy_required`
--    against the manufacturer's ruinous electric draw.
--
-- 2. THE LAVA-MANUFACTURER MACHINE. A dedicated Cindra building (a foundry clone
--    for v1 art reuse) at crafting_speed 2 with a big 40 MW electric draw. We
--    DEEP-COPY the shared foundry prototype before touching it, and give the
--    machine its own recipe category, so we never mutate Vulcanus content.
--
-- 3. THE VANILLA CASTS (no Cindra clone). Cindra casts lava through the vanilla
--    `molten-iron/copper-from-lava` recipes -- unchanged, unmutated, unlocked by
--    the `foundry` tech (a prerequisite here). The stone-negativity above makes
--    the returned-stone byproduct harmless; no Cindra-exclusive cast is needed.
--
-- 4. THE TECH. Unlocks the lava recipe AND the manufacturer AND (ci-eat) the
--    vanilla sulfuric-acid recipe the sulfur byproduct feeds, gated behind the
--    foundry (so the vanilla casts + metal path already exist) and Cindra
--    discovery.
--
-- ART. The lava recipe shows the plain vanilla lava fluid icon (its single fluid
-- product). The MACHINE (cindra-lava-manufacturer) wears the user-supplied
-- "glass-furnace" set by Hurricane046 (CC-BY) -- an animated body, a ground
-- shadow, and an emissive molten glow that fits a stone->lava melter. See
-- graphics/entity/lava-manufacturer/ATTRIBUTION.md (and CREDITS.md).
local util = require("util")

-- The ratio + energy. `1 stone -> 5 lava` is the ci-9yg nerf (from the old
-- 1:10). It is cast as a 64:320 batch so the manufacturer can run at a calm
-- crafting_speed 2 while keeping per-machine throughput identical (see THROUGHPUT
-- below). Productivity is OFF on this recipe, so the stone spent per unit lava is
-- FIXED -- the load-bearing fact for the stone-negativity invariant (ci-9yg).
local STONE_IN = 64
local LAVA_OUT = 320
local ENERGY_REQUIRED = 30

-- Sulfur liberated per batch by roasting the crushed stone (ci-eat). Small next
-- to LAVA_OUT so lava stays the main product; fully ignored_by_productivity so it
-- can never be inflated (atop allow_productivity=false). This is Cindra's sole
-- sulfur source and feeds the vanilla sulfur->sulfuric-acid recipe.
local SULFUR = "sulfur"
local SULFUR_OUT = 8

-- Vanilla `lava` end-to-end (ci-9yg): there is exactly ONE lava fluid. The lava
-- recipe outputs it and the vanilla casts consume it. No `cindra-lava` fluid.
local LAVA_FLUID = "lava"

-- Private recipe category: lava manufacturing lives ONLY in the Cindra
-- lava-manufacturer, never in the shared Vulcanus foundry (which keeps its
-- vanilla `metallurgy` recipes). This is machine routing, not a fluid gate.
local LAVA_CATEGORY = "cindra-lava-manufacturing"

-- THE MACHINE knobs. crafting_speed 2 keeps the working animation + sound calm
-- (the ci-4ee spazz fix; 64 made them play 32x too fast). The 40 MW draw is the
-- ruinous power cost -- kept the same as before the spazz fix, so a SINGLE-DIGIT
-- count of manufacturers feeds one melting foundry and the aggregate draw stays a
-- serious electric sink.
local MANUFACTURER_SPEED = 2
local MANUFACTURER_DRAW = "40000kW" -- 40 MW, ruinous; power is the real cost.

-- THROUGHPUT (the ci-4ee spazz fix, resolved). Per-machine lava output is
--     LAVA_OUT * crafting_speed / energy_required = 320 * 2 / 30 = 21.3 lava/s,
-- identical to the pre-fix 10 * 64 / 30. Energy-per-lava is
--     draw * (energy_required / speed) / LAVA_OUT
--       = 40e3 kW * (30 / 2) s / 320 = 1875 kJ/lava,
-- also identical to the pre-fix value: only the animation rate changed. A
-- vanilla melting foundry consumes 500 lava / (16/4) s = 125 lava/s, so
-- 125 / 21.3 ~= 6 manufacturers feed one melt (single-digit), drawing ~240 MW.

data:extend({ { type = "recipe-category", name = LAVA_CATEGORY } })

-- === The lava-manufacturer machine =========================================
-- A dedicated Cindra caster: a deep-copied foundry (v1 art reuse) retuned to a
-- calm speed + a big draw, moved onto the private lava category so the shared
-- foundry no longer crafts lava. Deep-copy guarantees we never alias or mutate
-- the shared space-age foundry or its nested tables.
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
-- Drop the foundry's inherited +50% base productivity. The lava recipe disallows
-- productivity (ci-9yg), so base prod is moot -- but clearing it makes the fixed
-- 320-lava-per-craft output (the stone-negativity invariant) unambiguous: nothing
-- can inflate lava output on this machine.
if manufacturer.effect_receiver and manufacturer.effect_receiver.base_effect then
  manufacturer.effect_receiver.base_effect.productivity = nil
end
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
-- Scale/shift tuned against the 5x5 foundry footprint with an in-engine render
-- (ci-ijk): at scale 0.5 the 270x310 frame was too small for the 5x5 box and
-- sat floating above the ground (empty tiles showing below it). The vanilla
-- foundry art (356x384) fills 5x5 at scale 0.5, so match its on-screen size:
-- 0.64 gives ~173x198 px (~5.4x6.2 tiles), filling the box and overhanging like
-- the foundry. The old -24 px lift is what made it hover.
-- ci-cge (playtest retune): at shift 0 the body sat too far SOUTH -- its bottom
-- overhung past the bottom of the selection box -- and read a touch too far left.
-- Nudge it UP so the base aligns with the selection-box bottom, and very slightly
-- RIGHT (the rightward move also reseats the right-side pipe connectors, which
-- were floating off the body). The lift stays well short of the ci-ijk -24 px
-- float, so the body still sits on the ground and fills the box.
local BODY_SCALE = 0.64
local BODY_SHIFT = util.by_pixel(6, -12)

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
        -- SE shadow offset, carried along with the ci-cge body nudge (+6,-12) so
        -- the shadow stays seated under the moved body.
        shift = util.by_pixel(30, -4),
        draw_as_shadow = true,
      },
      { -- emissive molten glow: stays lit in the dark (fits a lava melter).
        -- The emission sheet is FULLY OPAQUE (alpha 1 everywhere) with a black
        -- background and bright molten openings. blend_mode = "additive" is
        -- MANDATORY: without it the opaque black background is drawn normally
        -- and paints a solid black square straight over the furnace body (the
        -- ci-036 "black square + orange blobs" bug). Additive makes the black
        -- background contribute nothing and only the bright openings add glow --
        -- exactly how the vanilla foundry lights layer is wired (foundry-pictures
        -- foundry_lights_pictures: draw_as_glow + blend_mode = "additive").
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
        blend_mode = "additive",
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

-- === Circuit wire attachment point (ci-cge) =================================
-- The deep-copied foundry connector puts the wire pin near the TOP of the box
-- (foundry offset by_pixel(15, -50.5)); on the glass-furnace body the wires then
-- read as connecting in the middle/top, floating off the model. Rebuild the
-- connector from the same universal template at a BOTTOM-RIGHT offset so both the
-- pin sprite AND the wire endpoints (points.wire) land on the lower-right of the
-- furnace. create_vector wants one entry per direction; the glass furnace looks
-- the same from every side (like the foundry), so all four share the offset.
-- circuit_connector_definitions / universal_connector_template are core globals
-- present for every base/space-age machine, so this loads whenever the game does.
local CONNECTOR_OFFSET = util.by_pixel(48, 34) -- +x right, +y down -> bottom-right
manufacturer.circuit_connector = circuit_connector_definitions.create_vector(
  universal_connector_template,
  {
    { variation = 27, main_offset = CONNECTOR_OFFSET, shadow_offset = util.by_pixel(115, 32), show_shadow = false },
    { variation = 27, main_offset = CONNECTOR_OFFSET, shadow_offset = util.by_pixel(115, 32), show_shadow = false },
    { variation = 27, main_offset = CONNECTOR_OFFSET, shadow_offset = util.by_pixel(115, 32), show_shadow = false },
    { variation = 27, main_offset = CONNECTOR_OFFSET, shadow_offset = util.by_pixel(115, 32), show_shadow = false },
  }
)

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
-- `1 stone -> 5 lava` (ci-9yg nerf), cast as a 64:320 batch so the manufacturer
-- runs at a calm crafting_speed 2. Outputs VANILLA `lava` -- the only lava fluid.
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
    -- Sulfur from roasting the crushed stone (ci-eat). `ignored_by_productivity`
    -- pins the full amount out of any prod bonus -- belt-and-suspenders atop the
    -- allow_productivity=false below, so sulfur is FIXED at every module tier.
    { type = "item", name = SULFUR, amount = SULFUR_OUT, ignored_by_productivity = SULFUR_OUT },
  },
  -- Productivity is DISABLED (ci-9yg): the stone spent per unit lava must be
  -- FIXED so the stone->lava->cast loop is provably net stone-negative at every
  -- module tier. A prod bonus here would cut stone-in per cast and could let the
  -- cast's returned stone overtake it -- the exact self-sustain we are closing.
  allow_productivity = false,
  -- Single fluid product -> the recipe shows the vanilla lava icon (one visible
  -- "Lava", no custom icon, no tint).
  main_product = LAVA_FLUID,
}

-- Its own tech, gated behind BOTH the foundry (you need the Vulcanus metal path
-- the manufactured lava feeds -- the foundry tech also unlocks the vanilla casts
-- Cindra reuses) and Cindra discovery (so the recipe is Cindra-progression
-- content, never an option a Vulcanus-only player stumbles into). Unlocks the
-- manufacturer, the lava recipe, and the vanilla sulfuric-acid recipe (ci-eat);
-- the casts come free with the foundry tech.
local technology = {
  type = "technology",
  name = "cindra-lava",
  icon = "__space-age__/graphics/icons/fluid/lava.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-lava-manufacturer" },
    { type = "unlock-recipe", recipe = "cindra-lava" },
    -- Close the sulfur chain (ci-eat): the lava recipe hands back sulfur, so the
    -- same tech unlocks the VANILLA `sulfur + water -> sulfuric-acid` recipe (run
    -- in the chemical plant Cindra already uses for ice-melting). This only
    -- UNLOCKS the shared recipe -- it never edits it, so Vulcanus/other planets
    -- are untouched. Water is the vanilla water from the ice chain.
    { type = "unlock-recipe", recipe = "sulfuric-acid" },
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
  manufacturer,
  manufacturer_item,
  manufacturer_build,
  recipe,
  technology,
})
