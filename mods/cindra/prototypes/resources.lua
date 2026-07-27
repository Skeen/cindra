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
-- All of these are PLACED at runtime by scripts/worldgen.lua keyed to the ribbon
-- Y coordinate (the planet strips vanilla autoplace), so `autoplace = nil` here.
-- Everything is a NEW `cindra-*` prototype cloned from a vanilla base: we never
-- mutate the shared vanilla `stone`/`huge-rock` prototypes (that would leak onto
-- Nauvis), only deep-copy them.
--
-- Resource ROLE lives here (what a node yields); the recipes that CONSUME these
-- (ice processing §15-4, lava §15-5, chemistry §11) belong to the mechanics
-- track and are intentionally not defined in this file.

local util = require("util")

-- Autoplace-control prototypes for stone + ice (§15 v2 item 7, hq-wisp-j6olv).
-- These make STONE and ICE density show as Frequency / Size / Richness SLIDERS on
-- the NEW-GAME world-gen screen (a `resource`-category control renders those
-- sliders). Cindra's resources are placed by scripts/worldgen.lua (not vanilla
-- autoplace), so nothing binds its noise to these controls; instead worldgen
-- READS the chosen slider values at runtime (surface.map_gen_settings
-- .autoplace_controls) and scales placement chance + node richness by them.
-- They only appear on the world-gen screen because planet.lua lists them in
-- Cindra's map-gen `autoplace_controls`.
data:extend({
  { type = "autoplace-control", name = "cindra-stone", category = "resource", richness = true, order = "a[cindra]-a[stone]" },
  { type = "autoplace-control", name = "cindra-ice",   category = "resource", richness = true, order = "a[cindra]-b[ice]" },
})

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

-- Clone the vanilla `stone` resource into a Cindra-exclusive resource that yields
-- `item_yield` and is placed by our world-gen (not autoplace). Depleting (a real
-- mining activity), mineable by ordinary drills (default resource category).
local function cindra_resource(name, item_yield, map_color, order)
  local r = util.table.deepcopy(data.raw.resource["stone"])
  r.name = name
  r.order = order
  r.autoplace = nil            -- placed by scripts/worldgen.lua, not vanilla autoplace
  r.map_color = map_color
  r.minable = r.minable or {}
  r.minable.result = item_yield
  r.minable.results = nil      -- single-product; drop any inherited multi-result
  return r
end

data:extend({
  -- Stone: the central ribbon feedstock. Elevated, not throwaway (it feeds every
  -- lava craft). Warm ochre, like vanilla stone.
  cindra_resource("cindra-stone", "stone", { 0.690, 0.611, 0.427 }, "a[cindra-stone]"),
  -- Ice: the nightside's single signature raw. Cold blue.
  cindra_resource("cindra-ice", "ice", { 0.55, 0.75, 0.95 }, "b[cindra-ice]"),
  -- Volatiles: deep-nightside frozen gases, inside the cold-lethal band. Pale
  -- violet so it reads as "the deepest, coldest, best node."
  cindra_resource("cindra-volatiles", "cindra-volatiles", { 0.70, 0.60, 0.85 }, "c[cindra-volatiles]"),
})

-- Bootstrap rocks: scattered, hand-gatherable, FINITE (a mined simple-entity is
-- destroyed, so it can never become a per-craft supply of the main loop, per the
-- §6 no-soft-lock rule). Cloned from the vanilla huge-rock so it reads as a rock
-- pile, but re-mined for CINDRA: it drops stone, a small trickle of tungsten ore
-- (Vulcanus-legacy metal, §5), AND a SMALL amount of COAL. Cindra has NO mineable
-- coal patch anywhere (no coal autoplace) -- the ONLY coal is this finite,
-- hand-gathered bootstrap trickle. That finite coal seeds the foundry bootstrap
-- (nitro ci-arw: coal -> a little lubricant -> the first foundry) without ever
-- becoming a renewable coal supply. The exact amounts are a bootstrap-balance
-- decision (§15-13, coordinated with ci-arw); worldgen guarantees the rock
-- exists, is finite, and drops landing-tier stone + metal + a spark of coal.
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
    { type = "item", name = "tungsten-ore", amount_min = 2, amount_max = 5 },
    -- Finite bootstrap coal: small, rock-only, never a patch. (tune, w/ ci-arw)
    { type = "item", name = "coal", amount_min = 1, amount_max = 3 },
  },
}
data:extend({ rock })
