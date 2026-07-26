-- Environmental scanner proofs (factorio-test, in-engine).
--
-- Prototype shape: the scanner is a buildable, craftable, chemistry-free
-- constant-combinator, and its virtual signals exist. Runtime: a placed scanner
-- outputs the correct generic day/night/daylight/solar signals for its surface,
-- updates as the day advances, and (when a flare provider is injected) also
-- emits the flare-forecast block -- the SAME maths the unit test locks in
-- unit-tests/test_readings.lua, now proven against the real engine.

local C = require("scripts.config")
local readings = require("scripts.readings")
local forecast = require("scripts.forecast")
local scanner = require("scripts.scanner")

local S = readings.SIGNALS

local FORBIDDEN = {
  ["plastic-bar"] = true, ["sulfuric-acid"] = true, ["sulfur"] = true,
  ["lubricant"] = true, ["petroleum-gas"] = true, ["light-oil"] = true,
  ["heavy-oil"] = true, ["coal"] = true, ["rocket-fuel"] = true,
}

-- ============================================================================
-- Prototype shape
-- ============================================================================
describe("environmental scanner (prototype shape)", function()
  it("is a buildable, craftable constant-combinator", function()
    local e = prototypes.entity[C.SCANNER]
    assert.is_not_nil(e, "scanner entity must exist")
    assert.are.equal("constant-combinator", e.type)
    assert.is_not_nil(prototypes.item[C.SCANNER], "scanner item must exist")
    assert.is_not_nil(prototypes.recipe[C.SCANNER], "scanner recipe must exist")
  end)

  it("has a chemistry-free recipe (Cindra zero-chemistry identity)", function()
    local recipe = prototypes.recipe[C.SCANNER]
    for _, ing in pairs(recipe.ingredients) do
      assert.is_falsy(FORBIDDEN[ing.name],
        "scanner recipe must not use chemistry input: " .. ing.name)
    end
  end)

  it("defines all of its virtual signals", function()
    for _, name in ipairs(C.SIGNAL_ORDER) do
      assert.is_not_nil(prototypes.virtual_signal[name],
        "virtual signal must exist: " .. name)
    end
  end)
end)

-- ============================================================================
-- Runtime: signal output
-- ============================================================================
describe("environmental scanner (runtime)", function()
  local surface

  local function fresh_surface(name)
    local s = game.surfaces[name]
    if not s then s = game.create_surface(name, { width = 96, height = 96 }) end
    s.freeze_daytime = true
    for _, e in pairs(s.find_entities_filtered({ area = { { -40, -40 }, { 40, 40 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
    local tiles = {}
    for x = -12, 12 do
      for y = -12, 12 do tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } } end
    end
    s.set_tiles(tiles)
    return s
  end

  before_each(function()
    surface = fresh_surface("env-scanner-test")
    forecast.clear_provider()       -- default (no flare) unless a test injects one
    storage.es = { scanners = {} }
  end)

  after_each(function()
    forecast.clear_provider()
  end)

  local function build_scanner(pos)
    local e = surface.create_entity({
      name = C.SCANNER, position = pos or { 0, 0 }, force = "player", raise_built = true,
    })
    assert.is_not_nil(e, "scanner must place")
    return e
  end

  -- Read a signal back out of the scanner's constant-combinator output section.
  -- Exercises the real control-behavior API the runtime writes through. Returns
  -- nil when the signal is absent.
  local function output(entity, signal_name)
    local behavior = entity.get_or_create_control_behavior()
    local section = behavior.get_section(1)
    if not section then return nil end
    for _, f in pairs(section.filters) do
      if f.value and f.value.name == signal_name then return f.min end
    end
    return nil
  end

  -- A circuit network treats an absent signal as 0, and a constant combinator
  -- may drop a slot written with value 0. So for readouts whose value can be 0,
  -- absence and 0 are equivalent -- read them as 0.
  local function output0(entity, signal_name)
    return output(entity, signal_name) or 0
  end

  it("building a scanner registers it for updates", function()
    local e = build_scanner({ 0, 0 })
    assert.is_not_nil(storage.es.scanners[e.unit_number],
      "runtime must track the scanner after build")
  end)

  it("outputs full daylight and solar at noon", function()
    local e = build_scanner({ 0, 0 })
    surface.daytime = 0.0  -- noon
    scanner.update(e)
    assert.are.equal(100, output0(e, S.DAYLIGHT), "noon = 100% daylight")
    assert.are.equal(0, output0(e, S.DAYTIME), "noon position = 0 permille")
    -- Solar output = daylight * surface multiplier; on a normal surface (1x) = daylight.
    local expected_solar = readings.surface_signals(
      surface.daytime, surface.solar_power_multiplier, C.DAY_TICKS,
      { dusk = surface.dusk, evening = surface.evening, morning = surface.morning, dawn = surface.dawn }
    )[S.SOLAR]
    assert.are.equal(expected_solar, output0(e, S.SOLAR), "solar output matches the pure maths")
  end)

  it("outputs darkness at midnight and updates as the day advances", function()
    local e = build_scanner({ 0, 0 })
    surface.daytime = 0.0
    scanner.update(e)
    local day_daylight = output0(e, S.DAYLIGHT)

    surface.daytime = 0.5  -- midnight
    scanner.update(e)
    assert.are.equal(0, output0(e, S.DAYLIGHT), "midnight = 0% daylight")
    assert.are.equal(0, output0(e, S.SOLAR), "midnight = 0% solar")
    assert.are.equal(500, output0(e, S.DAYTIME), "midnight position = 500 permille")
    assert.is_true(day_daylight > output0(e, S.DAYLIGHT),
      "daylight signal must fall from day to night")
  end)

  it("emits NO flare signals with no provider (graceful degrade)", function()
    local e = build_scanner({ 0, 0 })
    surface.daytime = 0.0
    scanner.update(e)
    assert.is_nil(output(e, S.FLARE_COUNTDOWN), "no flare countdown without a provider")
    assert.is_nil(output(e, S.FLARE_PHASE))
    assert.is_nil(output(e, S.FLARE_INTENSITY))
  end)

  it("emits the flare forecast when a provider is present", function()
    -- Simulate Cindra's flare system supplying a warning-phase forecast.
    forecast.set_provider(function(_)
      return { countdown = 780, phase = "warning", intensity = 1.0 }
    end)
    local e = build_scanner({ 0, 0 })
    surface.daytime = 0.0
    scanner.update(e)

    assert.are.equal(780, output(e, S.FLARE_COUNTDOWN), "countdown emitted")
    assert.are.equal(readings.PHASE_CODE.warning, output(e, S.FLARE_PHASE), "phase code emitted")
    assert.are.equal(100, output(e, S.FLARE_INTENSITY), "baseline intensity = 100%")
    -- The generic signals are still present alongside the flare block.
    assert.are.equal(100, output0(e, S.DAYLIGHT), "generic signals coexist with flare block")
  end)

  it("clears the flare block when the forecast goes inactive", function()
    forecast.set_provider(function(_)
      return { countdown = 0, phase = "plateau", intensity = 100.0 }
    end)
    local e = build_scanner({ 0, 0 })
    scanner.update(e)
    assert.are.equal(10000, output(e, S.FLARE_INTENSITY), "peak intensity while active")

    -- Flare passes / provider stops answering: the block must disappear.
    forecast.set_provider(function(_) return nil end)
    scanner.update(e)
    assert.is_nil(output(e, S.FLARE_INTENSITY), "flare block cleared on next update")
    assert.are.equal(100, output0(e, S.DAYLIGHT), "generic signals remain")
  end)

  it("mining a scanner stops tracking it", function()
    local e = build_scanner({ 0, 0 })
    local un = e.unit_number
    e.destroy({ raise_destroy = true })
    assert.is_nil(storage.es.scanners[un], "destroyed scanner must be forgotten")
  end)

  it("the periodic sweep refreshes tracked scanners", function()
    local e = build_scanner({ 0, 0 })
    surface.daytime = 0.5
    scanner.update_all()  -- what on_nth_tick calls
    assert.are.equal(0, output0(e, S.DAYLIGHT), "sweep wrote the current (midnight) reading")
    assert.are.equal(500, output0(e, S.DAYTIME))
  end)
end)
