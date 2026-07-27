-- PROOF: the power system's prototypes exist, are craftable + tech-gated, and
-- the EXPORTABLE storage buildings are situational-not-strictly-better than a
-- vanilla accumulator (§12 guardrail). §15 item 9 (capacitor, molten-salt
-- battery, dissipator). Mirrors the electric-heater proto test.
--
-- Cindra reuses the PLAIN VANILLA solar panel (ci-8al); there is NO bespoke
-- Cindra panel tier. This suite asserts that removal held (no custom panel
-- prototype, no unlock tech), and that the FULL band the flare systems target
-- (C.PANEL) is literally the vanilla panel.

local C = require("scripts.flare-config")
local panel_solar = require("scripts.panel-solar")

local function unlocks(tech_name, recipe_name)
  local tech = prototypes.technology[tech_name]
  if not tech then return false end
  for _, e in pairs(tech.effects) do
    if e.type == "unlock-recipe" and e.recipe == recipe_name then return true end
  end
  return false
end

describe("power system prototypes", function()
  it("uses the plain vanilla solar panel (no custom Cindra panel tier)", function()
    -- The flare systems target C.PANEL; it must be the vanilla panel itself.
    assert.are.equal("solar-panel", C.PANEL, "the flare systems target the vanilla panel")
    assert.is_not_nil(prototypes.entity["solar-panel"], "the vanilla solar panel must exist")

    -- The removed custom panel (ci-8al): no entity / item / recipe of that name.
    assert.is_nil(prototypes.entity["cindra-solar-panel"],
      "the custom cindra-solar-panel entity must NOT exist (removed in ci-8al)")
    assert.is_nil(prototypes.item["cindra-solar-panel"],
      "the custom cindra-solar-panel item must NOT exist")
    assert.is_nil(prototypes.recipe["cindra-solar-panel"],
      "the custom cindra-solar-panel recipe must NOT exist")

    -- Its unlock tech is gone too, and nothing left behind unlocks it.
    assert.is_nil(prototypes.technology["cindra-flare-power"],
      "the cindra-flare-power tech must NOT exist (removed in ci-8al)")
    for _, tech in pairs(prototypes.technology) do
      assert.is_false(unlocks(tech.name, "cindra-solar-panel"),
        "no tech may unlock the removed cindra-solar-panel recipe (dangling): " .. tech.name)
    end
  end)

  it("registers reduced sunward-band variants as cindra clones of the vanilla panel", function()
    local vanilla = prototypes.entity["solar-panel"]
    local vanilla_out = vanilla.get_max_energy_production()

    local reduced = 0
    for _, f in ipairs(panel_solar.BANDS) do
      if f < 1.0 then
        reduced = reduced + 1
        local name = panel_solar.name_for_band(f)
        local v = prototypes.entity[name]
        assert.is_not_nil(v, "reduced band variant must exist: " .. name)
        assert.are.equal("solar-panel", v.type, name .. " must be a solar panel")
        -- Reduced output: a band strictly below the full (vanilla) panel, so a
        -- nightward panel never out-produces a sunward one.
        assert.is_true(v.get_max_energy_production() < vanilla_out,
          name .. " must produce LESS than the vanilla full band")
        -- Mines back to the vanilla item: the player only ever holds vanilla
        -- panels; a morphed variant returns the vanilla item.
        assert.are.equal("solar-panel", v.mineable_properties.products[1].name,
          name .. " must mine back to the vanilla solar-panel item")
        -- Variants have NO item / recipe of their own (never crafted directly).
        assert.is_nil(prototypes.recipe[name], name .. " must have no recipe of its own")
      end
    end
    assert.is_true(reduced >= 1, "there must be at least one reduced sunward band")
  end)

  -- The runtime prototype API exposes an accumulator's buffer_capacity but NOT
  -- its flow limits, so the guardrail asserts the readable intrinsic tradeoff
  -- (buffer size) plus the config-level flow/upkeep facts. The flow numbers
  -- themselves are locked by scripts/flare-config.lua and exercised live by the
  -- storage + catchability tests.
  it("registers the capacitor as a TINY, very-high-rate spike catcher (ci-wcu tuning)", function()
    local cap = prototypes.entity[C.CAPACITOR]
    assert.is_not_nil(cap, "cindra-capacitor entity must exist")
    assert.are.equal("accumulator", cap.type)

    -- Exact ci-wcu tuning: storage 0.5 MJ; max charge AND discharge 50 MW.
    assert.are.equal(0.5e6, C.CAPACITOR_BUFFER_J, "capacitor buffer must be 0.5 MJ")
    assert.are.equal(50e6, C.CAPACITOR_FLOW_W, "capacitor flow must be 50 MW")
    assert.are.equal(0.5e6, cap.electric_energy_source_prototype.buffer_capacity,
      "capacitor prototype buffer must be 0.5 MJ")

    local vanilla = prototypes.entity["accumulator"].electric_energy_source_prototype.buffer_capacity
    -- Situational-not-strictly-better (§12): a far SMALLER buffer than a plain
    -- accumulator (a poor reservoir), traded for a much higher flow (verified
    -- live in test_storage). Tiny, very high rate.
    assert.is_true(C.CAPACITOR_BUFFER_J < vanilla,
      "capacitor buffer must be SMALLER than a vanilla accumulator's (not a reservoir)")
    assert.is_true(C.CAPACITOR_FLOW_W > C.CAPACITOR_BUFFER_J,
      "capacitor flow (spike) must dwarf its buffer")
  end)

  it("registers the molten-salt battery as large-ish/slow/CHEAP/LEAKY (ci-wcu tuning)", function()
    local bat = prototypes.entity[C.BATTERY]
    assert.is_not_nil(bat, "cindra-molten-salt-battery entity must exist")
    assert.are.equal("accumulator", bat.type)

    -- Exact ci-wcu tuning: storage 2.5 MJ; max inflow AND discharge 150 kW.
    assert.are.equal(2.5e6, C.BATTERY_BUFFER_J, "battery buffer must be 2.5 MJ")
    assert.are.equal(150e3, C.BATTERY_FLOW_W, "battery flow must be 150 kW")
    assert.are.equal(2.5e6, bat.electric_energy_source_prototype.buffer_capacity,
      "battery prototype buffer must be 2.5 MJ")

    local vanilla = prototypes.entity["accumulator"].electric_energy_source_prototype.buffer_capacity
    -- Situational-not-strictly-better (§12): its buffer AND its flow are BOTH
    -- below a vanilla accumulator's, so on raw specs it is strictly worse. Its
    -- upside is a CHEAP recipe (asserted below) and its downside a heat-upkeep
    -- self-discharge (scripts/sinks.lua, verified live in test_storage).
    assert.is_true(C.BATTERY_BUFFER_J < vanilla,
      "battery buffer must be below a vanilla accumulator's (not bulk-superior)")
    assert.is_true(C.BATTERY_FLOW_W < 300e3,
      "battery throughput must be below a vanilla accumulator's 300 kW (slow)")
    assert.is_true(C.BATTERY_FLOW_W < C.CAPACITOR_FLOW_W,
      "battery throughput must be lower than the capacitor's (slow, not a spike buffer)")
    assert.is_true(C.BATTERY_UPKEEP_FRACTION > 0,
      "battery must pay a heat-upkeep self-discharge (a downside vanilla lacks)")

    -- CHEAP: the molten-salt battery is a thermal store and uses NO chemical
    -- `battery` item, unlike the vanilla accumulator (2 iron + 5 battery) and the
    -- capacitor. That is what makes it the cheap budget option.
    local recipe = prototypes.recipe[C.BATTERY]
    for _, ing in pairs(recipe.ingredients) do
      assert.are_not.equal("battery", ing.name,
        "the cheap molten-salt battery must not require chemical `battery` items")
    end
  end)

  it("registers the dissipator as a pure power consumer (the safe-waste fuse)", function()
    local d = prototypes.entity[C.DISSIPATOR]
    assert.is_not_nil(d, "cindra-dissipator entity must exist")
    assert.are.equal("electric-energy-interface", d.type)
    assert.is_not_nil(d.electric_energy_source_prototype, "the dissipator draws electricity")
  end)

  it("places capacitor + battery next to the vanilla accumulator, dissipator last (ci-wcu)", function()
    local acc = prototypes.item["accumulator"]
    local cap = prototypes.item[C.CAPACITOR]
    local bat = prototypes.item[C.BATTERY]
    local diss = prototypes.item[C.DISSIPATOR]

    -- Same crafting-tab subgroup as the vanilla accumulator, so they sit in one
    -- group in the production tab.
    local sub = acc.subgroup.name
    assert.are.equal(sub, cap.subgroup.name, "capacitor must share the accumulator subgroup")
    assert.are.equal(sub, bat.subgroup.name, "molten-salt battery must share the accumulator subgroup")
    assert.are.equal(sub, diss.subgroup.name, "dissipator must share the accumulator subgroup")

    -- Ordered right after the accumulator: accumulator < capacitor < battery, and
    -- the dissipator closes the group (last of the four).
    assert.is_true(acc.order < cap.order, "capacitor must sort after the accumulator")
    assert.is_true(cap.order < bat.order, "battery must sort after the capacitor")
    assert.is_true(bat.order < diss.order, "dissipator must sort after the battery")
    for _, other in ipairs({ acc, cap, bat }) do
      assert.is_true(other.order < diss.order,
        "dissipator must be LAST in the group (after " .. other.name .. ")")
    end
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
