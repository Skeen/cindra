-- COVERAGE EFFICIENCY + RADIAL SYMMETRY (ci-b5i, primary experiment Q5 proxy).
--
-- True UPS cannot be measured in a headless factorio-test (the Lua sandbox has no
-- wall clock), so the make-or-break perf question -- "does the O(R^2) heat scan of
-- a tens-of-tiles radius cost too much?" -- is flagged for manual profiling in
-- PLAYTEST.md. What IS deterministically testable here is the ENTITY-COUNT lever
-- that dominates heat-system cost: how few high-radius emitters replace a dense
-- low-radius grid.
--
--   * The thaw region is a SQUARE (Chebyshev) box of half-width ~100 (test_shape):
--     one r100 emitter keeps machines thawed in a 201x201 footprint (~40k tiles).
--   * A sparse fire-edge line at spacing <= ~2*reach covers a long warm band with
--     a HANDFUL of emitters, versus the thousands a radius-1 grid (vanilla heat-
--     pipe density) would need for the same band. That entity-count collapse is
--     the perf case (the heat system's cost scales with heat-entity count).

local H = require("tests.helpers")
local C = require("scripts.config")

describe("coverage efficiency of a high-radius emitter", function()
  it("thaws a square box footprint (both axes), bounded past ~100", function()
    local base, s = H.fresh_region(240, 140)
    local cx = base + 120
    H.emitter(s, 100, { cx, 0 })

    -- Inside the box on both axes (Chebyshev <= 90) -> thawed, in all 8 directions.
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }
    local inside = {}
    for i, d in ipairs(dirs) do inside[i] = H.probe(s, { cx + d[1] * 80, d[2] * 80 }, C.PROBE_INSERTER) end
    -- Past the box on an axis -> frozen (the bound).
    local out_px = H.probe(s, { cx + 120, 0 }, C.PROBE_INSERTER)
    local out_ny = H.probe(s, { cx, -120 }, C.PROBE_INSERTER)

    async(4000)
    after_ticks(2500, function()
      for i = 1, #dirs do
        assert.is_false(inside[i].frozen, "box: machine at Chebyshev 80 dir " .. i .. " must thaw")
      end
      assert.is_true(out_px.frozen, "past the box (+120 x) must stay frozen")
      assert.is_true(out_ny.frozen, "past the box (-120 y) must stay frozen")
      done()
    end)
  end)

  it("a sparse line covers a long band with orders of magnitude fewer emitters", function()
    -- A 400-tile fire edge, warm band ~100 deep. Square reach -> spacing up to
    -- ~2*reach (use 180 for margin) still gives a straight, gap-free front.
    local band_length = 400
    local spacing = 180
    local sparse_count = math.ceil(band_length / spacing) + 1

    -- Vanilla heat reach is radius 1 (dense heat pipes). Each radius-1 source is a
    -- 3x3 (Chebyshev 1) box = 9 tiles; blanketing the 400x200 band needs one per 9.
    local band_area = band_length * 200
    local dense_count = math.floor(band_area / 9)

    assert.is_true(sparse_count <= 6,
      "sparse r100 line needs <=6 emitters for a 400t edge, got " .. sparse_count)
    assert.is_true(dense_count / sparse_count > 1000,
      "high radius must cut emitter count by >1000x vs a radius-1 grid (got ratio "
      .. math.floor(dense_count / sparse_count) .. ")")
  end)
end)
