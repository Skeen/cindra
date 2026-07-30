-- Full-screen heat/cold damage feedback (§15 v2 item 4; ci-7tl).
--
-- When a player stands where the environment is damaging them, they must
-- UNMISTAKABLY see WHY they are losing health. As a character enters a lethal HEAT
-- band we tint the whole screen warm/red; a lethal COLD band tints it frost/blue;
-- anywhere safe (or off Cindra) shows nothing. The tint clears the instant the
-- player steps back to safety, so it always reflects the CURRENT danger, and its
-- ALPHA scales with how deep into the lethal band they stand -- a deeper, redder
-- burn toward the lava; a heavier frost toward the ice cap ("scaled to intensity").
--
-- The band decision reads the SAME source the damage does -- scripts/terrain.lua
-- M.lethal_at, keyed to the perpendicular ribbon axis via scripts/axis.lua -- so
-- the tint lines up EXACTLY with the tile-based lethal-zone damage
-- (scripts/tile-damage.lua) it explains: never a tint without damage, nor damage
-- without a tint. overlay_for / intensity_for are PURE (pass a cfg) and unit-
-- tested; the presentation is a render-layer screen effect (the tinted fill sprite
-- lives in prototypes/feedback.lua) proven against a live player.
--
-- This replaces the salvaged worldgen-v2 GUI-banner placeholder with a proper
-- full-screen tint, as ci-7tl asks -- the pure decision is kept, only show() moved
-- from a GUI frame to the rendering API.
--
-- 🚨 Scoped to characters on `surface.name == "cindra"`: a player on any other
-- planet never gets a tint, and only this mod's OWN render objects are ever
-- created or destroyed. No global / other-planet state is touched.

local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

local M = {}

-- The data-stage fill sprite (prototypes/feedback.lua), tinted at draw time.
M.SPRITE = "cindra-damage-vignette"

-- Heat/cold tint colours (RGB, 0..1). Alpha is supplied per-draw from intensity.
M.COLOR = {
  heat = { r = 1.0, g = 0.25, b = 0.05 },
  cold = { r = 0.35, g = 0.6, b = 1.0 },
}

-- Alpha envelope: even the lethal EDGE is clearly visible (MIN), deepening toward
-- the map edge (MAX) without ever fully blacking out the view.
M.MIN_ALPHA = 0.18
M.MAX_ALPHA = 0.55

-- Sprite is 10 px (= 10/32 tile at scale 1); this scale makes the tinted fill
-- ~625 tiles across, centred on the character, which blankets the viewport at any
-- normal zoom level. (scale_with_zoom is text-only on render objects, so the fill
-- is world-scaled and simply drawn large enough to always cover the screen.)
local FILL_SCALE = 2000

-- PURE: which overlay ("heat" | "cold" | nil) belongs at perpendicular coord `p`.
-- Delegates to terrain.lethal_at, so it matches the tile-damage sweep exactly.
function M.overlay_for(p, cfg)
  return terrain.lethal_at(p, cfg)
end

-- PURE: normalised danger 0..1 at perpendicular coord `p` -- 0 just inside the
-- lethal edge, 1 at the outermost (hottest / coldest) band; 0 anywhere safe.
-- Drives the tint alpha so the effect is "scaled to damage intensity".
function M.intensity_for(p, cfg)
  local which = terrain.lethal_at(p, cfg)
  if not which then return 0 end
  local b = terrain.damage_bounds(cfg)
  local _, total = terrain.bands(cfg)
  local half = total / 2
  local t
  if which == "heat" then
    local span = half - b.hot_from -- edge (hot_from) -> outermost hot edge (+half)
    t = span > 0 and (p - b.hot_from) / span or 1
  else
    local span = half + b.cold_from -- cold_from is negative; outermost cold edge = -half
    t = span > 0 and (b.cold_from - p) / span or 1
  end
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  return t
end

-- Alpha for a normalised intensity.
local function alpha_for(t)
  return M.MIN_ALPHA + (M.MAX_ALPHA - M.MIN_ALPHA) * t
end

local function state_table()
  storage.cindra_feedback = storage.cindra_feedback or {}
  return storage.cindra_feedback
end

-- Destroy a player's tint render object (if any) and forget it. Only ever touches
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

-- Public wrapper: clear a player's tint.
function M.clear(player)
  clear(player.index)
end

-- Show/refresh the `which` tint for `player` at normalised intensity `t`. The
-- render object is anchored to the character (follows it every frame) and shown
-- only to that player. Recreated on each refresh so colour + target stay correct;
-- the cadence is coarse (tile-damage rate), so this is cheap.
local function show(player, which, t)
  local ch = player.character
  local color = M.COLOR[which]
  clear(player.index)
  local obj = rendering.draw_sprite({
    sprite = M.SPRITE,
    surface = ch.surface,
    target = ch,
    players = { player },
    tint = { r = color.r, g = color.g, b = color.b, a = alpha_for(t) },
    render_layer = "cursor",
    x_scale = FILL_SCALE,
    y_scale = FILL_SCALE,
    only_in_alt_mode = false,
  })
  state_table()[player.index] = { id = obj.id, which = which }
end

-- PUBLIC (tests): which tint a player is CURRENTLY showing ("heat"/"cold"/nil),
-- resolved from the live render object so a destroyed one reads as nil.
function M.active_which(player)
  local s = state_table()[player.index]
  if not s then return nil end
  local obj = rendering.get_object_by_id(s.id)
  if not (obj and obj.valid) then return nil end
  return s.which
end

-- Refresh every connected player's tint from their character's position on the
-- perpendicular ribbon axis. Call on the tile-damage cadence so the tint tracks
-- the damage it explains. `cfg` defaults to nil, so the runtime reads the mod
-- settings exactly like tile-damage; tests pass an explicit cfg for determinism.
function M.update_all(cfg)
  local orient = axis.orientation()
  for _, player in pairs(game.connected_players) do
    local ch = player.character
    local which, t = nil, 0
    if ch and ch.valid and ch.surface.valid and ch.surface.name == "cindra" then
      local p = axis.perp(ch.position.x, ch.position.y, orient)
      which = M.overlay_for(p, cfg)
      if which then t = M.intensity_for(p, cfg) end
    end
    if which then
      show(player, which, t)
    else
      clear(player.index)
    end
  end
end

return M
