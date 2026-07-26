-- Cindra mod settings.
--
-- v1 exposes the ribbon-geometry tuning knobs so the temperature axis (§4) can
-- be balanced live without editing Lua. These mirror scripts/ribbon.lua's
-- DEFAULTS; the runtime systems that consume the axis (§15 item 2 onward) read
-- these. All are (tune) starting points (§16).

data:extend({
  -- Half-width (tiles) of the guaranteed-safe temperate band around the ribbon
  -- centre. Inside this, no environmental damage.
  {
    type = "int-setting",
    name = "cindra-ribbon-safe-half-width",
    setting_type = "startup",
    default_value = 24,
    minimum_value = 4,
    maximum_value = 128,
    order = "a-safe-half-width",
  },
  -- Distance (tiles) from centre at which environmental damage reaches its
  -- maximum (the lethal deep edge).
  {
    type = "int-setting",
    name = "cindra-ribbon-lethal-at",
    setting_type = "startup",
    default_value = 96,
    minimum_value = 16,
    maximum_value = 512,
    order = "b-lethal-at",
  },
  -- Distance (tiles) from centre of the hard-wall backstop: the player can never
  -- walk past this into instant death or off the usable map (§15 item 2).
  {
    type = "int-setting",
    name = "cindra-ribbon-wall-at",
    setting_type = "startup",
    default_value = 128,
    minimum_value = 16,
    maximum_value = 512,
    order = "c-wall-at",
  },
  -- Peak environmental damage-per-second at the lethal edge. Survivable briefly
  -- with mitigation gear so the best edge resources are reachable at a cost.
  {
    type = "double-setting",
    name = "cindra-ribbon-max-dps",
    setting_type = "startup",
    default_value = 200,
    minimum_value = 0,
    maximum_value = 10000,
    order = "d-max-dps",
  },
})
