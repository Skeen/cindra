-- Proof: the full-screen heat/cold damage-feedback tint (scripts/damage-feedback
-- .lua) appears while a character stands in a lethal band on Cindra and CLEARS the
-- moment it steps back to safety -- so the player always sees WHY they are losing
-- health. §15 v2 item 4 (ci-7tl).
--
-- The pure band decision (overlay_for / intensity_for) is proven in
-- unit-tests/test_feedback.lua; this drives a LIVE player character across the
-- ribbon and asserts the screen-tint render object shows / hides in step with the
-- lethal-zone damage it explains (both key off terrain.lethal_at). active_which
-- reads the live render object, so a destroyed tint reads as nil.

local H = require("tests.helpers")
local feedback = require("scripts.damage-feedback")

describe("full-screen heat/cold damage feedback (§15 v2 item 4; ci-7tl)", function()
  -- A compact ribbon keyed by the ci-wly ZONE ROLES (terrain.widths reads it), so the
  -- lethal bands sit near the origin. Total 44, half 22: heat lethal p >= 14, cold
  -- lethal p <= -14, safe between. Default orientation is vertical, so perp = -x: heat
  -- at x <= -14, cold at x >= 14, the centre (x = 0) safe.
  local CFG = {
    hot_ocean = 4, hot_inner = 4, hot_outer = 4,
    middle = 20,
    cold_outer = 4, cold_inner = 4, cold_ocean = 4,
  }
  local HEAT_X, COLD_X, SAFE_X = -18, 18, 0

  -- Ensure the test player has a character standing on `s`, robust to whatever
  -- surface/controller a previous test left it in. Teleport to the target surface
  -- FIRST (moves any existing character with it), so a fresh character is only
  -- ever created/attached on the surface the player already stands on.
  local function player_on(s)
    local player = game.connected_players[1]
    assert.is_not_nil(player, "the test needs a connected player")
    player.teleport({ 0, 0 }, s)
    if not (player.character and player.character.valid) then
      local ch = s.create_entity({ name = "character", position = { 0, 0 }, force = "player" })
      assert.is_not_nil(ch, "character must be creatable")
      player.set_controller({ type = defines.controllers.character, character = ch })
    end
    return player
  end

  it("tints red in a hot band, blue in a cold band, and clears when safe", function()
    local s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    local player = player_on(s)

    -- Start safe: no tint.
    player.character.teleport({ SAFE_X, 0 })
    feedback.update_all(CFG)
    assert.is_nil(feedback.active_which(player), "no tint in the safe building band")

    -- Step into the hot band: the heat (red) tint appears.
    player.character.teleport({ HEAT_X, 0 })
    feedback.update_all(CFG)
    assert.are.equal("heat", feedback.active_which(player), "heat tint shown in the hot band")

    -- Back to the ribbon: the tint clears immediately.
    player.character.teleport({ SAFE_X, 0 })
    feedback.update_all(CFG)
    assert.is_nil(feedback.active_which(player), "tint cleared back in the safe band")

    -- Step into the cold band: the cold (blue) tint appears.
    player.character.teleport({ COLD_X, 0 })
    feedback.update_all(CFG)
    assert.are.equal("cold", feedback.active_which(player), "cold tint shown in the cold band")

    -- Clean up: clear the tint and restore the driver.
    player.character.teleport({ SAFE_X, 0 })
    feedback.update_all(CFG)
    assert.is_nil(feedback.active_which(player), "tint cleared on exit")
    storage.cindra_driver_enabled = true
  end)

  it("switches straight from a heat tint to a cold tint without stale state", function()
    local s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    local player = player_on(s)

    player.character.teleport({ HEAT_X, 0 })
    feedback.update_all(CFG)
    assert.are.equal("heat", feedback.active_which(player), "heat first")

    -- Jump directly across the ribbon into the opposite lethal band.
    player.character.teleport({ COLD_X, 0 })
    feedback.update_all(CFG)
    assert.are.equal("cold", feedback.active_which(player), "flips to cold, no leftover heat tint")

    player.character.teleport({ SAFE_X, 0 })
    feedback.update_all(CFG)
    assert.is_nil(feedback.active_which(player))
    storage.cindra_driver_enabled = true
  end)

  it("never tints for a character on another planet (Cindra-only)", function()
    storage.cindra_driver_enabled = false
    local nauvis = game.surfaces["nauvis"]
    local player = player_on(nauvis)
    -- A "hot" perpendicular coordinate, but on the WRONG planet: no tint.
    player.character.teleport({ HEAT_X, 0 })
    feedback.update_all(CFG)
    assert.is_nil(feedback.active_which(player), "feedback is Cindra-only")
    storage.cindra_driver_enabled = true
  end)
end)
