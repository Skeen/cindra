-- Cindra per-chunk world generation (§4 ribbon geometry, §15 item 2 + bootstrap).
--
-- Two jobs as each chunk generates on a Cindra surface:
--   1. HARD-WALL BACKSTOP (§15-2 / §4 Impl B): tiles at or beyond `wall_at`
--      perpendicular distance become out-of-map, so the playable world is a
--      finite-width RIBBON (constrained on the sunward-nightward Y axis, infinite
--      east-west). The gradient damage (scripts/edge-damage.lua) is the teacher;
--      this void is the bulletproof floor so the player can never walk off the
--      usable map into instant death.
--   2. BOOTSTRAP-ROCK SCATTER (§6): finite, hand-gathered rocks around the
--      terminator, the landing-tier trickle of metal. Placement is DETERMINISTIC
--      (a coordinate hash, not math.random) so it is reproducible, testable, and
--      never desyncs in multiplayer.
--
-- The mineable RESOURCES (stone / ice / volatiles) are NOT placed here: they use
-- NATIVE Factorio resource autoplace (prototypes/resources.lua) so they form
-- natural spot-noise PATCHES with real map-gen sliders, band-masked to the ribbon.
-- The rocks stay script-scattered because they are simple-entities, not a resource
-- (and must stay finite, per §6 -- no ore/coal patches anywhere).
--
-- 🚨 Scoped to `surface.name == "cindra"`. Everything is a Cindra-exclusive
-- `cindra-*` prototype; no vanilla resource or tile is mutated anywhere.

local ribbon = require("scripts.ribbon")
local field = require("scripts.resource-field")

local M = {}

-- Placement lattice: candidate rock every STEP tiles. Coarser = sparser scatter.
M.STEP = 6
-- Rock placement probability at a candidate lattice point (0..1): sparse scatter,
-- a finite bootstrap trickle, not a patch. (tune)
M.ROCK_CHANCE = 0.05

local function is_cindra(surface)
  return surface and surface.valid and surface.name == "cindra"
end

local function ribbon_cfg()
  local s = settings and settings.startup
  if not s or not s["cindra-ribbon-safe-half-width"] then return nil end
  return {
    safe_half_width = s["cindra-ribbon-safe-half-width"].value,
    lethal_at = s["cindra-ribbon-lethal-at"].value,
    wall_at = s["cindra-ribbon-wall-at"].value,
  }
end

-- Deterministic pseudo-random fraction in [0,1) from integer tile coords, with a
-- `salt` so different resources draw independent streams (stone and rocks don't
-- always co-locate). Integer maths stays well under 2^53, so it is exact.
local function frac(x, y, salt)
  local h = (x * 49632 + y * 325176 + salt * 2606459) % 100000
  if h < 0 then h = h + 100000 end
  return h / 100000
end

-- Void every tile at/over the wall so the ribbon is finite perpendicular. Runs
-- first so we never place a resource on a tile we're about to remove.
function M.apply_hard_wall(surface, area, cfg)
  local wall = ribbon.resolve(cfg).wall_at
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  local void = {}
  for y = y1, y2 - 1 do
    if math.abs(y) >= wall then
      for x = x1, x2 - 1 do
        void[#void + 1] = { name = "out-of-map", position = { x, y } }
      end
    end
  end
  if #void > 0 then surface.set_tiles(void, true) end
end

local function try_rock(surface, x, y)
  local pos = { x = x + 0.5, y = y + 0.5 }
  if surface.can_place_entity({ name = field.ROCK, position = pos }) then
    surface.create_entity({ name = field.ROCK, position = pos })
  end
end

-- Scatter finite bootstrap rocks across the chunk on the lattice, only within the
-- terminator scatter band (field.rock_zone). The mineable resources are placed by
-- native autoplace (prototypes/resources.lua), not here.
function M.place_bootstrap_rocks(surface, area, cfg)
  local wall = ribbon.resolve(cfg).wall_at
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  -- Snap the lattice to global coords so it is continuous across chunk borders.
  local sx = x1 - (x1 % M.STEP)
  local sy = y1 - (y1 % M.STEP)
  for y = sy, y2 - 1, M.STEP do
    if math.abs(y) < wall and y >= y1 then
      for x = sx, x2 - 1, M.STEP do
        if x >= x1 and field.rock_zone(y, cfg) and frac(x, y, 4) < M.ROCK_CHANCE then
          try_rock(surface, x, y)
        end
      end
    end
  end
end

function M.on_chunk_generated(event)
  if not is_cindra(event.surface) then return end
  local cfg = ribbon_cfg()
  M.apply_hard_wall(event.surface, event.area, cfg)
  M.place_bootstrap_rocks(event.surface, event.area, cfg)
end

return M
