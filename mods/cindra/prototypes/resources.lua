-- Cindra's world resources (§5, §15 item 3).
--
-- The resource LIST and where each lives on the ribbon axis:
--   stone      -> the ribbon surface (feedstock for manufactured lava)
--   ice        -> the nightside (matter economy: water / calcite / volatiles)
--   volatiles  -> the DEEP nightside, inside the cold-lethal zone (optional carbon
--                 chemistry root; edge-pushing reward)
--   bootstrap rocks -> scattered near the terminator, hand-gathered, FINITE
--                 (the landing-tier trickle of metal, §6)
--
-- Stone / ice / volatiles are placed by NATIVE Factorio resource autoplace (the
-- core resource-autoplace / spot-noise library, same as nauvis/vulcanus ores) so
-- they form irregular NATURAL PATCHES of varying size/richness -- NOT the uniform
-- script grid of the earlier hand-rolled placement. Each is CONSTRAINED to its
-- ribbon band by multiplying its autoplace probability/richness by the
-- perpendicular-axis (Y) mask emitted from scripts/resource-field.lua (the one
-- band-geometry source of truth). Native autoplace also gives real
-- Frequency/Size/Richness map-gen sliders for free (via the autoplace-controls
-- below). Only the finite bootstrap ROCKS stay script-scattered (they are
-- simple-entities, not an autoplace resource).
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

-- The deep-nightside volatiles the player can harvest (frozen gases). A raw
-- harvestable, parallel to `ice`; the optional local-chemistry recipes that turn
-- it into carbon/CO2 (§11) are the mechanics track's to add. Placeholder icon
-- reuses the vanilla ice item art (bespoke art is a later pass).
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
-- base/prototypes/entity/resources.lua), so patch indices are stable.
resource_autoplace.initialize_patch_set("cindra-stone", true)
resource_autoplace.initialize_patch_set("cindra-ice", true)
resource_autoplace.initialize_patch_set("cindra-volatiles", false)

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

-- Autoplace-controls: one per resource so the new-game map-gen screen shows real
-- Frequency / Size / Richness sliders (category "resource"). The band masks read
-- `var('control:<name>:...')`, so these sliders drive the patches directly.
data:extend({
  {
    type = "autoplace-control",
    name = "cindra-stone",
    localised_name = { "", "[entity=cindra-stone] ", { "entity-name.cindra-stone" } },
    richness = true,
    order = "a-a",
    category = "resource",
  },
  {
    type = "autoplace-control",
    name = "cindra-ice",
    localised_name = { "", "[entity=cindra-ice] ", { "entity-name.cindra-ice" } },
    richness = true,
    order = "a-b",
    category = "resource",
  },
  {
    type = "autoplace-control",
    name = "cindra-volatiles",
    localised_name = { "", "[entity=cindra-volatiles] ", { "entity-name.cindra-volatiles" } },
    richness = true,
    order = "a-c",
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
  -- Ice: the nightside's single signature raw. Cold blue. Patches nightward of the
  -- safe band, richer the deeper (colder) they sit; a starting patch keeps the
  -- matter economy reachable near the landing terminator.
  cindra_resource("cindra-ice", "ice", { 0.55, 0.75, 0.95 }, "b[cindra-ice]",
    banded_autoplace("cindra-ice",
      { order = "b", base_density = 8, base_spots_per_km2 = 3, has_starting_area_placement = true },
      field.ice_mask_expr(CFG), field.ice_richness_mult_expr(CFG)),
    "__cindra__/graphics/icons/ice.png"),
  -- Volatiles: deep-nightside frozen gases, inside the cold-lethal band. Pale
  -- violet so it reads as "the deepest, coldest, best node." No starting patch:
  -- an edge-pushing reward you must brave the cold-lethal zone to reach.
  cindra_resource("cindra-volatiles", "cindra-volatiles", { 0.70, 0.60, 0.85 }, "c[cindra-volatiles]",
    banded_autoplace("cindra-volatiles",
      { order = "c", base_density = 6, base_spots_per_km2 = 4, has_starting_area_placement = false },
      field.volatiles_mask_expr(CFG), field.volatiles_richness_mult_expr(CFG))),
})

-- Bootstrap rocks: scattered, hand-gatherable, FINITE (a mined simple-entity is
-- destroyed, so it can never become a per-craft supply of the main loop, per the
-- §6 no-soft-lock rule). Cloned from the vanilla huge-rock so it reads as a rock
-- pile, but re-mined for CINDRA. Cindra has NO ore/coal patches at all (§6:
-- bootstrap from nothing), so these finite rocks are the ONLY landing-tier metal:
-- each yields stone plus a SMALL trickle of iron ore + copper ore + coal (and a
-- little tungsten, the Vulcanus-legacy metal accepted in §5). That is exactly
-- enough to hand-craft stone furnaces (from the stone) and smelt a first trickle
-- of iron/copper plates + fuel -- enough to stand up the first foundry / power /
-- ice-processing, after which the infinite lava->metal economy takes over. The
-- amounts are a bootstrap-balance decision (§15-13, coordinate with ci-arw /
-- ci-uex); kept small and finite so they can never replace the main loop.
local rock = util.table.deepcopy(data.raw["simple-entity"]["huge-rock"])
rock.name = "cindra-bootstrap-rock"
rock.autoplace = nil            -- scattered by scripts/worldgen.lua near the terminator
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
    { type = "item", name = "tungsten-ore", amount_min = 2, amount_max = 5 },
  },
}
data:extend({ rock })
