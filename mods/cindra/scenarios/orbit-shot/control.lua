-- Orbit-shot scenario (ci-6y9): capture an in-engine screenshot of Cindra's
-- LIVE orbital backdrop so the platform_surface_render_parameters can be tuned
-- for parity with the baked star-map icon. NOT shipped gameplay -- this is a
-- render harness the same way scripts/render-*.sh are (loaded only via
-- `--load-scenario cindra/orbit-shot` under the headless EGL renderer).
--
-- It spawns a stationary space platform in orbit of cindra, waits for the
-- backdrop to settle, then screenshots that surface at several zooms/positions
-- so we can find and frame the globe. Screenshots land in script-output/.

local done = false

script.on_event(defines.events.on_tick, function(e)
  if done then return end
  -- Give the game a few ticks to finish world init before spawning.
  if e.tick < 60 then return end
  done = true

  local f = game.forces["player"]
  -- Unlock space platforms (and everything else) so create_space_platform is
  -- permitted; the tech gate is the only thing standing between us and a
  -- platform in orbit.
  f.research_all_technologies()

  local p = f.create_space_platform{
    name = "orbit-shot",
    planet = "cindra",
    starter_pack = "space-platform-starter-pack",
  }
  p.apply_starter_pack()
  -- Park it stationary over cindra so the planet renders as the backdrop.
  p.paused = false
  local s = p.surface

  -- The globe is a parallax backdrop anchored near the platform origin, so it is
  -- best framed at {0,0}: a tight shot fills the frame with the disc; a wider
  -- shot shows the whole globe. (Panning the camera carries the globe with it, so
  -- there is no framing that also hides the small hub entity; it reads fine as a
  -- platform-eye view.)
  -- close/wide are the ci-6y9 parity shots (they crop the fire limb off the left).
  -- "full" zooms out so the WHOLE disc, including the fire (left) limb and its
  -- lower edge, is in frame -- that is where the ci-cn1 solar-flare arc rides, so
  -- this shot is how the flare gets eyeballed via render-orbit.sh. The far zoom
  -- leaves a few black parallax-tiling gaps under llvmpipe (a harness artifact, not
  -- the backdrop); the flare area on the lower-left limb stays clear.
  local shots = {
    { z = 0.2, pos = { 0, 0 }, tag = "close" },
    { z = 0.14, pos = { 0, 0 }, tag = "wide" },
    { z = 0.07, pos = { 0, 0 }, tag = "full" },
  }
  for _, sh in ipairs(shots) do
    game.take_screenshot{
      surface = s,
      position = sh.pos,
      zoom = sh.z,
      resolution = { 1440, 1440 },
      path = "orbit-" .. sh.tag .. ".png",
      daytime = 0.0,
      force_render = true,
      anti_alias = true,
    }
  end
end)
