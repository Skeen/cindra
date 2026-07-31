-- Native-freeze engine constants + emitter-line geometry (§ freeze, ci-bvk).
--
-- The SINGLE SOURCE OF TRUTH for the numbers behind Cindra's native freeze: the
-- engine's heat-emitter reach, the tight emitter spacing, and the deterministic
-- lattice the emitter line snaps to. Every part of the native-freeze mechanic
-- (the planet flag, the worldgen emitter placement, the ice-line alignment) reads
-- these; nothing re-derives the clamp. Kept DELIBERATELY PURE (no game.* /
-- prototypes.* access) so the geometry is fast, deterministic, and unit-testable
-- off the game (unit-tests/test_freeze.lua), exactly like scripts/ribbon.lua.
--
-- === EXACT CONSTANTS, MEASURED (ci-bvk step 1) ===
-- The ci-b5i spike (mods/freeze-radius-poc/) proved the inversion works and left
-- the clamp APPROXIMATE ("~100-101"). These values were then MEASURED to the tile,
-- headless in factorio-test, against a real heat-interface emitter on an
-- `entities_require_heating` surface (the tests/test_freeze.lua guard re-asserts
-- them against the actual Cindra emitter prototype):
--
--   * REACH is a Chebyshev SQUARE, INCLUSIVE, of exactly 100 tiles. A freezable
--     entity is THAWED iff |dx| <= 100 AND |dy| <= 100 from the emitter, and
--     FROZEN at 101. Measured seam (heating_radius = 100): last-thawed tile 100,
--     first-frozen tile 101, identical on +x, +y and the (100,100) diagonal
--     corner -- a square, not a disc.
--   * REACH is measured from the emitter's BOUNDING-BOX EDGE, not its centre: a
--     5x5 reactor at heating_radius 100 thawed out to 102 from its centre tile
--     (= 100 from its +2 edge). Our emitter is 1x1, so edge == centre +/- 0.5 and
--     an integer-tile distance of 100 is the last thawed tile either way.
--   * HARD ENGINE CLAMP at ~100: heating_radius above ~100 buys no usable reach
--     (r128 / r150 / r200 / r300 all land at the same 100-101). 100 is therefore
--     the MAX EFFECTIVE radius; setting the prototype higher only enlarges the
--     engine's O(R^2) per-emitter heating scan for nothing.
--   * SEAM measured exact: two heating_radius-100 emitters leave ZERO frozen tiles
--     between them at spacing 201 (= 2R+1) and open a one-tile frozen gap at 202
--     (= 2R+2). The 2R+1 spacing is a tight bound (contiguous, gap-free AND
--     overlap-free), not a padded one.

local M = {}

-- The exact inclusive Chebyshev reach (tiles) of a heating_radius-100 emitter.
M.FREEZE_REACH = 100

-- The emitter prototype's heating_radius. Pinned at the effective clamp: higher
-- is inert reach but a bigger engine scan (see the clamp note above).
M.EMITTER_HEATING_RADIUS = 100

-- Contiguous, gap-free AND overlap-free spacing along the emitter line. With an
-- INCLUSIVE reach R, emitter A covers [-R, R] and emitter B at 2R+1 covers
-- [R+1, 3R+1]: they ABUT exactly, no gap, no overlap (measured: no frozen tile at
-- 2R+1, a frozen gap at 2R+2). Derived from the pinned reach -- never hardcoded.
M.EMITTER_SPACING = 2 * M.FREEZE_REACH + 1 -- = 201

-- Chebyshev INCLUSIVE coverage predicate: is a point (dx, dy) tiles from an
-- emitter's centre thawed by that emitter? The load-bearing shape: because it is
-- a square (both axes independently bounded), a straight LINE of emitters yields
-- a STRAIGHT freeze front (no scallop) as long as the spacing keeps the boxes
-- abutting along the line. Pure.
function M.covers(dx, dy)
  return math.abs(dx) <= M.FREEZE_REACH and math.abs(dy) <= M.FREEZE_REACH
end

-- Deterministic emitter long-axis coordinates covering [lo, hi] with no gap,
-- SNAPPED to a fixed global lattice (integer multiples of EMITTER_SPACING). The
-- fixed lattice is what makes placement idempotent and seam-aligned no matter
-- which chunk (or in which order) the map-gen produces first: an emitter's world
-- coordinate is always exactly k * EMITTER_SPACING, so re-generating a chunk asks
-- for the SAME positions and a placement pass can dedupe by position. Returns the
-- ascending list of long-axis coordinates whose +/-R boxes together cover all of
-- [lo, hi]. Pure.
function M.line_coords(lo, hi)
  local S = M.EMITTER_SPACING
  local R = M.FREEZE_REACH
  -- Lattice index k places an emitter at k*S covering [k*S - R, k*S + R]. Its box
  -- overlaps [lo, hi] iff k*S + R >= lo and k*S - R <= hi.
  local first = math.ceil((lo - R) / S)
  local last = math.floor((hi + R) / S)
  local out = {}
  for k = first, last do
    out[#out + 1] = k * S
  end
  return out
end

return M
