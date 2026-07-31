-- THAW REGION SHAPE (ci-b5i, primary experiment Q4 foundation). The thaw region
-- around a hot emitter is a SQUARE (Chebyshev distance), NOT a Euclidean disc: a
-- machine is thawed iff BOTH |dx| and |dy| are within the effective radius. The
-- corner (100,100) from an r100 emitter thaws; (101, y) or (x, 101) freezes.
--
-- This is the load-bearing geometry for the whole inversion: because reach is a
-- bounding box, a straight LINE of emitters produces a STRAIGHT freeze front with
-- NO scalloping as long as the spacing keeps the boxes touching in Y (see
-- test_band_split). That is far better than the circular-reach model the bead
-- assumed (which would scallop).

local H = require("tests.helpers")
local C = require("scripts.config")

describe("thaw region is a Chebyshev square", function()
  it("thawed iff |dx|<=~100 AND |dy|<=~100 (square, not disc)", function()
    local base, s = H.fresh_region(240, 140)
    local cx = base + 120
    H.emitter(s, 100, { cx, 0 })

    -- Corner of the square: within the box on both axes -> MUST thaw. A disc would
    -- freeze this (Euclidean 127 > 100); a square thaws it (Chebyshev 90).
    local corner = H.probe(s, { cx + 90, 90 }, C.PROBE_INSERTER)
    -- Just past the box on one axis only -> MUST freeze.
    local past_x = H.probe(s, { cx + 110, 0 }, C.PROBE_INSERTER)
    local past_y = H.probe(s, { cx + 0, 110 }, C.PROBE_INSERTER)
    -- Deep diagonal past the box on both axes -> frozen.
    local past_corner = H.probe(s, { cx + 110, 110 }, C.PROBE_INSERTER)
    -- Well inside on both axes -> thawed.
    local inside = H.probe(s, { cx + 70, 70 }, C.PROBE_INSERTER)

    async(4000)
    after_ticks(2500, function()
      assert.is_false(inside.frozen, "inside the box (70,70) must thaw")
      assert.is_false(corner.frozen,
        "square corner (90,90) must THAW (Euclid 127 -> would freeze if it were a disc)")
      assert.is_true(past_x.frozen, "past the box in x (110,0) must freeze")
      assert.is_true(past_y.frozen, "past the box in y (0,110) must freeze")
      assert.is_true(past_corner.frozen, "past the box on both axes (110,110) must freeze")
      done()
    end)
  end)
end)
