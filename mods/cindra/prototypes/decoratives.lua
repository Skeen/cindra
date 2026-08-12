-- Cindra's zone-appropriate DECORATIVES (ci-6fq): cosmetic decals scattered across
-- the ribbon, keyed to the hot/cold gradient zone -- rocks + pebbles + craters on
-- the rocky/lava (hot) half, ice + light-snow decals on the icy (cold) half.
--
-- Each is a NEW `cindra-*` optimized-decorative CLONED (deep-copy) from a vanilla /
-- space-age decorative purely for its art, then given a Cindra autoplace keyed to the
-- perpendicular ribbon axis (scripts/decorative-field.lua). We enable ONLY these
-- clones in the Cindra map-gen (prototypes/planet.lua), so no Nauvis/Gleba decal ever
-- leaks onto the ribbon.
--
-- 🚨 We CLONE the vanilla decoratives; we NEVER mutate the shared vanilla prototype,
-- so no other planet's worldgen changes (the load-bearing invariant). We keep each
-- clone's vanilla autoplace table (its order / placement_density -> the native
-- density character the mayor asked us to mirror) and swap ONLY the
-- probability_expression for a zone-gated Cindra scatter, dropping the vanilla
-- tile_restriction (it names vanilla tiles that do not exist on Cindra -- the zone
-- MASK gates placement instead, keyed to the same axis as the terrain + damage).

local util = require("util")
local field = require("scripts.decorative-field")

-- The zone masks read the per-zone WIDTH layout (scripts/terrain.lua), which reads
-- its own startup settings, so `nil` means "the live layout" and there is no cfg to
-- build here. (ci-7k6: the table that used to be built from the ribbon
-- safe-half-width / lethal-at / wall-at sliders was keyed nothing downstream ever
-- looked at -- terrain's cfg is keyed by zone ROLE -- so moving those sliders moved
-- no decal. Same removal as prototypes/resources.lua.)
local CFG = nil

local decoratives = {}
for _, spec in ipairs(field.DECORATIVES) do
  local src = data.raw["optimized-decorative"][spec.clone_from]
  if not src then
    error("cindra decoratives: missing clone source decorative " .. tostring(spec.clone_from))
  end
  local d = util.table.deepcopy(src)
  d.name = spec.name
  -- Keep the cloned vanilla autoplace (its order / placement_density = the native
  -- scatter character), but re-scope it to the Cindra zone: swap the probability for
  -- our zone-gated scatter and drop the vanilla tile_restriction (Cindra tiles differ;
  -- the perpendicular-axis mask does the gating).
  d.autoplace = d.autoplace or {}
  d.autoplace.probability_expression = field.probability_expr(spec, CFG)
  d.autoplace.tile_restriction = nil
  decoratives[#decoratives + 1] = d
end

data:extend(decoratives)
