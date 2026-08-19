-- Cindra's world resources (§5, §15 item 3).
--
-- The resource LIST and where each lives on the ribbon axis:
--   stone      -> the ribbon surface (feedstock for manufactured lava)
--   ice field  -> the nightside; mining it yields a FIXED MIX of BOTH `ice` and
--                 `calcite` in one mining action (ci-9l6). There is no feedstock
--                 chunk and no crush step: the drill emits the mix directly, so
--                 calcite is a NATIVE mined resource (the planet's calcite source
--                 for the aluminium refine, the science pack, and the
--                 calcite->olefins chemistry, ci-400), and `ice` still feeds the
--                 water/electrolysis + science + ALICE-fuel sinks. There is NO
--                 standalone ice-derived ore or map-gen slider beyond stone + ice
--                 (ci-3yl); the two products both come off the ONE ice resource.
--   bootstrap rocks -> scattered near the terminator, hand-gathered, FINITE
--                 (the landing-tier trickle of metal, §6)
--
-- EVERYTHING is NATIVE map-gen (ci-3yl): stone + ice are placed by the core
-- resource-autoplace / spot-noise library (same as nauvis/vulcanus ores) so they
-- form irregular NATURAL PATCHES of varying size/richness, and the bootstrap
-- ROCKS are a native simple-entity autoplace scattered across the whole ribbon
-- terminator band (finite per-rock; ci-9bb). Each patch is CONSTRAINED to its
-- ribbon band by multiplying its autoplace probability/richness by the
-- perpendicular-axis mask emitted from
-- scripts/resource-field.lua (the one band-geometry source of truth). Native
-- autoplace also gives real Frequency/Size/Richness map-gen sliders for free (via
-- the autoplace-controls below). There is NO on_chunk_generated placement any more.
--
-- Everything is a NEW `cindra-*` prototype cloned from a vanilla base: we never
-- mutate the shared vanilla `stone`/`huge-rock` prototypes (that would leak onto
-- Nauvis), only deep-copy them.
--
-- Resource ROLE lives here (what a node yields); the recipes that CONSUME these
-- (ice processing §15-4, lava §15-5, chemistry §11) belong to the mechanics
-- track and are intentionally not defined in this file.

local util = require("util")
local resource_autoplace = require("resource-autoplace")
local field = require("scripts.resource-field")
local rock_tint = require("scripts.rock_tint")
-- Which vanilla MODEL each rock wears (ci-w87). Every rock below clones its source
-- from here rather than naming it inline, so the load-time audit
-- (prototypes/rock-models.lua) can never be checking a different intention than the
-- one the rocks were actually built from.
local rock_models = require("scripts.rock-models")

-- The vanilla simple-entity a Cindra rock wears, from the model catalogue. Errors
-- loudly rather than silently building a rock with no art.
local function model_source(name)
  local clone_from = rock_models.clone_from(name)
  if not clone_from then
    error("cindra resources: no declared model for rock " .. tostring(name)
      .. " (add it to scripts/rock-models.lua)")
  end
  local src = data.raw["simple-entity"][clone_from]
  if not src then
    error("cindra resources: missing rock model source " .. tostring(clone_from))
  end
  return src
end

-- The ribbon geometry the band masks read (so the autoplace bands line up exactly
-- with the damage axis) is the per-zone WIDTH layout in scripts/terrain.lua, and
-- terrain reads those startup settings itself. `nil` therefore means "the live
-- layout" -- there is nothing to hand it. (ci-7k6 deleted the cfg table that used
-- to be built here from the ribbon safe-half-width / lethal-at / wall-at sliders:
-- terrain's cfg is keyed by zone ROLE, so those three keys were silently ignored
-- all the way down, which is exactly what made the sliders dead knobs.)
local CFG = nil

-- Register the patch sets up front, in a deterministic order (mirrors vanilla
-- base/prototypes/entity/resources.lua), so patch indices are stable. Only Stone
-- and Ice are mineable resources (ci-3yl): the map-gen screen shows just these two.
resource_autoplace.initialize_patch_set("cindra-stone", true)
resource_autoplace.initialize_patch_set("cindra-ice", true)

-- How many spots the engine is ALLOWED to place per region (ci-l3k3).
--
-- The core spot-noise placer works one 1024x1024-tile region at a time and will
-- never place more spots in a region than its `candidate_spot_count`, whose
-- default is 21 (~20 spots/km2). A resource that asks for more than that gets
-- SILENTLY TRUNCATED: its Frequency slider stops doing anything the moment the
-- request crosses the budget, and the declared `base_spots_per_km2` is not what
-- the world gets either. Ice hit both: it declares 40 spots/km2, so it was
-- already saturated at Frequency 1 -- the nightside was placed at HALF its
-- declared density, and every Frequency from 0.5 to the slider maximum produced a
-- bit-identical world.
--
-- The request scales linearly with the Frequency slider, so the budget that keeps
-- the WHOLE slider live is the request at its maximum setting. Every banded
-- resource derives its budget from its own declared density here rather than
-- carrying a hand-tuned number, so a future spots-per-km2 bump can never quietly
-- reintroduce the truncation. Below the engine's own default the floor wins: a
-- sparse resource (stone, 2.5/km2) must not be given a SMALLER budget than vanilla.
local SPOT_REGION_SIZE = 1024        -- core `regular_patches` spot_noise region, in tiles
local MAX_FREQUENCY_SLIDER = 6       -- the map-gen screen's highest Frequency
local ENGINE_DEFAULT_SPOT_BUDGET = 21 -- core/lualib/resource-autoplace.lua's default
local function spot_budget(spots_per_km2)
  local region_km2 = (SPOT_REGION_SIZE / 1000) ^ 2
  return math.max(ENGINE_DEFAULT_SPOT_BUDGET,
    math.ceil(spots_per_km2 * MAX_FREQUENCY_SLIDER * region_km2))
end

-- Build a native spot-noise autoplace for `name`, CONSTRAINED to its ribbon band.
-- `mask_expr` zeroes probability/richness outside the band; `rich_mult_expr` is
-- the edge-pushing richness gradient (best nodes at the lethal margins). Both come
-- from scripts/resource-field.lua so this file never re-derives the geometry.
local function banded_autoplace(name, params, mask_expr, rich_mult_expr)
  local spec = resource_autoplace.resource_autoplace_settings({
    name = name,
    order = params.order,
    base_density = params.base_density,
    base_spots_per_km2 = params.base_spots_per_km2,
    -- Derived, never passed in (ci-l3k3): the declared density is the ONE number a
    -- resource states, and the budget that makes it real follows from it.
    candidate_spot_count = spot_budget(params.base_spots_per_km2),
    has_starting_area_placement = params.has_starting_area_placement,
    autoplace_control_name = name,
  })
  spec.probability_expression =
    "(" .. spec.probability_expression .. ") * (" .. mask_expr .. ")"
  spec.richness_expression =
    "(" .. spec.richness_expression .. ") * (" .. mask_expr .. ") * (" .. rich_mult_expr .. ")"
  -- ...and NEVER on ground that damages you (ci-bgpm). The band mask is positional, and a
  -- lethal tile bleeds ~20 tiles into the nominal safe side because the tile family comes
  -- from the noisy heightmap value -- so the band edge alone cannot keep ore off burning
  -- crust / frozen ground. The tile restriction can, exactly, at no cost to the band's
  -- width (scripts/resource-field.lua owns the list).
  spec.tile_restriction = field.field_tile_restriction()
  return spec
end

-- Clone the vanilla `stone` resource into a Cindra-exclusive resource that yields
-- `item_yield` and is placed by NATIVE autoplace (spec). Depleting (a real mining
-- activity), mineable by ordinary drills (default resource category).
local function cindra_resource(name, item_yield, map_color, order, autoplace, icon)
  local r = util.table.deepcopy(data.raw.resource["stone"])
  r.name = name
  r.order = order
  r.autoplace = autoplace       -- native spot-noise patches, band-masked
  r.map_color = map_color
  r.minable = r.minable or {}
  r.minable.result = item_yield
  r.minable.results = nil       -- single-product; drop any inherited multi-result
  -- Own icon so the map-view "Contains" list / Factoriopedia read the resource as
  -- what it actually is (ci-2sr): the deep-copied `stone` base carries the stone
  -- resource icon, which made the ICE patch read as stone. Override to a Cindra
  -- icon per resource (clear any inherited `icons` sheet so `icon` wins).
  if icon then
    r.icon = icon
    r.icon_size = 64
    r.icon_mipmaps = 4
    r.icons = nil
  end
  return r
end

-- The MIXED ice-field yield (ci-9l6): mining a Cindra ice field produces a FIXED
-- mix of BOTH `ice` and `calcite` from ONE mining action (a multi-product
-- resource), not a single feedstock chunk. There is no player choice of output and
-- no intermediate crush step -- the drill itself emits the mix, so SORTING the two
-- products apart and handling their backpressure (a full calcite belt stalls the
-- drill and chokes the ice too) IS the nightside logistics puzzle: the same
-- mixed-output-patch pressure as Fulgora scrap. Ice is the MAJORITY (it feeds the
-- many water/science/fuel sinks); calcite is a steady MINOR stream (the native
-- calcite source) that runs surplus early and gains real sinks as the chemistry
-- tech unlocks (aluminium refine, science pack, ci-400 calcination). The ratio is
-- fixed by these two amounts -- tune HERE (the one place), never re-derived.
local ICE_YIELD = 2      -- `ice` per mining action (the majority product)
local CALCITE_YIELD = 1  -- `calcite` per mining action (the minor product)

-- The Cindra ice resource: nightside patches whose mining yields a FIXED MIX of
-- `ice` + `calcite` (ci-9l6). One mining action drops BOTH products at once.
--
-- Icy world sprite (ci-9bb): the deep-copied vanilla `stone` resource carries the
-- warm-tan stone rubble stage sheet, so the ice deposit READ as a stone patch. v1
-- reuses vanilla art (per DESIGN.md), so rather than author a new stage sheet we
-- multiply the inherited stone stages by a pale frost-blue tint -- the ore patch
-- now reads as ICE/frost, not rock, and is distinct from the warm stone patch. The
-- mining particle burst is tinted icy too.
local ICE_STAGE_TINT = { r = 0.60, g = 0.80, b = 1.0, a = 1.0 } -- pale frost-blue multiply
local ICE_MINING_TINT = { r = 0.80, g = 0.94, b = 1.0, a = 1.0 } -- icy particle burst
-- Paler CYAN / frosted-ice map tone (ci-9bb): kept light blue (players liked it)
-- but shifted brighter and cyan-ward so it never reads as vanilla IRON ORE
-- (a darker steel-blue {0.415, 0.525, 0.580}); still clearly distinct from the
-- warm stone patch. Runtime-queryable via `prototypes.entity[..].map_color`.
local ICE_MAP_COLOR = { 0.62, 0.90, 0.95 }

-- Tint every stage sheet of a resource's `stages` in place (handles the single
-- `sheet` form the vanilla stone resource uses and the `sheets` array form).
local function tint_stages(stages, tint)
  if not stages then return end
  if stages.sheet then stages.sheet.tint = tint end
  if stages.sheets then
    for _, s in ipairs(stages.sheets) do s.tint = tint end
  end
end

local function cindra_ice_resource()
  local r = cindra_resource("cindra-ice", "ice", ICE_MAP_COLOR, "b[cindra-ice]",
    -- Denser spot placement than a vanilla ore (ci-da2, rebumped ci-wly): ice lives on
    -- the cold OUTER slope east of the middle (perp -120.5..-60), so its guaranteed
    -- starting-area patch (placed at the origin) is masked OUT -- ice relies entirely on
    -- the regular spots. The ci-wly redesign moved the band further out and wider, so a
    -- HIGHER spots-per-km2 (40) is needed to keep ice reliably present in the reachable
    -- cold zone on every seed instead of leaving the nightside barren. (tune)
    --
    -- 40/km2 is FAR past the engine's default 21-spot regional budget; banded_autoplace
    -- sizes the budget from this number (spot_budget above), which is what makes the
    -- density real and the Frequency slider live above 0.5 (ci-l3k3).
    banded_autoplace("cindra-ice",
      { order = "b", base_density = 8, base_spots_per_km2 = 40, has_starting_area_placement = true },
      field.ice_mask_expr(CFG), field.ice_richness_mult_expr(CFG)),
    "__cindra__/graphics/icons/ice.png")
  -- Override the single-product minable set up by cindra_resource with the FIXED
  -- ice+calcite MIX (ci-9l6): both products drop from ONE mining action, in the
  -- tuned ice-majority ratio (ICE_YIELD : CALCITE_YIELD).
  r.minable.result = nil
  r.minable.results = {
    { type = "item", name = "ice", amount = ICE_YIELD },
    { type = "item", name = "calcite", amount = CALCITE_YIELD },
  }
  tint_stages(r.stages, ICE_STAGE_TINT)
  r.mining_visualisation_tint = ICE_MINING_TINT
  return r
end

-- Autoplace-controls: one per resource so the new-game map-gen screen shows real
-- Frequency / Size / Richness sliders (category "resource"). The band masks read
-- `var('control:<name>:...')`, so these sliders drive the patches directly.
--
-- Labels are just "Stone" / "Ice" (locale [autoplace-control-names], no "Cindra"
-- prefix, no icon soup), and the `order` sorts them BELOW every vanilla planet's
-- resources -- including Aquilo -- so the Cindra sliders group together at the
-- BOTTOM of the map-gen screen instead of mixing in with Nauvis (ci-3yl).
data:extend({
  {
    type = "autoplace-control",
    name = "cindra-stone",
    richness = true,
    order = "z[cindra]-a[stone]",
    category = "resource",
  },
  {
    type = "autoplace-control",
    name = "cindra-ice",
    richness = true,
    order = "z[cindra]-b[ice]",
    category = "resource",
  },
})

data:extend({
  -- Stone: the central ribbon feedstock. Elevated, not throwaway (it feeds every
  -- lava craft). Warm ochre, like vanilla stone. Patches on the ribbon + hot
  -- margin, richest toward the hot edge; a starting patch so a from-nothing land
  -- can smelt its first stone furnaces immediately.
  cindra_resource("cindra-stone", "stone", { 0.690, 0.611, 0.427 }, "a[cindra-stone]",
    banded_autoplace("cindra-stone",
      { order = "a", base_density = 8, base_spots_per_km2 = 2.5, has_starting_area_placement = true },
      field.stone_mask_expr(CFG), field.stone_richness_mult_expr(CFG)),
    "__cindra__/graphics/icons/cindra-stone.png"),
  -- Ice: the nightside's signature raw. Mining it yields a FIXED MIX of BOTH
  -- `ice` and `calcite` in one action (ci-9l6) -- calcite is now a NATIVE mined
  -- resource (the planet's calcite source; ci-400's calcination consumes it), and
  -- `ice` still feeds water/electrolysis + science + ALICE fuel. `ice` melts to
  -- water in the vanilla chemical plant (prototypes/ice-processing.lua). Cold blue;
  -- patches nightward of the safe band, richer the deeper (colder) they sit, with a
  -- starting patch near the terminator. The DEPOSIT reads as "Ice field"
  -- (entity-name.cindra-ice); the mined items are the vanilla `ice`/`calcite` (we
  -- never rename the vanilla items).
  cindra_ice_resource(),
})

-- Bootstrap rocks: scattered, hand-gatherable, FINITE (a mined simple-entity is
-- destroyed, so it can never become a per-craft supply of the main loop, per the
-- §6 no-soft-lock rule). Cloned from the vanilla huge-rock so it reads as a rock
-- pile, but re-mined for CINDRA. Cindra has NO ore/coal patches at all (§6:
-- bootstrap from nothing), so these finite rocks are the ONLY landing-tier metal:
-- each yields stone plus a SMALL trickle of iron ore + copper ore. That is
-- exactly enough to hand-craft stone furnaces (from the stone) and smelt a first
-- trickle of iron/copper plates -- enough to stand up the first foundry /
-- power / ice-processing, after which the infinite lava->metal economy takes over.
-- (Coal, the early fuel/lubricant feedstock, is the VOLCANIC rocks' drop, ci-18n.)
-- No tungsten: the field foundry (prototypes/lubricant.lua) is Cindra's own
-- metallurgy answer, so the Vulcanus-legacy tungsten metal is off the planet
-- entirely (ci-2tz -- don't ship both a bespoke foundry AND its legacy metal).
-- No COAL either (ci-18n): coal is now the VOLCANIC rocks' drop (the burned rocks
-- in the lava region below), so the sandy rocks keep only stone + the iron/copper
-- trickle. The amounts are a bootstrap-balance decision (§15-13, coordinate with
-- ci-arw / ci-uex); kept small and finite so they can never replace the main loop.
local rock = util.table.deepcopy(model_source(field.ROCK))
-- Player-facing name is just "Rock" (locale entity-name.cindra-rock); the
-- prototype id carries no "bootstrap" either (ci-d2h). The bootstrap ROLE
-- (finite landing-tier metal) is unchanged -- only the name is plain.
rock.name = "cindra-rock"
-- NATIVE autoplace (ci-3yl, ci-9bb): a sparse per-tile scatter across the WHOLE
-- terminator safe band, appearing in new chunks as you explore the ribbon (NOT a
-- spawn-only disk -- playtest wanted them everywhere along the ribbon). Finiteness
-- comes from the ENTITY, not the placement: a mined simple-entity is destroyed, so
-- each rock is one-shot and can never become a per-craft supply of the main loop
-- (the §6 no-soft-lock rule holds because the drop stays off every loop recipe --
-- see test_bootstrap.lua). No on_chunk_generated script; the map-gen places them.
-- The autoplace `order` is its own random stream (see scripts/rock-models.lua): rocks
-- that share one succeed on identical tiles and all but the first silently never
-- generate.
rock.autoplace = {
  order = rock_models.place_order(field.ROCK),
  probability_expression = field.rock_probability_expr(CFG),
}
rock.order = "a[cindra]-a[rock]"
rock.map_color = { 0.55, 0.45, 0.35 }
-- Warm the stock huge-rock art toward a vanilla-STONE look (ci-jvc): a warm
-- multiply-tint over every sprite variation. Deep-copied above, so this tints
-- ONLY the cindra-rock clone and never the shared vanilla huge-rock. The tint
-- value + rationale live in scripts/rock_tint.lua (one source of truth).
rock_tint.apply(rock.pictures, rock_tint.STONE_TINT)
rock.minable = {
  mining_particle = "stone-particle",
  mining_time = 2,
  results = {
    { type = "item", name = "stone", amount_min = 12, amount_max = 24 },
    { type = "item", name = "iron-ore", amount_min = 3, amount_max = 6 },
    { type = "item", name = "copper-ore", amount_min = 3, amount_max = 6 },
  },
}
data:extend({ rock })

-- Ice-rocks (ci-18n): the cold-side counterpart of the sandy bootstrap rock. A
-- FINITE hand-minable simple-entity that generates in the SAFE cold/ice band (native
-- autoplace, field.ice_rock_probability_expr -- cold of the stone/ice divider but
-- warm of the lethal deep-ice zone 11, so it is gatherable with no cold damage).
-- Mining one yields an early ICE + STONE combo: a cold-side head-start on water (ice
-- -> water in the chemical plant) and stone, without a crusher. Like the sandy /
-- volcanic rocks it is finite (a mined simple-entity is DESTROYED), so the ice/stone
-- is a one-shot trickle, never a per-craft input of the main loop -- the sustaining
-- water supply is still the renewable ICE FIELD (crush -> ice -> melt), per §6.
--
-- ART (ci-w87): cloned from Aquilo's LITHIUM-ICEBERG models, not from the brown
-- huge-rock. The first cut re-used the sandy rock's huge-rock art under a pale
-- frost-blue multiply-tint, and the playtest read it exactly as what it was -- "a
-- blue-tinted normal rock" -- because a tint recolours rubble but cannot give it the
-- faceted, translucent silhouette of ice. Aquilo already ships that silhouette, so we
-- reuse it (extend, don't re-implement) in TWO sizes: the common big berg and an
-- occasional huge landmark. The medium/small/tiny members of the same family are
-- optimized-decoratives and ride the decorative catalogue instead
-- (scripts/decorative-field.lua), so the whole size family reads as one material.
--
-- We deep-copy each source and never mutate the shared vanilla prototype (that would
-- leak onto Aquilo). The source's minable table is kept for its ice mining sounds /
-- particles and only its RESULTS are replaced: Cindra has no lithium and no
-- ice-platform, so the Aquilo drop would be nonsense here.
local ICE_ROCKS = {
  {
    name = field.ICE_ROCK,
    order = "a[cindra]-d[ice-rock]",
    ice = { 4, 8 }, stone = { 8, 16 },
  },
  {
    name = field.ICE_ROCK_HUGE,
    order = "a[cindra]-e[ice-rock-huge]",
    ice = { 6, 12 }, stone = { 12, 24 },
  },
}

local ice_rocks = {}
for _, spec in ipairs(ICE_ROCKS) do
  local src = model_source(spec.name)
  local r = util.table.deepcopy(src)
  r.name = spec.name
  r.order = spec.order
  r.map_color = { 0.62, 0.82, 1.0 } -- pale frost-blue, matches the iceberg art
  -- Per-size share of the ONE cold-band scatter (field.ICE_ROCK_SHARE), so adding the
  -- second size changed the look and not the coverage (the ci-tizx density budget).
  -- The per-size autoplace ORDER is load-bearing, not cosmetic: two rocks sharing an
  -- order share the engine's per-tile roll, and the second then generates nowhere at
  -- all (see scripts/rock-models.lua).
  r.autoplace = {
    order = rock_models.place_order(spec.name),
    probability_expression = field.ice_rock_probability_expr(CFG, spec.name),
  }
  -- Keep the source's mining_time / particles / ice-crunch mining_trigger; replace only
  -- the drop with Cindra's ice + stone bootstrap trickle (no lithium, no ice-platform).
  r.minable = util.table.deepcopy(src.minable)
  r.minable.results = {
    { type = "item", name = "ice", amount_min = spec.ice[1], amount_max = spec.ice[2] },
    { type = "item", name = "stone", amount_min = spec.stone[1], amount_max = spec.stone[2] },
  }
  ice_rocks[#ice_rocks + 1] = r
end
data:extend(ice_rocks)

-- Burned volcanic rocks (ci-qy0): charred Vulcanus-style boulders that generate in
-- the HOT / lava region of the ribbon (never the temperate/building or ice zones),
-- clustered toward the lava edge so they read as "in the lava areas". They are
-- placed by NATIVE map-gen autoplace tied to the hot end of the gradient
-- (field.burned_rock_probability_expr), layered ON TOP of the terrain generation
-- as a separate entity autoplace (coordinate with ci-da2; this does not fight the
-- tile bands).
--
-- Cloned from the vanilla Vulcanus volcanic rocks purely for their charred art; we
-- never mutate the shared vanilla prototype (that would leak onto Vulcanus), only
-- deep-copy it. Mining one yields STONE + COAL ONLY -- the tungsten/iron/copper
-- trickle of the Vulcanus originals is dropped (no ore, per Cindra's no-ore-patch
-- design and ci-2tz's no-tungsten rule). Like the bootstrap rock they are FINITE
-- simple-entities (a mined rock is destroyed), so the coal is a one-shot trickle,
-- never a per-craft input of the main loop.
--
-- Two size variants for visual variety, each in a COOL and a HOT model (ci-w87).
-- Vulcanus ships every volcanic boulder twice -- a plain charred rock, and a `-hot`
-- twin whose art layers an EMISSIVE glow over the same silhouette -- and picks between
-- them by the tile underneath. Cindra reuses both and splits them on the ONE boundary
-- that already decides whether the ground burns you (field.lava_edge, the heat-damage
-- edge where the tile gradient turns to glowing crust): inside the lava area the rocks
-- glow, on the safe hot slope they do not. So the model you see is a truthful read of
-- the ground you are standing on, not decoration.
--
-- The HOT twin keeps the SAME stone+coal yield as its cool counterpart: this bead is an
-- art change, and a richer lava-side drop would be an unasked-for balance shift.
-- Vulcanus has no medium/small/tiny HOT decorative, so the small end of the family
-- (scripts/decorative-field.lua) stays the plain charred art on both sides of the line.
local BURNED_ROCKS = {
  {
    name = field.BURNED_ROCK,
    order = "a[cindra]-b[volcanic-rock]", map_color = { 0.35, 0.16, 0.10 },
    stone = { 4, 10 }, coal = { 2, 5 },
  },
  {
    name = field.BURNED_ROCK_HUGE,
    order = "a[cindra]-c[volcanic-rock-huge]", map_color = { 0.35, 0.16, 0.10 },
    stone = { 8, 20 }, coal = { 4, 10 },
  },
  {
    name = field.BURNED_ROCK_HOT,
    order = "a[cindra]-b[volcanic-rock]-hot", map_color = { 0.55, 0.20, 0.08 },
    stone = { 4, 10 }, coal = { 2, 5 },
  },
  {
    name = field.BURNED_ROCK_HUGE_HOT,
    order = "a[cindra]-c[volcanic-rock-huge]-hot", map_color = { 0.55, 0.20, 0.08 },
    stone = { 8, 20 }, coal = { 4, 10 },
  },
}

local burned_rocks = {}
for _, spec in ipairs(BURNED_ROCKS) do
  local src = model_source(spec.name)
  local r = util.table.deepcopy(src)
  r.name = spec.name
  r.order = spec.order
  r.map_color = spec.map_color
  -- Native autoplace tied to the hot end of the gradient (ci-3yl style, ci-qy0):
  -- the map-gen scatters them across the hot region, densest toward the lava. Every
  -- model shares that one band; the TILE RESTRICTION (ci-w87) is what decides which
  -- model stands where, so a glowing rock can only land on ground that burns and a
  -- plain one only on ground that does not -- no coordinate can put the two out of
  -- step. The per-model `order` is a separate necessity: see scripts/rock-models.lua.
  r.autoplace = {
    order = rock_models.place_order(spec.name),
    probability_expression = field.burned_rock_probability_expr(CFG),
    tile_restriction = field.burned_rock_tile_restriction(spec.name),
  }
  -- Mining yields STONE + COAL ONLY (the acceptance criterion). Drop the Vulcanus
  -- original's ore/tungsten trickle entirely.
  r.minable = {
    mining_particle = "stone-particle",
    mining_time = (src.minable and src.minable.mining_time) or 2,
    results = {
      { type = "item", name = "stone", amount_min = spec.stone[1], amount_max = spec.stone[2] },
      { type = "item", name = "coal", amount_min = spec.coal[1], amount_max = spec.coal[2] },
    },
  }
  burned_rocks[#burned_rocks + 1] = r
end
data:extend(burned_rocks)
