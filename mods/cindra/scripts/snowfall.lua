-- ICY-SIDE SNOWFALL (ci-mk5y; the ci-wly epic's "IDEA: consider snow-fall only on the icy
-- side"). Cosmetic falling snow over the FROZEN half of the ribbon, and nowhere else.
--
-- Cindra is ONE surface holding both a molten dayside and a frozen nightside, so the effect
-- has to be gated by POSITION, not by surface. That rules out the engine's own per-surface
-- weather-ish knobs (the planet's clouds / fog render parameters): they would snow on the
-- lava too. Instead each FLAKE is gated individually on the perpendicular axis, so the
-- snow stops exactly where the ice does -- stand at the boundary and it snows on your
-- nightward side only.
--
-- WHERE IT SNOWS: nightward of the icy-ground edge -- the SAME boundary the ice/snow DECALS
-- start at (terrain.damage_bounds().cold_from, scripts/decorative-field.lua's cold gate),
-- so the snow that falls and the snow that lies agree. One source of truth: the terrain.
--
-- WHY RENDER OBJECTS (and not particles / trivial smoke): a render object is queryable from
-- Lua, so "snow falls on the ice and NOWHERE else" is an assertion a test can make about
-- the actual visible effect (tests/test_snowfall.lua reads the live flakes back) instead of
-- a playtest hope. Engine particles are invisible to script and would leave the whole
-- invariant untested. It also needs no bespoke art: a flake is the stock white square,
-- scaled down and tinted (prototypes/snowfall.lua).
--
-- HOW IT MOVES: each player carries a fixed set of flake SLOTS whose offsets ride around
-- their view. Every update a slot falls a little (and drifts sideways with the wind); once
-- it passes the bottom of the field it wraps back to the top with a fresh lateral position,
-- so the field never empties and never needs re-seeding. A slot whose current world
-- position is NOT on the icy side has no render object at all -- that is the gate.
--
-- 🚨 Scoped to players on `surface.name == "cindra"`, and only ever creates/destroys THIS
-- module's own render objects. No global or other-planet state is touched; a player on any
-- other planet gets no flakes at all. Each flake is drawn for its OWN player only (the
-- field is a per-viewer effect, exactly like the damage-feedback tint).

local axis = require("scripts.axis")
local terrain = require("scripts.terrain")

local M = {}

-- The data-stage flake sprite (prototypes/snowfall.lua), tinted + scaled at draw time.
M.SPRITE = "cindra-snowflake"

-- Flake slots per player. Enough to read as weather across a screen, few enough that the
-- per-update work stays trivial (each update moves at most this many render objects, and
-- only for players actually standing in the snow).
M.FLAKES = 48

-- The field's size in tiles around the player: wide/tall enough to cover a normal viewport,
-- so flakes are always already falling wherever you look.
M.SPAN_X = 64
M.SPAN_Y = 44

-- Ticks between updates. A DISTINCT nth-tick (scripts/driver.lua registers it; on_nth_tick
-- is replace-not-add, so every periodic system owns its own N).
M.UPDATE_INTERVAL = 3

-- Per-update motion in tiles: snow falls slowly (~2.8 tiles/second at the interval above)
-- and drifts sideways on a per-flake wind, so the field never looks like a rigid grid.
M.FALL_SPEED = 0.14
M.DRIFT = 0.05

-- Per-flake look: small and faint, varied so the field reads as depth rather than as one
-- flat layer of identical dots. The sprite is 10 px, so scale 0.3..0.7 is a 3-7 px flake.
M.SCALE_MIN, M.SCALE_MAX = 0.3, 0.7
M.ALPHA_MIN, M.ALPHA_MAX = 0.35, 0.8

-- ---------------------------------------------------------------------------
-- PURE geometry + motion (no game.* / prototypes.*): unit-tested off the game in
-- unit-tests/test_snowfall.lua.
-- ---------------------------------------------------------------------------

-- Where the snow starts, in perpendicular tiles: the icy-ground edge, i.e. exactly where
-- the terrain's own value ramp turns from the brown dust of the habitable band to snow/ice
-- (scripts/terrain.lua owns that boundary; we read it rather than re-deriving it, and the
-- ice/snow decals gate on the same line).
function M.snow_start(cfg)
  return terrain.damage_bounds(cfg).cold_from
end

-- PURE: does snow fall at perpendicular position `p`? Only nightward of the icy-ground
-- edge -- never on the habitable band, never on the hot side.
function M.falls_at(p, cfg)
  return p < M.snow_start(cfg)
end

local function lerp(a, b, t) return a + (b - a) * t end

-- PURE: a fresh flake slot -- an offset from the player plus its own look and wind. `rand`
-- is injectable (a deterministic generator in the unit tests); in game it is the map's own
-- math.random, which is multiplayer-deterministic.
function M.new_flake(rand)
  rand = rand or math.random
  return {
    dx = (rand() - 0.5) * M.SPAN_X,
    dy = (rand() - 0.5) * M.SPAN_Y,
    scale = lerp(M.SCALE_MIN, M.SCALE_MAX, rand()),
    alpha = lerp(M.ALPHA_MIN, M.ALPHA_MAX, rand()),
    speed = M.FALL_SPEED * lerp(0.6, 1.4, rand()),
    drift = (rand() - 0.5) * 2 * M.DRIFT,
  }
end

-- PURE: advance a flake one update. It FALLS (down-screen = +y) and drifts sideways on its
-- own wind; once past the bottom of the field it wraps back to the TOP with a fresh lateral
-- position (so the field neither empties nor stripes), and lateral drift wraps within the
-- field width. Returns the flake.
function M.step(f, rand)
  rand = rand or math.random
  f.dy = f.dy + f.speed
  f.dx = f.dx + f.drift
  if f.dy > M.SPAN_Y / 2 then
    f.dy = -M.SPAN_Y / 2
    f.dx = (rand() - 0.5) * M.SPAN_X
  end
  local half = M.SPAN_X / 2
  if f.dx > half then f.dx = f.dx - M.SPAN_X elseif f.dx < -half then f.dx = f.dx + M.SPAN_X end
  return f
end

-- ---------------------------------------------------------------------------
-- Runtime presentation.
-- ---------------------------------------------------------------------------

local function state_table()
  storage.cindra_snowfall = storage.cindra_snowfall or {}
  return storage.cindra_snowfall
end

-- Destroy a slot's render object (if any) and forget it. Only ever touches the object THIS
-- module created for that slot.
local function drop(s, i)
  local id = s.ids[i]
  if id then
    local obj = rendering.get_object_by_id(id)
    if obj and obj.valid then obj.destroy() end
    s.ids[i] = nil
  end
end

-- Destroy every flake of one player's field, keeping (or forgetting) the slot state.
local function clear(player_index, forget)
  local st = state_table()
  local s = st[player_index]
  if not s then return end
  for i in pairs(s.flakes) do drop(s, i) end
  if forget then st[player_index] = nil end
end

-- PUBLIC: stop a player's snowfall (used on leaving Cindra; also handy for tests).
function M.clear(player)
  clear(player.index, true)
end

local function field_state(player_index)
  local st = state_table()
  local s = st[player_index]
  if not s then
    s = { flakes = {}, ids = {}, pos = {} }
    for i = 1, M.FLAKES do s.flakes[i] = M.new_flake() end
    st[player_index] = s
  end
  return s
end

-- Refresh ONE player's snow field: advance every slot, then show it if (and only if) its
-- new world position is on the icy side, otherwise make sure it is not drawn. Off Cindra
-- the whole field is torn down.
local function refresh(player)
  local surface = player.surface
  if not (surface and surface.valid and surface.name == "cindra") then
    clear(player.index, true)
    return
  end
  local s = field_state(player.index)
  -- A player who changed surface leaves render objects behind on the old one: drop them
  -- and redraw on the new surface (the slot offsets carry over, so the field is continuous).
  if s.surface ~= surface.index then
    for i in pairs(s.flakes) do drop(s, i) end
    s.surface = surface.index
  end
  local origin = player.position
  local orient = axis.orientation()
  for i, f in ipairs(s.flakes) do
    M.step(f)
    local x, y = origin.x + f.dx, origin.y + f.dy
    if M.falls_at(axis.perp(x, y, orient)) then
      local id = s.ids[i]
      local obj = id and rendering.get_object_by_id(id)
      if obj and obj.valid then
        obj.target = { x = x, y = y }
      else
        obj = rendering.draw_sprite({
          sprite = M.SPRITE,
          surface = surface,
          target = { x = x, y = y },
          players = { player },
          tint = { r = 1, g = 1, b = 1, a = f.alpha },
          x_scale = f.scale,
          y_scale = f.scale,
          -- Snow falls BETWEEN the camera and the world, so it draws on the topmost world
          -- layer -- the same `cursor` layer the damage-feedback tint uses (over the world,
          -- under the GUI), rather than behind the buildings it should be dusting.
          render_layer = "cursor",
          only_in_alt_mode = false,
        })
        s.ids[i] = obj.id
      end
      s.pos[i] = { x = x, y = y }
    else
      drop(s, i)
      s.pos[i] = nil
    end
  end
end

-- PUBLIC (tests): the world position of every flake a player can CURRENTLY see, keyed by
-- flake slot. Existence is read from the live render object, so a flake that was gated off
-- (or destroyed) is simply absent -- this is the visible effect, not an intention.
function M.flake_positions(player)
  local out = {}
  local s = state_table()[player.index]
  if not s then return out end
  for i, id in pairs(s.ids) do
    local obj = rendering.get_object_by_id(id)
    if obj and obj.valid then
      -- The live object's own target (a ScriptRenderTarget wrapping the position we drew
      -- it at); the recorded position is only a fallback so a shape change in that getter
      -- degrades to "where we put it" rather than erroring.
      local t = obj.target
      local p = (t and t.position) or t
      if not (p and type(p.x) == "number") then p = s.pos[i] end
      if p then out[i] = { x = p.x, y = p.y } end
    end
  end
  return out
end

-- PUBLIC (tests): how many flakes a player can currently see.
function M.flake_count(player)
  local n = 0
  for _ in pairs(M.flake_positions(player)) do n = n + 1 end
  return n
end

-- Refresh every connected player's snow field. A no-op for anyone off Cindra (their field
-- is torn down), and cheap for anyone standing off the ice (no objects to move). A player
-- who DISCONNECTED takes their field with them, so a dropped multiplayer client cannot leave
-- flakes hanging over the ice forever.
function M.update_all()
  local st = state_table()
  for index in pairs(st) do
    local p = game.players[index]
    if not (p and p.connected) then clear(index, true) end
  end
  for _, player in pairs(game.connected_players) do
    refresh(player)
  end
end

return M
