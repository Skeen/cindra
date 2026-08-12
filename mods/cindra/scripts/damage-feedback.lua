-- The AMBIENT THERMAL GRADE: a subtle, continuous screen hue wash driven by WHERE
-- the player stands on the ribbon's hot-cold axis (ci-nw0; supersedes the ci-7tl
-- binary damage overlay).
--
-- Cindra's whole identity is "hot one way, cold the other". The player should FEEL
-- that as they walk, not just when something bites them. So the screen carries a
-- gentle colour grade that tracks position on the temperature axis:
--
--   temperate middle band  ->  NOTHING at all (the ribbon reads neutral)
--   sunward of the middle  ->  a warm ORANGE wash, deepening toward the lava
--   nightward of the middle ->  a cool BLUE wash, deepening toward the ice
--
-- It is a HUE GRADE, not a vignette blackout: the alpha starts at literally zero at
-- the temperate edge, is a whisper for the first stretch out, and tops out at
-- M.MAX_ALPHA at the ocean cores. It is ALWAYS ON and CONTINUOUS -- there is no
-- threshold to cross, nothing snaps in.
--
-- WHAT CHANGED (and why the file keeps its name): v1 (ci-7tl) tinted the screen when
-- and only when the player was TAKING lethal-ground damage, at a flat 0.18-0.55 alpha.
-- That is a damage indicator, not a sense of place, and it died with the scripted
-- cold-damage model (ci-bvk). The trigger is now POSITION, so the grade survives any
-- change to the damage model. Paths are unchanged so the feature's history stays in
-- one place.
--
-- 🚨 COSMETIC ONLY. This module applies NO damage and reads no damage state. The
-- lethal-ground damage stays keyed to the ACTUAL TILE under an entity
-- (scripts/tile-damage.lua + terrain.tile_damage, the ci-ma18 invariant): concrete
-- over lava still shields, every hazard tile still burns. A player standing on
-- concrete deep in the hot belt therefore sees a warm grade (they ARE somewhere hot)
-- and takes zero damage (they are standing on cover). Those two are deliberately
-- independent now; do not re-couple them.
--
-- SOURCE OF TRUTH. The grade reads ribbon.temperature at the character's
-- perpendicular coordinate (scripts/axis.lua -> scripts/ribbon.lua) -- the same
-- temperature axis the rest of the planet reads. The two ANCHORS (where the grade
-- starts, where it saturates) are derived from the LIVE zone geometry
-- (scripts/terrain.lua), exactly as ribbon.solar_anchors does for the solar curve, so
-- retuning a zone width moves the grade with it. The temperature curve is evaluated
-- over the real ribbon half-width rather than ribbon's default `saturate_at` (128
-- tiles, far inside today's 800-tile ribbon), which would otherwise saturate the
-- curve before the player even reaches the burn belt and flatten the whole gradient.
--
-- 🚨 Scoped to characters on `surface.name == "cindra"`: a player on any other planet
-- never gets a grade, and only this mod's OWN render objects are created/destroyed.

local axis = require("scripts.axis")
local ribbon = require("scripts.ribbon")
local terrain = require("scripts.terrain")

local M = {}

-- The data-stage fill sprite (prototypes/feedback.lua), tinted at draw time.
M.SPRITE = "cindra-thermal-grade"

-- Grade hues (RGB, 0..1). Warm reads as a sunlit orange (r > g > b), cool as a
-- frost blue (b > g > r). Alpha rides on top, per position.
M.COLOR = {
  warm = { r = 1.00, g = 0.46, b = 0.14 },
  cool = { r = 0.32, g = 0.56, b = 1.00 },
}

-- Subtlety envelope. The wash NEVER exceeds MAX_ALPHA -- a tasteful hue shift, not
-- an opaque overlay. GAMMA > 1 eases IN: barely anything for the first stretch out
-- of the temperate band, deepening as you commit toward an extreme.
M.MAX_ALPHA = 0.22
M.GAMMA = 1.4

-- Sprite is 10 px (= 10/32 tile at scale 1); this scale makes the tinted fill
-- ~625 tiles across, centred on the character, which blankets the viewport at any
-- normal zoom level. (scale_with_zoom is text-only on render objects, so the fill
-- is world-scaled and simply drawn large enough to always cover the screen.)
local FILL_SCALE = 2000

local function clamp01(x)
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

-- ---------------------------------------------------------------------------
-- PURE: position -> grade. No game.* / prototypes.* access, so the whole decision
-- is unit-testable off the game (unit-tests/test_feedback.lua).
-- ---------------------------------------------------------------------------

-- The grade ANCHORS for the live zone layout. `widths` is an optional terrain widths
-- table (keyed by zone role) so tests / tuning can ask for a DIFFERENT layout.
--   warm_from / cool_from : the temperate middle band's two edges. Inside them the
--                           grade is exactly zero -- the ribbon reads neutral.
--   warm_sat / cool_sat   : the inner edge of each OCEAN, where the grade reaches
--                           full depth. Everything traversable between the middle
--                           and the ocean therefore spans the whole alpha range;
--                           inside an ocean it simply stays at full.
--   half                  : the ribbon's half-width, the span the temperature curve
--                           is evaluated over (see the header note on `saturate_at`).
-- The anchor TEMPERATURES are precomputed here so a sweep resolves the geometry once.
function M.anchors(widths)
  local mid = terrain.role_band("middle", widths)
  local hot_ocean = terrain.role_band("hot_ocean", widths)
  local cold_ocean = terrain.role_band("cold_ocean", widths)
  local _, total = terrain.bands(widths)
  local cfg = { saturate_at = total / 2 }
  return {
    cfg = cfg,
    half = total / 2,
    warm_from = mid.hi,
    warm_sat = hot_ocean.lo,
    cool_from = mid.lo,
    cool_sat = cold_ocean.hi,
    warm_from_t = ribbon.temperature(mid.hi, cfg),
    warm_sat_t = ribbon.temperature(hot_ocean.lo, cfg),
    cool_from_t = ribbon.temperature(mid.lo, cfg),
    cool_sat_t = ribbon.temperature(cold_ocean.hi, cfg),
  }
end

-- The temperature (°C) the grade reads at perpendicular coordinate `p`, on the live
-- ribbon geometry. The ONE temperature axis (scripts/ribbon.lua); this module only
-- normalises it into a colour.
function M.temperature_at(p, widths)
  local a = M.anchors(widths)
  return ribbon.temperature(p, a.cfg)
end

-- PURE, on precomputed anchors: the grade at perpendicular coordinate `p` ->
-- (which, t), where which is "warm" | "cool" | nil and t is the 0..1 grade depth.
-- t is the fraction of the way from the temperate edge TEMPERATURE to the ocean-core
-- temperature, so the grade follows the temperature curve, not a raw tile count.
function M.grade_from(a, p)
  local T = ribbon.temperature(p, a.cfg)
  if T > a.warm_from_t then
    return "warm", clamp01((T - a.warm_from_t) / (a.warm_sat_t - a.warm_from_t))
  elseif T < a.cool_from_t then
    return "cool", clamp01((a.cool_from_t - T) / (a.cool_from_t - a.cool_sat_t))
  end
  return nil, 0
end

-- PURE: the grade at perpendicular coordinate `p` for the live (or given) layout.
function M.grade_at(p, widths)
  return M.grade_from(M.anchors(widths), p)
end

-- The wash alpha for a 0..1 grade depth. Zero at the temperate edge (no wash at
-- all), easing in, capped at MAX_ALPHA at an ocean core.
function M.alpha_for(t)
  if t <= 0 then return 0 end
  return M.MAX_ALPHA * (clamp01(t) ^ M.GAMMA)
end

-- PURE: the full draw tint at perpendicular coordinate `p`, or nil where the ribbon
-- reads neutral.
function M.tint_at(p, widths)
  local which, t = M.grade_at(p, widths)
  if not which then return nil end
  local c = M.COLOR[which]
  return { r = c.r, g = c.g, b = c.b, a = M.alpha_for(t) }
end

-- ---------------------------------------------------------------------------
-- Runtime: draw the grade for each player.
-- ---------------------------------------------------------------------------

local function state_table()
  storage.cindra_feedback = storage.cindra_feedback or {}
  return storage.cindra_feedback
end

-- Destroy a player's grade render object (if any) and forget it. Only ever touches
-- the object THIS module created for that player.
local function clear(player_index)
  local st = state_table()
  local s = st[player_index]
  if s then
    local obj = rendering.get_object_by_id(s.id)
    if obj and obj.valid then obj.destroy() end
    st[player_index] = nil
  end
end

-- Public wrapper: clear a player's grade.
function M.clear(player)
  clear(player.index)
end

-- Show/refresh the grade for `player`. The render object is anchored to the character
-- (so it follows every frame) and shown only to that player. Because the grade is
-- always on and changes continuously as the player walks, the existing object's COLOUR
-- is updated in place; it is only recreated when there is no live object for the
-- current character/surface.
local function show(player, which, t)
  local ch = player.character
  local c = M.COLOR[which]
  local tint = { r = c.r, g = c.g, b = c.b, a = M.alpha_for(t) }
  local st = state_table()
  local s = st[player.index]
  if s and s.surface == ch.surface.index and s.unit == ch.unit_number then
    local obj = rendering.get_object_by_id(s.id)
    if obj and obj.valid then
      obj.color = tint
      s.which = which
      return
    end
  end
  clear(player.index)
  local obj = rendering.draw_sprite({
    sprite = M.SPRITE,
    surface = ch.surface,
    target = ch,
    players = { player },
    tint = tint,
    render_layer = "cursor",
    x_scale = FILL_SCALE,
    y_scale = FILL_SCALE,
    only_in_alt_mode = false,
  })
  st[player.index] = {
    id = obj.id,
    which = which,
    surface = ch.surface.index,
    unit = ch.unit_number,
  }
end

-- PUBLIC (tests): what the player is CURRENTLY seeing -> (which, alpha), read from
-- the LIVE render object, so a destroyed/absent grade reads as (nil, 0) and the alpha
-- is the one actually being drawn.
function M.active(player)
  local s = state_table()[player.index]
  if not s then return nil, 0 end
  local obj = rendering.get_object_by_id(s.id)
  if not (obj and obj.valid) then return nil, 0 end
  return s.which, obj.color.a
end

-- PUBLIC (tests): just the hue currently drawn ("warm"/"cool"/nil).
function M.active_which(player)
  return (M.active(player))
end

-- Refresh every connected player's grade from WHERE their character stands on the
-- hot-cold axis. Called on the worldgen cadence (scripts/driver.lua). A no-op for a
-- player off Cindra or without a character.
function M.update_all()
  local a = M.anchors()
  local orient = axis.orientation()
  for _, player in pairs(game.connected_players) do
    local ch = player.character
    local which, t = nil, 0
    if ch and ch.valid and ch.surface.valid and ch.surface.name == "cindra" then
      which, t = M.grade_from(a, axis.perp(ch.position.x, ch.position.y, orient))
    end
    if which and t > 0 then
      show(player, which, t)
    else
      clear(player.index)
    end
  end
end

return M
