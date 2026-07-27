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

  it("applies FIRE across the whole hot zone and FREEZE across the whole cold zone (§15 v2 item 3)", function()
    -- safe 24, lethal 96, wall 128: sand 50, molten rock 100, lava ocean 120;
    -- icy -50, ice wall -110.
    local cfg = { safe_half_width = 24, hot_lethal_at = 96, hot_wall_at = 128,
                  cold_lethal_at = 96, cold_wall_at = 128 }
    for _, p in ipairs({ 50, 100, 120 }) do
      local amt, dtype = edge.damage_for(p, edge.DAMAGE_INTERVAL, cfg)
      assert.are.equal("cindra-heat", dtype, "sunward band p=" .. p .. " deals fire")
      assert.is_true(amt > 0, "sunward band p=" .. p .. " hurts")
    end
    -- Fire escalates toward the lava ocean: sand < molten rock <= lava ocean.
    assert.is_true(edge.damage_for(100, 20, cfg) > edge.damage_for(50, 20, cfg), "molten rock > sand")
    assert.is_true(edge.damage_for(120, 20, cfg) >= edge.damage_for(100, 20, cfg), "lava >= molten rock")

    for _, p in ipairs({ -50, -110 }) do
      local amt, dtype = edge.damage_for(p, edge.DAMAGE_INTERVAL, cfg)
      assert.are.equal("cindra-cold", dtype, "nightward band p=" .. p .. " deals freeze")
      assert.is_true(amt > 0, "nightward band p=" .. p .. " hurts")
    end
    -- Freeze escalates: icy (mild) < ice wall (lethal).
    assert.is_true(edge.damage_for(-110, 20, cfg) > edge.damage_for(-50, 20, cfg), "ice wall > icy margin")

    -- SMOOTH GRADIENT (mayor add): damage strictly increases with depth across the
    -- margin on BOTH sides (a continuous ramp, not steps).
    local prev_hot, prev_cold = -1, -1
    for d = 25, 95 do
      local hot = edge.damage_for(d, 20, cfg)
      local cold = edge.damage_for(-d, 20, cfg)
      assert.is_true(hot > prev_hot, "fire strictly increases with depth at d=" .. d)
      assert.is_true(cold > prev_cold, "freeze strictly increases with depth at d=" .. d)
      prev_hot, prev_cold = hot, cold
    end
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
