-- Proof: the ribbon axis (scripts/ribbon.lua) is the single source of truth for
-- Cindra's hot-cold TEMPERATURE curve and its SOLAR falloff, and it behaves per
-- §4 / §16. The module is pure, so this asserts it under the real Factorio Lua
-- runtime (a matching plain-Lua unit test in unit-tests/test_ribbon.lua covers the
-- same maths off the game entirely).
--
-- It does NOT own the world's boundaries. The safe band, the lethal edges and the
-- map edge all come from the heightmap and its per-zone widths (scripts/terrain.lua),
-- and the damage a player takes comes from the TILE under them
-- (scripts/tile-damage.lua). ci-7k6 deleted the band layout that used to be
-- duplicated here; the last case below keeps it deleted.

local ribbon = require("scripts.ribbon")
local terrain = require("scripts.terrain")

describe("ribbon temperature axis (§4)", function()
  it("rises toward heat sunward and falls toward cold nightward", function()
    local center = ribbon.temperature(0)
    assert.is_true(ribbon.temperature(100) > center, "sunward must be hotter than centre")
    assert.is_true(ribbon.temperature(-100) < center, "nightward must be colder than centre")
    -- Symmetric geometry, asymmetric endpoints (fire one way, ice the other).
    assert.is_true(ribbon.temperature(128) > ribbon.temperature(64), "hotter further sunward")
    assert.is_true(ribbon.temperature(-128) < ribbon.temperature(-64), "colder further nightward")
  end)

  it("stretches the whole curve when the caller widens `saturate_at`", function()
    -- scripts/damage-feedback.lua hands in the REAL ribbon half-width instead of
    -- taking the default, so the grade spans the actual world rather than saturating
    -- 128 tiles out and reading flat everywhere past that.
    local wide = { saturate_at = 400 }
    assert.are.equal(ribbon.temperature(128), ribbon.temperature(400, wide),
      "the sunward endpoint moved out to 400")
    assert.is_true(ribbon.temperature(128, wide) < ribbon.temperature(128),
      "128 tiles out is only part-way up the stretched curve")
  end)

  it("honours a partial config override (unset keys fall back to defaults)", function()
    local cfg = { saturate_at = 400 }
    assert.are.equal(25, ribbon.temperature(0, cfg), "centre is still room temperature")
    assert.are.equal(1500, ribbon.temperature(400, cfg), "the endpoint is still temp_hot_max")
  end)

  it("keeps the world's geometry in terrain.lua, not here (ci-7k6)", function()
    -- ribbon used to carry its OWN band layout -- zone()/damage_per_second()/
    -- past_wall() over safe_half_width/lethal_at/wall_at -- fed by three mod settings
    -- and read by NOTHING at runtime. Re-adding any of it re-creates a second,
    -- drifting answer to "where is this planet dangerous". The real answers:
    for _, name in pairs({ "zone", "damage_per_second", "past_wall" }) do
      assert.is_nil(ribbon[name],
        "ribbon." .. name .. " is world geometry that belongs to scripts/terrain.lua")
    end
    for _, key in pairs({ "safe_half_width", "lethal_at", "wall_at", "max_dps" }) do
      assert.is_nil(ribbon.DEFAULTS[key],
        "ribbon.DEFAULTS." .. key .. " is a band-layout knob nothing reads")
    end
    -- ...and they are answered, live, by the module that generates the world.
    assert.are.equal("heat", terrain.lethal_at(terrain.damage_bounds().hot_from),
      "terrain answers 'is this position lethal, and to which extreme'")
    assert.is_true(terrain.tile_damage("cindra-lava-hot") > 0,
      "terrain answers 'how dangerous is the ground here'")
    assert.is_true(terrain.map_gen_bounds().width > 0
      or terrain.map_gen_bounds().height > 0,
      "terrain answers 'where does the world end'")
  end)
end)
