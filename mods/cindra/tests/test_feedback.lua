-- Proof: the ambient THERMAL GRADE -- a subtle, continuous screen hue wash driven by
-- WHERE the player stands on the ribbon (ci-nw0; supersedes the ci-7tl binary damage
-- overlay).
--
-- This drives a LIVE player character along the hot-cold axis and asserts what the
-- player would actually SEE: nothing in the temperate middle, a warm wash that
-- deepens the further they push sunward, a cool wash nightward, and a cap that keeps
-- it a colour grade instead of an opaque overlay. active() reads the LIVE render
-- object, so a destroyed/absent grade reads as (nil, 0) and the alpha is the one being
-- drawn.
--
-- The two behaviours that changed from ci-7tl are asserted head-on:
--   * the trigger is POSITION, not damage -- the screen already reads warm on ground
--     that deals ZERO damage, where the old overlay showed nothing at all;
--   * it is COSMETIC ONLY -- concrete over hot ground still shields the player
--     completely (the ci-ma18 tile-based damage invariant), and the grade no longer
--     pretends otherwise: they are somewhere hot, so the screen says so, and they
--     take no damage, because they are standing on cover.
--
-- The grade maths itself is unit-tested in unit-tests/test_feedback.lua.

local H = require("tests.helpers")
local grade = require("scripts.damage-feedback")
local axis = require("scripts.axis")
local td = require("scripts.tile-damage")

describe("ambient thermal grade (ci-nw0)", function()
  local s
  local ORIENT = axis.orientation()
  local LONG = 3600 -- far along the ribbon, clear of every other test's work area

  -- Perpendicular sample points, in the player's terms: the safe middle, three
  -- stations pushing sunward toward the lava, three pushing nightward into the ice.
  -- The deepest hot sample stops just short of the lava ocean (molten, impassable);
  -- the ice ocean is walkable, so the cold side reaches full depth on foot.
  local MIDDLE = 0
  local WARM_1, WARM_2, WARM_3 = 70, 120, 190
  local COOL_1, COOL_2, COOL_3 = -70, -120, -250

  local function at(p)
    local x, y = axis.world(LONG, p, ORIENT)
    return { x, y }
  end

  -- Paint an 11x11 patch of `name` centred on perpendicular coordinate `p`.
  local function pave(name, p)
    local c = at(p)
    local tiles = {}
    for x = c[1] - 5, c[1] + 5 do
      for y = c[2] - 5, c[2] + 5 do
        tiles[#tiles + 1] = { name = name, position = { x, y } }
      end
    end
    s.set_tiles(tiles, true)
  end

  -- Ensure the test player has a character on `surface`, robust to whatever
  -- surface/controller a previous test left it in.
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

  -- Walk the character to perpendicular coordinate `p` and refresh the grade.
  local function stand(player, p)
    player.character.teleport(at(p))
    grade.update_all()
  end

  local function setup(points)
    s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    for _, p in ipairs(points) do
      s.request_to_generate_chunks(at(p), 1)
    end
    s.force_generate_chunk_requests()
    return player_on(s)
  end

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  it("reads NEUTRAL in the temperate middle and warms, deepening, as you push sunward", function()
    local player = setup({ MIDDLE, WARM_1, WARM_2, WARM_3 })

    stand(player, MIDDLE)
    assert.is_nil(grade.active_which(player), "the safe middle shows no wash at all")

    stand(player, WARM_1)
    local w1, a1 = grade.active(player)
    assert.are.equal("warm", w1, "stepping sunward warms the screen")
    assert.is_true(a1 > 0, "with a visible wash")

    stand(player, WARM_2)
    local w2, a2 = grade.active(player)
    assert.are.equal("warm", w2, "still warm further out")
    assert.is_true(a2 > a1, "and deeper the further you go")

    stand(player, WARM_3)
    local w3, a3 = grade.active(player)
    assert.are.equal("warm", w3, "deepest approaching the lava")
    assert.is_true(a3 > a2, "the wash keeps deepening all the way out")

    stand(player, MIDDLE)
    assert.is_nil(grade.active_which(player), "walking back to the middle clears it entirely")
  end)

  it("cools, deepening, as you push nightward", function()
    local player = setup({ MIDDLE, COOL_1, COOL_2, COOL_3 })

    stand(player, COOL_1)
    local w1, a1 = grade.active(player)
    assert.are.equal("cool", w1, "stepping nightward cools the screen")
    assert.is_true(a1 > 0, "with a visible wash")

    stand(player, COOL_2)
    local w2, a2 = grade.active(player)
    assert.are.equal("cool", w2, "still cool further out")
    assert.is_true(a2 > a1, "and deeper the further you go")

    stand(player, COOL_3)
    local w3, a3 = grade.active(player)
    assert.are.equal("cool", w3, "deepest out on the ice")
    assert.is_true(a3 > a2, "the wash keeps deepening onto the ice ocean")

    stand(player, MIDDLE)
    assert.is_nil(grade.active_which(player), "and clears back in the middle")
  end)

  it("flips straight from warm to cool without stale state", function()
    local player = setup({ WARM_2, COOL_2 })
    stand(player, WARM_2)
    assert.are.equal("warm", grade.active_which(player), "warm first")
    stand(player, COOL_2)
    assert.are.equal("cool", grade.active_which(player), "flips to cool, no leftover warm wash")
    stand(player, MIDDLE)
  end)

  it("stays a WASH, never an opaque overlay, even at the extreme", function()
    local player = setup({ COOL_3, WARM_3 })
    stand(player, COOL_3)
    local _, deepest = grade.active(player)
    assert.is_true(deepest > 0, "the extreme is clearly felt")
    assert.is_true(deepest <= 0.25, "but never blacks the view out: alpha " .. tostring(deepest))
    stand(player, WARM_3)
    local _, hot = grade.active(player)
    assert.is_true(hot <= 0.25, "same sunward: alpha " .. tostring(hot))
    stand(player, MIDDLE)
  end)

  it("POSITION drives it, not damage: undamaging ground outside the band already reads warm", function()
    -- The ci-nw0 change in one assertion. WARM_1 sits between the temperate band and
    -- the burn belt: a full damage sweep takes nothing off the player, and the screen
    -- is warm anyway. The old damage-triggered overlay showed nothing here.
    local player = setup({ WARM_1 })
    pave("cindra-volcanic-ash-flats", WARM_1) -- plain safe ground under their feet
    stand(player, WARM_1)

    local before = player.character.health
    td.sweep(s, 20, 200)
    assert.are.equal(before, player.character.health, "this ground deals no damage at all")
    local which, a = grade.active(player)
    assert.are.equal("warm", which, "yet the screen reads warm: it is driven by where you are")
    assert.is_true(a > 0, "with a visible wash")
    stand(player, MIDDLE)
  end)

  it("COSMETIC ONLY (ci-ma18): concrete over hot ground still shields, and still reads warm", function()
    local player = setup({ WARM_3 })

    -- Control: bare hot crust really does burn, so the sweep below is live.
    pave("cindra-volcanic-cracks-hot", WARM_3)
    stand(player, WARM_3)
    local before = player.character.health
    td.sweep(s, 20, 200)
    assert.is_true(player.character.health < before, "bare hot crust burns (control)")

    -- Cover it. The player is shielded -- tile-based damage, exactly as ci-ma18 pins
    -- it -- while the grade still reports where they are standing.
    pave("concrete", WARM_3)
    player.character.health = player.character.max_health
    stand(player, WARM_3)
    local covered = player.character.health
    td.sweep(s, 20, 200)
    assert.are.equal(covered, player.character.health, "concrete over hot ground shields completely")
    assert.are.equal("warm", grade.active_which(player), "and the screen still reads warm (cosmetic, positional)")

    player.character.health = player.character.max_health
    stand(player, MIDDLE)
  end)

  it("never grades a character on another planet (Cindra-only)", function()
    storage.cindra_driver_enabled = false
    local nauvis = game.surfaces["nauvis"]
    local player = player_on(nauvis)
    -- Standing at a coordinate that would read deep-warm on Cindra: wrong planet, nothing.
    player.character.teleport(at(WARM_3))
    grade.update_all()
    assert.is_nil(grade.active_which(player), "the grade is Cindra-only")
  end)
end)
