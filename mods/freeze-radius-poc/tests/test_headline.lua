-- HEADLINE PROOF (ci-b5i). The make-or-break claim, exactly as the bead frames
-- it: on a surface with entities_require_heating=true, a SINGLE heat-interface
-- with heating_radius=100 keeps a freezable machine 100 TILES away thawed, while
-- an identical machine 100 tiles from ANY emitter freezes for real.
--
--   ASSERT A.frozen == false  (the r100 emitter reaches 100 tiles)
--   ASSERT B.frozen == true   (freezing genuinely happens at that distance)
--
-- Plus the two facts that make the inversion mechanic viable for Cindra:
--   * it works for assembler AND inserter AND pipe (native PIPE/FLUID freezing,
--     which the scripted cold-damage model could never produce), and
--   * it THAWS an already-frozen machine when the emitter arrives later (no
--     one-way hysteresis), so carrying warmth into the cold actually reclaims it.

local H = require("tests.helpers")
local C = require("scripts.config")

describe("headline: r100 thaws a machine 100 tiles away", function()
  it("A (100t from r100 emitter) thaws; B (100t from nothing) freezes", function()
    local baseA, s = H.fresh_region(140, 6)
    H.emitter(s, 100, { baseA, 0 })
    local A = H.probe(s, { baseA + 100, 0 }, C.PROBE_ASSEMBLER)

    -- Control region: same machine, same 100-tile offset, but NO emitter anywhere
    -- in reach (the region is >400 tiles of frozen ground from region A).
    local baseB = H.fresh_region(140, 6)
    local B = H.probe(s, { baseB + 100, 0 }, C.PROBE_ASSEMBLER)

    assert.is_true(A.is_freezable, "assembler must be freezable on this surface")

    async(3600)
    after_ticks(2500, function()
      assert.is_false(A.frozen, "machine 100 tiles from a hot r100 emitter must be THAWED")
      assert.is_true(B.frozen, "machine 100 tiles from no emitter must FREEZE")
      done()
    end)
  end)

  it("works for assembler, inserter, and pipe alike (native pipe/fluid freeze)", function()
    local base, s = H.fresh_region(120, 10)
    H.emitter(s, 100, { base, 0 })
    -- three freezable kinds, each 90 tiles out (comfortably inside reach), on
    -- their own y-lane; plus a far control lane with a bare pipe (must freeze).
    local a = H.probe(s, { base + 90, -6 }, C.PROBE_ASSEMBLER)
    local i = H.probe(s, { base + 90, 0 }, C.PROBE_INSERTER)
    local p = H.probe(s, { base + 90, 6 }, C.PROBE_PIPE)

    local cbase = H.fresh_region(20, 4)
    local cp = H.probe(s, { cbase + 5, 0 }, C.PROBE_PIPE)

    assert.is_true(p.is_freezable, "pipe must be freezable (native fluid freeze)")

    async(3600)
    after_ticks(2500, function()
      assert.is_false(a.frozen, "assembler at 90t must thaw")
      assert.is_false(i.frozen, "inserter at 90t must thaw")
      assert.is_false(p.frozen, "pipe at 90t must thaw")
      assert.is_true(cp.frozen, "control pipe with no emitter must freeze")
      done()
    end)
  end)

  it("THAWS an already-frozen machine when an emitter arrives (no hysteresis)", function()
    local base, s = H.fresh_region(120, 6)
    -- Place the machine alone and let it freeze solid first.
    local m = H.probe(s, { base + 80, 0 }, C.PROBE_ASSEMBLER)
    async(9000)
    after_ticks(900, function()
      assert.is_true(m.frozen, "machine must freeze before the emitter arrives")
      -- Now bring the warmth: an r100 emitter within reach.
      H.emitter(s, 100, { base, 0 })
      after_ticks(6000, function()
        assert.is_false(m.frozen, "frozen machine must THAW once a hot r100 emitter is in reach")
        done()
      end)
    end)
  end)
end)
