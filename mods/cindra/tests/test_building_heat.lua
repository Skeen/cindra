-- Proof: the nightside building-heat requirement (scripts/building-heat.lua)
-- freezes unheated machines past the cold threshold and thaws them when an active
-- heat source is near. §15 item 2 (Aquilo-like cold).
--
-- The cold threshold is read off the ribbon axis (single source of truth). We
-- pass an explicit cfg so the test is independent of mod settings.

local H = require("tests.helpers")
local heat = require("scripts.building-heat")

describe("nightside building-heat (§15-2)", function()
  -- freeze_temp -30 => the freeze zone starts around the nightward edge of the
  -- safe band; y=-40 is cold, y=0 is temperate.
  local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128, freeze_temp = -30 }
  local s

  before_each(function()
    storage.cindra_driver_enabled = false
    s = H.cindra_surface()
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  it("classifies the cold band off the ribbon axis", function()
    assert.is_false(heat.is_cold(0, CFG), "the temperate ribbon is not cold")
    assert.is_true(heat.is_cold(-40, CFG), "the nightward margin is cold")
    assert.is_true(heat.is_cold(-120, CFG), "the deep nightside is very cold")
  end)

  it("cold-damages an unheated machine in the cold nightside", function()
    -- Default vertical orientation: cold is the nightward (+x / east) side; the
    -- perpendicular coordinate is -x, so x = 40 sits deep in the cold band.
    local m = s.create_entity({ name = "assembling-machine-2", position = { 40, 0 }, force = "player" })
    local full = m.health
    heat.sweep(s, CFG)
    assert.is_true(m.health < full, "an unheated cold-nightside machine takes cold damage")
    m.destroy()
  end)

  it("leaves a machine in the temperate ribbon undamaged", function()
    local m = s.create_entity({ name = "assembling-machine-2", position = { 0, 0 }, force = "player" })
    local full = m.health
    heat.sweep(s, CFG)
    assert.are.equal(full, m.health, "the temperate ribbon never cold-damages a machine")
    m.destroy()
  end)

  it("spares a machine once an active heat source arrives", function()
    local m = s.create_entity({ name = "assembling-machine-2", position = { 40, 0 }, force = "player" })
    local full = m.health
    heat.sweep(s, CFG)
    local after_cold = m.health
    assert.is_true(after_cold < full, "took cold damage while unheated")

    -- Drop a heat pipe inside the heat radius (5 tiles along the long axis);
    -- further sweeps must not hurt it.
    local pipe = s.create_entity({ name = "heat-pipe", position = { 40, 5 }, force = "player" })
    assert.is_not_nil(pipe, "heat pipe must place")
    heat.sweep(s, CFG)
    assert.are.equal(after_cold, m.health, "a heated machine takes no further cold damage")
    m.destroy(); pipe.destroy()
  end)

  it("the freeze-temp slider MOVES the freeze boundary (a colder threshold spares a nightward machine) (ci-xs6)", function()
    -- The other cfg tests fix freeze_temp = -30; this one varies it. A machine at
    -- perp -40 sits at ~-67 C on the axis: cold under the default -30 threshold,
    -- but a colder -100 threshold pushes the freeze boundary further nightward, so
    -- the SAME tile is no longer a freeze target. (max-dps / safe-half-width already
    -- have such effect-varies-with-slider tests; this closes the freeze_temp gap.)
    local WARM = { safe_half_width = 24, lethal_at = 96, wall_at = 128, freeze_temp = -30 }
    local COLD = { safe_half_width = 24, lethal_at = 96, wall_at = 128, freeze_temp = -100 }

    -- Pure classification: the boundary flips at the same coordinate.
    assert.is_true(heat.is_cold(-40, WARM), "perp -40 is cold under the default -30 threshold")
    assert.is_false(heat.is_cold(-40, COLD), "a colder -100 threshold moves the boundary past perp -40")

    -- Engine sweep: same machine position, the cold damage follows the slider.
    local m = s.create_entity({ name = "assembling-machine-2", position = { 40, 0 }, force = "player" })
    local full = m.health
    heat.sweep(s, COLD)
    assert.are.equal(full, m.health, "a colder freeze_temp leaves the perp-40 machine unharmed")
    heat.sweep(s, WARM)
    assert.is_true(m.health < full, "the default freeze_temp still cold-damages the same machine")
    m.destroy()
  end)

  it("never cold-damages a machine on another planet", function()
    local nauvis = game.surfaces["nauvis"]
    local m = nauvis.create_entity({ name = "assembling-machine-2", position = { 0, -40 }, force = "player" })
    local full = m.health
    heat.sweep(nauvis, CFG) -- wrong surface: no-op
    assert.are.equal(full, m.health, "building-heat is Cindra-only")
    m.destroy()
  end)
end)
