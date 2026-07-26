-- Shared setup for the Cindra integration tests.
--
-- All Cindra tests run on a surface literally named "cindra" (created on
-- demand). This satisfies the `surface.name == "cindra"` gate the runtime
-- handlers use, and guarantees the tests never touch nauvis or any other planet
-- (the never-mutate-other-planets invariant).

local H = {}

-- A clean, buildable Cindra surface. Generated once, then wiped and paved with a
-- solid slab of land in the work area on each call.
function H.cindra_surface()
  local s = game.surfaces["cindra"]
  if not s then
    if game.planets and game.planets["cindra"] then
      s = game.planets["cindra"].create_surface()
    else
      s = game.create_surface("cindra", { width = 256, height = 256 })
    end
    s.request_to_generate_chunks({ 0, 0 }, 4)
    s.force_generate_chunk_requests()
  end

  for _, e in pairs(s.find_entities_filtered({ area = { { -60, -60 }, { 60, 60 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  local tiles = {}
  for x = -45, 45 do
    for y = -45, 45 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
  return s
end

return H
