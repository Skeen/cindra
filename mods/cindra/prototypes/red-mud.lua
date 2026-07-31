-- Red mud: the Bayer alumina route + iron recovery (ci-c7j; DESIGN.md §8, folds
-- into the authoritative ci-6vj recipe graph).
--
-- This adds a SECOND way to make the signature `cindra-alumina`, and with it
-- Cindra's coupling of aluminium and iron. The planet has no metal ore, so iron
-- (like aluminium) is MADE, not mined -- here from the waste of alumina refining
-- rather than from lava. The subsystem closes the calcination loop end to end:
-- calcination emits quicklime + CO2; the Bayer step consumes the quicklime, iron
-- recovery consumes the CO2, so both calcination outputs get a productive sink.
--
--   1. BAYER ALUMINA (an ALTERNATIVE to the acid leach): `stone + quicklime ->
--      alumina + red mud`, in an assembling machine. Petrochemical-free: it needs
--      no sulfuric acid, only the quicklime that calcination already frees (giving
--      quicklime a productive use beyond the lava-disposal sink). The strategic
--      fork vs the acid leach (prototypes/aluminium.lua): the leach returns 70%
--      of its stone and needs acid but makes NO red mud; Bayer is more stone-
--      hungry, needs quicklime, and hands you red mud you must then process into
--      iron to keep the line flowing. Both feed the same alumina electrolysis
--      unchanged. Productivity is OFF (a matter conversion, exactly like the
--      leach), so no module tier mints free alumina/red mud.
--
--   2. IRON RECOVERY (the disposal mechanic + Cindra's waste-born iron): `red mud
--      + CO2 + [RUINOUS power] -> iron + slag`, in a dedicated high-draw
--      CARBOTHERMIC FURNACE (its private `cindra-carbothermic` category). The
--      carbon comes from the calciner's CO2 (closing that loop); the reduction
--      heat is paid as a large continuous electric draw, so the furnace lands as
--      ANOTHER flare-timed POWER SINK next to the electrolysis cell, manufactured
--      lava, and the mass driver -- power is the honest cost. Output is the
--      VANILLA `iron-plate` (read as a recipe result only, never mutated), so it
--      inherits real sinks automatically: the vanilla `sulfuric-acid` recipe eats
--      it (feeding the OTHER alumina route -- the two metal lines cross-feed),
--      plus every vanilla steel/building use and orbital export. Productivity is
--      OFF: iron traces back only to real stone (via Bayer), never minted.
--
--   3. SLAG: the inert tailings iron recovery leaves behind. Genuine terminal
--      waste (as real-world smelter slag largely is), so its only fate is a
--      dedicated emergency vent -- it can never wedge the line, but there is no
--      free metal or stone hiding in it.
--
-- THE COUPLING (the point of the bead): to make aluminium via Bayer you GENERATE
-- red mud; to keep that line flowing you must CONVERT red mud to iron; then you
-- must SINK the iron. Overproduce alumina and you drown in red mud -> iron. Red
-- mud has NO free vent (that is the tension): its only relief is iron recovery.
-- This never HARD-deadlocks the economy, because the acid-leach alumina route is
-- the deadlock-free fallback and iron-plate has broad real sinks; the coupling is
-- a throughput tension, not a soft-lock. (Proven in test_materials_graph.lua:
-- red mud drains transitively to the slag vent, iron-plate to the O2 vent.)
--
-- INVARIANTS (re-proven at the +300% productivity cap in test_materials_graph):
-- Bayer and iron recovery add NO new stone source (Bayer consumes stone and
-- returns none; iron recovery touches no stone), so the net-stone-negative proof
-- is preserved. No free metal: alumina now has three producers (leach, catalyst
-- reprocessing, Bayer) all net stone-negative or make-up feeds; iron has one
-- Cindra source (this furnace) that is prod-off and eats real red mud.
--
-- 🚨 NEVER MUTATE OTHER PLANETS: every prototype here is brand new or a fresh
-- deep-copy. The shared vanilla `stone` / `iron-plate` / `assembling-machine-3` /
-- `calcite` are read as ingredients/results or cloned (never mutated); the shared
-- `cindra-quicklime` / `cindra-carbon-dioxide` / `cindra-alumina` are referenced
-- by name only. A private recipe category keeps iron recovery on the carbothermic
-- furnace alone.
--
-- ART: placeholder icons for v1 (ci-c7j). Red mud + slag reuse the bespoke
-- `cindra-stone` render under a tint; the furnace reuses its assembling-machine
-- clone art. A bespoke-render follow-up is filed (cf. ci-eb9); source + intended
-- attribution (Malcolm Riley's unused-renders, CC-BY-4.0) are in
-- graphics/ART-MANIFEST.md.

local util = require("util")

local RED_MUD = "cindra-red-mud"
local SLAG    = "cindra-slag"
local FURNACE = "cindra-carbothermic-furnace"
local CATEGORY = "cindra-carbothermic"       -- private: furnace-only, keeps iron recovery off cheap assemblers
local TECH    = "cindra-red-mud"

-- Referenced-by-name interfaces from the existing graph (never mutated here).
local ALUMINA   = "cindra-alumina"            -- prototypes/aluminium.lua
local QUICKLIME = "cindra-quicklime"          -- prototypes/plastics.lua (calcination co-product)
local CO2       = "cindra-carbon-dioxide"     -- prototypes/plastics.lua (calcination fluid)
local IRON      = "iron-plate"                -- VANILLA, read as a recipe result only
local STONE     = "stone"                     -- VANILLA

local ICON_DIR = "__cindra__/graphics/icons/"
local function bespoke(name) return ICON_DIR .. name .. ".png" end

local function set_icon(proto, icon, tint)
  proto.icon = nil
  proto.icons = { { icon = icon, icon_size = 64, tint = tint } }
  proto.icon_size = 64
  proto.pictures = nil -- fall back to the (tinted) icon for belt/inventory art
end

-- === Tune block (all `(tune)`, DESIGN.md §7 / §15-14 ci-63d) =================
-- Bayer is a matter conversion (power is spent downstream in iron recovery, which
-- is the whole point), so it runs at a modest craft time and is net stone-hungry
-- with no stone return -- provably prod-immune (see the recipe).
local STONE_PER_BAYER     = 20
local QUICKLIME_PER_BAYER = 5
local ALUMINA_PER_BAYER   = 10
local RED_MUD_PER_BAYER    = 5
local BAYER_SECONDS       = 4

-- THE POWER LEVER for iron. A large continuous draw over a long craft, so per-unit
-- energy is ruinous: FURNACE_DRAW (45 MW) * (IRON_SECONDS 12 / furnace speed) is
-- ~540 MJ/craft => ~108 MJ per iron-plate, the second-largest continuous single-
-- building draw on Cindra (below the aluminium cell's 50 MW, above the electric
-- heater's 40 MW). CO2 is the carbon reductant, closing the calcination loop.
local FURNACE_DRAW      = "45MW"
local IRON_SECONDS      = 12
local RED_MUD_PER_IRON  = 10
local CO2_PER_IRON      = 20
local IRON_PER_IRON     = 5
local SLAG_PER_IRON     = 5

-- Private recipe category: ONLY the carbothermic furnace runs iron recovery, and
-- nothing vanilla can (never-mutate-other-planets / no category leak).
local category = { type = "recipe-category", name = CATEGORY }

-- === Items ===================================================================
-- Red mud: the Bayer byproduct (iron-oxide-rich residue). Cloned from calcite for
-- a valid item def; placeholder reddish tint over the bespoke stone render (v1).
local red_mud = util.table.deepcopy(data.raw.item["calcite"])
red_mud.name = RED_MUD
red_mud.order = "z[cindra]-red-mud"
red_mud.stack_size = 100
set_icon(red_mud, bespoke("cindra-stone"), { r = 0.72, g = 0.34, b = 0.24, a = 1.0 })
red_mud.localised_name = { "item-name." .. RED_MUD }
red_mud.localised_description = { "item-description." .. RED_MUD }

-- Slag: inert tailings from iron recovery. Placeholder dark-grey tint (v1).
local slag = util.table.deepcopy(data.raw.item["calcite"])
slag.name = SLAG
slag.order = "z[cindra]-slag"
slag.stack_size = 100
set_icon(slag, bespoke("cindra-stone"), { r = 0.42, g = 0.44, b = 0.50, a = 1.0 })
slag.localised_name = { "item-name." .. SLAG }
slag.localised_description = { "item-description." .. SLAG }

-- === The carbothermic furnace: the iron-line power sink =======================
-- Cloned from assembling-machine-3: it already has a correct electric energy
-- source AND the fluid box the CO2 input needs (the zeolite catalyst proves AM3
-- accepts a fluid ingredient). We restrict it to the private category and crank
-- the electric draw. v1 art reuse: keep the cloned assembler sprite + icon.
local furnace = util.table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
furnace.name = FURNACE
furnace.minable = { mining_time = 0.5, result = FURNACE }
furnace.crafting_categories = { CATEGORY }
furnace.energy_usage = FURNACE_DRAW           -- the ruinous draw (far above a stock assembler)
furnace.fast_replaceable_group = nil          -- not interchangeable with the assembler
furnace.next_upgrade = nil
furnace.localised_name = { "entity-name." .. FURNACE }
furnace.localised_description = { "entity-description." .. FURNACE }

local furnace_item = util.table.deepcopy(data.raw.item["assembling-machine-3"])
furnace_item.name = FURNACE
furnace_item.place_result = FURNACE
furnace_item.order = "z[cindra]-carbothermic-furnace"
furnace_item.localised_name = { "item-name." .. FURNACE }
furnace_item.localised_description = { "item-description." .. FURNACE }

-- === Recipes =================================================================
-- BAYER: 20 stone + 5 quicklime -> 10 alumina + 5 red mud, in an assembling
-- machine (dry solids, default "crafting"). Net stone-NEGATIVE with NO stone
-- return, so it opens no new stone vector; productivity OFF (a matter conversion,
-- like the acid leach) so no module tier mints free alumina or red mud. Feeds the
-- same alumina electrolysis as the acid leach.
local bayer = {
  type = "recipe",
  name = "cindra-bayer-alumina",
  -- default "crafting": any assembler runs it; no fluids, so no fluid box needed.
  subgroup = "raw-material",
  order = "z[cindra]-a[alumina-bayer]",
  enabled = false, -- gated behind the red-mud tech, never free
  energy_required = BAYER_SECONDS,
  ingredients = {
    { type = "item", name = STONE, amount = STONE_PER_BAYER },
    { type = "item", name = QUICKLIME, amount = QUICKLIME_PER_BAYER },
  },
  results = {
    { type = "item", name = ALUMINA, amount = ALUMINA_PER_BAYER },
    { type = "item", name = RED_MUD, amount = RED_MUD_PER_BAYER },
  },
  allow_productivity = false, -- matter conversion: no free alumina/red mud
  main_product = ALUMINA,
  localised_name = { "recipe-name.cindra-bayer-alumina" },
  localised_description = { "recipe-description.cindra-bayer-alumina" },
}

-- IRON RECOVERY: 10 red mud + 20 CO2 + [RUINOUS power] -> 5 iron-plate + 5 slag,
-- in the carbothermic furnace (private category). The CO2 is the carbon reductant
-- (closing the calcination loop); the ruinous draw over a long craft is the
-- dominant cost. Productivity OFF: iron traces back only to real red mud (real
-- stone via Bayer), never minted. Output is the vanilla iron-plate, so it plugs
-- into the vanilla acid recipe and every vanilla iron/steel use + export.
local iron_recovery = {
  type = "recipe",
  name = "cindra-iron-recovery",
  categories = { CATEGORY },
  subgroup = "raw-material",
  order = "z[cindra]-b[iron-recovery]",
  enabled = false,
  energy_required = IRON_SECONDS,
  ingredients = {
    { type = "item", name = RED_MUD, amount = RED_MUD_PER_IRON },
    { type = "fluid", name = CO2, amount = CO2_PER_IRON },
  },
  results = {
    { type = "item", name = IRON, amount = IRON_PER_IRON },
    { type = "item", name = SLAG, amount = SLAG_PER_IRON },
  },
  allow_productivity = false, -- no minting free metal; iron is real stone + power
  main_product = IRON,
  localised_name = { "recipe-name.cindra-iron-recovery" },
  localised_description = { "recipe-description.cindra-iron-recovery" },
}

-- Recipe to BUILD the furnace (gated behind the tech). Native metal + electronics.
local furnace_recipe = {
  type = "recipe",
  name = FURNACE,
  enabled = false,
  energy_required = 10,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "copper-plate", amount = 20 },
    { type = "item", name = "copper-cable", amount = 20 },
  },
  results = { { type = "item", name = FURNACE, amount = 1 } },
}

-- SLAG vent (emergency sink): slag is inert terminal waste, so its only fate is a
-- pure sink -- a spare assembler dumps it so a backed-up slag box never wedges
-- iron recovery (and, transitively, the Bayer alumina line).
local vent_slag = {
  type = "recipe",
  name = "cindra-vent-slag",
  -- default "crafting": an assembler can dump slag (a solid) with no fluid box.
  subgroup = "raw-material",
  order = "z[cindra]-y[vent-slag]",
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "item", name = SLAG, amount = 10 },
  },
  results = {}, -- discarded: a pure sink
  allow_productivity = false,
  icons = { { icon = bespoke("cindra-stone"), icon_size = 64, tint = { r = 0.42, g = 0.44, b = 0.50, a = 1.0 } } },
  localised_name = { "recipe-name.cindra-vent-slag" },
  localised_description = { "recipe-description.cindra-vent-slag" },
}

-- === Technology ==============================================================
-- Clusters the whole red-mud subsystem in ONE tech (no fragmentation). Prereq is
-- the materials-chemistry tech `cindra-calcite-olefins`, because Bayer needs the
-- quicklime and iron recovery needs the CO2 that only calcination frees -- so the
-- subsystem is unreachable until that tier is in hand. Researched with brought
-- vanilla packs (no soft-lock behind the Cindra pack), like the sibling techs.
local technology = {
  type = "technology",
  name = TECH,
  -- v1 art reuse: the red-mud item render (placeholder tint over the stone render).
  icons = { { icon = bespoke("cindra-stone"), icon_size = 64, tint = { r = 0.72, g = 0.34, b = 0.24, a = 1.0 } } },
  icon_size = 64,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-bayer-alumina" },
    { type = "unlock-recipe", recipe = "cindra-iron-recovery" },
    { type = "unlock-recipe", recipe = FURNACE },
    { type = "unlock-recipe", recipe = "cindra-vent-slag" },
  },
  prerequisites = { "cindra-calcite-olefins" },
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
  red_mud, slag, furnace, furnace_item,
  bayer, iron_recovery, furnace_recipe, vent_slag,
  technology,
})

-- Exposed for tests + downstream integration.
return {
  RED_MUD = RED_MUD,
  SLAG = SLAG,
  FURNACE = FURNACE,
  CATEGORY = CATEGORY,
  TECH = TECH,
  IRON = IRON,
  FURNACE_DRAW = FURNACE_DRAW,
  IRON_SECONDS = IRON_SECONDS,
}
