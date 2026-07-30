-- Proof: you cannot pave over Cindra's ribbon (ci-cbn).
--
-- The ribbon's danger is load-bearing (DESIGN.md): landfilling the lava to
-- neutralise the heat, or foundationing across the void/ice to widen the buildable
-- band, would erase the hot/cold lethal zones and the finite width the whole planet
-- is built around. So on Cindra, landfill and foundation (and every is_foundation
-- variant) must be unplaceable.
--
-- Two layers, both proven here:
--   1. DATA-STAGE GUARANTEE. Every Cindra tile is a `cindra-<vanilla>` clone, so no
--      Cindra tile name is in the vanilla landfill/foundation place_as_tile
--      tile_condition whitelist -> the engine refuses the placement outright. Proven
--      by driving the REAL player build path (build_from_cursor) and asserting the
--      tile never changes.
--   2. RUNTIME SAFETY NET (scripts/no-paving.lua). If an is_foundation tile ever
--      does land on Cindra (a future tile reusing a vanilla condition name, a
--      blueprint edge, another mod's scripted placement), it is reverted to the tile
--      it replaced and the item refunded. Proven by placing a foundation tile
--      directly and raising the build event, then asserting the revert + refund.
--
-- The safety net is gated on surface.name == "cindra"; proven not to touch nauvis.

local H = require("tests.helpers")
local no_paving = require("scripts.no-paving")

describe("cindra: no paving over the ribbon (ci-cbn)", function()
  local function player()
    return game.players[1]
  end

  -- Drive the REAL hand-build path: put `item` in the cursor, aim at `pos`, and
  -- return the tile name after the attempt. `under` is laid down first so we know
  -- exactly what a failed placement leaves behind.
  local function hand_build(s, item, pos, under)
    s.set_tiles({ { name = under, position = pos } })
    local p = player()
    p.teleport({ pos[1], pos[2] }, s)
    p.cursor_stack.set_stack({ name = item, count = 50 })
    p.build_from_cursor({ position = { pos[1], pos[2] } })
    p.cursor_stack.clear()
    return s.get_tile(pos[1], pos[2]).name
  end

  it("landfill cannot be hand-placed on Cindra ground (data-stage whitelist)", function()
    local s = H.cindra_surface()
    assert.equals("cindra-sand-1", hand_build(s, "landfill", { 3, 3 }, "cindra-sand-1"))
  end)

  it("foundation cannot be hand-placed over Cindra lava or ground (data-stage)", function()
    local s = H.cindra_surface()
    -- Over an impassable lava tile (the exact "pave the lava safe" the design forbids).
    assert.equals("cindra-lava", hand_build(s, "foundation", { 6, 6 }, "cindra-lava"))
    -- And over ordinary walkable ground.
    assert.equals("cindra-sand-1", hand_build(s, "foundation", { 9, 9 }, "cindra-sand-1"))
  end)

  it("landfill/foundation ARE the tiles we mean to block (is_foundation guard)", function()
    -- The safety net keys on is_foundation; assert the classification the whole
    -- module relies on, and that Cindra's own tiles are exempt.
    assert.is_true(prototypes.tile["landfill"].is_foundation)
    assert.is_true(prototypes.tile["foundation"].is_foundation)
    assert.is_false(prototypes.tile["cindra-sand-1"].is_foundation)
    assert.is_false(prototypes.tile["cindra-lava"].is_foundation)
    -- Plain paving is NOT is_foundation: decorating walkable ground stays allowed.
    assert.is_false(prototypes.tile["refined-concrete"].is_foundation)
  end)

  -- Build a foundation tile at `pos` over `under`, then fire the build event through
  -- the handler exactly as the engine would, and return the resulting tile name.
  local function place_then_notify(s, tile, pos, under, extra)
    s.set_tiles({ { name = under, position = pos } })
    s.set_tiles({ { name = tile, position = pos } })
    local event = {
      surface_index = s.index,
      tile = prototypes.tile[tile],
      tiles = { { position = { x = pos[1], y = pos[2] }, old_tile = prototypes.tile[under] } },
    }
    for k, v in pairs(extra or {}) do event[k] = v end
    no_paving.undo_paving(event)
    return s.get_tile(pos[1], pos[2]).name
  end

  it("reverts a foundation tile that lands on Cindra, and refunds the item", function()
    local s = H.cindra_surface()
    local p = player()
    p.get_main_inventory().clear()

    local result = place_then_notify(s, "landfill", { 12, 12 }, "cindra-sand-1", {
      item = prototypes.item["landfill"],
      player_index = p.index,
    })
    -- Reverted to the tile it replaced (FAILS on main: no handler to revert it).
    assert.equals("cindra-sand-1", result)
    -- The consumed item was handed back.
    assert.equals(1, p.get_main_inventory().get_item_count("landfill"))
  end)

  it("reverts foundation built over lava too (the danger-zone case)", function()
    local s = H.cindra_surface()
    local result = place_then_notify(s, "foundation", { 15, 15 }, "cindra-lava", {
      item = prototypes.item["foundation"],
      player_index = player().index,
    })
    assert.equals("cindra-lava", result)
  end)

  it("leaves ordinary (non-foundation) paving alone", function()
    local s = H.cindra_surface()
    -- refined-concrete is not is_foundation: the handler must not revert it.
    local result = place_then_notify(s, "refined-concrete", { 18, 18 }, "cindra-sand-1", {
      item = prototypes.item["refined-concrete"],
      player_index = player().index,
    })
    assert.equals("refined-concrete", result)
  end)

  it("does NOT touch other surfaces (nauvis foundation stays)", function()
    local nauvis = game.surfaces["nauvis"]
    assert.is_not_nil(nauvis)
    nauvis.set_tiles({ { name = "grass-1", position = { 3, 3 } } })
    nauvis.set_tiles({ { name = "landfill", position = { 3, 3 } } })
    no_paving.undo_paving({
      surface_index = nauvis.index,
      tile = prototypes.tile["landfill"],
      tiles = { { position = { x = 3, y = 3 }, old_tile = prototypes.tile["grass-1"] } },
      item = prototypes.item["landfill"],
      player_index = player().index,
    })
    -- Untouched: the handler no-ops off Cindra.
    assert.equals("landfill", nauvis.get_tile(3, 3).name)
    -- Clean up so we never leave a mutated nauvis behind for other tests.
    nauvis.set_tiles({ { name = "grass-1", position = { 3, 3 } } })
  end)
end)
