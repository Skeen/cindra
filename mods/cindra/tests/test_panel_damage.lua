-- PROOF: the disposal-deficit panel-damage rule (§15-8; DESIGN.md §5).
-- Insufficient disposal -> panels degrade (then die if sustained), proportional
-- to the deficit, edge-biased along the ribbon SUNWARD axis (+Y), and
-- self-correcting (the array shrinks to match disposal instead of spiralling to
-- zero). Integrated from the proven flare-poc (ci-zg3).
--
-- Panels are laid along +Y (sunward); the sunmost panel (highest Y) is damaged
-- first, since scripts/panels.lua orders by ribbon.temperature (the single
-- source of truth for the hot-cold axis).

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local panels = require("scripts.panels")

local PEAK = C.PEAK_INTENSITY

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
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 26)
    local col = H.panel_col(s, 6, 6) -- y = 6 .. 26; col[6] is sunmost (max y)
    -- potential = 6 * 6 MW = 36 MW (vanilla 60 kW panel at the ~100x peak); leave
    -- a 1 MW deficit.
    H.set_consumption(36 * 1e6 - 1e6)

    async(120)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      assert.is_true(col[6].health < C.PANEL_MAX_HEALTH, "sunmost panel must degrade")
      assert.are.equal(C.PANEL_MAX_HEALTH, col[1].health, "nightward panel must be spared")
      assert.are.equal(C.PANEL_MAX_HEALTH, col[3].health, "interior panel must be spared")
      done()
    end)
  end)

  it("total damage tracks the DEFICIT, not the panel count", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 18)
    -- Grid A: 4 panels, 2 MW deficit.
    local a = H.panel_col(s, 4, 6)
    H.set_consumption(4 * 6e6 - 2e6)

    async(200)
    after_ticks(6, function()
      panels.sweep(s, PEAK)
      local dmgA = damage_of(a)

      -- Grid B: 8 panels, SAME 2 MW deficit (double the panels). A fresh surface
      -- wipe replaces grid A; dmgA was already captured above.
      local s2 = H.cindra_surface()
      H.grid(s2, 6, 34)
      local b = H.panel_col(s2, 8, 6)
      H.set_consumption(8 * 6e6 - 2e6)
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
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 6)
    local p = H.panel(s, { 6, 6 })
    H.set_consumption(0) -- full 6 MW deficit

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
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 6)
    local p = H.panel(s, { 6, 6 })
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
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 6)
    local p = H.panel(s, { 6, 6 })
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
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 42)
    local col = H.panel_col(s, 10, 6) -- 60 MW potential at peak (10 * 6 MW)
    -- 18 MW of disposal (consumption). Equilibrium: alive * 6 MW <= 18 MW.
    H.set_consumption(18 * 1e6)

    async(200)
    after_ticks(6, function()
      for _ = 1, 40 do panels.sweep(s, PEAK) end
      local survivors = alive(col)
      assert.is_true(survivors > 0, "must NOT death-spiral to zero (negative feedback)")
      assert.is_true(survivors < 10, "some panels must die under a large sustained deficit")
      assert.is_true(survivors >= 2 and survivors <= 4,
        "array converges to ~disposal capacity (3 panels ~ 18 MW): got " .. survivors)
      done()
    end)
  end)
end)

-- The overload-damage VISUAL (ci-clf): a panel that takes disposal-deficit damage
-- must pop a spark so the player can SEE which panels are burning up. The sweep
-- reports the spark count and the self-reaping spark explosion is created on the
-- Cindra surface (same tick, so it is still alive to query); a spared / recovering
-- panel arcs nothing.
local function sparks_on(surface)
  return #surface.find_entities_filtered({ name = C.PANEL_SPARK })
end

-- Total sparks the sweep reports across every network.
local function reported_sparks(summary)
  local n = 0
  for _, net in pairs(summary) do n = n + (net.sparked or 0) end
  return n
end

describe("panel damage - overload spark visual (ci-clf)", function()
  it("a panel that takes overload damage pops a spark", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 6)
    local p = H.panel(s, { 6, 6 })
    H.set_consumption(0) -- full 6 MW deficit -> the panel is damaged

    async(120)
    after_ticks(6, function()
      local summary = panels.sweep(s, PEAK)
      assert.is_true(p.health < C.PANEL_MAX_HEALTH, "the panel must have taken damage (control)")
      assert.are.equal(1, reported_sparks(summary), "the sweep must report one spark for the damaged panel")
      assert.is_true(sparks_on(s) >= 1, "an overload-spark explosion must exist on the Cindra surface")
      done()
    end)
  end)

  it("edge-biased: only the panels that actually take a hit spark", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 26)
    H.panel_col(s, 6, 6) -- 6 panels, 36 MW potential at peak
    H.set_consumption(36 * 1e6 - 1e6) -- 1 MW deficit -> only the sunmost panel(s) hit

    async(120)
    after_ticks(6, function()
      local summary = panels.sweep(s, PEAK)
      local n = reported_sparks(summary)
      assert.is_true(n >= 1, "the damaged sunmost panel must spark")
      assert.is_true(n < 6, "a small deficit must NOT spark every panel (edge-biased): " .. n)
      assert.are.equal(n, sparks_on(s), "one spark entity per reported spark")
      done()
    end)
  end)

  it("no damage, no spark: sufficient disposal spares the panels and pops nothing", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 6)
    local p = H.panel(s, { 6, 6 })
    H.set_consumption(100 * 1e6) -- disposal dwarfs output -> deficit <= 0, recovery path

    async(120)
    after_ticks(6, function()
      local summary = panels.sweep(s, PEAK)
      assert.are.equal(C.PANEL_MAX_HEALTH, p.health, "a spared panel must take no damage (control)")
      assert.are.equal(0, reported_sparks(summary), "no damage -> no spark reported")
      assert.are.equal(0, sparks_on(s), "no damage -> no spark entity created")
      done()
    end)
  end)
end)
