-- Ribbon ORIENTATION: the one place that maps a world (x, y) to the ribbon's
-- perpendicular (sunward-nightward) coordinate (§4, worldgen orientation).
--
-- scripts/ribbon.lua is the pure single source of truth for "given a position on
-- the hot-cold axis, what happens here" -- but it speaks in ONE number: the
-- signed perpendicular coordinate `p`, positive toward the SUN (hot), negative
-- toward NIGHT (cold). It deliberately does NOT know whether that coordinate is
-- the map's x or y; that is an ORIENTATION choice, and it lives here so no
-- downstream system (edge damage, building freeze, solar, resources, worldgen)
-- ever re-derives the hot-cold direction from raw x/y.
--
-- DEFAULT = "vertical": the ribbon's long axis runs NORTH-SOUTH (bottom-to-top,
-- the Y axis), so the hot<->cold gradient runs LEFT<->RIGHT (the X axis) with HOT
-- on the LEFT (west, -X) and cold on the right (east, +X). The sunward-positive
-- perpendicular coordinate is therefore p = -x (west is hotter).
--
-- "horizontal" keeps the legacy layout: long axis EAST-WEST (X), gradient
-- NORTH-SOUTH (Y), sunward = +Y, so p = y.
--
-- This module is safe to require in BOTH the data stage (resource band masks read
-- perp_expr) and the control stage (runtime sweeps read perp); it reads only the
-- final startup setting, and falls back to the default when `settings` is absent
-- (plain-Lua unit tests), so it never errors off-game.

local M = {}

-- Orientation values for the `cindra-ribbon-orientation` startup setting.
M.VERTICAL = "vertical"
M.HORIZONTAL = "horizontal"
M.DEFAULT = M.VERTICAL

-- The resolved orientation string. `settings.startup` exists in both the data and
-- control stages; when it is absent (pure unit tests) we return the default.
function M.orientation()
  local s = settings and settings.startup and settings.startup["cindra-ribbon-orientation"]
  return (s and s.value) or M.DEFAULT
end

-- Signed perpendicular coordinate (sunward-positive) for a world position.
-- `orient` is optional; when omitted it is resolved from the setting. Callers in
-- tight loops (worldgen, sweeps) resolve it ONCE and pass it in.
--   vertical  (default): p = -x  (hot on the left / west)
--   horizontal:          p =  y  (hot sunward / +Y, the legacy layout)
function M.perp(x, y, orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return y end
  return -x
end

-- The sunward-positive perpendicular coordinate as a Factorio noise-expression
-- string (the resource-field band masks substitute this for the raw axis so the
-- native autoplace patches band on the SAME axis the runtime damage reads).
function M.perp_expr(orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return "y" end
  return "(0 - x)"
end

-- The NIGHTWARD-positive perpendicular coordinate as a noise-expression string,
-- i.e. -perp. Band masks on the cold side read "how deep nightward am I", which
-- is this. Kept as a first-class emitter (rather than negating perp_expr, which
-- would double the unary minus) so both orientations stay clean:
--   vertical  : perp = -x  ->  -perp =  x   -> "x"
--   horizontal: perp =  y  ->  -perp = -y   -> "(0 - y)"
function M.perp_neg_expr(orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return "(0 - y)" end
  return "x"
end

-- The LONG-axis coordinate (along the ribbon) for a world position -- the axis the
-- emitter lattice steps along. It is the axis `perp` does NOT use:
--   vertical  (default): long = y  (the ribbon runs north-south)
--   horizontal:          long = x  (the ribbon runs east-west)
function M.long(x, y, orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return x end
  return y
end

-- The INVERSE of (long, perp): the world (x, y) for a point at long-axis coordinate
-- `long` and perpendicular coordinate `perp`. The emitter placer uses this to turn a
-- lattice point (long = k*spacing, perp = a row centre) back into a world position,
-- correctly for BOTH orientations. Round-trips perp()/long():
--   vertical  (default): perp = -x, long = y  ->  x = -perp, y = long
--   horizontal:          perp =  y, long = x  ->  x =  long, y = perp
-- Returns two numbers (x, y).
function M.world(long, perp, orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return long, perp end
  return -perp, long
end

return M
