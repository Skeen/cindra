-- PROOF: the ~100x peak OUTRUNS any buildable capture rate, so there is always
-- overflow to dump - the disposal decision never disappears at any scale (§15-7;
-- DESIGN.md §5 "the flare must NOT be 100%-catchable"). Integrated from flare-poc.
--
-- "Capture" = recoverable storage (capacitor + battery). Dissipation is infinite
-- but is WASTE, not capture; the point is you can never STORE the whole spike.

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local panels = require("scripts.panels")

local PEAK = C.PEAK_INTENSITY

-- Build a scaled grid: n panels along +Y, plus n/2 capacitors and n/2 batteries
-- (storage scaled WITH the array), all on one network. Returns the panels so we
-- can read the net.
local function scaled(surface, n, y_to)
  H.grid(surface, 6, y_to)
  local col = H.panel_col(surface, n, 6)
  local storage_pairs = math.floor(n / 2)
  local y = 6
  for _ = 1, storage_pairs do
    H.capacitor(surface, { -6, y }); y = y + 4
  end
  for _ = 1, storage_pairs do
    H.battery(surface, { -6, y }); y = y + 4
  end
  return col
end

describe("catchability", function()
  it("peak overflows storage at every scale (capture rate < delivery rate)", function()
    -- The tiny-buffer capacitors (0.5 MJ at 50 MW) saturate within ~10 ms of a
    -- plateau, so across a SUSTAINED flare their contribution to disposal is a
    -- one-shot buffer fill, not their flow -- only the slow battery trickle keeps
    -- catching. We model that steady plateau by topping off the capacitors (as a
    -- real flare does near-instantly) before measuring; the point of the invariant
    -- is the SUSTAINED overflow, not the sub-tick leading edge a capacitor is built
    -- to swallow. With capacitors saturated, the peak still overflows at any scale.
    local function saturate_capacitors(surface)
      for _, c in pairs(surface.find_entities_filtered({ name = C.CAPACITOR })) do
        c.energy = c.electric_buffer_size
      end
    end

    -- Small build.
    local s = H.cindra_surface()
    H.power_reset()
    H.set_consumption(0)
    local small = scaled(s, 4, 18)

    async(240)
    after_ticks(6, function()
      saturate_capacitors(s)
      local si = panels.deficit(s, small[1].electric_network_id, PEAK)
      local small_frac = si.capture.storage / si.potential
      assert.is_true(si.deficit > 0, "small build: peak must overflow storage")
      assert.is_true(small_frac < 0.5, "small build: storage catches < half the peak")

      -- Large build: storage scaled up with the array.
      local s2 = H.cindra_surface()
      H.set_consumption(0)
      local large = scaled(s2, 8, 34)
      after_ticks(6, function()
        saturate_capacitors(s2)
        local li = panels.deficit(s2, large[1].electric_network_id, PEAK)
        local large_frac = li.capture.storage / li.potential
        assert.is_true(li.deficit > 0, "large build: peak must STILL overflow storage")
        assert.is_true(large_frac < 0.5, "large build: storage still catches < half the peak")
        -- Scale-invariant: doubling everything does not improve the caught fraction.
        assert.is_true(math.abs(small_frac - large_frac) < 0.05,
          "overflow is scale-invariant: " .. string.format("%.2f vs %.2f", small_frac, large_frac))
        done()
      end)
    end)
  end)

  it("once storage fills, the entire peak overflows", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.set_consumption(0)
    local col = scaled(s, 4, 18)

    async(120)
    after_ticks(6, function()
      -- Top off every accumulator: no room left, so intake drops to zero.
      for _, e in pairs(s.find_entities_filtered({ name = { C.CAPACITOR, C.BATTERY } })) do
        e.energy = e.electric_buffer_size
      end
      local info = panels.deficit(s, col[1].electric_network_id, PEAK)
      assert.are.equal(0, info.capture.storage, "full storage accepts no more power")
      assert.are.equal(info.potential, info.deficit,
        "with storage full and no dissipation, 100% of the peak is undisposed")
      done()
    end)
  end)
end)
