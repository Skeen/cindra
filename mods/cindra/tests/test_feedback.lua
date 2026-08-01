-- Proof: the full-screen heat/cold damage-feedback tint (scripts/damage-feedback
-- .lua) appears while a character stands on a hazard TILE on Cindra and CLEARS the
-- moment it steps onto safe ground -- or onto a concrete COVER over a hazard -- so the
-- player always sees WHY they are (or are not) losing health. §15 v2 item 4 (ci-7tl),
-- retargeted to the tile-based damage source (ci-ma18).
--
-- The pure decision (for_tile) is proven in unit-tests/test_feedback.lua; this drives a
-- LIVE player character onto painted tiles and asserts the screen-tint render object
-- shows / hides in step with the tile-based lethal-ground damage it explains (both key
-- off terrain.tile_damage). active_which reads the live render object, so a destroyed
-- tint reads as nil.

local H = require("tests.helpers")
local feedback = require("scripts.damage-feedback")

describe("full-screen heat/cold damage feedback (§15 v2 item 4; ci-7tl, ci-ma18)", function()
  local s
  -- Distinct integer tiles for each case, far from spawn so worldgen never overwrites
  -- them; the character stands at the tile centre (integer + 0.5) so the tint reads the
  -- painted tile under it.
  local HOT = { -40, 4000 }
  local COLD = { 40, 4000 }
  local SAFE = { 0, 4000 }
  local COVER = { -60, 4000 }

  local function paint(name, pos)
    s.set_tiles({ { name = name, position = { pos[1], pos[2] } } }, true)
  end
  local function stand(player, pos)
    player.character.teleport({ pos[1] + 0.5, pos[2] + 0.5 })
    feedback.update_all()
  end

  -- Ensure the test player has a character on `s`, robust to whatever surface/controller
  -- a previous test left it in.
  local function player_on(surface)
    local player = game.connected_players[1]
    assert.is_not_nil(player, "the test needs a connected player")
    player.teleport({ 0, 0 }, surface)
    if not (player.character and player.character.valid) then
      local ch = surface.create_entity({ name = "character", position = { 0, 0 }, force = "player" })
      assert.is_not_nil(ch, "character must be creatable")
      player.set_controller({ type = defines.controllers.character, character = ch })
    end
    return player
  end

  it("tints red on hot ground, blue on cold ground, and clears on safe ground", function()
    s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    s.request_to_generate_chunks({ 0, 4000 }, 6)
    s.force_generate_chunk_requests()
    local player = player_on(s)
    paint("cindra-volcanic-cracks-hot", HOT)  -- walkable glowing hot crust
    paint("cindra-ice-rough", COLD)           -- walkable cold ice
    paint("cindra-volcanic-ash-flats", SAFE)  -- safe middle ground

    stand(player, SAFE)
    assert.is_nil(feedback.active_which(player), "no tint on safe ground")

    stand(player, HOT)
    assert.are.equal("heat", feedback.active_which(player), "heat tint on the hot crust")

    stand(player, SAFE)
    assert.is_nil(feedback.active_which(player), "tint clears back on safe ground")

    stand(player, COLD)
    assert.are.equal("cold", feedback.active_which(player), "cold tint on the ice")

    stand(player, SAFE)
    assert.is_nil(feedback.active_which(player), "tint cleared on exit")
    storage.cindra_driver_enabled = true
  end)

  it("SHIELD (ci-ma18): concrete over hot ground shows NO tint (matches the shield)", function()
    s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    s.request_to_generate_chunks({ 0, 4000 }, 6)
    s.force_generate_chunk_requests()
    local player = player_on(s)

    -- Bare hot crust tints; lay concrete on top and the tint clears (no damage -> no tint).
    paint("cindra-volcanic-cracks-hot", COVER)
    stand(player, COVER)
    assert.are.equal("heat", feedback.active_which(player), "bare hot crust tints (control)")
    paint("concrete", COVER)
    stand(player, COVER)
    assert.is_nil(feedback.active_which(player), "concrete cover shows no tint")

    player.character.teleport({ SAFE[1] + 0.5, SAFE[2] + 0.5 })
    feedback.update_all()
    storage.cindra_driver_enabled = true
  end)

  it("switches straight from a heat tint to a cold tint without stale state", function()
    s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    s.request_to_generate_chunks({ 0, 4000 }, 6)
    s.force_generate_chunk_requests()
    local player = player_on(s)
    paint("cindra-volcanic-cracks-hot", HOT)
    paint("cindra-ice-rough", COLD)

    stand(player, HOT)
    assert.are.equal("heat", feedback.active_which(player), "heat first")
    stand(player, COLD)
    assert.are.equal("cold", feedback.active_which(player), "flips to cold, no leftover heat tint")

    stand(player, SAFE)
    storage.cindra_driver_enabled = true
  end)

  it("never tints for a character on another planet (Cindra-only)", function()
    storage.cindra_driver_enabled = false
    local nauvis = game.surfaces["nauvis"]
    local player = player_on(nauvis)
    -- Even standing where a hazard tile would tint on Cindra: wrong planet, no tint.
    player.character.teleport({ 0, 0 })
    feedback.update_all()
    assert.is_nil(feedback.active_which(player), "feedback is Cindra-only")
    storage.cindra_driver_enabled = true
  end)
end)
