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
-- vanilla ores, enemies, trees, rocks, cliffs -- and, crucially, NO WATER. Cindra
-- has no biology, no native crude, and no water bodies (its only water comes from
-- processing nightside ice); a molten dayside and a frozen nightside leave no room
-- for lakes. The resource economy (stone patches on the ribbon, ice patches on the
-- nightside, deep-nightside volatiles, scattered bootstrap rocks) is Cindra's own,
-- via the `cindra-*` autoplace controls below (§15 item 3 / worldgen-v2).
local function cindra_map_gen()
  local mg = planet_map_gen.nauvis()

  -- Enable ONLY Cindra's own resource controls plus terrain moisture. Note: NO
  -- "water" control -> the water autoplace is off. Keeping the resource controls
  -- here is what surfaces their Frequency/Size/Richness sliders on the map-gen
  -- screen and lets a game actually generate the patches.
  mg.autoplace_controls = {
    ["cindra-stone"] = {},
    ["cindra-ice"] = {},
    ["cindra-volatiles"] = {},
    ["starting_area_moisture"] = {},
  }
  mg.default_enable_all_autoplace_controls = false

  mg.autoplace_settings = mg.autoplace_settings or {}
  -- Entities: ONLY the three Cindra resources autoplace (no vanilla ore/enemy/
  -- rock). The bootstrap rocks are scattered by scripts/worldgen.lua, not here.
  mg.autoplace_settings.entity = {
    treat_missing_as_default = false,
    settings = {
      ["cindra-stone"] = {},
      ["cindra-ice"] = {},
      ["cindra-volatiles"] = {},
    },
  }
  mg.autoplace_settings.decorative = { treat_missing_as_default = false, settings = {} }

  -- Tiles: nauvis LAND tiles only. water + deepwater are deliberately OMITTED, so
  -- no water tile is ever a placement candidate -- Cindra generates NO water and
  -- NO starting lake at ANY map-gen setting (a water slider cannot conjure a tile
  -- that is not in the set). This is the same mechanism the no-water vanilla
  -- planets (e.g. Vulcanus) use.
  mg.autoplace_settings.tile = {
    treat_missing_as_default = false,
    settings = {
      ["grass-1"] = {}, ["grass-2"] = {}, ["grass-3"] = {}, ["grass-4"] = {},
      ["dry-dirt"] = {},
      ["dirt-1"] = {}, ["dirt-2"] = {}, ["dirt-3"] = {}, ["dirt-4"] = {},
      ["dirt-5"] = {}, ["dirt-6"] = {}, ["dirt-7"] = {},
      ["sand-1"] = {}, ["sand-2"] = {}, ["sand-3"] = {},
      ["red-desert-0"] = {}, ["red-desert-1"] = {}, ["red-desert-2"] = {}, ["red-desert-3"] = {},
    },
  }

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
    -- TIDAL LOCK: the fiery dayside must face the star (ci-2sr). The star-map
    -- icon is a fixed bake (space-appearance.lua) with the FIRE hemisphere on
    -- the sprite's LEFT limb and the icy nightside on the right. Left unset, the
    -- engine defaults starmap_icon_orientation to "pointing at the sun" by
    -- aiming the icon's TOP sunward, which leaves the fiery LEFT limb ~90deg off
    -- the sunward direction. Rotate the icon so the FIRE limb -- not the top --
    -- points at the star.
    --
    -- Geometry (RealOrientation: 0 = up, increasing clockwise). The sun sits
    -- opposite the planet's orbital angle, at (orientation + 0.5). The fire limb
    -- is a quarter-turn (0.25) counter-clockwise of the icon's top, so aiming it
    -- sunward means orienting the icon's top to (orientation + 0.5 - 0.75) =
    -- (orientation - 0.25). For orientation 0.05 this is 0.8.
    starmap_icon_orientation = (0.05 - 0.25) % 1,
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
