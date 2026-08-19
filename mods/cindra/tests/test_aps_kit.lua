-- Proof: a start-on-Cindra game lands with a MINIMAL bootstrap kit (ci-8wu) and
-- that kit rides INSIDE the crash-site spaceship APS drops on the surface
-- (ci-q6nh) -- not in a separate chest beside it. The two machines that are
-- painful to hand-bootstrap (a foundry + the lava caster that feeds it) plus
-- basic power, loaded into the wreck the player instinctively opens, with the
-- ship's default ammo stripped to make room (Cindra has nothing to shoot at
-- start, and the wreck only has five slots). This suite runs ONLY in the APS
-- invocation (see control.lua); the plain `mods/cindra` run does not load
-- cindra-start, so it never executes there.
--
-- The in-game flow (cargo-pod cutscene timing, walking up to the wreck, feel)
-- stays a PLAYTEST item -- that needs a real player-created cutscene. What is
-- proven here is the thing a test CAN pin: cindra-start's ship stocker (its
-- `stock_ship`, reached through the `cindra-start` remote seam) turns a stock
-- crashed ship into the intended MINIMAL kit container, and spawns no chest
-- doing it. The runtime path calls the exact same function, so the tested path
-- is the shipped one.

local H = require("tests.helpers")

local SHIP = "crash-site-spaceship"

-- The crashed ship as APS hands it over: base freeplay's cargo is 8 firearm
-- magazines (any-planet-start/control.lua forwards `get_ship_items`), so every
-- test here starts from that exact state.
local SHIP_AMMO = "firearm-magazine"
local SHIP_AMMO_COUNT = 8

local function place_crashed_ship(s, position)
  local ship = s.create_entity({ name = SHIP, position = position, force = "player" })
  assert.is_not_nil(ship, "the crash-site spaceship must be placeable for this suite")
  ship.get_inventory(defines.inventory.chest).insert({ name = SHIP_AMMO, count = SHIP_AMMO_COUNT })
  return ship
end

local function ship_inventory(ship)
  return ship.get_inventory(defines.inventory.chest)
end

-- The describe name shares the "cindra APS start chain" prefix so the documented
-- filtered APS invocation (`-- "cindra APS start chain"`, see README) runs it
-- alongside the other APS-start suites.
describe("cindra APS start chain: bootstrap kit in the crashed ship", function()
  it("only applies to a Cindra start (sanity)", function()
    assert.is_true(H.aps_loaded(), "APS must be active for this suite")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    assert.is_true(H.aps_cindra_start(),
      "this suite asserts the Cindra-start kit; the picker must be Cindra")
  end)

  it("exposes the ship stocker as a cindra-start remote (the tested = shipped seam)", function()
    assert.is_not_nil(remote.interfaces["cindra-start"],
      "cindra-start must register its remote interface")
    assert.is_not_nil(remote.interfaces["cindra-start"]["stock_bootstrap_ship"],
      "the ship stocker must be callable (the runtime path calls the same function)")
    assert.is_nil(remote.interfaces["cindra-start"]["spawn_bootstrap_kit"],
      "the old chest-capsule spawner is gone: the kit lives in the ship now (ci-q6nh)")
  end)

  it("stocks the crashed ship itself -- no chest capsule beside it", function()
    local s = H.cindra_surface()
    local ship = place_crashed_ship(s, { 0, 0 })

    local containers_before = #s.find_entities_filtered({ type = "container" })
    assert.is_true(remote.call("cindra-start", "stock_bootstrap_ship", s.index),
      "stocking must find the crashed ship and report success")

    local inv = ship_inventory(ship)
    assert.is_false(inv.is_empty(), "the wreck must hold the kit, not be left empty")
    -- The whole point of ci-q6nh: the kit relocated INTO the ship, so stocking
    -- must not add a single container to the surface (the ship was already there).
    assert.are.equal(containers_before, #s.find_entities_filtered({ type = "container" }),
      "no extra container may appear: the kit goes in the ship, not in a chest beside it")
    ship.destroy()
  end)

  it("drops the ship's ammo to make room (nothing to shoot on Cindra)", function()
    local s = H.cindra_surface()
    local ship = place_crashed_ship(s, { 0, 0 })
    assert.are.equal(SHIP_AMMO_COUNT, ship_inventory(ship).get_item_count(SHIP_AMMO),
      "sanity: the ship starts with base freeplay's ammo cargo")

    remote.call("cindra-start", "stock_bootstrap_ship", s.index)

    local inv = ship_inventory(ship)
    assert.are.equal(0, inv.get_item_count(SHIP_AMMO),
      "the ship's magazines must be gone: dead weight, and they cost the kit a slot")
    for _, item in pairs(inv.get_contents()) do
      local proto = prototypes.item[item.name]
      assert.are_not.equal("ammo", proto and proto.type,
        "no ammo may survive in the ship (" .. item.name .. ")")
    end
    ship.destroy()
  end)

  it("stocks the two hard-to-bootstrap machines + basic power (eases the opening)", function()
    local s = H.cindra_surface()
    local ship = place_crashed_ship(s, { 0, 0 })
    remote.call("cindra-start", "stock_bootstrap_ship", s.index)
    local inv = ship_inventory(ship)

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
    ship.destroy()
  end)

  it("fits ENTIRELY in the wreck's five slots (nothing silently dropped)", function()
    local s = H.cindra_surface()
    local ship = place_crashed_ship(s, { 0, 0 })
    remote.call("cindra-start", "stock_bootstrap_ship", s.index)
    local inv = ship_inventory(ship)

    -- `crash-site-spaceship` has inventory_size 5, and insert() fails SILENTLY
    -- once the slots run out -- a sixth kit entry would vanish with no error. So
    -- assert the shipped manifest arrives item for item.
    local kit = remote.call("cindra-start", "get_bootstrap_kit")
    for _, stack in pairs(kit) do
      assert.are.equal(stack.count, inv.get_item_count(stack.name),
        "the whole kit must fit in the ship: " .. stack.name .. " is short (slots exhausted?)")
    end
    assert.is_true(#kit <= #inv,
      "the kit is " .. #kit .. " stacks but the wreck only has " .. #inv .. " slots")
    ship.destroy()
  end)

  it("stays MINIMAL: it eases the opening, it is not a free economy", function()
    local s = H.cindra_surface()
    local ship = place_crashed_ship(s, { 0, 0 })
    remote.call("cindra-start", "stock_bootstrap_ship", s.index)
    local inv = ship_inventory(ship)

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
    assert.is_true(types <= 5, "the kit must fit the wreck's five slots (got " .. types .. " types)")
    ship.destroy()
  end)

  it("delivers on LANDING, through the gate the runtime uses (ci-e9sj)", function()
    -- The two seams above deliberately bypass cindra-start's `is_cindra_start()`
    -- gate so they can pin the kit's CONTENTS. This one goes THROUGH it, replaying
    -- the on_player_created path: on a Cindra start the wreck must come out
    -- stocked. tests/test_aps_offered runs the same call in the world where APS is
    -- installed but Cindra was not chosen and asserts the opposite, so the gate is
    -- proven in both directions instead of assumed.
    local s = H.cindra_surface()
    local ship = place_crashed_ship(s, { 0, 0 })
    local player = game.players[1]
    assert.is_not_nil(player, "this assertion needs a player")

    assert.is_true(remote.call("cindra-start", "simulate_player_landing", player.index),
      "landing on a Cindra start must deliver the kit")
    assert.is_true(ship_inventory(ship).get_item_count("foundry") >= 1,
      "the wreck the player lands next to must hold the kit's foundry")
    ship.destroy()
  end)

  it("falls back to the player's inventory when there is no crashed ship", function()
    -- freeplay's crash site can be disabled (APS honours `disable_crashsite`), and
    -- a from-scratch Cindra start with no kit at all is a soft-lock. The fallback
    -- hands the same kit over directly -- still no chest entity anywhere.
    local player = game.players[1]
    assert.is_not_nil(player, "this fallback assertion needs a player")
    local inv = player.get_main_inventory()
    local before = inv.get_item_count("foundry")

    assert.is_true(remote.call("cindra-start", "give_bootstrap_kit_to_player", player.index),
      "the fallback must report that it handed the kit over")
    assert.are.equal(before + 1, inv.get_item_count("foundry"),
      "the player must receive the kit's foundry when no ship exists")
    assert.is_true(inv.get_item_count("cindra-lava-manufacturer") >= 1,
      "and the lava caster with it")

    for _, stack in pairs(remote.call("cindra-start", "get_bootstrap_kit")) do
      inv.remove({ name = stack.name, count = stack.count })
    end
  end)
end)
