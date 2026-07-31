-- Proof: a start-on-Cindra game lands with a MINIMAL bootstrap kit (ci-8wu) --
-- a stocked supply chest ("capsule") holding the two machines that are painful
-- to hand-bootstrap (a foundry + the lava caster that feeds it) plus basic
-- power. This suite runs ONLY in the APS invocation (see control.lua); the plain
-- `mods/cindra` run does not load cindra-start, so it never executes there.
--
-- The in-game drop (cargo-pod cutscene timing, where the capsule lands, feel)
-- stays a PLAYTEST item -- that flow needs a real player-created cutscene. What
-- is proven here is the thing a test CAN pin: the kit spawner (cindra-start's
-- place_kit_chest, reached through its `cindra-start` remote seam) produces a
-- real, stocked chest with the intended MINIMAL contents. The runtime drop calls
-- the exact same function, so the tested path is the shipped one.

local H = require("tests.helpers")

-- The describe name shares the "cindra APS start chain" prefix so the documented
-- filtered APS invocation (`-- "cindra APS start chain"`, see README) runs it
-- alongside the other APS-start suites.
describe("cindra APS start chain: bootstrap kit capsule", function()
  it("only applies to a Cindra start (sanity)", function()
    assert.is_not_nil(script.active_mods["any-planet-start"], "APS must be active for this suite")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    assert.are.equal("cindra", settings.startup["aps-planet"].value,
      "this suite asserts the Cindra-start kit; the picker must be Cindra")
  end)

  it("exposes the kit spawner as a cindra-start remote (the tested = shipped seam)", function()
    assert.is_not_nil(remote.interfaces["cindra-start"],
      "cindra-start must register its remote interface")
    assert.is_not_nil(remote.interfaces["cindra-start"]["spawn_bootstrap_kit"],
      "the kit spawner must be callable (the runtime drop calls the same function)")
  end)

  it("drops a real, stocked chest on Cindra", function()
    local s = H.cindra_surface()
    local pos = remote.call("cindra-start", "spawn_bootstrap_kit", s.index, { 0, 0 }, "player")
    assert.is_not_nil(pos, "spawning the kit must return where the capsule landed")

    local chest = s.find_entity("steel-chest", pos)
    assert.is_not_nil(chest, "the kit must land as a physical container the player can open")
    local inv = chest.get_inventory(defines.inventory.chest)
    assert.is_not_nil(inv, "the capsule must have an inventory")
    assert.is_false(inv.is_empty(), "the capsule must arrive pre-stocked, not empty")
    chest.destroy()
  end)

  it("stocks the two hard-to-bootstrap machines + basic power (eases the opening)", function()
    local s = H.cindra_surface()
    local pos = remote.call("cindra-start", "spawn_bootstrap_kit", s.index, { 0, 0 }, "player")
    local chest = s.find_entity("steel-chest", pos)
    local inv = chest.get_inventory(defines.inventory.chest)

    -- The metal spine you cannot easily hand-build: a foundry (a Vulcanus-only
    -- machine, normally imported) and the lava caster that feeds it.
    assert.is_true(inv.get_item_count("foundry") >= 1,
      "the kit must hand over a foundry (the machine a from-scratch start cannot import)")
    assert.is_true(inv.get_item_count("cindra-lava-manufacturer") >= 1,
      "the kit must hand over the lava caster (so the foundry has an input)")

    -- Enough basic power to actually run them past nightfall.
    assert.is_true(inv.get_item_count("solar-panel") >= 1,
      "the kit must include a solar panel (basic power)")
    assert.is_true(inv.get_item_count("accumulator") >= 1,
      "the kit must include an accumulator (power through the night)")
    assert.is_true(inv.get_item_count("small-electric-pole") >= 1,
      "the kit must include power poles (to wire the panels in)")
    chest.destroy()
  end)

  it("stays MINIMAL: it eases the opening, it is not a free economy", function()
    local s = H.cindra_surface()
    local pos = remote.call("cindra-start", "spawn_bootstrap_kit", s.index, { 0, 0 }, "player")
    local chest = s.find_entity("steel-chest", pos)
    local inv = chest.get_inventory(defines.inventory.chest)

    -- The whole point is ONE of each expensive machine -- a leg-up, not a stack of
    -- foundries the player never has to reproduce. This guard fails loudly if the
    -- kit ever gets fattened past a bootstrap.
    assert.are.equal(1, inv.get_item_count("foundry"),
      "exactly one foundry -- the kit is a leg-up, not a free machine supply")
    assert.are.equal(1, inv.get_item_count("cindra-lava-manufacturer"),
      "exactly one lava caster -- minimal")

    -- No single stack balloons into a windfall, and the kit is a handful of item
    -- types, not a full starter base.
    local types = 0
    for _, item in pairs(inv.get_contents()) do
      types = types + 1
      assert.is_true(item.count <= 10,
        "no kit stack may exceed 10 (" .. item.name .. " = " .. item.count .. "); keep it minimal")
    end
    assert.is_true(types <= 6, "the kit must stay a handful of item types (got " .. types .. ")")
    chest.destroy()
  end)
end)
