-- TEMPORARY graphical render-evidence scenario for ci-036 (delete after use).
-- Loaded with `factorio --load-scenario cindra/ci036-shot` in GRAPHICAL mode
-- (under Xvfb): the factorio-test harness runs headless and cannot screenshot,
-- so this drives the REAL renderer to prove the cindra-lava-manufacturer draws
-- as the glass-furnace body (not a black square), at the right footprint, with
-- its molten glow. A vanilla foundry is placed beside it as a size reference.
script.on_event(defines.events.on_tick, function(e)
  local s = game.surfaces[1]
  if e.tick == 20 then
    s.request_to_generate_chunks({ 0, 0 }, 3)
    s.force_generate_chunk_requests()
    -- Flat concrete so the ground does not distract from the machine body.
    local tiles = {}
    for x = -20, 20 do
      for y = -15, 15 do
        tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
      end
    end
    s.set_tiles(tiles)
    for _, ent in pairs(s.find_entities_filtered({ area = { { -25, -20 }, { 25, 20 } } })) do
      if ent.type ~= "character" then ent.destroy() end
    end
    s.create_entity({ name = "cindra-lava-manufacturer", position = { 0, 0 }, force = "player" })
    s.create_entity({ name = "foundry", position = { 9, 0 }, force = "player" })
  elseif e.tick == 80 then
    -- Daylight: the opaque furnace body must be visible at the foundry-scale
    -- footprint (left = lava-manufacturer, right = vanilla foundry reference).
    game.take_screenshot({
      surface = s,
      position = { 4.5, 0 },
      resolution = { 1000, 640 },
      zoom = 1.4,
      path = "ci-036-lavaman-day.png",
      show_entity_info = false,
      anti_alias = true,
      daytime = 0.0,
      force_render = true,
    })
  elseif e.tick == 140 then
    -- Night: the always-on emissive glow must read against the dark.
    game.take_screenshot({
      surface = s,
      position = { 0, 0 },
      resolution = { 720, 720 },
      zoom = 2.0,
      path = "ci-036-lavaman-night.png",
      show_entity_info = false,
      anti_alias = true,
      daytime = 0.5,
      force_render = true,
    })
  elseif e.tick == 220 then
    game.write_file("ci-036-done.txt", "shots taken\n")
  end
end)
