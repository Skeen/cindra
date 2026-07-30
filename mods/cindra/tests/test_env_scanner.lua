-- ci-xor: the environmental scanner (radio tower) must actually exist in a
-- Cindra playtest. It was invisible in-game because the standalone env-scanner
-- mod was never loaded: play.sh's mod-list omitted it, the test harness only
-- loaded cindra, and cindra declared no dependency on it. cindra now declares a
-- required (~ env-scanner) dependency and every launch config (play.sh + this
-- harness) wires env-scanner in, so the two always load together.
--
-- This suite fails on main (env-scanner absent -> mod inactive, prototypes nil)
-- and passes on the fix. It only reads prototype/mod state, so it is planet-
-- agnostic and does not touch any other surface.

local SCANNER = "environmental-scanner" -- entity/item/recipe name (env-scanner config.SCANNER)

describe("env-scanner loads alongside cindra (ci-xor)", function()
  it("has the env-scanner mod active", function()
    assert.is_not_nil(script.active_mods["env-scanner"],
      "env-scanner must be loaded whenever cindra is (required ~ dependency)")
  end)

  it("registers the buildable scanner entity", function()
    local proto = prototypes.entity[SCANNER]
    assert.is_not_nil(proto, "environmental-scanner entity must exist")
    -- A renamed constant-combinator, so it keeps that type (native circuit output).
    assert.are.equal("constant-combinator", proto.type)
  end)

  it("registers the scanner item that places the entity", function()
    local item = prototypes.item[SCANNER]
    assert.is_not_nil(item, "environmental-scanner item must exist")
    assert.are.equal(SCANNER, item.place_result and item.place_result.name,
      "the item must place the scanner entity")
  end)

  it("exposes a craftable-from-the-start recipe", function()
    local recipe = prototypes.recipe[SCANNER]
    assert.is_not_nil(recipe, "environmental-scanner recipe must exist")
    -- enabled=true in the prototype => available without any research, so the
    -- radio tower shows in the build menu from the start (the user report).
    assert.is_true(recipe.enabled, "scanner recipe must be enabled from the start")
  end)
end)
