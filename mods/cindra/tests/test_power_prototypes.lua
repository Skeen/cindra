-- PROOF: the power system's prototypes exist, are craftable + tech-gated, and
-- the EXPORTABLE storage buildings are situational-not-strictly-better than a
-- vanilla accumulator (§12 guardrail). §15 items 7 (solar panel) + 9 (capacitor,
-- molten-salt battery, dissipator). Mirrors the electric-heater proto test.

local C = require("scripts.flare-config")

local function unlocks(tech_name, recipe_name)
  local tech = prototypes.technology[tech_name]
  if not tech then return false end
  for _, e in pairs(tech.effects) do
    if e.type == "unlock-recipe" and e.recipe == recipe_name then return true end
  end
  return false
end

describe("power system prototypes", function()
  it("registers the Cindra solar panel as a higher-output solar tier", function()
    local p = prototypes.entity[C.PANEL]
    assert.is_not_nil(p, "cindra-solar-panel entity must exist")
    assert.are.equal("solar-panel", p.type)
    local vanilla = prototypes.entity["solar-panel"]
    assert.is_true(p.get_max_energy_production() > vanilla.get_max_energy_production(),
      "the Cindra panel must out-produce the vanilla solar panel (the flare tier)")
  end)

  it("gates the solar panel behind a recipe + tech (not free)", function()
    local item = prototypes.item[C.PANEL]
    assert.is_not_nil(item, "cindra-solar-panel item must exist")
    assert.are.equal(C.PANEL, item.place_result.name, "the item places the panel")

    local recipe = prototypes.recipe[C.PANEL]
    assert.is_not_nil(recipe, "cindra-solar-panel recipe must exist")
    assert.is_false(recipe.enabled, "the recipe must be unlocked by research, not free")

    assert.is_true(unlocks("cindra-flare-power", C.PANEL),
      "cindra-flare-power tech must unlock the solar panel")
    assert.is_not_nil(prototypes.technology["cindra-flare-power"].prerequisites["solar-energy"],
      "the flare-power tech is gated behind vanilla solar-energy")
  end)

  -- The runtime prototype API exposes an accumulator's buffer_capacity but NOT
  -- its flow limits, so the guardrail asserts the readable intrinsic tradeoff
  -- (buffer size) plus the config-level flow/upkeep facts. The flow numbers
  -- themselves are locked by scripts/flare-config.lua and exercised live by the
  -- storage + catchability tests.
  it("registers the capacitor as a SPIKE catcher (situational vs a vanilla accumulator)", function()
    local cap = prototypes.entity[C.CAPACITOR]
    assert.is_not_nil(cap, "cindra-capacitor entity must exist")
    assert.are.equal("accumulator", cap.type)

    local mine = cap.electric_energy_source_prototype.buffer_capacity
    local vanilla = prototypes.entity["accumulator"].electric_energy_source_prototype.buffer_capacity
    -- Situational-not-strictly-better (§12): a SMALLER buffer than a plain
    -- accumulator (a poor reservoir), traded for a much higher flow (the config
    -- spike-catcher upside, verified live in test_storage).
    assert.is_true(mine < vanilla,
      "capacitor buffer must be SMALLER than a vanilla accumulator's (not a reservoir)")
    assert.is_true(C.CAPACITOR_FLOW_W > C.CAPACITOR_BUFFER_J / 1e6 * 1e6,
      "capacitor flow (spike) is large relative to its buffer")
  end)

  it("registers the molten-salt battery as a BULK reserve (situational vs a vanilla accumulator)", function()
    local bat = prototypes.entity[C.BATTERY]
    assert.is_not_nil(bat, "cindra-molten-salt-battery entity must exist")
    assert.are.equal("accumulator", bat.type)

    local mine = bat.electric_energy_source_prototype.buffer_capacity
    local vanilla = prototypes.entity["accumulator"].electric_energy_source_prototype.buffer_capacity
    -- Situational-not-strictly-better (§12): a huge buffer (bulk), traded for an
    -- intrinsically LOWER throughput (config: BATTERY_FLOW_W < the capacitor's,
    -- verified live in test_catchability) PLUS a heat-upkeep self-discharge
    -- (scripts/sinks.lua, verified in test_storage) that a vanilla accumulator
    -- never pays.
    assert.is_true(mine > vanilla,
      "battery buffer must dwarf a vanilla accumulator's (bulk reserve)")
    assert.is_true(C.BATTERY_FLOW_W < C.CAPACITOR_FLOW_W,
      "battery throughput must be lower than the capacitor's (slow, not a spike buffer)")
    assert.is_true(C.BATTERY_UPKEEP_FRACTION > 0,
      "battery must pay a heat-upkeep self-discharge (a downside vanilla lacks)")
  end)

  it("registers the dissipator as a pure power consumer (the safe-waste fuse)", function()
    local d = prototypes.entity[C.DISSIPATOR]
    assert.is_not_nil(d, "cindra-dissipator entity must exist")
    assert.are.equal("electric-energy-interface", d.type)
    assert.is_not_nil(d.electric_energy_source_prototype, "the dissipator draws electricity")
  end)

  it("gates all three storage/disposal buildings behind one tech (not free)", function()
    for _, name in ipairs({ C.CAPACITOR, C.BATTERY, C.DISSIPATOR }) do
      local item = prototypes.item[name]
      assert.is_not_nil(item, name .. " item must exist")
      assert.are.equal(name, item.place_result.name, name .. " item places its entity")

      local recipe = prototypes.recipe[name]
      assert.is_not_nil(recipe, name .. " recipe must exist")
      assert.is_false(recipe.enabled, name .. " recipe must be research-gated, not free")

      assert.is_true(unlocks("cindra-flare-storage", name),
        "cindra-flare-storage tech must unlock " .. name)
    end
  end)
end)
