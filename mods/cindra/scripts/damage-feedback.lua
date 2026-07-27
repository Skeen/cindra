-- Player heat/cold feedback overlay (§15 v2 item 4).
--
-- When the player takes environmental damage, they must UNMISTAKABLY see why. As
-- a character stands in a hot band we show a warm "overheating" screen banner; in
-- a cold band, a "freezing" one; in the safe ribbon (or off Cindra), neither. The
-- banner is removed the instant the player steps out of the zone, so it always
-- reflects the current danger.
--
-- The band decision reads the ribbon axis via ribbon.perp (scripts/ribbon.lua is
-- the single source of truth), so it is correct in BOTH orientations and lines up
-- exactly with the ticking edge damage (scripts/edge-damage.lua) that it explains.
--
-- v1 art: a coloured, non-interactive GUI banner (placeholder for a full-screen
-- tint / flame shader -- see PLAYTEST.md). The decision (overlay_for) is pure and
-- unit-tested; the GUI show/hide is integration-tested against a live player.
--
-- 🚨 Scoped to characters on `surface.name == "cindra"`; a player on any other
-- planet never gets a banner.

local ribbon = require("scripts.ribbon")
local config = require("scripts.config")

local M = {}

-- The two banner element names (in player.gui.screen).
M.HEAT_GUI = "cindra-heat-overlay"
M.COLD_GUI = "cindra-cold-overlay"

local SPEC = {
  heat = { name = M.HEAT_GUI, other = M.COLD_GUI,
           caption = { "cindra-feedback.overheating" }, color = { 1.0, 0.45, 0.15 } },
  cold = { name = M.COLD_GUI, other = M.HEAT_GUI,
           caption = { "cindra-feedback.freezing" }, color = { 0.55, 0.8, 1.0 } },
}

-- PURE: which overlay ("heat" | "cold" | nil) belongs at perpendicular coord `p`.
-- Keyed off the ribbon zone so it matches the edge damage exactly.
function M.overlay_for(p, cfg)
  local z = ribbon.zone(p, cfg)
  if z == "hot_warn" or z == "hot_lethal" then return "heat" end
  if z == "cold_warn" or z == "cold_lethal" then return "cold" end
  return nil
end

local function destroy(screen, name)
  local e = screen[name]
  if e then e.destroy() end
end

-- Show `which` banner for a player, removing the opposite one. Idempotent.
local function show(player, which)
  local screen = player.gui.screen
  local spec = SPEC[which]
  destroy(screen, spec.other)
  if screen[spec.name] then return end
  local frame = screen.add({ type = "frame", name = spec.name, caption = spec.caption })
  frame.style.font_color = spec.color
  -- A prominent, non-interactive top-centre banner.
  frame.location = { 8, 8 }
  frame.ignored_by_interaction = true
end

-- Refresh every connected player's banner from their character's position. Call
-- on the edge-damage cadence. `cfg` defaults to the settings-derived ribbon cfg.
function M.update_all(cfg)
  cfg = cfg or config.ribbon_cfg()
  for _, player in pairs(game.connected_players) do
    local ch = player.character
    local which = nil
    if ch and ch.valid and ch.surface.valid and ch.surface.name == "cindra" then
      which = M.overlay_for(ribbon.perp(ch.position, cfg), cfg)
    end
    if which then
      show(player, which)
    else
      local screen = player.gui.screen
      destroy(screen, M.HEAT_GUI)
      destroy(screen, M.COLD_GUI)
    end
  end
end

return M
