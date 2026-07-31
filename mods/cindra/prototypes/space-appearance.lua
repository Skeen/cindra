-- Cindra space appearance: the star-map sprite + the live orbital backdrop.
--
-- SELF-CONTAINED MODULE. This owns the ART side of the planet prototype (the
-- icon/starmap fields and the platform_surface_render_parameters VALUES), kept
-- apart from the gameplay prototype (prototypes/planet.lua, ci-m1n). All wiring
-- lives in data-updates.lua (nauvis params only exist by the data-updates stage):
--
--   local space = require("prototypes.space-appearance")
--   space.apply_icons(data.raw.planet["cindra"])                                -- icon + star-map sprite
--   space.apply_backdrop(data.raw.planet["cindra"], data.raw.planet["nauvis"])  -- orbital backdrop
--
-- Both the star-map bake and this orbital backdrop are derived from the SAME
-- procedural equirectangular maps in graphics/space/ (scripts/render-planet.sh),
-- so the two views read as one planet.
--
-- TIDALLY LOCKED = NO PLANET ROTATION. The star-map sprite is a static bake, so
-- it cannot spin. The orbital backdrop is frozen here by setting rotation_seconds
-- to an enormous value (NO_ROTATION): the engine's spin becomes imperceptible, so
-- the same molten-day / terminator / frozen-night face is presented permanently.
-- Only the CLOUD layer animates, via rotate_with_planet = false, so the terminator
-- steam band drifts while the GLOBE stays still (planet_design.md: "only the GLOBE
-- must be static"). A SUBTLE solar-flare arc rides the dayside (fire) limb (ci-cn1):
-- the oversized full-height version was pulled in ci-i9m for reading as a bottom-of-
-- globe rocket plume, so this one is small and pinned to the LEFT limb. The flare
-- GAMEPLAY event (prototypes/flare.lua) is a separate system.

local util = require("util")

local M = {}

-- One full rotation takes ~31 years of game time: the globe never visibly turns.
-- This is how we express tidal lock through the existing rotation_seconds field
-- instead of a bespoke "no spin" flag the engine does not provide.
local NO_ROTATION = 1.0e9

-- Icon / star-map fields for the planet prototype (data stage).
M.icon_fields = {
  icon = "__cindra__/graphics/icons/cindra.png",
  icon_size = 64,
  icon_mipmaps = 4,
  starmap_icon = "__cindra__/graphics/icons/starmap-planet-cindra.png",
  starmap_icon_size = 512,
}

-- Merge the icon/star-map fields onto a planet prototype table.
function M.apply_icons(planet)
  for k, v in pairs(M.icon_fields) do
    planet[k] = v
  end
  return planet
end

-- Route icon for the Vulcanus -> Cindra space connection (ci-bu4).
--
-- Space Age's own data-updates.lua auto-composites a route icon for every
-- space-connection that lacks one: a transfer-arrow base (planet-route.png) with
-- the ORIGIN badge top-left and the DESTINATION badge bottom-right, both at scale
-- 0.333, the destination drawn LAST so it sits frontmost. Every vanilla route
-- icon follows that convention.
--
-- We cannot just let that loop fill ours in. It runs BEFORE Cindra's own
-- data-updates swaps the baked icon onto the planet (cindra depends on space-age,
-- so cindra's data-updates runs later), so it would bake the vanilla Vulcanus
-- PLACEHOLDER as the Cindra badge -- two Vulcanus globes, no transfer arrows read
-- as a route. The earlier hand-rolled override then broke the convention the
-- other way (a full-size Cindra base with a shrunken Vulcanus in FRONT).
--
-- Fix: pin the SAME composite by hand, matching the vanilla formula exactly but
-- with the real baked Cindra icon as the destination:
--   * planet-route.png transfer arrows as the base,
--   * Vulcanus (origin) top-left at scale 0.333,
--   * Cindra  (destination) bottom-right at scale 0.333, LAST -> frontmost.
M.ROUTE_ARROWS_ICON = "__space-age__/graphics/icons/planet-route.png"
M.ROUTE_BADGE_SCALE = 0.333 -- vanilla route-badge scale (space-age data-updates)

function M.route_icons()
  return {
    { icon = M.ROUTE_ARROWS_ICON },
    {
      icon = "__space-age__/graphics/icons/vulcanus.png",
      icon_size = 64, scale = M.ROUTE_BADGE_SCALE, shift = { -6, -6 },
    },
    {
      icon = M.icon_fields.icon,
      icon_size = M.icon_fields.icon_size,
      icon_mipmaps = M.icon_fields.icon_mipmaps,
      scale = M.ROUTE_BADGE_SCALE, shift = { 6, 6 },
    },
  }
end

local function map(name)
  return { filename = "__cindra__/graphics/space/" .. name, width = 2048, height = 1024 }
end

-- Build the non-rotating orbital backdrop. Deep-copies the passed nauvis params
-- (which carry the generic, planet-agnostic space-dust fields) and overrides only
-- the planet-specific backdrop, so we never mutate the shared nauvis table.
function M.build_render_parameters(nauvis_params)
  local params = util.table.deepcopy(nauvis_params)

  -- Subtle solar-flare arc on the dayside (fire) limb (ci-cn1). The star is
  -- perilously close and throws flares (DESIGN.md; the gameplay event lives in
  -- prototypes/flare.lua), so a small emissive prominence licking off the LEFT
  -- limb sells that from space. This is a deliberate re-do of the overlay ci-i9m
  -- removed: that one used full-height quads (up to 0.95 of the disc) anchored low,
  -- so the vertical flame columns read as a "rocket-engine plume" near the bottom
  -- of the globe. The fix is size + placement, not deletion:
  --   * SMALL -- a fraction of the disc, so it reads as a flare tongue not a plume;
  --   * pinned to the LEFT (fire) limb, upper hemisphere, well clear of the bottom;
  --   * front-only + rotate_with_planet = false so it arcs in place while the
  --     tidally-locked globe stays frozen (see NO_ROTATION);
  --   * emissive so it glows against dark space like a real prominence.
  -- The flare spritesheet is 24 frames on a 6-wide sheet of 256px cells
  -- (scripts/gen-planet-maps.py build_flare_sheet): a seamless rise-and-fall loop.
  local flare_sheet = {
    filename = "__cindra__/graphics/space/cindra-flare.png",
    width = 256, height = 256, line_length = 6, frame_count = 24, animation_speed = 0.35,
  }
  -- ONE instance: a single arc reads as a flare, two staggered ones read as the
  -- old competing plumes. LEFT limb (negative x), upper hemisphere (positive y,
  -- away from the bottom where the old plume sat), small size.
  local flare_heroes = {
    {
      sprite_index = 1,
      rotate_with_planet = false,
      projection_style = "front-only",
      positions = { { -0.50, 0.42 } },   -- upper-left: flames lick off the fire limb into dark sky
      size = { 0.32, 0.44 },             -- small: a fraction of the disc, not the old 0.95
      position_deviation = { 0.02, 0.02 },
      rotation_deviation = 0.0,
      starting_frame_offset = 0,
    },
  }

  params.platform_backdrop = {
    emission_scales_with_shadow = false,   -- magma glows on its own, across the disc
    -- The emission map does DOUBLE duty (see cindra-emission.png): a white-hot
    -- magma core on the dayside AND a faint blue self-glow on the ice side. The
    -- engine has no cool world-ambient field like the Blender bake's (0.11,0.17,
    -- 0.30 @ 0.40), so this emission IS the engine's stand-in for it: scaled high
    -- and independent of shadow, it both blows the sunward limb out to near-WHITE
    -- (matching the star-map icon's hot highlight) and lifts the shadowed ice
    -- hemisphere off pure black into a dim shimmery BLUE (ci-6y9 orbital parity).
    emission_scalar = 5.5,                 -- blow out lava + lift the blue ice glow

    radius = 600,
    -- TIDAL LOCK: the globe does not spin. See NO_ROTATION above.
    rotation_seconds = NO_ROTATION,

    -- Was 0.4: a heavy grey steam band muddied the whole terminator into an
    -- opaque wall, nothing like the icon's clean fire->ice boundary. Thinned so
    -- the seam still drifts with life (cloud_* below) but the lit/dark gradient
    -- reads through it.
    cloudiness = 0.09,                     -- thin drifting terminator steam
    surface_vertical_offset = 0.1,
    cloud_vertical_offset = 0.02,
    -- Was 0.95: at the grazing terminator angle that high sheen lit the sandy
    -- transition strip into a bright pale-CREAM wall, far brighter than the icon's
    -- darker rocky terminator. Dropped so the fire->ice boundary stays a readable
    -- gradient and the ice keeps a subtle (not glaring) cold glint (ci-6y9).
    specular_intensity = 0.5,              -- subtle icy nightside sheen
    -- COOL blue twilight rim (ci-6y9): the icon's dark hemisphere reads as deep
    -- blue ICE, not a warm void. A faintly warm rim (the old {0.06,0.04,0.05})
    -- tinted the whole night side olive; a cool blue rim pushes it toward the
    -- icy blue the emission glow is already lifting.
    atmosphere_color = { 0.05, 0.08, 0.14, 0.08 },
    cloud_flow_intensity = 0.8,
    cloud_panning_rate = -0.06,

    -- Static presentation tilt of the globe's axis: a fixed angle, not motion.
    planet_axis = { -18.0, -4.0 },
    -- TIDAL LOCK => the axis must NOT wobble either (ci-ane). Vanilla planets set
    -- a non-zero deviation amplitude so their globes gently NOD on the orbital
    -- backdrop; Cindra inherited {6,6}, which left the rotation-frozen globe still
    -- WOBBLING -- exactly the "planet rotates/wobbles in the space view" the report
    -- flags. Freezing rotation_seconds (NO_ROTATION) alone is NOT enough: the axis
    -- deviation is an independent periodic nod. Zero the amplitude so the tidally
    -- locked face is truly static. At zero amplitude the deviation period is inert,
    -- so the paired *_deviation_seconds knob is dropped.
    planet_axis_deviation_amplitude = { 0.0, 0.0 },
    position = { -400, 300 },
    parallax_strength = { 0.95, 0.95 },

    -- Key light FROM the dayside (fire) limb on the left. The star-map bake aims
    -- a single sun EXACTLY HORIZONTAL from the left, perpendicular to the vertical
    -- terminator meridian (bake-starmap.py), so the sunward limb blows out and the
    -- disc falls to shadow across the centre. Match that here: near-horizontal
    -- from the left (x dominant, y/z small) instead of the old three-quarter angle
    -- that pulled the terminator off-vertical and left <50% lit (ci-6y9).
    light_direction = { -0.90, 0.05, 0.24 },
    -- Larger radius softens the terminator and wraps a little light past 90deg so
    -- ~55% of the disc reads as lit (the icon's soft, slightly-past-centre seam,
    -- ci-nyj), instead of the old crisp <50% half.
    light_radius = 12.0,
    -- Raised (was 0.45): a harder falloff drops the sandy transition strip at the
    -- terminator out of the bright-cream wall it was reading as into the icon's
    -- darker mid-brown rocky terminator, and sharpens the icon's DRAMATIC
    -- fire->ice pop so the shadowed ice hemisphere stays clearly the dark side.
    light_intensity_contrast = 0.58,
    -- Cool blue frost sheen on the icy nightside (the bake's glossy ice catches
    -- the cool ambient); a warm/white specular would wash the ice yellow.
    specular_color = { 0.5, 0.7, 1.0, 1 },

    -- Subtle emissive solar-flare arc on the fire limb (ci-cn1; defined above).
    hero_clouds_are_emissive = true,
    hero_cloud_texture_1 = flare_sheet,
    hero_clouds = flare_heroes,

    -- Surface + relief + reflectivity: the molten/frozen crust.
    planet_surface = map("cindra.png"),
    planet_normal = map("cindra-normal.png"),
    planet_reflectivity = map("cindra-reflectivity.png"),

    -- planet_emission = the self-lit MAGMA GLOW on the dayside (white-hot at the
    -- sub-stellar point, cooling to orange/red toward the terminator). It rotates
    -- rigidly with the globe, which is fine because the globe is frozen.
    planet_emission = map("cindra-emission.png"),

    -- global_cloud = the drifting TERMINATOR steam/ash band (coloured RGBA) that
    -- slides over the seam via the flow map + cloud_panning_rate, so the seam looks
    -- alive while the globe stays still.
    global_cloud = map("cindra-cloud.png"),
    global_cloud_normal = map("cindra-cloud-normal.png"),
    global_cloud_flow = map("cindra-cloud-flow.png"),
  }

  return params
end

-- Convenience: set the planet's orbital backdrop from the nauvis prototype.
function M.apply_backdrop(planet, nauvis)
  if planet and nauvis and nauvis.platform_surface_render_parameters then
    planet.platform_surface_render_parameters =
      M.build_render_parameters(nauvis.platform_surface_render_parameters)
  end
  return planet
end

return M
