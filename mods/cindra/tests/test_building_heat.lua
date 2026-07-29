-- Proof: the nightside building-heat requirement (scripts/building-heat.lua)
-- freezes unheated machines past the cold threshold and thaws them when an active
-- heat source is near. §15 item 2 (Aquilo-like cold).
--
-- The cold threshold is read off the ribbon axis (single source of truth). We
-- pass an explicit cfg so the test is independent of mod settings.

local H = require("tests.helpers")
local heat = require("scripts.building-heat")
local zones = require("scripts.zones")

describe("nightside building-heat (§15-2; ci-a35)", function()
  -- The temperate reference is the SAND spawn (ref); freeze begins some tiles
  -- nightward of it. Perp = -x (vertical), so a COLD machine sits at a large
  -- positive x (deep nightward / east). freeze_temp -30.
  local REF = zones.geometry().ref
  local CFG = { safe_half_width = 24, lethal_at = 96, wall_at = 128, freeze_temp = -30 }
  -- x that maps to a genuinely cold perpendicular coordinate (deep nightward, past
  -- the freeze boundary), kept within the helper's generated + placeable area.
  local COLD_X = 110
  local s

  before_each(function()
    storage.cindra_driver_enabled = false
    s = H.cindra_surface()
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  it("classifies the cold band off the ribbon axis (nightward of the spawn)", function()
    assert.is_false(heat.is_cold(REF, CFG), "the temperate sand spawn is not cold")
    assert.is_false(heat.is_cold(REF + 40, CFG), "sunward of the spawn is not cold")
    assert.is_true(heat.is_cold(REF - 40, CFG), "the nightward margin is cold")
    assert.is_true(heat.is_cold(REF - 100, CFG), "the deep nightside is very cold")
  end)

  it("cold-damages an unheated machine in the cold nightside", function()
    local m = s.create_entity({ name = "assembling-machine-2", position = { COLD_X, 0 }, force = "player" })
    local full = m.health
    heat.sweep(s, CFG)
    assert.is_true(m.health < full, "an unheated cold-nightside machine takes cold damage")
    m.destroy()
  end)

  it("leaves a machine at the temperate spawn undamaged", function()
    -- The sand spawn is at x = -ref; a machine there is temperate.
    local m = s.create_entity({ name = "assembling-machine-2", position = { -REF, 0 }, force = "player" })
    local full = m.health
    heat.sweep(s, CFG)
    assert.are.equal(full, m.health, "the temperate spawn never cold-damages a machine")
    m.destroy()
  end)

  it("spares a machine once an active heat source arrives", function()
    local m = s.create_entity({ name = "assembling-machine-2", position = { COLD_X, 0 }, force = "player" })
    local full = m.health
    heat.sweep(s, CFG)
    local after_cold = m.health
    assert.is_true(after_cold < full, "took cold damage while unheated")

    -- Drop a heat pipe inside the heat radius (5 tiles along the long axis);
    -- further sweeps must not hurt it.
    local pipe = s.create_entity({ name = "heat-pipe", position = { COLD_X, 5 }, force = "player" })
    assert.is_not_nil(pipe, "heat pipe must place")
    heat.sweep(s, CFG)
    assert.are.equal(after_cold, m.health, "a heated machine takes no further cold damage")
    m.destroy(); pipe.destroy()
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
