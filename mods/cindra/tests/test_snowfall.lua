-- Proof: it SNOWS on Cindra's icy side, and NOWHERE else (ci-mk5y; the ci-wly epic's
-- "consider snow-fall only on the icy side").
--
-- Cindra is ONE surface holding a molten dayside and a frozen nightside, so a per-surface
-- weather effect would snow on the lava; scripts/snowfall.lua gates each FLAKE on the
-- perpendicular axis instead. That is the player-observable claim this drives with a LIVE
-- player: the flakes a player can actually SEE (read back from the live render objects),
-- where they are, and that they FALL.
--
--   1. deep on the ice  -> a field of flakes, every one of them over icy ground;
--   2. on the habitable band / the volcanic slope -> NONE (the brown middle never snows);
--   3. standing AT the icy edge -> flakes on the nightward side ONLY (the gate is per
--      FLAKE, not per player -- the invariant a naive "is the player cold" check fails);
--   4. the flakes MOVE: each one either fell or wrapped back to the top of the field;
--   5. leaving the ice tears the field down (no leaked render objects);
--   6. another planet never snows (the never-touch-other-planets invariant).
--
-- The pure boundary + motion maths is proven off-game in unit-tests/test_snowfall.lua. How
-- the snow LOOKS (flake size/density/speed reading as weather) is a PLAYTEST.md item.

local snowfall = require("scripts.snowfall")
local axis = require("scripts.axis")
local terrain = require("scripts.terrain")

describe("icy-side snowfall (ci-mk5y)", function()
  local EDGE = terrain.damage_bounds().cold_from -- the icy-ground edge (-130 by default)

  -- A world position at perpendicular `p`, `long` tiles along the ribbon -- default well
  -- along the long axis, clear of every other suite's scratch space. Orientation-agnostic
  -- (scripts/axis.lua owns which world axis is perpendicular), so this reads the same in the
  -- horizontal layout.
  local function at(p, long)
    local x, y = axis.world(long or 3000, p)
    return { x, y }
  end

  local function perp_of(pos)
    return axis.perp(pos.x, pos.y)
  end

  -- The REAL Cindra surface: snowfall is gated on `surface.name == "cindra"`, so the effect
  -- only exists there (tests/helpers' paved work area is on this same surface).
  local function cindra()
    local s = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    return s
  end

  -- Put the test player on `surface` at world position `pos`, then run one snowfall update.
  -- The move is verified: snowfall keys off where the player IS, so a refused teleport would
  -- otherwise read as a (wrong) result about the position we never reached.
  local function stand(surface, pos)
    local player = game.connected_players[1]
    assert.is_not_nil(player, "the test needs a connected player")
    player.teleport(pos, surface)
    assert.are.equal(surface.name, player.surface.name, "the player moved to " .. surface.name)
    local p = player.position
    assert.is_true(math.abs(p.x - pos[1]) < 2 and math.abs(p.y - pos[2]) < 2,
      "the player really stands at (" .. pos[1] .. ", " .. pos[2] .. ")")
    snowfall.update_all()
    return player
  end

  local function count(player)
    return snowfall.flake_count(player)
  end

  before_each(function()
    storage.cindra_driver_enabled = false
    local player = game.connected_players[1]
    if player then snowfall.clear(player) end
  end)

  after_each(function()
    local player = game.connected_players[1]
    if player then
      snowfall.clear(player)
      -- Never leave the character parked out on the lava / deep ice: the next suite's ticks
      -- would burn or freeze it. Home is the temperate middle of the Cindra ribbon.
      player.teleport({ 0, 0 }, cindra())
    end
    storage.cindra_driver_enabled = true
  end)

  -- 1 + 2. It snows on the ice, and only there --------------------------------------
  it("snows on the deep ice and NOT on the habitable band or the volcanic slope", function()
    local s = cindra()
    local player = stand(s, at(EDGE - 120))
    assert.is_true(count(player) > 0, "a field of flakes falls out on the deep ice")
    for _, p in pairs(snowfall.flake_positions(player)) do
      assert.is_true(snowfall.falls_at(perp_of(p)),
        "every flake is over icy ground (perp " .. perp_of(p) .. ")")
    end

    stand(s, at(0))
    assert.are.equal(0, count(player), "the terminator centre never snows (clean landing band)")

    stand(s, at(-60))
    assert.are.equal(0, count(player), "the brown habitable band never snows")

    stand(s, at(120))
    assert.are.equal(0, count(player), "the volcanic slope never snows")

    stand(s, at(300))
    assert.are.equal(0, count(player), "it never snows over the lava ocean")
  end)

  -- 3. The gate is per FLAKE: at the edge, snow falls nightward of it only ----------
  it("standing AT the icy edge, snow falls on the nightward side ONLY", function()
    local s = cindra()
    local player = stand(s, at(EDGE))
    -- Run a few updates so the field settles into the half-covered state.
    for _ = 1, 5 do snowfall.update_all() end
    local seen = snowfall.flake_positions(player)
    local n = 0
    for _, p in pairs(seen) do
      n = n + 1
      assert.is_true(perp_of(p) < EDGE,
        "no flake falls warmward of the icy edge (perp " .. perp_of(p) .. ")")
    end
    assert.is_true(n > 0, "the nightward half of the view still snows")
    assert.is_true(n < snowfall.FLAKES,
      "and the warmward half does not (" .. n .. " of " .. snowfall.FLAKES .. " flakes)")
  end)

  -- 4. The snow actually FALLS ------------------------------------------------------
  it("the flakes fall: each one drops, or wraps back to the top of the field", function()
    local s = cindra()
    local player = stand(s, at(EDGE - 200))
    local before = snowfall.flake_positions(player)
    -- The player does not move, so any change in a flake's position is the snow falling.
    snowfall.update_all()
    local after = snowfall.flake_positions(player)
    local fell, wrapped = 0, 0
    for i, a in pairs(after) do
      local b = before[i]
      if b then
        -- Down-screen is +y in world space; a wrapped flake jumps back up a whole field.
        if a.y > b.y then
          fell = fell + 1
        else
          assert.is_true(b.y - a.y > snowfall.SPAN_Y / 2,
            "a flake either falls or wraps to the top (slot " .. i .. ")")
          wrapped = wrapped + 1
        end
      end
    end
    assert.is_true(fell > 0, "flakes fell (" .. fell .. " fell, " .. wrapped .. " wrapped)")
  end)

  -- 5. No leaked render objects when the player leaves the snow ---------------------
  it("tears the field down when the player leaves the ice (no leftover flakes)", function()
    local s = cindra()
    local player = stand(s, at(EDGE - 120))
    assert.is_true(count(player) > 0, "snowing (control)")
    stand(s, at(0))
    assert.are.equal(0, count(player), "no flake survives the walk back to the middle")
  end)

  -- 6. Never another planet --------------------------------------------------------
  it("never snows on another planet (Cindra-only)", function()
    local nauvis = game.surfaces["nauvis"]
    -- The SAME coordinates that snow on Cindra: it is the surface + position pair that
    -- gates, and nauvis is never Cindra.
    local player = stand(nauvis, { 0, 0 })
    assert.are.equal(0, count(player), "snowfall is Cindra-only")
    -- Moving to the icy-side coordinates on the wrong planet still snows nothing.
    stand(nauvis, at(EDGE - 120, 0))
    assert.are.equal(0, count(player), "not even at the icy-side coordinates")
    -- ...and coming back to Cindra's ice it snows again (the field re-seeds cleanly).
    local s = cindra()
    stand(s, at(EDGE - 120))
    assert.is_true(count(player) > 0, "back on the Cindra ice it snows again")
  end)
end)
