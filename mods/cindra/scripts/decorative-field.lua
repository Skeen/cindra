-- Zone-appropriate DECORATIVES for the ribbon (ci-6fq) -- cosmetic scatter layered
-- ON TOP of the terrain gradient, never fighting it.
--
-- The planet's two halves get the decorative set of the vanilla world they echo
-- (per the mayor's zone->source-planet mapping):
--
--   HOT half  (sunward margin + lava edge)  ->  do as VULCANUS does:
--       volcanic ROCKS + PEBBLES + CRATERS scattered across the rocky/lava zone.
--   COLD half (nightward frost + deep ice)  ->  do as AQUILO does:
--       ICE decals + LIGHT-SNOW decals + snow drifts scattered across the icy zone.
--
-- This is a PURE module (no game.* / prototypes.*): it maps a ribbon perpendicular
-- coordinate to a placement zone, and emits the Factorio NOISE-EXPRESSION strings
-- prototypes/decoratives.lua bolts onto each cloned decorative's autoplace. That
-- keeps the zone geometry deterministic + unit-testable off the game
-- (unit-tests/test_decorative_field.lua), exactly like scripts/resource-field.lua.
--
-- ONE axis, ONE divider (the ci-7w0 purity idea, reused). Every mask reads the SAME
-- perpendicular axis (scripts/axis.lua) as the terrain bands, the resource bands and
-- the runtime damage. The hot decoratives are gated to perp > +safe_half_width and
-- the cold decoratives to perp < -safe_half_width; the two zones share the safe band
-- as a neutral divider and NEVER overlap, so a rock can never appear on the ice and
-- snow can never appear in the lava region -- the "no decals in the wrong zone"
-- acceptance is pure geometry, not a hope. The temperate terminator centre stays
-- decal-free (a clean landing spawn).
--
-- WHY WE MIRROR, NOT LITERALLY REUSE, THE NATIVE AUTOPLACE (per the mayor's
-- "copy the vanilla decorative autoplace and re-gate it to the zone"): a decorative's
-- autoplace lives on the SHARED vanilla prototype, so we CLONE each one (like
-- prototypes/tiles.lua clones the tiles) rather than mutate it -- the load-bearing
-- "never change another planet's worldgen" invariant. Aquilo's ice/snow autoplace is
-- self-contained (random_penalty + a generic high-frequency peaks field), so we
-- mirror its FORMULA SHAPE faithfully. Vulcanus's rock/crater autoplace, by
-- contrast, is coupled to Vulcanus-only inputs (aux / moisture / vulcanus_*_biome /
-- vulcanus_rock_noise) that do not exist on Cindra and evaluate strongly NEGATIVE
-- here (nothing would place), so we mirror its scatter CHARACTER with the same
-- self-contained primitives. Both sides share ONE Cindra-owned peaks field
-- (cindra_decorative_peaks, prototypes/noise.lua) so we never depend on another
-- planet's named noise.

local ribbon = require("scripts.ribbon")
local axis = require("scripts.axis")

local M = {}

-- The sunward-positive perpendicular axis expression (hot side). scripts/axis.lua
-- owns which world axis is perpendicular; we never re-derive it. Default vertical
-- orientation: "(0 - x)" (hot on the left / west).
M.PERP = axis.perp_expr()

-- The Cindra-owned generic high-frequency peaks noise (prototypes/noise.lua), the
-- density modulation both sides ride -- the "as Aquilo does" scatter field, but
-- Cindra-named so we never couple to an Aquilo-internal prototype.
local PEAKS = "cindra_decorative_peaks"

-- Format a number for the noise DSL (integers stay clean, no float noise).
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.6g", v)
end

-- A self-contained sparse scatter probability, mirroring the vanilla decal shape
-- `min(1, random_penalty{...} + coef * peaks + bias)`:
--   * random_penalty (source 1, amplitude 1/0.1 = 10) evaluates to 1 - 10*r for a
--     per-tile uniform r in [0,1): positive (a decal here) only on the small
--     fraction of tiles where r is tiny, so it is a SPARSE scatter. A less-negative
--     bias widens that fraction (denser); a more-negative bias narrows it (sparser).
--   * coef * cindra_decorative_peaks modulates that by the smooth peaks field
--     (patchy clumping), the sign chosen per decal as Aquilo's own decals do.
--   * bias sets the overall coverage. The ice/snow decals keep Aquilo's own values
--     (bias 0 / 0.3 -> a dense frosted ground, the intended icy look). The rock /
--     crater / pebble decals use markedly more-negative biases so they read as
--     OCCASIONAL scatter (rocks strewn about), not a carpet; bigger decals
--     (medium rock, large crater) are the sparsest.
-- `seed` varies the random field per decal so they do not all land on the same tiles.
local function scatter(seed, coef, bias)
  return "min(1, random_penalty{x = x, y = y, seed = " .. num(seed) ..
         ", source = 1, amplitude = 1/0.1} + (" .. num(coef) .. ") * " .. PEAKS ..
         " + (" .. num(bias) .. "))"
end

-- The decorative catalogue: each a NEW `cindra-*` optimized-decorative cloned
-- (prototypes/decoratives.lua) from a vanilla decorative for its art, given a
-- zone-gated Cindra autoplace. `side` picks the zone mask; `scatter` is the base
-- density expression above.
--   name                          clone_from             side    scatter
M.DECORATIVES = {
  -- HOT half -- Vulcanus rocks + pebbles + craters (the rocky/lava zone). Occasional
  -- scatter (negative biases), sparsest for the biggest decals.
  { name = "cindra-volcanic-rock-tiny",   clone_from = "tiny-volcanic-rock",   side = "hot",  scatter = scatter(5, 0.5, -0.5) },
  { name = "cindra-volcanic-rock-small",  clone_from = "small-volcanic-rock",  side = "hot",  scatter = scatter(4, 0.5, -0.6) },
  { name = "cindra-volcanic-rock-medium", clone_from = "medium-volcanic-rock", side = "hot",  scatter = scatter(3, 0.5, -0.75) },
  { name = "cindra-crater-small",         clone_from = "crater-small",         side = "hot",  scatter = scatter(6, 0.5, -0.7) },
  { name = "cindra-crater-large",         clone_from = "crater-large",         side = "hot",  scatter = scatter(7, 0.5, -0.9) },
  -- COLD half -- Aquilo ice + light-snow decals (the icy zone).
  { name = "cindra-ice-decal",            clone_from = "aqulio-ice-decal-blue", side = "cold", scatter = scatter(1, 0.5, 0.0) },
  { name = "cindra-snowy-decal",          clone_from = "aqulio-snowy-decal",    side = "cold", scatter = scatter(1, -0.5, 0.3) },
  { name = "cindra-snow-drift-decal",     clone_from = "snow-drift-decal",      side = "cold", scatter = scatter(2, -0.5, 0.3) },
}

-- Numeric zone predicates (unit-testable off the game). `y` is the signed
-- perpendicular coordinate (sunward-positive). The hot (rocky/lava) zone is beyond
-- the safe band sunward; the cold (icy) zone is beyond it nightward. They share the
-- |y| <= safe_half_width divider and never overlap.
function M.hot_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return y > cfg.safe_half_width
end

function M.cold_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return y < -cfg.safe_half_width
end

-- The zone mask as a noise-expression string (1 inside the zone, 0 outside): a
-- comparison in the DSL yields 1/0, so multiplying a decal's scatter by it zeroes
-- placement outside the zone. Encodes M.hot_zone / M.cold_zone on the perpendicular
-- axis, so the emitted decals land exactly where the pure geometry says they should.
function M.hot_mask_expr(cfg)
  cfg = ribbon.resolve(cfg)
  return "(" .. M.PERP .. " > " .. num(cfg.safe_half_width) .. ")"
end

function M.cold_mask_expr(cfg)
  cfg = ribbon.resolve(cfg)
  return "(" .. M.PERP .. " < " .. num(-cfg.safe_half_width) .. ")"
end

-- The full `probability_expression` string for one decorative: its base scatter
-- ANDed (multiplied) with its side's zone mask. Outside the zone the mask is 0, so
-- the decal never generates there; inside, the sparse scatter decides per tile.
function M.probability_expr(spec, cfg)
  local mask = (spec.side == "hot") and M.hot_mask_expr(cfg) or M.cold_mask_expr(cfg)
  return "(" .. spec.scatter .. ") * (" .. mask .. ")"
end

-- All Cindra decorative names (for the planet map-gen decorative allow-list).
function M.decorative_names()
  local out = {}
  for _, d in ipairs(M.DECORATIVES) do out[#out + 1] = d.name end
  return out
end

return M
