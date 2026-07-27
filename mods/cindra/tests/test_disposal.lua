-- PROOF: with sufficient disposal there is ZERO panel loss, and the dissipator
-- is the sacrificial fuse - its capacity is spent before any panel is damaged
-- (§15-8/§15-9; DESIGN.md §5 "the disposal problem" + panel-damage mechanic).
-- Integrated from the proven flare-poc (ci-zg3).

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local flare = require("scripts.flare")
local panels = require("scripts.panels")

local PEAK = C.PEAK_INTENSITY

local function total_damage(list)
  local d = 0
  for _, p in ipairs(list) do
    if p.valid then d = d + (p.max_health - p.health) else d = d + C.PANEL_MAX_HEALTH end
  end
  return d
end

describe("disposal", function()
  it("dissipator is the fuse: it absorbs before panels; sized disposal = zero loss", function()
    -- Phase 1: no dissipator -> full deficit damages panels.
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 18)
    local none = H.panel_col(s, 4, 6) -- 24 MW at peak (4 * 6 MW)
    H.set_consumption(0)

    async(240)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      local dmg_none = total_damage(none)
      assert.is_true(dmg_none > 0, "no disposal must damage panels")

      -- Phase 2: one dissipator (20 MW) absorbs half the surplus first.
      local s2 = H.cindra_surface()
      H.grid(s2, 6, 18)
      local part = H.panel_col(s2, 4, 6)
      H.dissipator(s2, { -6, 6 })
      H.set_consumption(0)
      after_ticks(6, function()
        panels.sweep(s2, PEAK)
        local dmg_part = total_damage(part)
        assert.is_true(dmg_part > 0 and dmg_part < dmg_none,
          "a partial dissipator must REDUCE panel damage: none=" .. dmg_none .. " part=" .. dmg_part)

        -- Phase 3: two dissipators (40 MW) cover the whole surplus -> zero loss.
        local s3 = H.cindra_surface()
        H.grid(s3, 6, 18)
        local full = H.panel_col(s3, 4, 6)
        H.dissipator(s3, { -6, 6 })
        H.dissipator(s3, { -6, 10 })
        H.set_consumption(0)
        after_ticks(6, function()
          panels.sweep(s3, PEAK)
          assert.are.equal(0, total_damage(full),
            "dissipation >= surplus must spare every panel (fuse absorbs first)")
          done()
        end)
      end)
    end)
  end)

  it("sufficient disposal (dissipator + capacitor + battery) = zero loss over a full flare", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 34)
    local col = H.panel_col(s, 8, 6) -- 48 MW at peak (8 * 6 MW)
    -- Four dissipators (80 MW) + storage + a little consumption: capture always
    -- covers the peak, so there is never a deficit.
    H.dissipator(s, { -6, 6 })
    H.dissipator(s, { -6, 10 })
    H.dissipator(s, { -6, 14 })
    H.dissipator(s, { -6, 18 })
    H.capacitor(s, { -6, 24 })
    H.battery(s, { -6, 28 })
    H.set_consumption(5e6)

    async(240)
    after_ticks(6, function()
      -- Surplus is genuinely absorbed AND captured at the peak: both the
      -- dissipators (dumped) and the storage (captured) show available capacity.
      local id = col[1].electric_network_id
      local info = panels.deficit(s, id, PEAK)
      assert.is_true(info.capture.dissipator > 0, "dissipators must be dumping")
      assert.is_true(info.capture.storage > 0, "storage must be capturing")
      assert.is_true(info.deficit <= 0, "sufficient disposal -> no surplus with nowhere to go")

      -- Run a whole flare event (plus the calm on either side) through the damage
      -- sweep: no panel may be lost. Anchor the event at offset 0 and sweep from
      -- the calm before it, across the ramp/plateau/decay, to the calm after.
      for off = -60, C.EVENT_TICKS + 60, 30 do
        panels.sweep(s, flare.state(off, 0).intensity)
      end
      for i, p in ipairs(col) do
        assert.is_true(p.valid, "panel " .. i .. " must survive the flare")
        assert.are.equal(C.PANEL_MAX_HEALTH, p.health, "panel " .. i .. " must take zero damage")
      end
      done()
    end)
  end)
end)
