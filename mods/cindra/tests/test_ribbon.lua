-- Proof: the ribbon temperature axis (scripts/ribbon.lua) is the single source
-- of truth for Cindra's hot-cold axis, and it behaves per §4 / §16 under the real
-- Factorio Lua runtime (a matching plain-Lua unit test in unit-tests/test_ribbon
-- covers the same maths off the game entirely).
--
-- ci-a35: the temperate reference is the SAND-band spawn (`ref`), with asymmetric
-- reaches to each void edge, derived from the per-zone gradient (scripts/zones).
-- Player-facing environmental damage is now the TILE damage (tests/test_tile_damage),
-- so ribbon maps a perpendicular coordinate to a temperature and a solar fraction.

local ribbon = require("scripts.ribbon")
local zones = require("scripts.zones")

describe("ribbon temperature axis (§4; ci-a35)", function()
  local GEO = zones.geometry()
  local REF = GEO.ref

  it("is room temperature at the sand spawn reference", function()
    assert.are.equal(25, ribbon.temperature(REF), "the sand-band centre is temperate")
  end)

  it("rises toward heat sunward and falls toward cold nightward of the spawn", function()
    local center = ribbon.temperature(REF)
    assert.is_true(ribbon.temperature(REF + 60) > center, "sunward must be hotter than the spawn")
    assert.is_true(ribbon.temperature(REF - 60) < center, "nightward must be colder than the spawn")
    assert.is_true(ribbon.temperature(GEO.hot_edge_p) > ribbon.temperature(REF + 40),
      "hotter further sunward")
    assert.is_true(ribbon.temperature(GEO.cold_edge_p) < ribbon.temperature(REF - 40),
      "colder further nightward")
  end)

  it("saturates at each void edge (asymmetric endpoints: fire one way, ice the other)", function()
    assert.are.equal(1500, ribbon.temperature(GEO.hot_edge_p), "hot edge = temp_hot_max")
    assert.are.equal(-270, ribbon.temperature(GEO.cold_edge_p), "cold edge = temp_cold_min")
    assert.are.equal(ribbon.temperature(GEO.hot_edge_p), ribbon.temperature(GEO.hot_edge_p + 500),
      "no runaway beyond the hot edge")
    assert.are.equal(ribbon.temperature(GEO.cold_edge_p), ribbon.temperature(GEO.cold_edge_p - 500),
      "no runaway beyond the cold edge")
  end)

  it("delivers full solar deep sunward and ~nothing deep nightward", function()
    assert.are.equal(1.0, ribbon.sunward_factor(GEO.hot_damage_start), "full sun on the fire margin")
    assert.are.equal(0.0, ribbon.sunward_factor(GEO.cold_damage_start), "floor at the freeze boundary")
    assert.is_true(ribbon.sunward_factor(REF + (GEO.hot_reach * 0.5))
      > ribbon.sunward_factor(REF - (GEO.cold_reach * 0.5)) + 0.2,
      "a sunward panel materially out-produces a nightward one")
  end)

  it("honours a partial config override (settings-driven tuning)", function()
    local cfg = { ref = 0, hot_reach = 100, cold_reach = 100 }
    assert.are.equal(25, ribbon.temperature(0, cfg), "custom reference is temperate")
    assert.is_true(ribbon.temperature(-50, cfg) < 25, "nightward of the custom ref is colder")
  end)
end)
