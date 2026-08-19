-- Zone-appropriate DECORATIVES for the ribbon (ci-6fq) -- cosmetic scatter layered
-- ON TOP of the terrain gradient, never fighting it.
--
-- The planet's two halves get the decorative set of the vanilla world they echo
-- (per the mayor's zone->source-planet mapping):
--
--   HOT half  (the volcanic slope + crust)  ->  do as VULCANUS does:
--       volcanic ROCKS + PEBBLES + CRATERS scattered across the solid volcanic ground,
--       stopping short of the molten lava (nothing lies on liquid rock).
--   COLD half (nightward frost + deep ice)  ->  do as AQUILO does:
--       ICE decals + LIGHT-SNOW decals + snow drifts scattered across the icy zone,
--       plus the small end of the LITHIUM-ICEBERG family (ci-w87), whose big/huge
--       members are the cold-side ROCKS in prototypes/resources.lua.
--
-- This is a PURE module (no game.* / prototypes.*): it maps a ribbon perpendicular
-- coordinate to a placement zone, and emits the Factorio NOISE-EXPRESSION strings
-- prototypes/decoratives.lua bolts onto each cloned decorative's autoplace. That
-- keeps the zone geometry deterministic + unit-testable off the game
-- (unit-tests/test_decorative_field.lua), exactly like scripts/resource-field.lua.
--
-- ONE axis, ONE divider (the ci-7w0 purity idea, reused). Every mask reads the SAME
-- perpendicular axis (scripts/axis.lua) as the terrain bands, the resource bands and
-- the runtime damage. Both sides are gated to the GROUND they belong on, read off the one
-- heightmap: the rock/crater decals to the volcanic slope + crust band (M.hot_band,
-- ci-mk5y) and the ice/snow decals to the icy ground (M.cold_start, ci-tizx). The whole
-- habitable band between them -- the brown ash + dust, including the terminator centre
-- (a clean landing spawn) -- carries no decal at all, so the two zones can never overlap:
-- a rock can never appear on the ice, snow can never appear in the lava region, and
-- neither can appear in the middle. The "no decals in the wrong zone" acceptance is pure
-- geometry, not a hope.
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

--
-- COLD-SIDE PULL-BACK + THINNING (ci-tizx). The first cut gated the ice/snow decals
-- at the ribbon's safe band (p < -safe_half_width = -24) and kept Aquilo's own
-- densities, which put a near-carpet of snow decals across ~100 tiles of BROWN
-- habitable ground (the ash + dust bands run out to the cold damage boundary at
-- p = -130; only past that does the terrain actually turn snow/ice -- see
-- terrain.VALUE_RAMP). The result obscured the tiles underneath. Now:
--   * the cold decals start where the GROUND turns icy (terrain.damage_bounds().cold_from,
--     the snow/ice belt edge), so no snow decal ever lands on the habitable browns;
--   * they FADE IN over COLD_FADE_SPAN tiles from that edge, so the boundary is a
--     gradient, not a stamped line, and the decals are thickest near the ice wall;
--   * each cold decal carries a `density` multiplier well below 1 (the big
--     snow-drift art the sparsest), so the ground dominates the decals.
-- ci-tizx left the hot side untouched (it was the cold-side read only); the section below
-- re-gates it.
--
-- HOT-SIDE RE-GATE ONTO THE HEIGHTMAP TILES (ci-mk5y). The hot gate was still the one
-- ci-6fq shipped against the OLD three-band world: `perp > safe_half_width` (+24), a line
-- with no relation to the ci-wly heightmap, and with NO outer bound at all. On the ci-oe83
-- field that strewed rocks, pebbles and craters across the hot half of the brown ash
-- MIDDLE (the clean landing band) and then straight on out over the molten LAVA, where
-- nothing can lie. The rock decals now ride the volcanic SLOPE + CRUST, i.e. the value
-- segment of the ONE field from the ash convergence (terrain.BRANCH_SPAN.lo, where the
-- cracks / folds families bottom out into volcanic-ash-dark) up to the molten floor
-- (terrain.MOLTEN_FLOOR, where the ground turns to liquid rock) -- so a rock sits on
-- volcanic ground and nowhere else. The cold side keeps its ci-tizx gate.
--
-- ICE-OCEAN THINNING (ci-10ze). ci-tizx pulled the frost off the BROWN band and faded it in
-- over 40 tiles, then left it at FULL strength everywhere nightward of that ramp -- which,
-- with the default widths, is an ~18-tile strip of rough-ice shore plus the ENTIRE ~212-tile
-- smooth-ice OCEAN. So the frozen sea, the single largest region on the cold half, carried
-- the densest clutter on the planet: chips, drifts and icebergs strewn thickly enough that
-- the playtest could not tell it WAS an ice ocean. A sea reads as a sea by being flat and
-- open, so the clutter now fades OUT again as it goes offshore: full strength at the
-- smooth-ice contour, down to M.OCEAN_DENSITY over M.OCEAN_FADE_SPAN tiles. The shore keeps
-- its frost (detail belongs at the boundary, and it is what makes the sheet read as smooth
-- by contrast), the open sheet keeps a bare trace of it, and because the drop is a ramp
-- there is no stamped line offshore either.
--
-- The thinning gates on the smooth-ice TILE contour (terrain.FROZEN_CEILING through
-- terrain.field_crossing), NOT on the cold-ocean zone band edge -- the same lesson the hot
-- side learned in ci-mk5y. With the default widths the sheet starts ~12 tiles WARMWARD of
-- that band edge, so a band-edge gate would leave a carpeted strip of ocean behind.
--
-- WHY VALUE CROSSINGS, NOT A ZONE BAND (the same trap the first gate fell into): a zone
-- band edge is NOT a tile boundary. With the default widths the molten contour sits ~35
-- tiles INSIDE the hot-ocean band, and the slope's ash boundary ~12 tiles outside the
-- middle band -- so we convert the value segment into two perpendicular gate lines with
-- terrain.field_crossing (the inverse of the field the tiles are painted from) instead of
-- reaching for a band edge. Unlike the burned-rock ENTITIES (scripts/resource-field.lua),
-- which the engine's own collision check keeps off the lava however loose their band is, a
-- DECAL goes wherever its probability is positive: the mask is the only thing standing
-- between a crater and the lava, so it has to be the tile boundary itself.
--
-- THE COLD COVERAGE BUDGET (ci-fwaq). ci-tizx set a hard ceiling on how much of the icy
-- ground the frost may bury, and guarded it with ONE number measured on ONE fixed seed out
-- on the frost shore. That guard is a rear-view mirror: it only reports a breach after a
-- four-minute engine run, and it cannot say WHICH decal spent the budget. The ci-w87
-- iceberg families duly joined the cold set with no re-balance and took the shore from
-- 0.059 to 0.090 decals/tile -- a 90% spend of a ceiling nobody re-read.
--
-- So the coverage is now PREDICTED from the catalogue itself, in closed form, off the game
-- (M.coverage_budget). Every cold decal's scatter is `min(1, 1 - A*r + coef*peaks + bias)`
-- for a per-tile uniform r, so the fraction of tiles it covers is a plain integral over r
-- (M.tile_probability) times its `density` multiplier -- and the catalogue's total is the
-- sum. Two guards then replace the single measured strip, and TOGETHER they imply it:
--
--   * unit-tests: budget * (1 + M.COVERAGE_MODEL_TOLERANCE) <= M.SHORE_COVERAGE_CEILING.
--     Pure arithmetic, no engine, no seed. A new cold family costs its coverage the moment
--     it is written down, so the density pass happens in the same commit as the row.
--   * tests/test_decoratives.lua: the coverage the engine actually generates on the shore
--     sits within M.COVERAGE_MODEL_TOLERANCE of the budget. That is what makes the model
--     admissible evidence rather than arithmetic about itself -- and it is measured on the
--     ground the player walks on.
--
-- budget * (1 + tol) <= ceiling AND measured <= budget * (1 + tol)  =>  measured <= ceiling,
-- for ANY seed rather than for the one the old strip happened to use. Raising the ceiling to
-- fit a new family is the regression the whole thing exists to catch, so the ceiling carries
-- its own upper-bound assertion.

local axis = require("scripts.axis")
local terrain = require("scripts.terrain")

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

-- The `random_penalty` amplitude every Cindra decal's scatter uses, as a NUMBER: the
-- coverage model (M.tile_probability) integrates over it, so it cannot be left as an
-- opaque substring of the emitted expression. `random_penalty{source = S, amplitude = A}`
-- is S - A*r for a per-tile uniform r in [0,1) (see core/prototypes/noise-functions.lua,
-- where random_penalty_between(from, to) spells it source = to, amplitude = to - from), so
-- source 1 with this amplitude is 1 - 10*r. The emitted string keeps the vanilla SPELLING
-- `1/0.1` (the Aquilo decals we mirror write it that way); a unit test pins the two
-- together so the model can never drift from the expression the map-gen actually reads.
M.PENALTY_AMPLITUDE = 1 / 0.1
local PENALTY_AMPLITUDE_DSL = "1/0.1"

-- A self-contained sparse scatter probability, mirroring the vanilla decal shape
-- `min(1, random_penalty{...} + coef * peaks + bias)`:
--   * random_penalty (source 1, amplitude 1/0.1 = 10) evaluates to 1 - 10*r for a
--     per-tile uniform r in [0,1): positive (a decal here) only on the small
--     fraction of tiles where r is tiny, so it is a SPARSE scatter. A less-negative
--     bias widens that fraction (denser); a more-negative bias narrows it (sparser).
--   * coef * cindra_decorative_peaks modulates that by the smooth peaks field
--     (patchy clumping), the sign chosen per decal as Aquilo's own decals do.
--   * bias sets the overall coverage. The rock / crater / pebble decals use markedly
--     negative biases so they read as OCCASIONAL scatter (rocks strewn about), not a
--     carpet; bigger decals (medium rock, large crater) are the sparsest. The ice /
--     snow decals keep AQUILO's own biases (0 / 0.3) -- that is the clumping
--     CHARACTER we mirror -- and are thinned by their `density` multiplier instead
--     (ci-tizx), which scales the resulting probability directly and so is the one
--     knob that maps linearly onto "how much of the ground is covered".
-- `seed` varies the random field per decal so they do not all land on the same tiles.
local function scatter(seed, coef, bias)
  return "min(1, random_penalty{x = x, y = y, seed = " .. num(seed) ..
         ", source = 1, amplitude = " .. PENALTY_AMPLITUDE_DSL .. "} + (" .. num(coef) ..
         ") * " .. PEAKS .. " + (" .. num(bias) .. "))"
end

-- One catalogue row. The scatter PARAMETERS live on the spec and the expression string is
-- built from them here (ci-fwaq), instead of the row carrying a pre-baked string: the
-- coverage budget needs those numbers, and a row that could carry a hand-written
-- expression instead would be invisible to the budget -- i.e. a new cold family could
-- spend the whole ci-tizx ceiling for free. Missing parameters are a hard error for the
-- same reason: an unmodellable decal must be impossible to write down, not merely score
-- zero and slip past the guard.
local function decal(spec)
  for _, key in ipairs({ "seed", "coef", "bias" }) do
    if type(spec[key]) ~= "number" then
      error("cindra decorative " .. tostring(spec.name) .. ": scatter parameter '" .. key ..
            "' must be a number -- the cold coverage budget reads it (ci-fwaq)")
    end
  end
  spec.scatter = scatter(spec.seed, spec.coef, spec.bias)
  return spec
end

-- The decorative catalogue: each a NEW `cindra-*` optimized-decorative cloned
-- (prototypes/decoratives.lua) from a vanilla decorative for its art, given a
-- zone-gated Cindra autoplace. `side` picks the zone mask; `seed` / `coef` / `bias` are the
-- base scatter parameters above (the row's `scatter` expression is built from them, and the
-- cold coverage budget reads them); `density` (default 1) is a straight multiplier on the
-- resulting probability -- the fraction of the mirrored vanilla density we keep.
--   name                          clone_from             side   seed coef bias  density
M.DECORATIVES = {
  -- HOT half -- Vulcanus rocks + pebbles + craters, confined to the solid volcanic slope +
  -- crust (ci-mk5y). Occasional scatter (negative biases), sparsest for the biggest decals.
  decal{ name = "cindra-volcanic-rock-tiny",   clone_from = "tiny-volcanic-rock",   side = "hot",  seed = 5, coef = 0.5, bias = -0.5 },
  decal{ name = "cindra-volcanic-rock-small",  clone_from = "small-volcanic-rock",  side = "hot",  seed = 4, coef = 0.5, bias = -0.6 },
  decal{ name = "cindra-volcanic-rock-medium", clone_from = "medium-volcanic-rock", side = "hot",  seed = 3, coef = 0.5, bias = -0.75 },
  decal{ name = "cindra-crater-small",         clone_from = "crater-small",         side = "hot",  seed = 6, coef = 0.5, bias = -0.7 },
  decal{ name = "cindra-crater-large",         clone_from = "crater-large",         side = "hot",  seed = 7, coef = 0.5, bias = -0.9 },
  -- COLD half -- Aquilo ice + light-snow decals, confined to the icy ground and
  -- thinned so the tiles read through (ci-tizx). The snow-drift art is huge (a
  -- ~6.6 x 4.6 tile decal), so at equal probability it alone carpets the ground:
  -- it gets the sparsest density of the three.
  --
  -- 🚨 Every row below spends the SHARED cold coverage budget (M.coverage_budget, ci-fwaq),
  -- which the unit tests hold under M.SHORE_COVERAGE_CEILING. Adding a family means
  -- re-balancing the `density` figures here so the total still fits -- NOT raising the
  -- ceiling, which is the regression the ceiling exists to catch.
  decal{ name = "cindra-ice-decal",            clone_from = "aqulio-ice-decal-blue", side = "cold", seed = 1, coef = 0.5,  bias = 0.0, density = 0.4 },
  decal{ name = "cindra-snowy-decal",          clone_from = "aqulio-snowy-decal",    side = "cold", seed = 1, coef = -0.5, bias = 0.3, density = 0.4 },
  decal{ name = "cindra-snow-drift-decal",     clone_from = "snow-drift-decal",      side = "cold", seed = 2, coef = -0.5, bias = 0.3, density = 0.15 },
  -- The small end of the ICEBERG family (ci-w87). The cold-side rocks are Aquilo's
  -- lithium-iceberg models now (prototypes/resources.lua), and that family's
  -- medium/small/tiny members are DECORATIVES rather than entities -- so they belong
  -- here, scattered among the frost decals, and the icy ground reads as one material
  -- from pebble to landmark instead of two unrelated art sets.
  --
  -- Their densities are deliberately a fraction of the frost decals'. The cold half
  -- already spends most of its ci-tizx coverage budget on ice/snow decals, and the
  -- point of that bead was that the GROUND must dominate; three more families at frost
  -- density would put the carpet straight back. These add a sparse chip-scatter on top.
  decal{ name = "cindra-lithium-iceberg-medium", clone_from = "lithium-iceberg-medium", side = "cold", seed = 8,  coef = 0.5, bias = 0.0, density = 0.10 },
  decal{ name = "cindra-lithium-iceberg-small",  clone_from = "lithium-iceberg-small",  side = "cold", seed = 9,  coef = 0.5, bias = 0.0, density = 0.14 },
  decal{ name = "cindra-lithium-iceberg-tiny",   clone_from = "lithium-iceberg-tiny",   side = "cold", seed = 10, coef = 0.5, bias = 0.0, density = 0.18 },
}

-- The MARGIN, in field-VALUE units, each hot gate line is pulled INSIDE the tile contour it
-- must not cross (ci-mk5y). A tile's visible contour breathes around its nominal position,
-- and a decal does not land exactly where its probability was sampled, so the budget is:
--   * the boundary WIGGLE: the field is sampled on a wiggled perpendicular coordinate
--     (terrain.NOISE_AMPLITUDE = 2 tiles), worth <= 0.007 H at the steepest part of the crust;
--   * the per-tile SPECKLE in the value itself: terrain.SPECKLE_H = 0.012 H;
--   * a tile of placement granularity (the engine stores a decal within the tile it sampled),
--     worth <= 0.004 H.
-- That is ~0.023 H worst case; THREE times the speckle amplitude (0.036) clears it with room
-- to spare, so no wiggle, speckle or placement offset can put a rock on the lava or off the
-- slope onto the ash middle. The band is still ~64 tiles wide and still reaches well past the
-- heat-damage boundary onto the glowing crust.
--
-- The margin is in VALUE, not tiles, deliberately: the field's slope differs by a factor of
-- ~2 between the shallow safe slope and the steeper crust, so a fixed tile margin would be
-- generous at one contour and too thin at the other. Derived from the terrain constant, so
-- it tracks a noise retune.
M.HOT_MARGIN_H = 3 * terrain.SPECKLE_H

-- The value segment the rock / crater decals ride: the volcanic slope + crust, from the ash
-- convergence up to (but never reaching) the molten floor.
function M.hot_value_span()
  return { lo = terrain.BRANCH_SPAN.lo, hi = terrain.MOLTEN_FLOOR }
end

-- Where the hot (rock / crater) decals live, in perpendicular tiles: the two field
-- crossings of the value segment above, each pulled M.HOT_MARGIN_H inside its contour.
-- `lo` is the middle-ward (ash) line, `hi` the sunward (lava) line.
function M.hot_band(cfg)
  local span = M.hot_value_span()
  return {
    lo = terrain.field_crossing(span.lo + M.HOT_MARGIN_H, cfg),
    hi = terrain.field_crossing(span.hi - M.HOT_MARGIN_H, cfg),
  }
end

-- The GROUND a rock / crater decal may sit on: every tile whose value band overlaps the hot
-- value segment (both hot-slope texture families included). Excludes the two lava tiles,
-- the ash middle and the whole cold side by construction -- tests read this to prove each
-- generated decal really did land on volcanic slope / crust ground.
function M.hot_ground_tiles()
  local span = M.hot_value_span()
  return terrain.value_range_tiles(span.lo, span.hi)
end

-- How far nightward of the icy-ground edge the cold decals reach FULL density: they
-- fade in linearly across this span, so the frost thickens toward the ice wall
-- instead of starting at a hard line (ci-tizx).
M.COLD_FADE_SPAN = 40

-- Where the cold (ice/snow) decals START, in perpendicular tiles: the inner edge of
-- the cold belt, i.e. exactly where the terrain's own value ramp turns from the brown
-- dust of the habitable band to snow/ice (scripts/terrain.lua owns that boundary; we
-- read it rather than re-deriving it). Everything warmward of this is habitable
-- BROWN ground and must stay decal-free on the cold side (ci-tizx).
function M.cold_start(cfg)
  return terrain.damage_bounds(cfg).cold_from
end

-- How much of the cold decals' full density survives out on the OPEN smooth-ice sheet, and
-- how many tiles offshore the thinning takes to get there (ci-10ze). A trace rather than
-- zero: a perfectly bare sheet reads as a hole in the world rather than as ice, and the few
-- chips left are what give the sea its scale. The span makes the shore-to-sea drop a ramp,
-- so no stamped line appears offshore -- the mirror image of M.COLD_FADE_SPAN inshore.
M.OCEAN_DENSITY = 0.12
M.OCEAN_FADE_SPAN = 24

-- Where the smooth-ice OCEAN SHEET begins, in perpendicular tiles: the contour of the field
-- value at which the ramp starts painting the ocean core. scripts/terrain.lua owns that
-- boundary (terrain.FROZEN_CEILING); we read it rather than re-deriving it, and we read the
-- TILE contour rather than the cold-ocean band edge (the sheet begins well warmward of it).
function M.ice_ocean_start(cfg)
  return terrain.field_crossing(terrain.FROZEN_CEILING, cfg)
end

-- Numeric zone predicates (unit-testable off the game). `y` is the signed
-- perpendicular coordinate (sunward-positive). The hot (rock/crater) zone is the volcanic
-- slope + crust band (M.hot_band, bounded on BOTH sides: no rocks on the ash middle,
-- none on the lava); the cold (icy) zone starts only where the ground itself turns icy
-- (M.cold_start), far nightward of the safe band -- so the two never overlap and the whole
-- habitable band is free of decals.
function M.hot_zone(y, cfg)
  local b = M.hot_band(cfg)
  return y > b.lo and y < b.hi
end

function M.cold_zone(y, cfg)
  return y < M.cold_start(cfg)
end

-- The cold fade-in fraction (0 at the icy-ground edge, 1 once COLD_FADE_SPAN tiles
-- nightward of it). The numeric mirror of M.cold_fade_expr below: a decal's placement
-- probability is scaled by this, so frost is sparse at the boundary and full-strength
-- out by the ice wall.
function M.cold_fade(y, cfg)
  local start = M.cold_start(cfg)
  local f = (start - y) / M.COLD_FADE_SPAN
  if f < 0 then return 0 end
  if f > 1 then return 1 end
  return f
end

-- The ocean THINNING multiplier at perpendicular position `y` (ci-10ze): 1 everywhere
-- warmward of the smooth-ice sheet (the snow / rough-ice shore keeps its full frost),
-- ramping down to M.OCEAN_DENSITY across the first M.OCEAN_FADE_SPAN tiles offshore and
-- staying there out to the map edge. The numeric mirror of M.ocean_thin_expr below.
function M.ocean_thin(y, cfg)
  local start = M.ice_ocean_start(cfg)
  local f = (start - y) / M.OCEAN_FADE_SPAN
  if f < 0 then f = 0 elseif f > 1 then f = 1 end
  return 1 - (1 - M.OCEAN_DENSITY) * f
end

-- The whole COLD-SIDE coverage story as one positional number: the inshore fade-in times
-- the offshore thinning. 0 on the brown habitable band, rising to 1 across the frost shore,
-- falling back to M.OCEAN_DENSITY on the open sea. Every cold decal's scatter is multiplied
-- by exactly this (plus its own `density`), so it is the direct answer to "how much of the
-- ground is covered here" -- which is the question both legibility beads were about.
function M.cold_density(y, cfg)
  return M.cold_fade(y, cfg) * M.ocean_thin(y, cfg)
end

-- THE COLD COVERAGE BUDGET (ci-fwaq) -------------------------------------------------
-- The positional half of the coverage story is above (M.cold_density: WHERE the frost is
-- thick). This is the CATALOGUE half: how much ground the cold set covers where that
-- positional factor is 1, i.e. on the full-strength frost shore -- the thickest cold ground
-- there is, and so the place the ci-tizx ceiling has to be read.

-- The ceiling from ci-tizx: the largest fraction of shore tiles the cold decals may carry
-- before the ground stops dominating them. Calibrated in-engine against the frost shore
-- (0.182 decals/tile with the pre-ci-tizx densities read as a carpet; 0.059 after ci-tizx
-- thinned the three original families; 0.090 once the ci-w87 iceberg families joined).
--
-- 🚨 RAISING THIS NUMBER IS THE REGRESSION IT EXISTS TO CATCH. A new cold family is paid
-- for out of the existing `density` figures, never out of the ceiling -- unit-tests assert
-- an upper bound on the constant itself so a raise cannot pass as a re-balance.
M.SHORE_COVERAGE_CEILING = 0.1

-- The value M.tile_probability evaluates the peaks modulation at. `cindra_decorative_peaks`
-- is an abs() of noise, so it is non-negative and the coefficient's SIGN decides whether
-- reality sits above the nominal (the ice / iceberg decals, coef > 0) or below it (the snowy
-- / drift decals, coef < 0). We nominate its floor rather than guess a mean: the modulation
-- is worth at most ~0.014 coverage across the whole cold catalogue -- an order of magnitude
-- less than the biases and densities -- and whatever residual it leaves is not hand-waved
-- but MEASURED, by the model-vs-engine cross-check in tests/test_decoratives.lua that holds
-- the two within M.COVERAGE_MODEL_TOLERANCE of each other.
M.PEAKS_NOMINAL = 0

-- How far the model and the coverage the engine actually generates may sit apart, as a
-- fraction. It buys two things at once, which is why it is one constant and not two: it is
-- the slack the in-engine cross-check allows, AND the margin the budget is held below the
-- ceiling by -- so `budget * (1 + tol) <= ceiling` plus `measured <= budget * (1 + tol)`
-- proves `measured <= ceiling` outright, on any seed. Sized well clear of the ~6% the
-- current catalogue actually shows.
M.COVERAGE_MODEL_TOLERANCE = 0.15

-- The fraction of tiles ONE decal covers where its zone mask and positional multipliers are
-- 1, before its own `density` -- i.e. the mean of its scatter expression clamped to [0,1].
--
-- The scatter is `min(1, 1 - A*r + coef*peaks + bias)` for a per-tile uniform r in [0,1)
-- and A = M.PENALTY_AMPLITUDE, and a probability outside [0,1] is clamped by the engine, so
-- with `u = 1 + bias + coef*peaks` the coverage is the plain integral
--   (1/A) * integral over t in [0,A] of clamp(u - t, 0, 1) dt,
-- which is closed form: u^2/(2A) while the ramp is still inside the interval (u <= 1),
-- (u - 1/2)/A once it has cleared it, and 1 once even u - A saturates. That is why the
-- budget needs no sampling and no seed: coverage is arithmetic on the catalogue.
function M.tile_probability(bias, coef)
  local a = M.PENALTY_AMPLITUDE
  local u = 1 + (bias or 0) + (coef or 0) * M.PEAKS_NOMINAL
  if u <= 0 then return 0 end              -- never positive: nothing places
  if u <= 1 then return u * u / (2 * a) end -- the ramp's whole triangle fits inside
  if u >= a + 1 then return 1 end          -- saturated everywhere: a solid carpet
  if u <= a then return (u - 0.5) / a end  -- a saturated stretch plus the ramp
  return ((u - 1) + (1 - (u - a) ^ 2) / 2) / a -- ...with the ramp truncated at t = A
end

-- The fraction of ground one catalogue row covers at full positional strength: its scatter's
-- own coverage times the `density` multiplier ci-tizx thins it by. Multiplying the
-- PROBABILITY is what makes density linear in covered ground, so halving a density halves
-- the row's share of the budget -- the knob a re-balance turns.
function M.expected_coverage(spec)
  return M.tile_probability(spec.bias, spec.coef) * (spec.density or 1)
end

-- What one side of the catalogue costs in covered ground, summed live from M.DECORATIVES so
-- a family cannot join without appearing here. For "cold" this is the shore coverage the
-- ci-tizx ceiling governs.
function M.coverage_budget(side)
  local total = 0
  for _, spec in ipairs(M.DECORATIVES) do
    if spec.side == side then total = total + M.expected_coverage(spec) end
  end
  return total
end

-- The most the modelled budget may be, so that the coverage the engine generates still
-- clears the ceiling even at the far end of the model's proven error bar.
function M.coverage_allowance()
  return M.SHORE_COVERAGE_CEILING / (1 + M.COVERAGE_MODEL_TOLERANCE)
end

-- The zone mask as a noise-expression string (1 inside the zone, 0 outside): a
-- comparison in the DSL yields 1/0, so multiplying a decal's scatter by it zeroes
-- placement outside the zone. Encodes M.hot_zone / M.cold_zone on the perpendicular
-- axis, so the emitted decals land exactly where the pure geometry says they should.
-- The hot mask is TWO-SIDED (ci-mk5y): the volcanic slope + crust band, so a rock can
-- neither drift middle-ward onto the ash nor sunward onto the lava. A comparison yields
-- 1/0, so the product is a logical AND (the same shape resource-field.lua bands with).
function M.hot_mask_expr(cfg)
  local b = M.hot_band(cfg)
  return "(" .. M.PERP .. " > " .. num(b.lo) .. ")" ..
         " * (" .. M.PERP .. " < " .. num(b.hi) .. ")"
end

-- The cold mask starts at the icy-ground edge (M.cold_start), NOT at the safe band:
-- the habitable browns run all the way out to the cold belt, and snow decals scattered
-- over them are what buried the tiles (ci-tizx).
function M.cold_mask_expr(cfg)
  return "(" .. M.PERP .. " < " .. num(M.cold_start(cfg)) .. ")"
end

-- The cold fade-in as a noise-expression string: 0 at the icy-ground edge, ramping to
-- 1 COLD_FADE_SPAN tiles nightward. Encodes M.cold_fade; multiplying a decal's
-- probability by it thins the frost at the boundary and leaves it full near the wall.
function M.cold_fade_expr(cfg)
  return "clamp((" .. num(M.cold_start(cfg)) .. " - " .. M.PERP .. ") / " ..
         num(M.COLD_FADE_SPAN) .. ", 0, 1)"
end

-- The ocean thinning as a noise-expression string: 1 up to the smooth-ice contour, falling
-- to M.OCEAN_DENSITY over M.OCEAN_FADE_SPAN tiles offshore. Encodes M.ocean_thin; a cold
-- decal's probability is multiplied by it, so the open sea keeps only that fraction of the
-- shore's coverage (ci-10ze).
function M.ocean_thin_expr(cfg)
  return "(1 - " .. num(1 - M.OCEAN_DENSITY) .. " * clamp((" .. num(M.ice_ocean_start(cfg)) ..
         " - " .. M.PERP .. ") / " .. num(M.OCEAN_FADE_SPAN) .. ", 0, 1))"
end

-- The full `probability_expression` string for one decorative: its base scatter
-- ANDed (multiplied) with its side's zone mask, then scaled by its `density`
-- multiplier and (cold side) the fade-in ramp plus the offshore ocean thinning. Outside the
-- zone the mask is 0, so the decal never generates there; inside, the scaled sparse scatter
-- decides per tile. The scale factors multiply the PROBABILITY, so halving `density` halves
-- the covered fraction of ground -- the direct, predictable knob for "how much ground shows".
function M.probability_expr(spec, cfg)
  local mask = (spec.side == "hot") and M.hot_mask_expr(cfg) or M.cold_mask_expr(cfg)
  local expr = "(" .. spec.scatter .. ") * (" .. mask .. ")"
  if spec.density and spec.density ~= 1 then
    expr = expr .. " * " .. num(spec.density)
  end
  if spec.side == "cold" then
    expr = expr .. " * (" .. M.cold_fade_expr(cfg) .. ")"
    expr = expr .. " * " .. M.ocean_thin_expr(cfg)
  end
  return expr
end

-- All Cindra decorative names (for the planet map-gen decorative allow-list).
function M.decorative_names()
  local out = {}
  for _, d in ipairs(M.DECORATIVES) do out[#out + 1] = d.name end
  return out
end

return M
