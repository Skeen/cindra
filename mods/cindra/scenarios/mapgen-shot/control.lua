-- Mapgen-shot scenario (ci-tizx): capture in-engine screenshots of the LIVE Cindra
-- ground so a decal/terrain density change can be judged the way the player sees it.
-- NOT shipped gameplay -- a render harness like scenarios/orbit-shot (loaded only via
-- `--load-scenario cindra/mapgen-shot`, driven by scripts/render-mapgen.sh).
--
-- The frames deliberately straddle the cold half of the ribbon, where the frost decals
-- live: the habitable brown band, the brown->ice transition, and the deep ice. If the
-- ground tiles are not clearly legible under the decals in these shots, the density is
-- still too high. Screenshots land in script-output/.

local done = false

script.on_event(defines.events.on_tick, function(e)
  if done then return end
  -- Let the world finish init before creating the planet surface.
  if e.tick < 60 then return end
  done = true

  local s = game.surfaces["cindra"]
    or (game.planets["cindra"] and game.planets["cindra"].create_surface())
  if not s then error("mapgen-shot: no cindra surface") end

  -- Generate the whole cold half plus the middle (x in [-64, 416] at chunk grain).
  s.request_to_generate_chunks({ 160, 0 }, 9)
  s.force_generate_chunk_requests()

  -- Perp = -x, so the COLD side is +x: middle 0..60, brown dust 60..130, frost/ice
  -- belt 130..200, ice ocean beyond 200.
  local shots = {
    -- Wide: the whole cold half in one frame -- does the frost stay off the browns?
    { pos = { 130, 0 }, z = 0.22, res = { 1600, 1000 }, tag = "cold-half" },
    -- Closeups at the three reads the bead cares about.
    { pos = { 90, 0 },  z = 1.0, res = { 1280, 800 }, tag = "habitable-dust" },
    { pos = { 140, 0 }, z = 1.0, res = { 1280, 800 }, tag = "frost-edge" },
    { pos = { 185, 0 }, z = 1.0, res = { 1280, 800 }, tag = "deep-frost" },
  }
  for _, sh in ipairs(shots) do
    game.take_screenshot{
      surface = s,
      position = sh.pos,
      zoom = sh.z,
      resolution = sh.res,
      path = "mapgen-" .. sh.tag .. ".png",
      daytime = 0.0,
      force_render = true,
      anti_alias = true,
    }
  end
end)
