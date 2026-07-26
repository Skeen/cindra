-- PROOF: with sufficient disposal there is ZERO panel loss, and the dissipator
-- is the sacrificial fuse - its capacity is spent before any panel is damaged
-- (planet_design.md sec.10 "The disposal problem" + "Panel damage mechanic").

local H = require("tests.helpers")
local C = require("scripts.config")
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
    local s = H.surface()
    H.reset()
    H.grid(s, -8, 24)
    local none = H.panel_row(s, 4, -6, 6) -- 40 MW at peak
    H.set_consumption(0)

    async(240)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      local dmg_none = total_damage(none)
      assert.is_true(dmg_none > 0, "no disposal must damage panels")

      -- Phase 2: one dissipator (20 MW) absorbs half the surplus first.
      local s2 = H.surface()
      H.grid(s2, -8, 24)
      local part = H.panel_row(s2, 4, -6, 6)
      H.dissipator(s2, { 0, -6 })
      H.set_consumption(0)
      after_ticks(6, function()
        panels.sweep(s2, PEAK)
        local dmg_part = total_damage(part)
        assert.is_true(dmg_part > 0 and dmg_part < dmg_none,
          "a partial dissipator must REDUCE panel damage: none=" .. dmg_none .. " part=" .. dmg_part)

        -- Phase 3: two dissipators (40 MW) cover the whole surplus -> zero loss.
        local s3 = H.surface()
        H.grid(s3, -8, 24)
        local full = H.panel_row(s3, 4, -6, 6)
        H.dissipator(s3, { 0, -6 })
        H.dissipator(s3, { 4, -6 })
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
    local s = H.surface()
    H.reset()
    H.grid(s, -8, 40)
    local row = H.panel_row(s, 8, -6, 6) -- 80 MW at peak
    -- Four dissipators (80 MW) + storage + a little consumption: capture always
    -- covers the peak, so there is never a deficit.
    for i = 0, 3 do H.dissipator(s, { -6 + i * 4, -6 }) end
    H.capacitor(s, { 12, -6 })
    H.battery(s, { 16, -6 })
    H.set_consumption(5e6)

    async(240)
    after_ticks(6, function()
      -- Surplus is genuinely absorbed AND captured at the peak: both the
      -- dissipators (dumped) and the storage (captured) show available capacity.
      local id = row[1].electric_network_id
      local info = panels.deficit(s, id, PEAK)
      assert.is_true(info.capture.dissipator > 0, "dissipators must be dumping")
      assert.is_true(info.capture.storage > 0, "storage must be capturing")
      assert.is_true(info.deficit <= 0, "sufficient disposal -> no surplus with nowhere to go")

      -- Run a whole flare cycle through the damage sweep: no panel may be lost.
      for t = 0, C.PERIOD_TICKS, 30 do
        panels.sweep(s, flare.state(t).intensity)
      end
      for i, p in ipairs(row) do
        assert.is_true(p.valid, "panel " .. i .. " must survive the flare")
        assert.are.equal(C.PANEL_MAX_HEALTH, p.health, "panel " .. i .. " must take zero damage")
      end
      done()
    end)
  end)
end)
