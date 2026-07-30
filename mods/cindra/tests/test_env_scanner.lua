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

  -- ci-ijk (Overseer): the scanner is a 2x2 building, not the 1x1 combinator it
  -- was cloned from. Guards the collision/selection/tile footprint override so a
  -- future edit can't silently revert it to 1x1.
  it("is a 2x2 building", function()
    local proto = prototypes.entity[SCANNER]
    assert.are.equal(2, proto.tile_width, "scanner must occupy 2 tiles wide")
    assert.are.equal(2, proto.tile_height, "scanner must occupy 2 tiles tall")
    local sb = proto.selection_box
    local w = sb.right_bottom.x - sb.left_top.x
    local h = sb.right_bottom.y - sb.left_top.y
    assert.is_true(math.abs(w - 2) < 0.01 and math.abs(h - 2) < 0.01,
      "selection box must be 2x2, got " .. w .. "x" .. h)
    local cb = proto.collision_box
    local cw = cb.right_bottom.x - cb.left_top.x
    assert.is_true(cw > 1.0 and cw <= 2.0,
      "collision box must span most of the 2x2 (got width " .. cw .. ")")
  end)

  -- ci-ijk (Overseer): the scanner must sort in the crafting menu right AFTER the
  -- programmable-speaker, in the SAME subgroup as the speaker + display-panel.
  -- Reads the REAL vanilla prototypes so this stays correct if base tweaks its
  -- own order strings.
  it("sorts after the programmable-speaker (same subgroup)", function()
    local scanner = prototypes.item[SCANNER]
    local speaker = prototypes.item["programmable-speaker"]
    local display = prototypes.item["display-panel"]
    assert.is_not_nil(speaker, "programmable-speaker item must exist")
    assert.are.equal(speaker.subgroup.name, scanner.subgroup.name,
      "scanner must share the programmable-speaker's subgroup")
    assert.is_true(scanner.order > speaker.order,
      "scanner order (" .. scanner.order .. ") must sort after speaker (" .. speaker.order .. ")")
    if display then
      assert.is_true(scanner.order < display.order,
        "scanner order (" .. scanner.order .. ") should sort before the display panel (" .. display.order .. ")")
    end
  end)
end)
