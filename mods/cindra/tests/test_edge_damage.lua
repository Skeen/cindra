-- Proof: the lethal-edge damage (scripts/edge-damage.lua) turns the ribbon axis
-- into real ticking damage on characters standing on Cindra. §15 item 2.
--
-- The pure axis (scripts/ribbon.lua) is proven in test_ribbon; this proves the
-- CONSUMER: heat sunward, cold nightward, none in the safe band, scaling with
-- distance and time, applied to live characters on the cindra surface only.

local H = require("tests.helpers")
local edge = require("scripts.edge-damage")

describe("lethal-edge damage (§15-2)", function()
  it("maps sunward damage to heat and nightward to cold", function()
    local _, hot = edge.damage_for(60, edge.DAMAGE_INTERVAL)
    local _, cold = edge.damage_for(-60, edge.DAMAGE_INTERVAL)
    assert.are.equal("cindra-heat", hot, "sunward -> heat damage type")
    assert.are.equal("cindra-cold", cold, "nightward -> cold damage type")
    local amt, dtype = edge.damage_for(0, edge.DAMAGE_INTERVAL)
    assert.are.equal(0, amt, "no damage in the safe band")
    assert.is_nil(dtype, "no damage type in the safe band")
  end)

  it("scales damage with distance into the zone and with elapsed time", function()
    local mid = edge.damage_for(60, 20)
    local deep = edge.damage_for(200, 20)
    assert.is_true(deep > mid, "deeper into the lethal edge hurts more")
    -- Twice the interval -> twice the HP (dps * seconds).
    local one = edge.damage_for(200, 20)
    local two = edge.damage_for(200, 40)
    assert.is_true(math.abs(two - 2 * one) < 1e-6, "damage is linear in time")
  end)

  it("damages characters in the margins but spares the safe band", function()
    local s = H.cindra_surface()
    storage.cindra_driver_enabled = false -- only our explicit sweep applies

    local safe = s.create_entity({ name = "character", position = { 0, 0 }, force = "player" })
    local warm = s.create_entity({ name = "character", position = { 10, 40 }, force = "player" })
    local cold = s.create_entity({ name = "character", position = { -10, -40 }, force = "player" })
    assert.is_not_nil(safe); assert.is_not_nil(warm); assert.is_not_nil(cold)

    local h_safe, h_warm, h_cold = safe.health, warm.health, cold.health

    edge.sweep(s, edge.DAMAGE_INTERVAL)

    assert.are.equal(h_safe, safe.health, "the temperate ribbon deals no damage")
    assert.is_true(warm.health < h_warm, "the sunward margin cooks the character")
    assert.is_true(cold.health < h_cold, "the nightward margin freezes the character")

    storage.cindra_driver_enabled = true
  end)

  it("never touches a character on another planet", function()
    local nauvis = game.surfaces["nauvis"]
    local char = nauvis.create_entity({ name = "character", position = { 0, 40 }, force = "player" })
    local before = char.health
    edge.sweep(nauvis) -- wrong surface: must be a no-op
    assert.are.equal(before, char.health, "edge damage is Cindra-only")
    char.destroy()
  end)
end)
