-- Manufactured aluminium: the ruinous-power material (ci-txh; DESIGN.md §1, §5,
-- §7; sub-bead of the economy epic ci-4xj).
--
-- Cindra has NO native metal ores and NO petrochemistry -- everything is made
-- from rock, ice, and the star's surplus. Aluminium leans all the way into that
-- identity: it is the most POWER-EXPENSIVE thing the planet makes, so it slots in
-- as another big flare-timed POWER SINK next to manufactured lava (ci-8mw), the
-- mass driver (ci-epp), and water boil-off. Where the flare overflows, aluminium
-- is where that overflow goes.
--
-- MODELED ON REAL ACID LEACHING + HALL-HEROULT ELECTROLYSIS (ci-6vj S2, DESIGN
-- §8, recipes #5/#6). No oil, no coal, no plastic -- sulfuric acid is the one
-- honest chemical input, itself made from Cindra's own sulfur (a stone-melt
-- byproduct) via the vanilla acid recipe the lava tech unlocks:
--
--   1. LEACH  `20 stone + 30 sulfuric-acid + 20 water -> 10 alumina + 14 stone
--      + 2 sulfur`  in a vanilla CHEMICAL PLANT (category "chemistry"). Alumina is
--      the white feedstock. Stone is the ribbon's central raw; the leach is net
--      stone-NEGATIVE (20 in, only 14 back) and the acid ties alumina into the
--      sulfur/acid loop. The 14 stone + 2 sulfur returns are
--      `ignored_by_productivity` and productivity is OFF, so no module tier can
--      flip the leach stone-positive (matter honesty, ci-669 / DESIGN §8.6).
--
--   2. ELECTROLYSE  `4 alumina + [RUINOUS electricity] -> 2 aluminium + 30 O2`  in
--      the dedicated Cindra ELECTROLYSIS CELL (the §2 signature building). The cell
--      has a large uncapped electric draw and the recipe a long crafting time, so
--      per-unit energy dwarfs a lava craft (see the tune block). That energy IS the
--      cost. The step vents `cindra-oxygen` gas through an output fluid box -- the
--      O2 economy's dominant source (DESIGN §8.4); O2's early sink is the existing
--      vent-oxygen recipe. Productivity is ON: aluminium is an intermediate (a
--      plate-analog) so a prod bonus is a fair reward (per lava), and the O2
--      byproduct is `ignored_by_productivity` so prod can never mint free gas.
--
-- PURPOSE (so it is not a dead-end; DESIGN.md §5, §12):
--   * DEMAND: aluminium is consumed by the flare CAPACITOR (storage.lua) as its
--     plates -- a real, textbook use (aluminium electrolytic capacitor) and a
--     poetic one: the power-metal builds the thing that stores the power. The
--     capacitor is optional recoverable storage (the dissipator, not the
--     capacitor, is the panel-damage safety floor), so this creates demand
--     WITHOUT gating flare survival behind aluminium -- no soft-lock.
--   * EXPORT: aluminium is a clean, high-value bulk good, AND the very stuff the
--     mass driver (ci-o39, ci-loa) burns to launch -- raw aluminium is fed straight
--     into the silo's internal launch-vehicle build (no pre-pressed can), and it
--     also grinds into the nano-aluminium powder the "ALICE solid rocket fuel" recipe
--     reacts with ICE into VANILLA rocket-fuel (ci-519, ci-8g1). So the launch chain
--     lands its whole recurring cost back on this ruinous-power metal + power:
--     local metallurgy and the star, never chemistry.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is brand new or a fresh
-- deep-copy (util.table.deepcopy) before any nested edit. The shared vanilla
-- `stone` / `sulfuric-acid` / `water` / `sulfur` prototypes are read as recipe
-- ingredients/results only (never mutated), exactly as the lava and ice chains
-- already read them; the shared `cindra-oxygen` fluid lives in plastics.lua and is
-- referenced here by name only. A private recipe category keeps the electrolysis
-- recipe on the Cindra cell only, and vanilla smelting out of it.
--
-- ART: bespoke item icons (ci-6vj S6) for alumina (white refined-mineral render)
-- and aluminium (aluminium-plate render), from Malcolm Riley's `unused-renders`
-- (CC-BY-4.0); see graphics/ART-MANIFEST.md. The electrolysis CELL entity wears
-- Hurricane046's bespoke "oxidizer" set (CC-BY, ci-a6z; it wore the "arc furnace"
-- set until ci-a6z handed that off to the iron-recovery building, ci-hs1j) -- see
-- the graphics_set block below and graphics/entity/electrolysis-cell/ATTRIBUTION.md.

local util = require("util")

local ALUMINA = "cindra-alumina"
local ALUMINIUM = "cindra-aluminium"
local CELL = "cindra-electrolysis-cell"
local CATEGORY = "cindra-electrolysis"      -- private: cell-only, keeps vanilla smelting out
local TECH = "cindra-aluminium"
local OXYGEN = "cindra-oxygen"              -- shared fluid, defined in plastics.lua (§8)

-- === Tune block (all `(tune)`, DESIGN.md §7 / §15-14 ci-63d; §8 recipe #5/#6) =
-- The leach step is a matter-conversion in a chemical plant: power is NOT the
-- lever here (it is spent in electrolysis below, which is the whole point), so it
-- runs at a modest craft time. It is deliberately net stone-NEGATIVE and
-- productivity-immune (see the recipe) so no module tier can mint free stone.
local STONE_PER_LEACH = 20
local ACID_PER_LEACH = 30          -- sulfuric-acid (fluid), from the vanilla recipe cindra-lava unlocks
local WATER_PER_LEACH = 20         -- water (fluid), from ice-melting
local ALUMINA_PER_LEACH = 10
local STONE_BACK_PER_LEACH = 14    -- ignored_by_productivity: fixed return, keeps the leach net -6 stone
local SULFUR_BACK_PER_LEACH = 2    -- ignored_by_productivity: a second sulfur source feeding the acid loop
local LEACH_SECONDS = 4

-- THE POWER LEVER. Aluminium's cost is a LARGE building draw times a LONG craft:
--   CELL_DRAW (50 MW) * (ELECTROLYSIS_SECONDS / cell crafting_speed 2) = ~400 MJ
--   per craft => ~200 MJ per aluminium. That is ~5x a manufactured-lava craft, so
--   aluminium genuinely competes for flare energy with the other big sinks. 50 MW
--   is the largest CONTINUOUS single-building draw on Cindra (above the electric
--   heater's 40 MW); only the mass driver's bursty per-launch charge (ci-o39) costs
--   more, and briefly. Productivity is ON for aluminium (an intermediate), but the
--   O2 byproduct is ignored_by_productivity, so power stays the honest cost.
local CELL_DRAW = "50MW"
local ELECTROLYSIS_SECONDS = 16
local ALUMINA_PER_ELECTROLYSIS = 4
local ALUMINIUM_PER_ELECTROLYSIS = 2
local OXYGEN_PER_ELECTROLYSIS = 30      -- ignored_by_productivity: the O2 economy's dominant source (§8.4)

local function set_icon(proto, icon, tint)
  proto.icon = nil
  proto.icons = { { icon = icon, icon_size = 64, tint = tint } }
  proto.icon_size = 64
end

-- Private recipe category: ONLY the electrolysis cell runs the electrolysis
-- recipe, and nothing vanilla can (never-mutate-other-planets / no category leak).
local category = { type = "recipe-category", name = CATEGORY }

-- === Alumina: the white feedstock (cloned from calcite for a valid item def) ==
local alumina = util.table.deepcopy(data.raw.item["calcite"])
alumina.name = ALUMINA
alumina.order = "z[cindra]-a[alumina]"
alumina.stack_size = 100
-- Bespoke render (ci-6vj S6): a white refined-mineral pile (silica-gel render) that
-- reads as alumina powder. Source + attribution in graphics/ART-MANIFEST.md.
set_icon(alumina, "__cindra__/graphics/icons/cindra-alumina.png")
alumina.localised_name = { "item-name.cindra-alumina" }
alumina.localised_description = { "item-description.cindra-alumina" }

-- === Aluminium: the ruinous-power metal (cloned from steel-plate) =============
local aluminium = util.table.deepcopy(data.raw.item["steel-plate"])
aluminium.name = ALUMINIUM
aluminium.order = "z[cindra]-b[aluminium]"
aluminium.stack_size = 100
-- Bespoke render (ci-6vj S6): a genuine aluminium plate render, distinct from steel.
-- Source + attribution in graphics/ART-MANIFEST.md.
set_icon(aluminium, "__cindra__/graphics/icons/cindra-aluminium.png")
aluminium.localised_name = { "item-name.cindra-aluminium" }
aluminium.localised_description = { "item-description.cindra-aluminium" }

-- === The electrolysis cell: the big power sink ================================
-- Cloned from the electric furnace: it already has a correct electric energy
-- source and a smelting-style single-input flow, so feeding it alumina yields
-- aluminium. We restrict it to the private category and crank the electric draw.
local cell = util.table.deepcopy(data.raw["furnace"]["electric-furnace"])
cell.name = CELL
cell.minable = { mining_time = 0.5, result = CELL }
cell.crafting_categories = { CATEGORY }
cell.energy_usage = CELL_DRAW           -- the ruinous draw (uncapped, far above lava)
cell.fast_replaceable_group = nil       -- not interchangeable with the electric furnace
cell.next_upgrade = nil
cell.localised_name = { "entity-name.cindra-electrolysis-cell" }
cell.localised_description = { "entity-description.cindra-electrolysis-cell" }
-- The electric furnace has no fluid box; electrolysis vents O2 gas, so give the
-- cell a single OUTPUT fluid box on its north edge. The furnace still auto-selects
-- the private-category recipe from its input item (alumina); the O2 leaves here.
-- pipe_covers/pipe_picture are omitted (v1 art reuse) -- the connection still works.
cell.fluid_boxes = {
  {
    production_type = "output",
    volume = 1000,
    pipe_connections = {
      { flow_direction = "output", direction = defines.direction.north, position = { 0, -1 } },
    },
  },
}
cell.fluid_boxes_off_when_no_fluid_recipe = true

-- === Footprint: a 4x4 machine, not a 3x3 (ci-a6z) ============================
-- The cloned electric furnace is 3x3 (collision 2.4, selection 3x3), but the
-- oxidizer body below is a big bulbous machine that reads far larger, so its
-- selection box has to grow to match the model (a 3x3 box under a ~4.5-tile body
-- makes the machine impossible to click cleanly). Enlarge to a 4x4 footprint:
-- tile_width/height are pinned to 4 so the (even) grid snap is unambiguous, the
-- selection box is the full 4x4, and the collision box sits 0.1 tile inside it
-- (the vanilla landing-pad 4x4 ratio). This is a Cindra-exclusive clone, so the
-- box change cannot leak to the shared electric furnace.
cell.tile_width = 4
cell.tile_height = 4
cell.collision_box = { { -1.9, -1.9 }, { 1.9, 1.9 } }
cell.selection_box = { { -2.0, -2.0 }, { 2.0, 2.0 } }

-- === Circuit-wire connection point: bottom-right (ci-a6z) ====================
-- The inherited electric-furnace connector attaches the circuit wire near the
-- machine's centre-top, which reads badly floating over the tall oxidizer body.
-- Re-anchor the wire to the BOTTOM-RIGHT of the 4x4 footprint, seated on the
-- lower-right body mass. +x = east (right), +y = south (down), so bottom-right
-- is (+,+); the green pin sits just right of the red one, per the vanilla
-- convention. We drop the inherited connector SPRITES and give a points-only
-- connector (CircuitConnectorDefinition.sprites is optional): a stale centre LED
-- with the wire attaching at the far corner would look broken, and the wire
-- POINT is the load-bearing bit. LuaEntityPrototype does not expose the connector
-- offset at runtime, so the plain-Lua unit test asserts this at the data layer.
local function wire_br()
  return {
    points = {
      wire = { red = { 1.3, 1.1 }, green = { 1.65, 1.1 } },
      -- shadow is required by the engine; cast it down-right of the wire pins.
      shadow = { red = { 1.55, 1.35 }, green = { 1.9, 1.35 } },
    },
  }
end
-- Furnaces are not rotatable, but the connector is a per-direction vector; supply
-- four identical entries (matching the vanilla furnace convention).
cell.circuit_connector = { wire_br(), wire_br(), wire_br(), wire_br() }
-- Keep it circuit-connectable (the inherited furnace wire distance, defaulted for
-- the unit-test stub which clones a connector-less electric furnace).
cell.circuit_wire_max_distance = cell.circuit_wire_max_distance or 9

-- === Bespoke art: Hurricane046's "oxidizer" set (ci-a6z) =====================
-- The signature aluminium building wears the OXIDIZER set by Hurricane046 (CC-BY
-- 4.0, as bundled in the Nullius Visual Overhaul) -- a big bulbous riveted vessel
-- with a green electro-chemical glow, which reads as the grand power sink the cell
-- is and fills the enlarged 4x4 box. It wore the "arc furnace" set until ci-a6z,
-- which handed that set to the iron-recovery building (ci-hs1j) so the two
-- machines do not both claim it; the arc-furnace PNGs now live in
-- graphics/entity/arc-furnace/. See graphics/entity/electrolysis-cell/ATTRIBUTION.md
-- + CREDITS.md.
--
-- The cloned electric-furnace brings its OWN graphics_set (base body + heater
-- working_visualisations). Replace it WHOLESALE so the cell reads as its own
-- machine, not a reskinned electric furnace, and no electric-furnace art leaks.
local ENTITY_GFX = "__cindra__/graphics/entity/electrolysis-cell/"
local ICON = "__cindra__/graphics/icons/oxidizer-icon.png"

-- Single-file animation sheet: 2240x2560 px = an 8x8 grid of 280x320-px frames
-- (64 cells), of which only the first 60 are non-empty (rows 0-6 full = 56, plus
-- the first 4 of row 7). line_length 8 walks the grid and frame_count 60 stops
-- before the 4 trailing empty cells -- otherwise the machine blinks out on those
-- frames as the animation cycles through the blanks. The emission sheet shares
-- the exact geometry so the glow registers on the body frame-for-frame.
local FRAME_W, FRAME_H = 280, 320
local FRAME_COUNT = 60
local LINE_LENGTH = 8
-- The footprint is now 4x4 (see the box block above). The 320px-tall frame at
-- scale 0.45 renders ~144 px (~4.5 tiles) tall and ~126 px (~3.9 tiles) wide, a
-- modest overhang that reads as a grand signature machine over its 4x4 box
-- without swamping neighbours. shift 0 centres the body and seats it on the
-- ground. Final scale/shift are pending an in-engine render (PLAYTEST.md) exactly
-- as the arc-furnace/glass-furnace sets were tuned.
local BODY_SCALE = 0.45
local BODY_SHIFT = { 0, 0 }

-- Body + shadow + emissive glow. The emission sheet is opaque black (bright glow
-- openings on a black background), so it MUST blend "additive" with draw_as_glow
-- -- draw_as_glow alone does NOT change the blend op, so an opaque black frame
-- would paint a black box over the body (the ci-036 glass-furnace regression).
-- Additive makes the black background contribute nothing and only the glow
-- openings add light, exactly how the vanilla electric-furnace light layer blends.
-- (The oxidizer set also ships color1/color2 tint-mask sheets for Nullius tier
-- colouring; the cell is a single fixed machine, so they are deliberately unused.)
cell.graphics_set = {
  animation = {
    layers = {
      { -- lit, opaque body
        filename = ENTITY_GFX .. "oxidizer-hr-animation-1.png",
        width = FRAME_W,
        height = FRAME_H,
        frame_count = FRAME_COUNT,
        line_length = LINE_LENGTH,
        scale = BODY_SCALE,
        shift = BODY_SHIFT,
        animation_speed = 0.5,
      },
      { -- ground shadow: one static image (all layers of a layered Animation must
        -- share frame_count, so pin it to 1 and let the engine hold the frame).
        filename = ENTITY_GFX .. "oxidizer-hr-shadow.png",
        width = 700,
        height = 500,
        frame_count = 1,
        repeat_count = FRAME_COUNT,
        scale = BODY_SCALE,
        shift = BODY_SHIFT,
        draw_as_shadow = true,
      },
      { -- emissive electro-chemical glow, locked to the body geometry
        filename = ENTITY_GFX .. "oxidizer-hr-emission-1.png",
        width = FRAME_W,
        height = FRAME_H,
        frame_count = FRAME_COUNT,
        line_length = LINE_LENGTH,
        scale = BODY_SCALE,
        shift = BODY_SHIFT,
        animation_speed = 0.5,
        draw_as_glow = true,
        blend_mode = "additive",
      },
    },
  },
  -- === Nightside frost overlay (ci-z7nu) ===================================
  -- Cindra's `entities_require_heating` surface freezes this cell for real; the
  -- engine draws a frost sheen ONLY from graphics_set.frozen_patch, and replacing
  -- the electric-furnace graphics_set wholesale above dropped the furnace's own
  -- patch (space-age wires it in a later data-updates pass, onto the shared
  -- electric-furnace, never this clone), so the frozen oxidizer showed NO frost
  -- while the other frozen buildings kept theirs. Restore it by reusing the
  -- electric-furnace frost sprite -- the cell's source machine; at scale 0.5 it
  -- renders ~3.7 tiles wide, a close match for the ~3.9-tile oxidizer body.
  -- reset_animation_when_frozen halts the electro-chemical cycle on frame 0 so a
  -- frozen cell reads as stopped, matching vanilla frozen machines. Final frost
  -- shift/scale against the bulbous body is a visual tune (PLAYTEST.md).
  frozen_patch = {
    filename = "__space-age__/graphics/entity/frozen/electric-furnace/electric-furnace.png",
    width = 239,
    height = 219,
    shift = util.by_pixel(0.75, 5.75),
    scale = 0.5,
  },
  reset_animation_when_frozen = true,
}
-- Drop every inherited electric-furnace overlay so nothing of the old machine
-- leaks through the new body.
cell.graphics_set_flipped = nil
cell.working_visualisations = nil
-- Wear the oxidizer icon (matching the entity), clearing any inherited layered
-- electric-furnace icon.
cell.icon = ICON
cell.icon_size = 64
cell.icons = nil

local cell_item = util.table.deepcopy(data.raw.item["electric-furnace"])
cell_item.name = CELL
cell_item.place_result = CELL
cell_item.order = "z[cindra]-c[electrolysis-cell]"
cell_item.localised_name = { "item-name.cindra-electrolysis-cell" }
cell_item.localised_description = { "item-description.cindra-electrolysis-cell" }
-- Item wears the same oxidizer icon as the entity.
cell_item.icon = ICON
cell_item.icon_size = 64
cell_item.icons = nil

-- === Recipes =================================================================
-- LEACH: 20 stone + 30 sulfuric-acid + 20 water -> 10 alumina + 14 stone + 2
-- sulfur, in a vanilla CHEMICAL PLANT ("chemistry" category -- it needs fluid
-- boxes for the acid + water in and no new building). The 14-stone + 2-sulfur
-- returns are `ignored_by_productivity` (fixed at every module tier) and
-- productivity is OFF, so the leach is provably net stone-NEGATIVE (20 in, 14
-- back = -6/craft) forever -- no prod tier can mint free stone (ci-669 / §8.6).
local alumina_recipe = {
  type = "recipe",
  name = ALUMINA,
  categories = { "chemistry" }, -- vanilla chemical plant: has the fluid boxes the acid + water need
  subgroup = "raw-material",
  order = "z[cindra]-a[alumina]",
  enabled = false, -- gated behind the aluminium tech, never free
  energy_required = LEACH_SECONDS,
  ingredients = {
    { type = "item", name = "stone", amount = STONE_PER_LEACH },
    { type = "fluid", name = "sulfuric-acid", amount = ACID_PER_LEACH },
    { type = "fluid", name = "water", amount = WATER_PER_LEACH },
  },
  results = {
    { type = "item", name = ALUMINA, amount = ALUMINA_PER_LEACH },
    -- Fixed matter returns: pinned out of any prod bonus so the leach stays net
    -- stone-negative and only ever tops the acid loop with a trickle of sulfur.
    { type = "item", name = "stone", amount = STONE_BACK_PER_LEACH, ignored_by_productivity = STONE_BACK_PER_LEACH },
    { type = "item", name = "sulfur", amount = SULFUR_BACK_PER_LEACH, ignored_by_productivity = SULFUR_BACK_PER_LEACH },
  },
  -- Productivity OFF: a matter-conversion step. A prod bonus would cut stone-in
  -- per alumina and could let the fixed 14-stone return overtake it -- the exact
  -- self-sustain the stone-negativity invariant closes (per the lava recipe).
  allow_productivity = false,
  main_product = ALUMINA,
}

-- ELECTROLYSE: 4 alumina + [RUINOUS power] -> 2 aluminium + 30 O2. The single item
-- ingredient + the cell's huge draw over a long craft is the dominant cost. The
-- O2 gas leaves via the cell's output fluid box (the O2 economy's dominant source,
-- §8.4; early sink = the vent-oxygen recipe in plastics.lua). Productivity ON:
-- aluminium is an intermediate (a plate-analog), so a prod bonus is a fair reward
-- and matches vanilla intermediate conventions (per lava); the O2 byproduct is
-- `ignored_by_productivity` so a prod bonus can never mint free oxygen.
local aluminium_recipe = {
  type = "recipe",
  name = ALUMINIUM,
  categories = { CATEGORY },
  subgroup = "raw-material",
  order = "z[cindra]-b[aluminium]",
  enabled = false,
  energy_required = ELECTROLYSIS_SECONDS,
  ingredients = {
    { type = "item", name = ALUMINA, amount = ALUMINA_PER_ELECTROLYSIS },
  },
  results = {
    { type = "item", name = ALUMINIUM, amount = ALUMINIUM_PER_ELECTROLYSIS },
    { type = "fluid", name = OXYGEN, amount = OXYGEN_PER_ELECTROLYSIS, ignored_by_productivity = OXYGEN_PER_ELECTROLYSIS },
  },
  allow_productivity = true, -- intermediate: prod is a fair reward (per lava); power stays the dominant cost
  main_product = ALUMINIUM,
}

-- Recipe to BUILD the cell (gated behind the tech). Native metal + electronics.
local cell_recipe = {
  type = "recipe",
  name = CELL,
  enabled = false,
  energy_required = 10,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "copper-plate", amount = 20 },
    { type = "item", name = "copper-cable", amount = 20 },
  },
  results = { { type = "item", name = CELL, amount = 1 } },
}

-- === Technology ==============================================================
-- Gated behind `cindra-lava` (the metal economy + the power to run electrolysis).
-- The leach's sulfuric-acid input is exactly what `cindra-lava` unlocks (the
-- vanilla `sulfur + iron-plate + water -> sulfuric-acid` recipe, fed by the
-- stone-melt sulfur byproduct, ci-eat), and its water comes from ice-melting -- so
-- everything the leach needs is already in hand behind this one prereq. The gate
-- that keeps aluminium late is `cindra-lava` (rock + power + the acid loop), so
-- aluminium is still unreachable until the player commands both rock and ice. As
-- the signature apex (ci-84s) it gates the headline science tech, and the full
-- Cindra tree (ci-3or) folds it in.
local technology = {
  type = "technology",
  name = TECH,
  -- v1 art reuse: the vanilla electric-furnace tech icon.
  icon = "__base__/graphics/technology/electronics.png",
  icon_size = 256,
  effects = {
    { type = "unlock-recipe", recipe = CELL },
    { type = "unlock-recipe", recipe = ALUMINA },
    { type = "unlock-recipe", recipe = ALUMINIUM },
  },
  prerequisites = { "cindra-lava" },
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
  alumina, aluminium, cell, cell_item,
  alumina_recipe, aluminium_recipe, cell_recipe,
  technology,
})

-- Exposed for tests + downstream integration (storage.lua reads ALUMINIUM).
return {
  ALUMINA = ALUMINA,
  ALUMINIUM = ALUMINIUM,
  CELL = CELL,
  CATEGORY = CATEGORY,
  TECH = TECH,
  CELL_DRAW = CELL_DRAW,
  ELECTROLYSIS_SECONDS = ELECTROLYSIS_SECONDS,
  ALUMINIUM_PER_ELECTROLYSIS = ALUMINIUM_PER_ELECTROLYSIS,
}
