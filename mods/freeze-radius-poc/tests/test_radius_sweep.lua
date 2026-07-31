-- RADIUS SWEEP + ENGINE CLAMP (ci-b5i, primary experiment Q1). Maps effective
-- thaw reach against prototype heating_radius on clean, separated ground.
--
-- Findings encoded as assertions:
--   * reach tracks heating_radius roughly 1:1 BELOW the clamp (r10 -> ~10,
--     r50 -> ~48, r100 -> ~100), and
--   * there is a HARD ENGINE CLAMP at ~100 tiles: r150 / r200 / r300 all reach
--     the SAME ~100 tiles as r100, no further. So the MAX EFFECTIVE heating
--     radius is ~100 tiles regardless of how high the prototype value is set.
-- This is the "find the max effective radius / hidden clamp" deliverable.

local H = require("tests.helpers")
local C = require("scripts.config")

-- Distance ladder covering 1..~135 with fine steps near the boundary.
local DISTS = {}
for d = 1, 135 do DISTS[#DISTS + 1] = d end

local function measure(radius)
  local base, s = H.fresh_region(radius + 40, 6)
  H.emitter(s, radius, { base, 0 })
  local probes = {}
  for _, d in ipairs(DISTS) do
    if d <= radius + 35 then probes[d] = H.probe(s, { base + d, 0 }, C.PROBE_INSERTER) end
  end
  return probes
end

describe("radius sweep: reach tracks radius then clamps at ~100", function()
  it("reach ~= radius below the clamp", function()
    local cases = { { r = 10 }, { r = 50 }, { r = 100 } }
    for _, c in ipairs(cases) do c.probes = measure(c.r) end
    async(4000)
    after_ticks(2500, function()
      for _, c in ipairs(cases) do
        local reach = H.reach(c.probes, DISTS)
        -- reach should be within a couple tiles of the radius (footprint/edge slop).
        assert.is_true(reach >= c.r - 3 and reach <= c.r + 3,
          string.format("r%d: reach %d should be ~= %d", c.r, reach, c.r))
      end
      done()
    end)
  end)

  it("hard clamps at ~100: r150/r200/r300 reach no further than r100", function()
    local r100 = measure(100)
    local r150 = measure(150)
    local r200 = measure(200)
    local r300 = measure(300)
    async(4000)
    after_ticks(2500, function()
      local reach100 = H.reach(r100, DISTS)
      local reach150 = H.reach(r150, DISTS)
      local reach200 = H.reach(r200, DISTS)
      local reach300 = H.reach(r300, DISTS)
      -- The clamp: everything at/above r100 lands at the same ~100-101 ceiling.
      assert.is_true(reach100 >= 98 and reach100 <= 103, "r100 reach ~100, got " .. reach100)
      for _, pair in ipairs({ { 150, reach150 }, { 200, reach200 }, { 300, reach300 } }) do
        assert.is_true(math.abs(pair[2] - reach100) <= 3,
          string.format("r%d reach %d must equal the r100 clamp %d (no gain above 100)",
            pair[1], pair[2], reach100))
      end
      -- And crucially: a machine at 130 tiles is FROZEN even at r300 (the clamp
      -- means huge radii cannot reach it).
      assert.is_true(r300[130].frozen, "r300 must NOT thaw a machine 130 tiles away (clamp at ~100)")
      done()
    end)
  end)
end)
