-- Proof: a start-on-Cindra game arrives with the foundry path already unlocked,
-- so the from-nothing player never soft-locks (ci-arw). This suite runs ONLY in
-- the APS invocation (see control.lua): the plain `mods/cindra` run does not load
-- cindra-start, so it never executes there.
--
-- The mechanism: cindra-start/control.lua pre-researches a tech chain on every
-- force when the chosen APS start is Cindra. That grant is what turns the
-- prototypes proven in test_foundry_bootstrap into something the player can
-- actually use at tick zero -- with no Vulcanus to import from and no science yet
-- to research it themselves. Here we assert the grant took effect on the live
-- player force.

-- The describe name shares the "cindra APS start chain" prefix so the documented
-- filtered APS invocation (`-- "cindra APS start chain"`, see README) runs it
-- alongside test_aps_start.
describe("cindra APS start chain: foundry path pre-researched (no soft-lock)", function()
  it("only applies to a Cindra start (sanity)", function()
    assert.is_not_nil(script.active_mods["any-planet-start"], "APS must be active for this suite")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    assert.are.equal("cindra", settings.startup["aps-planet"].value,
      "this suite asserts the Cindra-start pre-research; the picker must be Cindra")
  end)

  it("hands the player force the improvised-metallurgy tech at tick zero", function()
    local force = game.forces["player"]
    assert.is_true(force.technologies["cindra-improvised-metallurgy"].researched,
      "a Cindra start must arrive with improvised metallurgy already researched")
  end)

  it("makes the native lubricant + field foundry craftable from the start", function()
    local force = game.forces["player"]
    -- The soft-lock rescue in action: with no research done by the player, the
    -- native lubricant and the Cindra-buildable foundry are already available.
    assert.is_true(force.recipes["cindra-crude-lubricant"].enabled,
      "crude lubricant (coal -> lubricant) must be craftable from tick zero")
    assert.is_true(force.recipes["cindra-mineral-lubricant"].enabled,
      "mineral lubricant (the renewable sustain) must be craftable from tick zero")
    assert.is_true(force.recipes["cindra-field-foundry"].enabled,
      "the Cindra-buildable field foundry must be craftable from tick zero")
  end)

  it("also arrives with the rest of the lava->metal spine (so the economy is reachable)", function()
    local force = game.forces["player"]
    -- foundry tech unlocks the molten-iron/copper-from-lava recipes; cindra-lava
    -- is the spine recipe; ice processing supplies water (for renewable lubricant)
    -- and calcite (for the molten recipes). Pre-researching the chain is what lets
    -- a from-scratch start reach the metal economy with no chicken-and-egg.
    assert.is_true(force.technologies["foundry"].researched,
      "the foundry tech (molten-metal recipes) must be pre-researched")
    assert.is_true(force.recipes["cindra-lava"].enabled,
      "manufactured lava must be craftable from the start")
    -- Since ci-e8a lava is crafted on a dedicated caster, not the foundry. The
    -- cindra-lava tech unlocks both, so pre-researching it also hands the caster
    -- (else a Cindra start could research lava but have nothing to craft it in).
    assert.is_true(force.recipes["cindra-lava-manufacturer"].enabled,
      "the lava manufacturer (the machine that crafts lava) must be craftable from the start")
    assert.is_true(force.recipes["molten-iron-from-lava"].enabled,
      "the molten-iron recipe (foundry tech) must be available")
  end)
end)
