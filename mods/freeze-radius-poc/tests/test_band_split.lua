-- BAND SPLIT + OVERSHOOT + SPACING (ci-b5i, primary experiments Q2/Q3/Q4).
--
-- The proposed Cindra inversion: whole-surface freeze ON, then a single sparse
-- LINE of high-radius emitters on the LAVA/fire edge keeps the warm band thawed
-- while the nightward/ice side still freezes. These tests prove the layout works
-- and characterise its geometry, all off LuaEntity.frozen on clean ground.
--
--   Q2 SPLIT:    an emitter line thaws a band ~100 wide; the night beyond freezes
--                (a real warm/frozen split from ONE line).
--   Q3 OVERSHOOT:the ~100-tile clamp BOUNDS the bleed -- warmth cannot reach past
--                ~100 from the line, so a night edge >100 out stays frozen no
--                matter the radius. Overshoot is self-limiting.
--   Q4 SHAPE:    because reach is a Chebyshev SQUARE (test_shape), the freeze
--                front is STRAIGHT (no scallop) for spacing up to ~2*reach; only
--                beyond that do rectangular cold gaps open between emitters. The
--                spacing rule is therefore S <= ~2*reach (~=190 for margin), far
--                more generous than a circular-reach line would allow.

local H = require("tests.helpers")
local C = require("scripts.config")

local DISTS = {}
for d = 1, 135 do DISTS[#DISTS + 1] = d end

-- Vertical emitter line at x=baseX, ALWAYS with an emitter at y=0, then ±S, ±2S...
local function build_line(s, baseX, R, S, ymax)
  H.emitter(s, R, { baseX, 0 })
  local y = S
  while y <= ymax do
    H.emitter(s, R, { baseX, y })
    H.emitter(s, R, { baseX, -y })
    y = y + S
  end
end

local function lane(s, baseX, lane_y)
  local probes = {}
  for _, d in ipairs(DISTS) do probes[d] = H.probe(s, { baseX + d, lane_y }, C.PROBE_INSERTER) end
  return probes
end

describe("band split from a single fire-edge emitter line", function()
  it("thaws a ~100-wide warm band; night beyond it freezes (Q2/Q3)", function()
    local base, s = H.fresh_region(140, 130)
    build_line(s, base, 100, 40, 120)
    local across = lane(s, base, 0)

    async(4000)
    after_ticks(2500, function()
      local reach = H.reach(across, DISTS)
      assert.is_true(reach >= 96, "warm band must extend ~100 tiles from the line, got " .. reach)
      assert.is_false(across[20].frozen, "20t inside the band must be thawed")
      assert.is_false(across[90].frozen, "90t inside the band must be thawed")
      assert.is_true(across[120].frozen, "night at 120t must stay frozen (bounded by ~100 clamp)")
      assert.is_true(across[135].frozen, "deep night at 135t must stay frozen")
      done()
    end)
  end)

  it("STRAIGHT front at wide spacing S=160 (< 2*reach): no scallop (Q4)", function()
    -- Square reach -> each emitter covers +/-100 in Y. At S=160 the boxes overlap
    -- in Y (160 < 200), so the front depth is ~100 BOTH across an emitter (y=0)
    -- and between two (y=80). A circular-reach line would scallop to ~sqrt(100^2
    -- -80^2)=60 between; the square does not.
    local base, s = H.fresh_region(140, 220)
    build_line(s, base, 100, 160, 200)
    local across = lane(s, base, 0)    -- on an emitter
    local between = lane(s, base, 80)  -- midpoint between emitters at 0 and 160

    async(4000)
    after_ticks(2500, function()
      local d_across = H.reach(across, DISTS)
      local d_between = H.reach(between, DISTS)
      assert.is_true(d_across >= 96, "across depth ~100, got " .. d_across)
      assert.is_true(d_between >= 96, "between depth ALSO ~100 (straight front), got " .. d_between)
      assert.is_true(math.abs(d_across - d_between) <= 5,
        "front must be straight (<=5t undulation) at S=160: across=" .. d_across .. " between=" .. d_between)
      done()
    end)
  end)

  it("cold GAPS open when spacing exceeds 2*reach (S=240) (Q4 limit)", function()
    -- Emitter boxes cover y in [-100,100] and [140,340] (emitters at 0 and 240).
    -- The strip y in (100,140) is out of every box -> a rectangular cold gap.
    local base, s = H.fresh_region(140, 260)
    build_line(s, base, 100, 240, 240)
    local across = lane(s, base, 0)      -- on an emitter: full depth
    local gap = lane(s, base, 120)       -- inside the y-gap: frozen at all x

    async(4000)
    after_ticks(2500, function()
      assert.is_true(H.reach(across, DISTS) >= 96, "on-emitter lane still reaches ~100")
      assert.is_true(gap[10].frozen and gap[50].frozen and gap[90].frozen,
        "a lane inside the y-gap (S>2*reach) must be frozen at every depth")
      done()
    end)
  end)
end)
