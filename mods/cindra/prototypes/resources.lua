-- Cindra's world resources (§5, §15 item 3).
--
-- The resource LIST and where each lives on the ribbon axis:
--   stone      -> the ribbon surface (feedstock for manufactured lava)
--   ice field  -> the nightside; yields ONLY the vanilla `oxide-asteroid-chunk`
--                 that the vanilla crush -> melt chain turns into water / calcite
--                 (ci-3mx). There is NO standalone volatiles resource or map-gen
--                 slider (ci-3yl) and volatiles are NOT a mining yield (ci-4xx):
--                 the frozen volatiles the science pack needs come from PROCESSING
--                 the chunk (prototypes/ice-processing.lua), not from the field.
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

-- The ribbon geometry (startup settings, available at data stage). The band masks
-- read these so the autoplace bands line up exactly with the damage axis.
local function ribbon_cfg()
  local s = settings.startup
  return {
    safe_half_width = s["cindra-ribbon-safe-half-width"].value,
    lethal_at = s["cindra-ribbon-lethal-at"].value,
    wall_at = s["cindra-ribbon-wall-at"].value,
  }
end
local CFG = ribbon_cfg()

-- The deep-nightside frozen volatiles, a science-pack input. It is NOT a mined
-- resource: no map-gen slider (ci-3yl) and NO LONGER a mining yield of the ice
-- field (ci-4xx). The ITEM survives and comes from a PROCESSING recipe -- crushing
-- the deep-nightside oxide chunks in the ice crusher sublimes out the frozen
-- volatile fraction (prototypes/ice-processing.lua, per DESIGN §11). It has its OWN
-- distinct icon (a violet-frost gas vial, ci-9bb): the old placeholder reused the
-- vanilla ice item art, so the volatiles read as plain "ice cubes". The bespoke
-- icon reads as frozen volatile gases, not ice.
data:extend({
  {
    type = "item",
    name = "cindra-volatiles",
    icon = "__cindra__/graphics/icons/cindra-volatiles.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = "raw-resource",
    order = "z[cindra-volatiles]",
    stack_size = 50,
    weight = 100000, -- matches other raw solids for platform hauling
  },
})

-- Register the patch sets up front, in a deterministic order (mirrors vanilla
-- base/prototypes/entity/resources.lua), so patch indices are stable. Only Stone
-- and Ice are mineable resources (ci-3yl): the map-gen screen shows just these two.
resource_autoplace.initialize_patch_set("cindra-stone", true)
resource_autoplace.initialize_patch_set("cindra-ice", true)

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
    has_starting_area_placement = params.has_starting_area_placement,
    autoplace_control_name = name,
  })
  spec.probability_expression =
    "(" .. spec.probability_expression .. ") * (" .. mask_expr .. ")"
  spec.richness_expression =
    "(" .. spec.richness_expression .. ") * (" .. mask_expr .. ") * (" .. rich_mult_expr .. ")"
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

-- The vanilla ice-chunk item a Cindra ice field yields (ci-3mx): the whole ice
-- chain reuses vanilla recipes (crush -> ice + calcite, melt -> water).
local ICE_ITEM = "oxide-asteroid-chunk"

-- The Cindra ice resource: ice-chunk patches that yield ONLY the vanilla oxide
-- chunk (ci-4xx). Frozen volatiles are NOT a mining yield any more -- they come
-- from a PROCESSING recipe (crushing the chunk, prototypes/ice-processing.lua), so
-- mining the field is a single-product drop of the vanilla chunk that the crush ->
-- melt chain (ci-3mx) turns into ice / calcite / water.
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
  local r = cindra_resource("cindra-ice", ICE_ITEM, ICE_MAP_COLOR, "b[cindra-ice]",
    -- Denser spot placement than the old narrow ribbon (ci-da2): ice now lives on
    -- the cold cap east of the building band (x > 100), so its guaranteed
    -- starting-area patch (placed at the origin) is masked out. A higher
    -- spots-per-km2 keeps ice reliably present in the reachable cold zone instead
    -- of leaving the nightside barren.
    banded_autoplace("cindra-ice",
      { order = "b", base_density = 8, base_spots_per_km2 = 12, has_starting_area_placement = true },
      field.ice_mask_expr(CFG), field.ice_richness_mult_expr(CFG)),
    "__cindra__/graphics/icons/ice.png")
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
  -- Ice: the nightside's single signature raw. It yields ONLY the VANILLA
  -- `oxide-asteroid-chunk` (ci-4xx) so the whole ice chain reuses vanilla recipes
  -- (crush -> ice + calcite, melt -> water; ci-3mx). The frozen volatiles the
  -- science pack needs are NOT a mining yield: they come from PROCESSING the chunk
  -- (prototypes/ice-processing.lua), not from the field. Cold blue; patches
  -- nightward of the safe band, richer the deeper (colder) they sit, with a
  -- starting patch near the terminator. The DEPOSIT reads as "Ice field"
  -- (entity-name.cindra-ice); the mined item is the vanilla chunk (we never rename
  -- the vanilla item).
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
local rock = util.table.deepcopy(data.raw["simple-entity"]["huge-rock"])
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
rock.autoplace = { probability_expression = field.rock_probability_expr(CFG) }
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
-- Cloned from the vanilla huge-rock (like the sandy rock) purely for the rock art;
-- we never mutate the shared vanilla prototype (that would leak onto Nauvis), only
-- deep-copy it. A pale frost-blue multiply-tint (rock_tint.ICE_TINT) shifts the warm
-- rubble art toward an ICY boulder so it reads correctly on the cold cap.
local ice_rock = util.table.deepcopy(data.raw["simple-entity"]["huge-rock"])
ice_rock.name = field.ICE_ROCK
ice_rock.order = "a[cindra]-d[ice-rock]"
ice_rock.map_color = { 0.62, 0.82, 1.0 } -- pale frost-blue, matches the icy tint
ice_rock.autoplace = { probability_expression = field.ice_rock_probability_expr(CFG) }
rock_tint.apply(ice_rock.pictures, rock_tint.ICE_TINT)
ice_rock.minable = {
  mining_particle = "stone-particle",
  mining_time = 2,
  results = {
    { type = "item", name = "ice", amount_min = 4, amount_max = 8 },
    { type = "item", name = "stone", amount_min = 8, amount_max = 16 },
  },
}
data:extend({ ice_rock })

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
-- Two size variants for visual variety; both share the hot-region autoplace and
-- the stone+coal drop, differing only in art and yield magnitude.
local BURNED_ROCKS = {
  {
    name = field.BURNED_ROCK, clone_from = "big-volcanic-rock",
    order = "a[cindra]-b[volcanic-rock]", map_color = { 0.35, 0.16, 0.10 },
    stone = { 4, 10 }, coal = { 2, 5 },
  },
  {
    name = field.BURNED_ROCK_HUGE, clone_from = "huge-volcanic-rock",
    order = "a[cindra]-c[volcanic-rock-huge]", map_color = { 0.35, 0.16, 0.10 },
    stone = { 8, 20 }, coal = { 4, 10 },
  },
}

local burned_rocks = {}
for _, spec in ipairs(BURNED_ROCKS) do
  local src = data.raw["simple-entity"][spec.clone_from]
  if not src then
    error("cindra resources: missing volcanic rock clone source " .. tostring(spec.clone_from))
  end
  local r = util.table.deepcopy(src)
  r.name = spec.name
  r.order = spec.order
  r.map_color = spec.map_color
  -- Native autoplace tied to the hot end of the gradient (ci-3yl style, ci-qy0):
  -- the map-gen scatters them across the hot region, densest toward the lava.
  r.autoplace = { probability_expression = field.burned_rock_probability_expr(CFG) }
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
