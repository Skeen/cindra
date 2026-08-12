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
-- "horizontal" rotates that a quarter turn: long axis EAST-WEST (X), gradient
-- NORTH-SOUTH (Y), with FIRE AT THE TOP -- the hot band is the NORTH (-Y) edge and
-- the ice is the SOUTH (+Y) edge, so the sunward-positive coordinate is p = -y
-- (ci-65p). Both orientations therefore put the fire on the same side of the
-- screen the player is looking at: left for vertical, top for horizontal.
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
--   horizontal:          p = -y  (hot at the TOP / north)
--
-- This is the RAW world coordinate. A system that looks a ZONE up by position (which
-- band am I in, how sunny is it here) wants the NOMINAL coordinate instead --
-- zone-scale.nominal_perp(x, y, orient, scales) -- because the world-gen-screen zone
-- sliders (ci-i4z) stretch the world against the nominal zone table. Order/monotone
-- comparisons are safe on the raw coordinate (the warp is monotonic).
function M.perp(x, y, orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return -y end
  return -x
end

-- The RAW sunward-positive perpendicular coordinate as a Factorio noise-expression
-- string: the plain orientation mapping, in WORLD tiles. Only the zone-scale warp
-- itself should read this -- every BAND reads the nominal axis below.
function M.raw_perp_expr(orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return "(0 - y)" end
  return "(0 - x)"
end

-- The RAW nightward-positive perpendicular coordinate, i.e. -perp. Kept as a
-- first-class emitter (rather than negating raw_perp_expr, which would double the
-- unary minus) so both orientations stay clean:
--   vertical  : perp = -x  ->  -perp =  x   -> "x"
--   horizontal: perp = -y  ->  -perp =  y   -> "y"
function M.raw_perp_neg_expr(orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return "y" end
  return "x"
end

-- The sunward-positive perpendicular coordinate every BAND MASK reads: the NOMINAL
-- axis, published as a named noise expression (prototypes/zone-sliders.lua) that
-- warps the raw world axis through the world-gen-screen zone sliders (ci-i4z,
-- scripts/zone-scale.lua). Because every band in the mod substitutes this for the raw
-- axis -- tiles, resources, decoratives -- the sliders stretch the WHOLE world
-- coherently while every band constant stays in nominal tiles. With the sliders at
-- their defaults (and on any surface that is not Cindra) it IS the raw axis.
function M.perp_expr()
  return "cindra_perp"
end

-- The nightward-positive nominal coordinate (-perp), likewise a named expression.
function M.perp_neg_expr()
  return "cindra_perp_neg"
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
--   horizontal:          perp = -y, long = x  ->  x =  long, y = -perp
-- Returns two numbers (x, y).
function M.world(long, perp, orient)
  orient = orient or M.orientation()
  if orient == M.HORIZONTAL then return long, -perp end
  return -perp, long
end

return M
