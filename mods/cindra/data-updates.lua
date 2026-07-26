-- Cindra ART wiring (ci-94v), kept separate from the gameplay prototype
-- (prototypes/planet.lua, ci-m1n) so the two concerns stay in their own files.
--
-- planet.lua ships with vanilla Vulcanus placeholder icons and no orbital
-- backdrop (it explicitly defers the bespoke ribbon art to "a later art pass").
-- This IS that pass: here we swap in the baked Cindra star-map sprite + icon and
-- add the NON-ROTATING (tidally locked) orbital backdrop, all sourced from the
-- self-contained module prototypes/space-appearance.lua.
--
-- Why the data-updates stage: Space Age assigns
-- nauvis.platform_surface_render_parameters in its OWN data-updates pass, so the
-- nauvis params (generic space-dust fields we deep-copy) only exist by now. The
-- module deep-copies them, so we never mutate the shared nauvis table.

local space = require("prototypes.space-appearance")

local cindra = data.raw.planet["cindra"]
local nauvis = data.raw.planet["nauvis"]

if cindra then
  -- Star-map sprite + planet icon: the baked tidally-locked fire/ice globe.
  space.apply_icons(cindra)

  -- The live orbital backdrop: the same face presented permanently (frozen
  -- rotation), with only the terminator cloud band and solar flares animating.
  space.apply_backdrop(cindra, nauvis)
end

-- Match the planet-discovery tech icon to the real Cindra planet (it also shipped
-- with the Vulcanus placeholder). Only the flat icon fields apply to a technology.
local tech = data.raw.technology["planet-discovery-cindra"]
if tech then
  tech.icon = space.icon_fields.icon
  tech.icon_size = space.icon_fields.icon_size
  tech.icon_mipmaps = space.icon_fields.icon_mipmaps
end
