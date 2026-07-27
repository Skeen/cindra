-- Cindra's world resources (§5, §15 item 3).
--
-- The resource LIST and where each lives on the ribbon axis:
--   stone      -> the ribbon surface (feedstock for manufactured lava)
--   ice field  -> the nightside; yields the vanilla `oxide-asteroid-chunk` that the
--                 vanilla crush -> melt chain turns into water / calcite (ci-3mx),
--                 AND a chance of the frozen volatiles the science pack needs, so
--                 there is NO standalone volatiles resource or map-gen slider
--                 (ci-3yl): deep-nightside ice IS the volatiles chain.
--   bootstrap rocks -> scattered near the terminator, hand-gathered, FINITE
--                 (the landing-tier trickle of metal, §6)
--
-- EVERYTHING is NATIVE map-gen (ci-3yl): stone + ice are placed by the core
-- resource-autoplace / spot-noise library (same as nauvis/vulcanus ores) so they
-- form irregular NATURAL PATCHES of varying size/richness, and the finite
-- bootstrap ROCKS are a native simple-entity autoplace confined to a bounded disk
-- near spawn. Each patch is CONSTRAINED to its ribbon band by multiplying its
-- autoplace probability/richness by the perpendicular-axis mask emitted from
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

-- The deep-nightside frozen volatiles, a science-pack input. It is NO LONGER a
-- standalone mined resource with its own map-gen slider (ci-3yl); the ITEM
-- survives and is obtained from the deep-nightside ICE chain (mining ice yields a
-- chance of volatiles, see cindra_ice_resource below). Placeholder icon reuses the
-- vanilla ice item art (bespoke art is a later pass).
data:extend({
  {
    type = "item",
    name = "cindra-volatiles",
    icon = "__space-age__/graphics/icons/ice.png",
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
-- Chance a mined ice node also yields a unit of frozen volatiles. Deep-nightside
-- ice is the volatiles chain (ci-3yl), so ice mining is where volatiles come from.
local VOLATILES_FROM_ICE_PROBABILITY = 0.4

-- The Cindra ice resource: ice-chunk patches that ALSO yield frozen volatiles when
-- mined. Built on the shared `cindra_resource` clone, then its single-product
-- mining is swapped for a multi-product drop (the vanilla ice chunk + a chance of
-- volatiles) so the science pack's volatiles come from working the nightside ice,
-- with no standalone volatiles ore or map-gen slider.
local function cindra_ice_resource()
  local r = cindra_resource("cindra-ice", ICE_ITEM, { 0.55, 0.75, 0.95 }, "b[cindra-ice]",
    banded_autoplace("cindra-ice",
      { order = "b", base_density = 8, base_spots_per_km2 = 3, has_starting_area_placement = true },
      field.ice_mask_expr(CFG), field.ice_richness_mult_expr(CFG)),
    "__cindra__/graphics/icons/ice.png")
  r.minable.result = nil
  r.minable.results = {
    { type = "item", name = ICE_ITEM, amount = 1 },
    { type = "item", name = "cindra-volatiles", amount = 1, independent_probability = VOLATILES_FROM_ICE_PROBABILITY },
  }
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
  -- Ice: the nightside's single signature raw, and the SOURCE of the deep-nightside
  -- frozen volatiles the science pack needs (ci-3yl: no standalone volatiles
  -- resource). It yields the VANILLA `oxide-asteroid-chunk` so the whole ice chain
  -- reuses vanilla recipes (crush -> ice + calcite, melt -> water; ci-3mx) AND a
  -- chance of frozen volatiles. Cold blue; patches nightward of the safe band,
  -- richer the deeper (colder) they sit, with a starting patch near the terminator.
  -- The DEPOSIT reads as "Ice field" (entity-name.cindra-ice); the mined items are
  -- the vanilla chunk + the Cindra volatiles item (we never rename the vanilla item).
  cindra_ice_resource(),
})

-- Bootstrap rocks: scattered, hand-gatherable, FINITE (a mined simple-entity is
-- destroyed, so it can never become a per-craft supply of the main loop, per the
-- §6 no-soft-lock rule). Cloned from the vanilla huge-rock so it reads as a rock
-- pile, but re-mined for CINDRA. Cindra has NO ore/coal patches at all (§6:
-- bootstrap from nothing), so these finite rocks are the ONLY landing-tier metal:
-- each yields stone plus a SMALL trickle of iron ore + copper ore + coal. That is
-- exactly enough to hand-craft stone furnaces (from the stone) and smelt a first
-- trickle of iron/copper plates + fuel -- enough to stand up the first foundry /
-- power / ice-processing, after which the infinite lava->metal economy takes over.
-- No tungsten: the field foundry (prototypes/lubricant.lua) is Cindra's own
-- metallurgy answer, so the Vulcanus-legacy tungsten metal is off the planet
-- entirely (ci-2tz -- don't ship both a bespoke foundry AND its legacy metal).
-- The amounts are a bootstrap-balance decision (§15-13, coordinate with ci-arw /
-- ci-uex); kept small and finite so they can never replace the main loop.
local rock = util.table.deepcopy(data.raw["simple-entity"]["huge-rock"])
rock.name = "cindra-bootstrap-rock"
-- NATIVE autoplace (ci-3yl): a sparse per-tile scatter confined to the terminator
-- safe band AND a bounded disk around spawn (scripts/resource-field), so the rocks
-- stay FINITE without any on_chunk_generated script. The map-gen places them.
rock.autoplace = { probability_expression = field.rock_probability_expr(CFG) }
rock.order = "a[cindra]-a[bootstrap-rock]"
rock.map_color = { 0.55, 0.45, 0.35 }
rock.minable = {
  mining_particle = "stone-particle",
  mining_time = 2,
  results = {
    { type = "item", name = "stone", amount_min = 12, amount_max = 24 },
    { type = "item", name = "iron-ore", amount_min = 3, amount_max = 6 },
    { type = "item", name = "copper-ore", amount_min = 3, amount_max = 6 },
    { type = "item", name = "coal", amount_min = 2, amount_max = 4 },
  },
}
data:extend({ rock })
