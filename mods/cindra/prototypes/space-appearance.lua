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
-- must be static"). The hero solar-flare overlay was removed in ci-i9m (it rendered
-- as a bottom-of-globe plume artifact); the flare GAMEPLAY event is separate.

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

  -- NO hero-flare overlay on the orbital backdrop (ci-i9m). The old flare-arc
  -- sprites were placed as huge (up to 0.95 of the disc) front-only quads and
  -- rendered as garish white/yellow vertical PLUMES near the bottom of the globe
  -- -- the "rocket-engine plume" junk artifact the mayor flagged. They are removed
  -- here so the from-space planet is a clean fire/ice globe. This is the ART view
  -- only; the GAMEPLAY solar-flare power event (prototypes/flare.lua) is untouched.
  -- A tasteful limb-flare visual can return later as its own bead (see PLAYTEST.md).

  params.platform_backdrop = {
    emission_scales_with_shadow = false,   -- magma glows on its own, across the disc
    emission_scalar = 2.4,                 -- STRONGLY GLOWING dayside (ci-fg6)

    radius = 600,
    -- TIDAL LOCK: the globe does not spin. See NO_ROTATION above.
    rotation_seconds = NO_ROTATION,

    cloudiness = 0.4,                      -- drifting terminator steam band
    surface_vertical_offset = 0.1,
    cloud_vertical_offset = 0.02,
    specular_intensity = 0.95,             -- shimmery icy nightside sheen (ci-fg6)
    -- Dark, faintly warm twilight rim (the atmosphere itself is thin here).
    atmosphere_color = { 0.06, 0.04, 0.05, 0.1 },
    cloud_flow_intensity = 0.8,
    cloud_panning_rate = -0.06,

    planet_axis = { -18.0, -4.0 },
    planet_axis_deviation_amplitude = { 6.0, 6.0 },
    planet_axis_deviation_seconds = { 900.0, 760.0 },
    position = { -400, 300 },
    parallax_strength = { 0.95, 0.95 },

    -- Hot key light FROM the dayside (fire) limb on the left: strong, warm,
    -- high-contrast so the terminator falls into deep shadow toward the nightside.
    light_direction = { -0.62, 0.20, 0.55 },
    light_radius = 6.0,
    light_intensity_contrast = 0.45,

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
