-- Environmental scanner prototypes.
--
-- The scanner is a CONSTANT-COMBINATOR clone: reusing that type gives us a
-- native circuit-network output (wires, sections) for free, and the runtime
-- (scripts/scanner.lua) just writes the surface readings into its output each
-- tick. Cloning a vanilla prototype into a NEW name means this mod adds content
-- without editing any shared/vanilla prototype (the never-mutate rule).
--
-- The recipe is deliberately chemistry-free (iron + copper + electronic
-- circuits, no plastic / sulfur / oil) to preserve Cindra's zero-chemistry
-- identity, while remaining buildable on any vanilla planet (it is exportable).
--
-- The scanner ENTITY + ITEM art is the user-supplied "radio-station" set (ci-0e8):
-- a bespoke building body, a ground shadow, and an emissive glow layer, plus a
-- dedicated icon. The SIGNAL icons remain placeholder (reused base icons); a
-- follow-up bead tracks bespoke signal art. See scripts/readings.lua for the
-- signal meanings and scaling.
--
-- Body-animation note: a constant-combinator renders its body through the
-- `sprites` field, which is a Sprite4Way built from *static* Sprites (the Sprite
-- type has no frame_count). So the body cannot frame-animate from the prototype.
-- We render the first frame of the supplied animation strip as the static body
-- and wire the emission as a draw_as_glow layer. The full multi-frame strips are
-- shipped (not just a cropped frame) so a future entity-type change or runtime
-- overlay can animate without re-sourcing the art. A runtime LuaRendering overlay
-- would animate in-world but would NOT show in ghost / blueprint / factoriopedia
-- previews (a regression) and cannot be visually verified headless, so it is out
-- of scope here. Visual scale/shift confirmation is tracked in PLAYTEST.md.

local util = require("util")
local C = require("scripts.config")
local readings = require("scripts.readings")

local S = readings.SIGNALS

-- === Radio-station art (user-supplied) =======================================
local GFX = "__env-scanner__/graphics/"
local ENTITY_GFX = GFX .. "entity/scanner/"
local ICON = GFX .. "icons/radio-station-icon.png"

-- Frame geometry of the supplied animation strip: 1280x870 px laid out as an
-- 8-wide grid of 160x290 frames (20 frames; last row partial). We render the
-- top-left frame (x=0, y=0) as the static body.
local FRAME_W, FRAME_H = 160, 290
local BODY_SCALE = 0.4
-- Lift the sprite so the building base sits on the 1x1 footprint (the frame is
-- tall; a centered sprite would bury the base). Values pending PLAYTEST.
local BODY_SHIFT = util.by_pixel(0, -44)

local scanner_sprites = {
  layers = {
    { -- building body (frame 0 of the animation strip)
      filename = ENTITY_GFX .. "radio-station-hr-animation-1.png",
      width = FRAME_W,
      height = FRAME_H,
      scale = BODY_SCALE,
      shift = BODY_SHIFT,
    },
    { -- ground shadow (its own composed image, not on the frame grid)
      filename = ENTITY_GFX .. "radio-station-hr-shadow.png",
      width = 400,
      height = 350,
      scale = BODY_SCALE,
      shift = util.by_pixel(30, 6),
      draw_as_shadow = true,
    },
    { -- emissive glow: screens / status LEDs / vents (renders lit in the dark)
      filename = ENTITY_GFX .. "radio-station-hr-emission-1.png",
      width = FRAME_W,
      height = FRAME_H,
      scale = BODY_SCALE,
      shift = BODY_SHIFT,
      draw_as_glow = true,
    },
  },
}

-- === The buildable scanner (a renamed constant combinator) ===================
local scanner = util.table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
scanner.name = C.SCANNER
scanner.minable = { mining_time = 0.1, result = C.SCANNER }
scanner.next_upgrade = nil
-- A single Sprite applies to all 4 directions (Sprite4Way rule); the radio
-- station reads the same from every side.
scanner.sprites = scanner_sprites
scanner.icon = ICON
scanner.icon_size = 64

local scanner_item = util.table.deepcopy(data.raw["item"]["constant-combinator"])
scanner_item.name = C.SCANNER
scanner_item.place_result = C.SCANNER
scanner_item.order = "c[combinators]-z[environmental-scanner]"
scanner_item.icon = ICON
scanner_item.icon_size = 64

-- Chemistry-free recipe, enabled from the start for this standalone PoC.
local scanner_recipe = {
  type = "recipe",
  name = C.SCANNER,
  enabled = true,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "iron-plate", amount = 5 },
    { type = "item", name = "copper-cable", amount = 5 },
    { type = "item", name = "electronic-circuit", amount = 5 },
  },
  results = { { type = "item", name = C.SCANNER, amount = 1 } },
}

-- === Virtual signals =========================================================
-- A dedicated subgroup under the vanilla "signals" group so the scanner's
-- readouts cluster together in the signal picker.
local subgroup = {
  type = "item-subgroup",
  name = "env-scanner-signals",
  group = "signals",
  order = "z[env-scanner]",
}

-- Placeholder icons reused from base items (art follow-up bead filed).
local SIGNAL_DEFS = {
  { name = S.DAYTIME,         icon = "__base__/graphics/icons/accumulator.png",     order = "a" },
  { name = S.DAYLIGHT,        icon = "__base__/graphics/icons/solar-panel.png",     order = "b" },
  { name = S.SOLAR,           icon = "__base__/graphics/icons/substation.png",      order = "c" },
  { name = S.TICK_OF_DAY,     icon = "__base__/graphics/icons/radar.png",           order = "d" },
  { name = S.FLARE_COUNTDOWN, icon = "__base__/graphics/icons/lab.png",             order = "e" },
  { name = S.FLARE_PHASE,     icon = "__base__/graphics/icons/iron-plate.png",      order = "f" },
  { name = S.FLARE_INTENSITY, icon = "__base__/graphics/icons/copper-plate.png",    order = "g" },
}

local signals = {}
for _, def in ipairs(SIGNAL_DEFS) do
  signals[#signals + 1] = {
    type = "virtual-signal",
    name = def.name,
    icon = def.icon,
    icon_size = 64,
    subgroup = "env-scanner-signals",
    order = def.order .. "[" .. def.name .. "]",
  }
end

data:extend({ scanner, scanner_item, scanner_recipe, subgroup })
data:extend(signals)
