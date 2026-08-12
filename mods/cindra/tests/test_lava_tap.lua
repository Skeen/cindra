-- Proof: Cindra's natural lava is NOT a tap (ci-8vu).
--
-- Cindra's whole metal economy hangs off MANUFACTURED lava: stone melted with
-- ruinous electric power (prototypes/lava.lua), which is the planet's flare-timed
-- power sink and the gate on everything downstream. The map also renders REAL
-- fire-edge lava (the hot backstop of the ribbon), and in Factorio 2.0 an offshore
-- pump produces whatever fluid the TILE under its intake declares -- the pump names
-- no fluid of its own. Cindra's lava tiles are clones of the Vulcanus ones, so they
-- carried `fluid = "lava"` and handed the player a free lava well: walk to the
-- shore, drop a vanilla offshore pump, tap the sea, skip the entire chain and its
-- power sink. That is the ci-8vu exploit, and it directly contradicts lava.lua's own
-- premise ("Cindra has no lava lakes to pump -- here lava is MADE from stone").
--
-- WHAT THE PLAYER OBSERVES NOW: a pump aimed at Cindra lava never puts a drop of
-- lava into the pipe behind it.
--
-- The A/B below is the whole proof -- three identical taps, same surface, same
-- ticks, same direction: a pump on safe ground with a molten patch in front of its
-- intake and a pipe run behind its output, exactly how a player would plumb one.
-- The ONLY difference is which tile the molten patch is made of:
--   * VANILLA `lava` (the CONTROL)      -> the pipes fill. The measurement is live.
--   * `cindra-lava` / `cindra-lava-hot` -> pump and pipes stay bone dry.
-- The control is load-bearing: an offshore pump only produces into a CONNECTED
-- output, so without it "0 lava" could just mean "we plumbed it wrong" and the test
-- would pass for the wrong reason.
--
-- The ci-wly paving ban (tests/test_paving.lua) closes the OTHER half of ci-8vu --
-- you cannot concrete a walkway over the hazard to reach the shore. This suite
-- closes the tap itself, which is the load-bearing half: with no fluid on the tile
-- there is nothing to reach for.

local H = require("tests.helpers")

-- The vanilla offshore pump (base entities.lua) is 1x1: it draws from the tile ONE
-- tile in FRONT of it (`fluid_source_offset = {0, -1}` when facing north) and pushes
-- what it draws out of its BACK (a single output pipe connection on the south side).
-- Both ends are plumbed below, so these taps are exactly what a player would build.
local PUMP = "offshore-pump"

describe("cindra: natural lava cannot be tapped (ci-8vu)", function()
  -- A complete tap at tile (tx, ty): a molten patch of `tile` filling the rows in
  -- FRONT of the pump, the pump itself on the paved shore, and a two-pipe run behind
  -- it to receive the flow. Returns the pump and its pipes.
  local function tap_at(s, tile, tx, ty)
    local patch = {}
    for x = tx - 3, tx + 3 do
      for y = ty - 6, ty - 1 do
        patch[#patch + 1] = { name = tile, position = { x, y } }
      end
    end
    s.set_tiles(patch)
    -- The shore the pump stands on, and the ground its pipes run over.
    s.set_tiles({
      { name = "refined-concrete", position = { tx, ty } },
      { name = "refined-concrete", position = { tx, ty + 1 } },
      { name = "refined-concrete", position = { tx, ty + 2 } },
    })

    local pump = s.create_entity({
      name = PUMP,
      position = { tx + 0.5, ty + 0.5 }, -- tile centre: a 1x1 entity lands square
      direction = defines.direction.north,
      force = "player",
    })
    assert.is_not_nil(pump, "an offshore pump must stand on the shore of " .. tile)
    local pipes = {
      s.create_entity({ name = "pipe", position = { tx + 0.5, ty + 1.5 }, force = "player" }),
      s.create_entity({ name = "pipe", position = { tx + 0.5, ty + 2.5 }, force = "player" }),
    }
    assert.is_not_nil(pipes[1], "the pump's output pipe must place")
    assert.is_not_nil(pipes[2], "the second pipe must place")
    return { pump = pump, pipes = pipes, tx = tx, ty = ty }
  end

  -- Everything this tap holds, pump plus pipe run: what the player would actually
  -- have to show for the attempt.
  local function tapped(t)
    assert.is_true(t.pump.valid, "the pump survived the run")
    local total = t.pump.get_fluid_count()
    for _, p in ipairs(t.pipes) do
      assert.is_true(p.valid, "the pipe survived the run")
      total = total + p.get_fluid_count()
    end
    return total
  end

  -- Hand the work area back the way we found it: no stray pumps or pipes, no molten
  -- tiles left on the paved slab for the next suite.
  local function restore(s, taps)
    local tiles = {}
    for _, t in pairs(taps) do
      if t.pump.valid then t.pump.destroy() end
      for _, p in ipairs(t.pipes) do
        if p.valid then p.destroy() end
      end
      for x = t.tx - 3, t.tx + 3 do
        for y = t.ty - 6, t.ty + 2 do
          tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
        end
      end
    end
    s.set_tiles(tiles)
  end

  it("a pump aimed at natural Cindra lava draws NOTHING (vanilla lava control fills)",
    function()
      local s = H.cindra_surface()
      -- Same row, twelve tiles apart so the patches never touch: identical exposure
      -- to everything the surface does (sweeps, freeze, the same ticks), which leaves
      -- the tile under the intake as the ONLY variable between them.
      local control = tap_at(s, "lava", 2, -7)             -- vanilla Vulcanus lava
      local shallow = tap_at(s, "cindra-lava", -10, -7)    -- the fire-edge sea
      local hot     = tap_at(s, "cindra-lava-hot", 14, -7) -- its molten core

      -- The pump moves 20 fluid/tick, so the control's 300 units of pipe+box are full
      -- within ~15 ticks; 300 is an ample margin.
      async(900)
      after_ticks(300, function()
        -- CONTROL FIRST: the plumbing is right and these taps really do run.
        local got = tapped(control)
        assert.is_true(got > 0,
          "control: a tap over VANILLA lava delivers lava into the pipes (got "
            .. tostring(got) .. ")")

        -- ...and Cindra's own lava gives up nothing at all. Not "less" -- nothing.
        assert.equals(0, tapped(shallow),
          "a tap on natural cindra-lava must deliver NOTHING: on Cindra lava is "
            .. "manufactured from stone, never pumped out of the ground")
        assert.equals(0, tapped(hot),
          "a tap on natural cindra-lava-hot must deliver NOTHING either")

        restore(s, { control, shallow, hot })
        done()
      end)
    end)

  it("NO Cindra tile declares a fluid (a new tile cannot ship a new tap)", function()
    -- Coverage guard: enumerated LIVE from the loaded prototypes, so a future Cindra
    -- tile cloned from a fluid-bearing vanilla tile (any ocean, any lava) fails here
    -- instead of quietly reopening ci-8vu.
    local seen = 0
    for name, proto in pairs(prototypes.tile) do
      if string.find(name, "^cindra%-") then
        seen = seen + 1
        assert.is_nil(proto.fluid,
          "no Cindra tile may declare a fluid -- that IS an offshore-pump tap: " .. name)
      end
    end
    assert.is_true(seen > 0, "the sweep must actually see the Cindra tiles (saw " .. seen .. ")")
  end)

  it("leaves the SHARED vanilla tiles pumpable (no other-planet mutation)", function()
    -- We clone; we never mutate. Vulcanus still pumps its lava lakes and Nauvis its
    -- water -- and, because these read back non-nil, the nil assertions above are
    -- real findings rather than an accessor that never returns anything.
    assert.is_not_nil(prototypes.tile["lava"].fluid, "vanilla lava is still a fluid source")
    assert.equals("lava", prototypes.tile["lava"].fluid.name)
    assert.equals("lava", prototypes.tile["lava-hot"].fluid.name)
    assert.equals("water", prototypes.tile["water"].fluid.name)
  end)
end)
