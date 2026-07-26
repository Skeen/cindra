-- PROOF: the disposal-deficit panel-damage rule (planet_design.md sec.10).
-- Insufficient disposal -> panels degrade (then die if sustained), proportional
-- to the deficit, edge-biased, and self-correcting (the array shrinks to match
-- disposal instead of spiralling to zero).

local H = require("tests.helpers")
local C = require("scripts.config")
local panels = require("scripts.panels")

local PEAK = C.PEAK_INTENSITY
local PER_PANEL_PEAK = C.PANEL_NOMINAL_W * PEAK -- 10 MW at peak

local function damage_of(list)
  local d = 0
  for _, p in ipairs(list) do
    if p.valid then d = d + (p.max_health - p.health) else d = d + C.PANEL_MAX_HEALTH end
  end
  return d
end

local function alive(list)
  local n = 0
  for _, p in ipairs(list) do if p.valid then n = n + 1 end end
  return n
end

describe("panel damage - disposal deficit rule", function()
  it("is edge-biased: a small deficit dents the sunmost panel, nightward is spared", function()
    local s = H.surface()
    H.reset()
    H.grid(s, -8, 24)
    local row = H.panel_row(s, 6, -6, 6) -- x = -6 .. 14, row[6] is sunmost (max x)
    -- potential = 6 * 10 MW = 60 MW; leave a 1 MW deficit.
    H.set_consumption(60 * 1e6 - 1e6)

    async(120)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      assert.is_true(row[6].health < C.PANEL_MAX_HEALTH, "sunmost panel must degrade")
      assert.are.equal(C.PANEL_MAX_HEALTH, row[1].health, "nightward panel must be spared")
      assert.are.equal(C.PANEL_MAX_HEALTH, row[3].health, "interior panel must be spared")
      done()
    end)
  end)

  it("total damage tracks the DEFICIT, not the panel count", function()
    local s = H.surface()
    H.reset()
    H.grid(s, -8, 40)
    -- Grid A: 4 panels, 2 MW deficit.
    local a = H.panel_row(s, 4, -6, 6)
    H.set_consumption(4 * 10e6 - 2e6)

    async(200)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      local dmgA = damage_of(a)

      -- Grid B: 8 panels, SAME 2 MW deficit (double the panels).
      local s2 = H.surface()
      H.grid(s2, -8, 40)
      local b = H.panel_row(s2, 8, -6, 6)
      H.set_consumption(8 * 10e6 - 2e6)
      after_ticks(6, function()
        panels.sweep(s2, PEAK)
        local dmgB = damage_of(b)
        assert.is_true(dmgA > 0 and dmgB > 0, "both grids must take damage")
        assert.is_true(math.abs(dmgA - dmgB) < 1,
          "same deficit -> same total damage despite 2x panels: A=" .. dmgA .. " B=" .. dmgB)
        done()
      end)
    end)
  end)

  it("degrades before death: one over-budget sweep dents but does not kill", function()
    local s = H.surface()
    H.reset()
    H.grid(s, 0, 0)
    local p = H.panel(s, { 0, 6 })
    H.set_consumption(0) -- full 10 MW deficit

    async(120)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      assert.is_true(p.valid, "one sweep must not kill the panel")
      assert.is_true(p.health > 0 and p.health < C.PANEL_MAX_HEALTH,
        "panel must run 'hot' (degraded, alive): health=" .. p.health)
      done()
    end)
  end)

  it("dies under a SUSTAINED deficit", function()
    local s = H.surface()
    H.reset()
    H.grid(s, 0, 0)
    local p = H.panel(s, { 0, 6 })
    H.set_consumption(0)

    async(120)
    after_ticks(6, function()
      for _ = 1, 20 do
        if not p.valid then break end
        panels.sweep(s, PEAK)
      end
      assert.is_false(p.valid, "a sustained deficit must eventually destroy the panel")
      done()
    end)
  end)

  it("recovers when disposal is added (degradation is reversible)", function()
    local s = H.surface()
    H.reset()
    H.grid(s, 0, 0)
    local p = H.panel(s, { 0, 6 })
    H.set_consumption(0)

    async(120)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      panels.sweep(s, PEAK)
      local hurt = p.health
      assert.is_true(hurt < C.PANEL_MAX_HEALTH, "panel should be degraded first")

      -- Add ample disposal: now deficit <= 0, so sweeps heal instead of harm.
      H.set_consumption(100 * 1e6)
      panels.sweep(s, PEAK)
      panels.sweep(s, PEAK)
      assert.is_true(p.valid and p.health > hurt,
        "adding disposal must let the panel recover: " .. hurt .. " -> " .. p.health)
      done()
    end)
  end)

  it("self-corrects: die-off converges to disposal, it does NOT spiral to zero", function()
    local s = H.surface()
    H.reset()
    H.grid(s, -8, 40)
    local row = H.panel_row(s, 10, -6, 6) -- 100 MW potential at peak
    -- 30 MW of disposal (consumption). Equilibrium: alive * 10 MW <= 30 MW.
    H.set_consumption(30 * 1e6)

    async(200)
    after_ticks(6, function()
      for _ = 1, 40 do panels.sweep(s, PEAK) end
      local survivors = alive(row)
      assert.is_true(survivors > 0, "must NOT death-spiral to zero (negative feedback)")
      assert.is_true(survivors < 10, "some panels must die under a large sustained deficit")
      assert.is_true(survivors >= 2 and survivors <= 4,
        "array converges to ~disposal capacity (3 panels ~ 30 MW): got " .. survivors)
      done()
    end)
  end)
end)
