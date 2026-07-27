-- Proof: the ribbon temperature axis (scripts/ribbon.lua) is the single source
-- of truth for Cindra's hot-cold axis, and it behaves per §4 / §16. The module
-- is pure, so this asserts it under the real Factorio Lua runtime (a matching
-- plain-Lua unit test in unit-tests/test_ribbon.lua covers the same maths off
-- the game entirely).

local ribbon = require("scripts.ribbon")

describe("ribbon temperature axis (§4)", function()
  it("is temperate and damage-free in the central safe band", function()
    for _, y in pairs({ -24, -10, 0, 10, 24 }) do
      assert.are.equal("safe", ribbon.zone(y), "y=" .. y .. " must be in the safe band")
      assert.are.equal(0, (ribbon.damage_per_second(y)), "y=" .. y .. " must take no damage")
    end
  end)

  it("rises toward heat sunward and falls toward cold nightward", function()
    local center = ribbon.temperature(0)
    assert.is_true(ribbon.temperature(100) > center, "sunward (+Y) must be hotter than centre")
    assert.is_true(ribbon.temperature(-100) < center, "nightward (-Y) must be colder than centre")
    -- Symmetric geometry, asymmetric endpoints (fire one way, ice the other).
    assert.is_true(ribbon.temperature(128) > ribbon.temperature(64), "hotter further sunward")
    assert.is_true(ribbon.temperature(-128) < ribbon.temperature(-64), "colder further nightward")
  end)

  it("classifies the sunward margin as heat and the nightward margin as cold", function()
    assert.are.equal("hot_warn", ribbon.zone(60), "just past the safe band, sunward")
    assert.are.equal("cold_warn", ribbon.zone(-60), "just past the safe band, nightward")
    assert.are.equal("hot_lethal", ribbon.zone(110), "deep sunward edge")
    assert.are.equal("cold_lethal", ribbon.zone(-110), "deep nightward edge")

    local _, hot_type = ribbon.damage_per_second(60)
    local _, cold_type = ribbon.damage_per_second(-60)
    assert.are.equal("heat", hot_type, "sunward damage is heat")
    assert.are.equal("cold", cold_type, "nightward damage is cold")
  end)

  it("ramps damage 0 -> max across the margin, then holds at the lethal edge", function()
    local dps_safe_edge = ribbon.damage_per_second(24)
    local dps_mid = ribbon.damage_per_second(60)
    local dps_lethal = ribbon.damage_per_second(96)
    local dps_deep = ribbon.damage_per_second(200)
    assert.are.equal(0, dps_safe_edge, "no damage at the very edge of the safe band")
    assert.is_true(dps_mid > 0 and dps_mid < dps_lethal, "damage ramps in the margin")
    assert.are.equal(dps_lethal, dps_deep, "damage saturates at the lethal edge (no runaway)")
  end)

  it("bounds the playable ribbon with a hard-wall backstop", function()
    assert.is_false(ribbon.past_wall(120), "inside the wall")
    assert.is_true(ribbon.past_wall(128), "at the wall")
    assert.is_true(ribbon.past_wall(-200), "past the wall nightward")
  end)

  it("honours a partial config override (settings-driven tuning)", function()
    local cfg = { safe_half_width = 4 }
    assert.are.equal("hot_warn", ribbon.zone(10, cfg),
      "a narrower safe band must expose y=10 to damage")
    -- Unspecified keys fall back to defaults.
    assert.are.equal("safe", ribbon.zone(0, cfg))
  end)

  it("maps positions to the perpendicular axis per orientation (v2)", function()
    -- East-west: the ribbon runs left-right, so the hot-cold axis is Y.
    assert.are.equal(40, ribbon.perp({ x = 500, y = 40 }, { orientation = "east-west" }))
    assert.are.equal(500, ribbon.along({ x = 500, y = 40 }, { orientation = "east-west" }))
    -- North-south: the ribbon runs top-bottom, so the hot-cold axis is X.
    assert.are.equal(40, ribbon.perp({ x = 40, y = 500 }, { orientation = "north-south" }))
    assert.are.equal(500, ribbon.along({ x = 40, y = 500 }, { orientation = "north-south" }))
    -- Default (no orientation) is east-west.
    assert.are.equal(40, ribbon.perp({ x = 500, y = 40 }))
  end)

  it("supports asymmetric hot vs cold zone depths (v2 sliders)", function()
    local cfg = { safe_half_width = 24, hot_lethal_at = 40, hot_wall_at = 60,
                  cold_lethal_at = 96, cold_wall_at = 200 }
    assert.are.equal("hot_lethal", ribbon.zone(50, cfg), "shallow hot zone")
    assert.are.equal("cold_warn", ribbon.zone(-50, cfg), "deep cold zone")
    assert.is_true(ribbon.past_wall(60, cfg), "sunward wall is shallow")
    assert.is_false(ribbon.past_wall(-60, cfg), "nightward wall is deep")
  end)
end)
