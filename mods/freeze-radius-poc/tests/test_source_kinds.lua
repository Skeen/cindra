-- SOURCE KINDS + TEMPERATURE INDEPENDENCE (ci-b5i). Two findings that widen the
-- design space for the inversion mechanic:
--
--   * heating_radius lives on HeatInterface, Reactor AND HeatPipe, and all three
--     honour a large radius identically (~100 reach at radius 100). So Cindra is
--     not tied to the debug heat-interface: a bespoke reactor- or heat-pipe-typed
--     emitter works the same. (The heat-interface is just the cleanest test rig:
--     its buffer temperature is directly settable and needs no fuel.)
--   * reach is a pure DISTANCE mechanic: identical from a barely-hot buffer to a
--     max-hot one. The emitter only has to be ABOVE the freeze point, not blazing.

local H = require("tests.helpers")
local C = require("scripts.config")

local DISTS = {}
for d = 1, 120 do DISTS[#DISTS + 1] = d end

local function lane(s, base, name, temp)
  local em = s.create_entity({ name = name, position = { base, 0 }, force = "player" })
  pcall(function() em.temperature = temp end)
  pcall(function() em.set_heat_setting({ temperature = temp, mode = "at-least" }) end)
  local probes = {}
  for _, d in ipairs(DISTS) do probes[d] = H.probe(s, { base + d, 0 }, C.PROBE_INSERTER) end
  return probes
end

describe("all heating_radius sources + temperature independence", function()
  it("reactor, heat-pipe and heat-interface all reach ~100 at radius 100", function()
    local b1, s = H.fresh_region(140, 6); local reactor = lane(s, b1, "freeze-poc-reactor-r100", 1000)
    local b2 = H.fresh_region(140, 6); local heatpipe = lane(s, b2, "freeze-poc-heatpipe-r100", 1000)
    local b3 = H.fresh_region(140, 6); local hi = lane(s, b3, C.emitter_name(100), 1000)
    async(4000)
    after_ticks(2500, function()
      for _, c in ipairs({ { "reactor", reactor }, { "heat-pipe", heatpipe }, { "heat-interface", hi } }) do
        local reach = H.reach(c[2], DISTS)
        assert.is_true(reach >= 90, c[1] .. " r100 must reach ~100, got " .. reach)
      end
      done()
    end)
  end)

  it("reach is independent of emitter temperature (a hot-enough buffer suffices)", function()
    local blo, s = H.fresh_region(140, 6); local lo = lane(s, blo, C.emitter_name(100), 100)
    local bhi = H.fresh_region(140, 6); local hi = lane(s, bhi, C.emitter_name(100), 1000)
    async(4000)
    after_ticks(2500, function()
      local reach_lo = H.reach(lo, DISTS)
      local reach_hi = H.reach(hi, DISTS)
      assert.is_true(reach_lo >= 90, "100C buffer must still reach ~100, got " .. reach_lo)
      assert.is_true(math.abs(reach_lo - reach_hi) <= 4,
        "reach must not depend on temperature: 100C=" .. reach_lo .. " 1000C=" .. reach_hi)
      done()
    end)
  end)
end)
