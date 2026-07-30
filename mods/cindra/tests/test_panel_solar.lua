-- PROOF: solar output scales with sunward position (§ ci-9ht). Panels only REALLY
-- work on the sunny (sunward) part of the ribbon: a panel's REAL engine output
-- scales with how far sunward it sits and drops toward ~nothing nightward, so
-- panel PLACEMENT is a real decision (build sunward, toward the heat/danger). In
-- the default vertical orientation sunward is the LEFT / west (negative x); see
-- scripts/axis.lua for the perpendicular-coordinate mapping.
--
-- Mechanism (scripts/panel-solar.lua + scripts/panels.lua reconcile): a placed
-- panel morphs to the reduced-output VARIANT matching its Y. Each variant is a
-- real solar panel, so the engine's daylight/flare curve multiplies its band
-- output natively -- position scaling composes with the flare for free. The pure
-- band maths is exhausted in unit-tests/test_panel_solar.lua + the sunward_factor
-- cases in unit-tests/test_ribbon.lua; here we prove it drives the real engine.

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local panels = require("scripts.panels")
local panel_solar = require("scripts.panel-solar")
local flare = require("scripts.flare")

-- Pin a deterministic sporadic-flare anchor: the telegraph begins at WS, so tick
-- 10 is calm and PEAK_TICK lands on the plateau.
local WS = 600
local PEAK_TICK = WS + C.WARNING_TICKS + C.RAMP_TICKS + 10 -- a plateau tick

-- The sunmost / nightmost panel on a surface (panels.panels is sunward-first).
local function sunward_and_nightward(s)
  local list = panels.panels(s)
  return list[1], list[#list]
end

describe("position-scaled solar - morph", function()
  it("morphs a placed panel to the output band matching its sunward Y", function()
    local s = H.cindra_surface()
    H.power_reset()
    -- Default vertical orientation: sunward is the LEFT / west (negative x), so
    -- perp = -x. Put the sunward panel at x = -40 and the nightward one at x = 40.
    local sun = H.panel(s, { -40, 6 })  -- sunward (west)
    local night = H.panel(s, { 40, 6 }) -- nightward (east)
    assert.are.equal(C.PANEL, sun.name, "freshly placed panels start as the base item")
    assert.are.equal(C.PANEL, night.name)

    local morphed = panels.reconcile_variants(s)
    assert.is_true(morphed >= 1, "at least the nightward panel must morph to a reduced band")

    -- (3x3 panels center on tile+0.5, so the exact x is ~-39.5 / ~40.5.)
    local sunward, nightward = sunward_and_nightward(s)
    assert.is_true(sunward.position.x < 0, "sunmost panel is the west (-x) one")
    assert.is_true(nightward.position.x > 0, "nightmost panel is the east (+x) one")
    assert.is_true(
      panel_solar.nominal_w(sunward.name) > panel_solar.nominal_w(nightward.name),
      "sunward panel's band output must beat the nightward panel's: "
        .. panel_solar.nominal_w(sunward.name) .. " vs " .. panel_solar.nominal_w(nightward.name))
    assert.are_not.equal(C.PANEL, nightward.name, "the nightward panel is a reduced variant")
  end)

  it("is idempotent and never re-morphs (or heals) a settled panel", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.panel(s, { 40, 6 }) -- nightward (east): morphs to a reduced band
    panels.reconcile_variants(s)

    local before = #panels.panels(s)
    local again = panels.reconcile_variants(s)
    assert.are.equal(0, again, "a settled panel must not morph a second time")
    assert.are.equal(before, #panels.panels(s), "the panel count is unchanged")

    -- A settled, DEGRADED panel must survive reconcile with its health intact:
    -- morph-on-reconcile must never silently reset the disposal-deficit damage.
    local p = panels.panels(s)[1]
    p.health = 50
    panels.reconcile_variants(s)
    assert.is_true(p.valid, "a settled panel is not destroyed by reconcile")
    assert.are.equal(50, p.health, "reconcile must not heal a degraded panel")
  end)
end)

describe("position-scaled solar - real engine output", function()
  it("delivers materially more power sunward than nightward", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)

    -- Two isolated grids (80 tiles apart in x, beyond substation wire reach), so
    -- each measurement sink only ever sees its own panel's output. Placed at
    -- x = -/+40 (the survivable-ribbon edges): under the ci-da2 curve (ci-22v) the
    -- sunward edge sits a clear band above the nightward edge, so real output still
    -- proves placement matters even though the ramp now spans the whole ribbon.
    H.grid(s, 30, 42, -40)
    H.panel(s, { -40, 40 })              -- sunward panel (west edge of the work area)
    local sun_sink = H.measure_sink(s, { -40, 30 })

    H.grid(s, -42, -30, 40)
    H.panel(s, { 40, -40 })              -- nightward panel (east edge)
    local night_sink = H.measure_sink(s, { 40, -30 })

    panels.reconcile_variants(s) -- morph both to their position bands

    -- Same flare (peak) for both; freeze_daytime holds output constant so the
    -- energy each sink gains over the window is a clean measure of real output.
    flare.apply(s, PEAK_TICK)
    sun_sink.energy = 0
    night_sink.energy = 0
    async(300)
    after_ticks(120, function()
      local sun_e = sun_sink.energy
      local night_e = night_sink.energy
      assert.is_true(sun_e > 0, "the sunward panel must actually produce power")
      assert.is_true(sun_e > 3 * night_e,
        "sunward output must dwarf nightward (placement matters): "
          .. string.format("%.0f", sun_e) .. " vs " .. string.format("%.0f", night_e))
      done()
    end)
  end)

  it("composes with the flare: a placed panel still swings ~15x baseline", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    H.grid(s, 30, 42, 0)
    H.panel(s, { 0, 40 }) -- a reduced-band panel (perp = 0 at the terminator)
    local sink = H.measure_sink(s, { 0, 30 })
    panels.reconcile_variants(s)

    -- Baseline (calm) window.
    flare.apply(s, 10)
    sink.energy = 0
    async(600)
    after_ticks(120, function()
      local base_e = sink.energy
      assert.is_true(base_e > 0, "the night floor still runs a sunward panel")

      -- Peak (plateau) window on the SAME morphed panel.
      sink.energy = 0
      flare.apply(s, PEAK_TICK)
      after_ticks(120, function()
        local ratio = sink.energy / base_e
        -- ci-ezk re-baseline: swing is ~15x (6 MW / 400 kW), not the old 100x.
        -- Position scaling multiplies the flare, it does not flatten it.
        assert.is_true(ratio > 10 and ratio < 20,
          "position scaling multiplies the flare, it does not flatten it; got "
            .. string.format("%.1f", ratio))
        done()
      end)
    end)
  end)
end)

describe("vanilla panel targeting - cindra only", function()
  -- ci-8al: the flare mechanics target the PLAIN VANILLA solar panel, and only on
  -- the Cindra surface. A vanilla panel on any other surface must be untouched:
  -- no sunward morph, no disposal-deficit damage (the never-mutate-other-planets
  -- invariant, enforced by the surface.name == C.SURFACE gate).
  local function other_surface()
    local s = game.surfaces["not-cindra-test"]
    if not s then
      s = game.create_surface("not-cindra-test", { width = 64, height = 64 })
      s.request_to_generate_chunks({ 0, 0 }, 2)
      s.force_generate_chunk_requests()
    end
    for _, e in pairs(s.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
    local tiles = {}
    for x = -20, 20 do for y = -20, 20 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end end
    s.set_tiles(tiles)
    return s
  end

  it("damages a genuinely vanilla solar panel on Cindra", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 6)
    local p = H.panel(s, { 6, 6 }) -- a plain vanilla solar panel on Cindra
    assert.are.equal("solar-panel", p.name, "the placed panel is the vanilla solar panel")
    assert.are.equal("solar-panel", p.prototype.type, "it is a real solar-panel prototype")

    -- Disposal-deficit damage targets the vanilla panel directly (no morph here):
    -- with no disposal, the vanilla panel degrades.
    H.set_consumption(0)
    panels.sweep(s, C.PEAK_INTENSITY)
    assert.is_true(p.valid and p.name == "solar-panel",
      "the damaged entity is still the plain vanilla solar panel")
    assert.is_true(p.health < p.max_health,
      "the vanilla panel takes disposal-deficit damage on Cindra")
  end)

  it("leaves a vanilla solar panel on another surface untouched (no morph, no damage)", function()
    local s = other_surface()
    -- A plain vanilla solar panel, placed nightward-equivalent (would morph on Cindra).
    local p = s.create_entity({ name = "solar-panel", position = { 0, -18 }, force = "player" })
    assert.is_not_nil(p, "vanilla solar panel places on the other surface")
    local hp0 = p.health

    -- Sunward morph is a no-op off Cindra: reconcile touches nothing.
    local morphed = panels.reconcile_variants(s)
    assert.are.equal(0, morphed, "reconcile must not morph panels off Cindra")
    assert.is_true(p.valid, "the off-Cindra panel is not destroyed")
    assert.are.equal("solar-panel", p.name, "the off-Cindra panel stays a plain vanilla panel")

    -- Damage sweep is a no-op off Cindra even under a maximal deficit.
    H.set_consumption(0)
    local summary = panels.sweep(s, C.PEAK_INTENSITY)
    assert.is_nil(next(summary), "sweep reports nothing off Cindra")
    assert.are.equal(hp0, p.health, "the off-Cindra panel takes NO disposal-deficit damage")

    p.destroy()
  end)
end)

describe("position-scaled solar - damage model", function()
  it("sizes a panel's disposal surplus by its position band", function()
    -- A sunward array dumps far more surplus than an equal-count nightward array,
    -- so the disposal-deficit damage rule (scripts/panels.lua) reads the real,
    -- position-scaled output -- a nightward panel produces ~nothing, so it adds
    -- ~no surplus and earns ~no damage.
    local s = H.cindra_surface()
    H.power_reset()
    -- Sunward column at x = -40 (west); the perpendicular coordinate is -x, so
    -- these sit deep in the sunward band.
    H.panel_col(s, 4, 0, -40) -- sunward column (x = -40)
    panels.reconcile_variants(s)
    local sunward_potential = panels.potential(panels.panels(s), C.PEAK_INTENSITY)

    local s2 = H.cindra_surface() -- fresh surface wipes the first
    H.panel_col(s2, 4, 0, 40)     -- SAME count, nightward (x = 40, east)
    panels.reconcile_variants(s2)
    local nightward_potential = panels.potential(panels.panels(s2), C.PEAK_INTENSITY)

    assert.is_true(sunward_potential > 3 * nightward_potential,
      "equal panel counts, but sunward surplus dwarfs nightward: "
        .. string.format("%.0f", sunward_potential) .. " vs "
        .. string.format("%.0f", nightward_potential))
  end)
end)
