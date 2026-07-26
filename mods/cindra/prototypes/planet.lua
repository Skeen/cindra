-- The Cindra planet (§1, §2, §4; §15 item 1).
--
-- Minimal-but-real: a valid, LOADABLE, LANDABLE planet so `surface.name ==
-- "cindra"` exists in a live game and the ribbon/temperature systems actually
-- run on it. Cindra is tidally locked and orbits perilously close to its star:
-- a molten dayside, a frozen nightside, and a narrow survivable ribbon at the
-- terminator (the playable surface). Its identity is a single tension — HOT vs
-- COLD — and survival is routing the star's surplus between fire and ice.
--
-- v1 ART NOTE (see TODO.md / PLAYTEST.md): custom Cindra sprites (star-map,
-- orbital backdrop, terminator terrain) are DEFERRED. To keep the planet
-- loadable now we reference vanilla Vulcanus icons (a hot, sunward-facing world
-- reads correctly for the dayside). The bespoke ribbon art is a later art pass;
-- gameplay does not depend on it.
--
-- DEFERRED to §15 item 2 (documented, not a gap): the PHYSICAL ribbon geometry
-- (impassable hard-wall backstop perpendicular to the terminator, generous
-- east-west length). This file establishes the planet + surface + the
-- temperature axis framing; scripts/ribbon.lua is the single source of truth for
-- the hot-cold axis value (unit-tested). The lethal-edge damage that CONSUMES
-- that axis, and the wall that bounds it, land in item 2.

local planet_map_gen = require("__base__/prototypes/planet/planet-map-gen")
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")

local minute = 60 * 60

-- Cindra terrain: NAUVIS map gen for its working, buildable land, but with NO
-- vanilla ores, enemies, trees, rocks or cliffs. Cindra has no biology and no
-- native crude; the resource economy (stone on the ribbon, ice on the nightside,
-- scattered bootstrap rocks) is added deliberately in §15 item 3, not via
-- vanilla autoplace. This mirrors the well-trodden "clean-slate planet" pattern.
local function cindra_map_gen()
  local mg = planet_map_gen.nauvis()

  -- Keep only terrain-shaping controls; drop every ore, enemy, tree, rock, cliff.
  mg.autoplace_controls = {
    ["water"] = {},
    ["starting_area_moisture"] = {},
  }
  mg.default_enable_all_autoplace_controls = false

  mg.autoplace_settings = mg.autoplace_settings or {}
  mg.autoplace_settings.entity = { treat_missing_as_default = false, settings = {} }
  mg.autoplace_settings.decorative = { treat_missing_as_default = false, settings = {} }

  -- No cliffs (push the elevation threshold out of reach).
  mg.cliff_settings = { name = "cliff", cliff_elevation_0 = 1024, cliff_elevation_interval = 1024 }

  return mg
end

data:extend({
  {
    type = "planet",
    name = "cindra",
    -- v1: vanilla Vulcanus art (see ART NOTE above). Swap for baked Cindra
    -- ribbon art in a later pass.
    icon = "__space-age__/graphics/icons/vulcanus.png",
    icon_size = 64,
    icon_mipmaps = 4,
    starmap_icon = "__space-age__/graphics/icons/starmap-planet-vulcanus.png",
    starmap_icon_size = 512,
    gravity_pull = 10,
    -- Innermost world of the system: Cindra hugs the star, sunward of Vulcanus.
    distance = 6,
    orientation = 0.05,
    magnitude = 1.2,
    order = "a[cindra]",
    subgroup = "planets",
    map_gen_settings = cindra_map_gen(),
    pollutant_type = nil,
    -- Orbits perilously close to the star -> enormous raw solar intensity.
    solar_power_in_space = 2000,
    surface_properties = {
      -- Day-night cycle: the flare driver (§15-7, scripts/flare.lua) FREEZES
      -- daytime and drives it along the telegraph/ramp/plateau/decay curve, so
      -- this value is a fallback rhythm only (used if the driver is disabled).
      ["day-night-cycle"] = 5 * minute,
      ["magnetic-field"] = 25,
      -- §15-7 solar: the real ~10000%-of-Nauvis surface multiplier (100x). Nauvis
      -- reads 100 here; 10000 = 100x, the fixed high multiplier the flare swings
      -- across via the daylight curve. scripts/flare.lua re-affirms the matching
      -- surface.solar_power_multiplier at runtime as it drives the curve, and the
      -- dim between-flare floor still delivers ~one Nauvis-full-day (runs the
      -- factory). (tune) §15-14 validates this against the lava recipe's cost.
      ["solar-power"] = 10000,
      -- No atmosphere to speak of ("the air itself would boil, were there any"):
      -- a thin envelope over molten rock.
      pressure = 500,
      gravity = 20,
    },
    -- No custom orbital backdrop / clouds in v1 (art deferred). The engine
    -- renders a plain approach; the planet is fully playable without it.
  },
  -- Reachability (§6): Cindra is GATED AFTER VULCANUS — you need foundries +
  -- lava-processing tech before the manufactured-lava economy makes sense.
  -- Hang it off Vulcanus (both hot, sunward worlds), reached after it.
  {
    type = "space-connection",
    name = "vulcanus-cindra",
    subgroup = "planet-connections",
    from = "vulcanus",
    to = "cindra",
    order = "a[cindra]",
    length = 80000,
    -- Space-connection form: the helper takes NO density multiplier (that second
    -- arg is for a planet's approach field, and yields a different structure).
    asteroid_spawn_definitions = asteroid_util.spawn_definitions(asteroid_util.nauvis_vulcanus),
  },
  -- Discovery tech: without an unlock-space-location effect Cindra shows up
  -- greyed-out (visible but not travellable) on the star map. Gated behind
  -- Vulcanus per §6. (When a game STARTS on Cindra via any-planet-start, that
  -- mod removes this tech and unlocks the location directly.)
  {
    type = "technology",
    name = "planet-discovery-cindra",
    icon = "__space-age__/graphics/icons/vulcanus.png",
    icon_size = 64,
    icon_mipmaps = 4,
    essential = true,
    effects = {
      { type = "unlock-space-location", space_location = "cindra", use_icon_overlay_constant = true },
    },
    prerequisites = { "planet-discovery-vulcanus" },
    unit = {
      count = 500,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "space-science-pack", 1 },
      },
      time = 60,
    },
  },
})
