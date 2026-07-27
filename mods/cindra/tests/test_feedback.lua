-- Proof: the player heat/cold feedback banner (scripts/damage-feedback.lua)
-- appears while a character is in a damaging band on Cindra and clears the moment
-- it steps back to safety -- so the player always sees WHY they are losing health.
-- §15 v2 item 4.
--
-- The pure band decision is proven in unit-tests/test_feedback.lua; this drives a
-- LIVE player character across the ribbon and asserts the GUI banner shows/hides.

local H = require("tests.helpers")
local feedback = require("scripts.damage-feedback")

describe("player heat/cold feedback banner (§15 v2 item 4)", function()
  local CFG = { safe_half_width = 24, hot_lethal_at = 96, hot_wall_at = 128,
                cold_lethal_at = 96, cold_wall_at = 128, orientation = "east-west" }

  -- Ensure the test player has a character standing on `s`, robust to whatever
  -- surface/controller a previous test left it in. Teleport to the target surface
  -- FIRST (moves any existing character with it), so a fresh character is only
  -- ever created/attached on the surface the player already stands on -- avoiding
  -- cross-surface set_controller errors.
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

  it("shows the heat banner sunward, the cold banner nightward, and none when safe", function()
    local s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    local player = player_on(s)
    local screen = player.gui.screen

    -- Start safe: no banner.
    player.character.teleport({ 0, 0 })
    feedback.update_all(CFG)
    assert.is_nil(screen[feedback.HEAT_GUI], "no heat banner in the safe band")
    assert.is_nil(screen[feedback.COLD_GUI], "no cold banner in the safe band")

    -- Step into the sunward margin: heat banner appears, cold stays absent.
    player.character.teleport({ 0, 40 })
    feedback.update_all(CFG)
    assert.is_not_nil(screen[feedback.HEAT_GUI], "heat banner shown in the sunward margin")
    assert.is_nil(screen[feedback.COLD_GUI], "no cold banner while hot")

    -- Back to the ribbon: the banner clears immediately.
    player.character.teleport({ 0, 0 })
    feedback.update_all(CFG)
    assert.is_nil(screen[feedback.HEAT_GUI], "heat banner cleared back in the safe band")

    -- Step into the nightward margin: cold banner appears, heat absent.
    player.character.teleport({ 0, -40 })
    feedback.update_all(CFG)
    assert.is_not_nil(screen[feedback.COLD_GUI], "cold banner shown in the nightward margin")
    assert.is_nil(screen[feedback.HEAT_GUI], "no heat banner while cold")

    -- Clean up: clear the banner and restore the driver.
    player.character.teleport({ 0, 0 })
    feedback.update_all(CFG)
    assert.is_nil(screen[feedback.COLD_GUI], "banner cleared on exit")
    storage.cindra_driver_enabled = true
  end)

  it("never shows a banner for a character on another planet", function()
    storage.cindra_driver_enabled = false
    local nauvis = game.surfaces["nauvis"]
    local player = player_on(nauvis)
    -- A "hot" perpendicular coordinate, but on the WRONG planet: no banner.
    player.character.teleport({ 0, 40 })
    feedback.update_all(CFG)
    assert.is_nil(player.gui.screen[feedback.HEAT_GUI], "feedback is Cindra-only")
    assert.is_nil(player.gui.screen[feedback.COLD_GUI], "feedback is Cindra-only")
    storage.cindra_driver_enabled = true
  end)
end)
