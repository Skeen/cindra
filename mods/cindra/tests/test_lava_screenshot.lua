-- TEMPORARY render-evidence test for ci-036. Places a cindra-lava-manufacturer
-- on the Cindra surface and screenshots it (daylight body + night glow) via the
-- real engine renderer, so we can EYEBALL that it is the glass-furnace machine
-- body at the right footprint, animated, glowing -- NOT a black square. Not a
-- committed guard (needs a display + writes artifacts); delete after capture.
local H = require("tests.helpers")

describe("ci-036 lava-manufacturer render evidence", function()
  it("renders the glass-furnace body (not a black square)", function()
    local s = H.cindra_surface()
    local m = s.create_entity({
      name = "cindra-lava-manufacturer",
      position = { 0, 0 },
      force = "player",
    })
    assert.is_truthy(m)

    -- A vanilla foundry next to it as a size/appearance reference.
    s.create_entity({ name = "foundry", position = { 8, 0 }, force = "player" })

    async(240)
    after_ticks(60, function()
      -- Daylight shot: the opaque body must be visible at the correct footprint.
      game.take_screenshot({
        surface = s,
        position = { 4, 0 },
        resolution = { 900, 600 },
        zoom = 1.5,
        path = "ci-036-lavaman-day.png",
        show_entity_info = false,
        anti_alias = true,
        daytime = 0.0,
        force_render = true,
      })
      after_ticks(60, function()
        -- Night shot: the emissive molten glow must read in the dark.
        game.take_screenshot({
          surface = s,
          position = { 0, 0 },
          resolution = { 700, 700 },
          zoom = 2.0,
          path = "ci-036-lavaman-night.png",
          show_entity_info = false,
          anti_alias = true,
          daytime = 0.5,
          force_render = true,
        })
        after_ticks(60, function() done() end)
      end)
    end)
  end)
end)
