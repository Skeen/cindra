-- WORLD-GEN-SCREEN zone sliders: the ribbon's playable width and its hot/cold zone
-- depths, adjustable from the new-game map-gen screen (ci-i4z, finishing what ci-i8a
-- started for stone/ice density).
--
-- WHY THIS MODULE EXISTS. Zone widths are startup mod settings (settings.lua, looped
-- from terrain.ZONES), which means they can only be changed in the mod-settings menu
-- and only take effect on a full reload. The map-gen screen is where a player expects
-- to shape a world, but the engine exposes NO custom scalar slider there: the only
-- player-facing map-gen knobs a mod can add are AUTOPLACE CONTROLS, and those offer
-- exactly Frequency / Size / Richness multipliers. So the ribbon geometry is encoded
-- onto a control's SIZE multiplier (the "creative encoding" ci-i4z asks for):
--
--   Habitable band (size) -> scales the safe MIDDLE band you build in
--   Hot zone       (size) -> scales the two hot bands (safe slope + heat belt)
--   Cold zone      (size) -> scales the two cold bands (safe slope + cold belt)
--
-- THE ONE WARP. Nothing downstream is re-taught the geometry. Every band in the mod
-- -- the tile field, the resource masks, the decorative gates, the freeze onset, the
-- solar curve -- is expressed against the perpendicular coordinate from
-- scripts/axis.lua, so the sliders are applied in exactly ONE place: axis's
-- perpendicular coordinate is WARPED from WORLD tiles into NOMINAL tiles.
--
--   NOMINAL  the coordinate the zone table + every band constant speaks (unchanged by
--            the sliders: the middle is still [-60, 60], the belts still start at
--            +/-130, ...).
--   WORLD    actual tiles on the surface. A slider stretches a zone in WORLD tiles;
--            the warp maps that stretched world back onto the nominal coordinate.
--
-- Consequences (all of them load-bearing):
--   * Every system stays correct with no change: it bands in nominal space, and the
--     nominal space is untouched. A system CANNOT forget to follow the sliders.
--   * The tile-based environmental damage (scripts/tile-damage.lua) needs no warp at
--     all -- it reads the ACTUAL tile under an entity, and the tiles moved with the
--     world.
--   * The MAP is unchanged in size: the two OCEANS absorb whatever the scaled zones
--     take or give back, so the total ribbon width (and therefore the finite map
--     dimension + the void backstop) is the same on every slider setting. An ocean is
--     a pinned impassable plateau, so trading its width is free -- down to
--     MIN_WALL tiles, which every setting keeps, so the edge is always a real wall.
--   * SPAWN stays put: the warp is anchored at the middle band's CENTRE, and each
--     side (sunward / nightward) is budgeted independently, so moving the cold slider
--     cannot shove the habitable band (or the landing pad) sunward. Spawn is safe,
--     buildable ground -- with a landing pad's clearance from either lethal belt -- at
--     every setting. (Because the two sides budget separately, an EXTREME one-sided
--     slider squeezes its own half of the habitable band harder than the other half:
--     the band is then a little off-centre. That is the deliberate trade for keeping
--     the sliders independent, and it costs a player nothing but symmetry.)
--
-- ONE CODE PATH, TWO OUTPUTS. The warp is built through a tiny ARITHMETIC ALGEBRA
-- (M.NUMERIC / M.SYMBOLIC): the same builder emits either plain Lua numbers (the
-- runtime, for the systems that map a world position onto the axis) or a Factorio
-- noise-expression string (the data stage, for the map-gen). The runtime and the
-- map-gen therefore cannot disagree about where a band is -- they are the same
-- function. unit-tests/test_zone_scale.lua evaluates the EMITTED STRING against the
-- numeric path to prove it.
--
-- PURE: no game.* / prototypes.* except M.for_surface (which reads one surface's map
-- gen settings). Unit-testable off the game.

local axis = require("scripts.axis")
local terrain = require("scripts.terrain")

local M = {}

-- ---------------------------------------------------------------------------
-- The sliders.
-- ---------------------------------------------------------------------------
-- One entry per world-gen-screen slider. `key` is the scale key zones carry
-- (terrain.ZONES[i].scale); `control` is the autoplace-control prototype name (the
-- map-gen screen row); `var` is the noise-expression variable the warp reads the
-- multiplier from. Ordered hot -> middle -> cold for the map-gen screen.
M.SLIDERS = {
  { key = "hot",    control = "cindra-hot-zone",       var = "cindra_ribbon_scale_hot",
    order = "z[cindra]-a[hot-zone]" },
  { key = "middle", control = "cindra-habitable-band", var = "cindra_ribbon_scale_middle",
    order = "z[cindra]-b[habitable-band]" },
  { key = "cold",   control = "cindra-cold-zone",      var = "cindra_ribbon_scale_cold",
    order = "z[cindra]-c[cold-zone]" },
}

-- Which of an autoplace control's multipliers carries the width. "size" is the only
-- honest fit: a bigger Size = a wider band. (Frequency is not wired to anything --
-- there is nothing on a ribbon band for it to mean -- so the warp ignores it.)
M.SLIDER_PROPERTY = "size"

-- The noise-expression name of the per-slider READER (the Cindra-only override that
-- actually reads the map-gen screen value). See prototypes/zone-sliders.lua.
function M.reader_name(key) return "cindra_ribbon_slider_" .. key end

-- The named noise expressions the warp itself is published as (prototypes/zone-sliders.lua);
-- axis.perp_expr / axis.perp_neg_expr return these, so every band reads the warp.
M.PERP_EXPR = "cindra_perp"
M.PERP_NEG_EXPR = "cindra_perp_neg"

-- Slider clamps. The map-gen screen's Size dropdown spans 1/6 .. 6 (and can offer a
-- 0 "None" on a disabled control), so the warp clamps into a sane band: 0 would
-- collapse a zone to nothing (no habitable band at all), and anything past 6 is off
-- the dropdown. Clamping lives HERE, in the shared builder, so the runtime and the
-- map-gen clamp identically.
M.MIN_SCALE = 1 / 6
M.MAX_SCALE = 6

-- The narrowest an OCEAN may be squeezed to (tiles, per ocean). The ocean is the
-- planet's hard wall: solid lava / smooth ice pinned at the field's extreme. A full
-- CHUNK of it (32 tiles) is already unwalkable-by-construction -- the lava tiles are
-- impassable and the field is pinned at its extreme all the way to the map edge -- so
-- even the most extreme slider combination leaves a real wall between the ribbon and
-- the void, and 2x zone depths still fit exactly (no silent squeeze at the settings a
-- player is most likely to pick). (A zone table whose ocean is NARROWER than this
-- nominally keeps its nominal width as the floor -- the floor can never demand width
-- the zone table does not have.)
M.MIN_WALL = 32

-- ---------------------------------------------------------------------------
-- The arithmetic algebra: numbers (runtime) or noise-expression strings (data stage).
-- ---------------------------------------------------------------------------
M.NUMERIC = {
  lit = function(x) return x end,
  add = function(a, b) return a + b end,
  sub = function(a, b) return a - b end,
  mul = function(a, b) return a * b end,
  div = function(a, b) return a / b end,
  min = function(a, b) if a < b then return a end return b end,
  max = function(a, b) if a > b then return a end return b end,
}

-- Number -> noise-expression literal (integers stay integers so the emitted strings
-- read like the hand-written ones in scripts/terrain.lua).
local function fmt(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.10g", v)
end

-- The emitted expression is evaluated per map point, so the identity operands the
-- generic builder produces (a zero accumulator, a single-ocean share of 1) are folded
-- out rather than shipped as arithmetic. Purely a size/cost saving: the unit test
-- evaluates the emitted string against the numeric path either way.
M.SYMBOLIC = {
  lit = fmt,
  add = function(a, b)
    if a == "0" then return b end
    if b == "0" then return a end
    return "(" .. a .. " + " .. b .. ")"
  end,
  sub = function(a, b)
    if b == "0" then return a end
    return "(" .. a .. " - " .. b .. ")"
  end,
  mul = function(a, b)
    if a == "1" then return b end
    if b == "1" then return a end
    return "(" .. a .. " * " .. b .. ")"
  end,
  div = function(a, b)
    if b == "1" then return a end
    return "(" .. a .. " / " .. b .. ")"
  end,
  -- min/max are noise-expression built-ins AND Lua library functions of the same
  -- shape, which is what lets the unit test evaluate an emitted warp as Lua.
  min = function(a, b) return "min(" .. a .. ", " .. b .. ")" end,
  max = function(a, b) return "max(" .. a .. ", " .. b .. ")" end,
}

-- 0..1 clamp of an algebra value.
local function clamp01(A, t)
  return A.min(A.lit(1), A.max(A.lit(0), t))
end

-- A slider multiplier, clamped into the usable band.
local function clamped_scale(A, s)
  return A.min(A.lit(M.MAX_SCALE), A.max(A.lit(M.MIN_SCALE), s))
end

-- ---------------------------------------------------------------------------
-- The zone geometry the warp stretches (nominal, from terrain).
-- ---------------------------------------------------------------------------

-- The index of the safe middle band in terrain.ZONES.
local function building_index()
  for i, z in ipairs(terrain.ZONES) do
    if z.role == terrain.BUILDING_ROLE then return i end
  end
  error("zone-scale: terrain.ZONES has no " .. tostring(terrain.BUILDING_ROLE) .. " zone")
end

-- COVERAGE GUARD: every scale key a zone claims must be a real slider, and every
-- slider must be claimed by at least one zone. A new zone (or a renamed slider)
-- therefore cannot silently end up unscaled-by-accident: it either absorbs on
-- purpose (scale = nil, the oceans) or it errors here at load.
local SLIDER_BY_KEY = {}
for _, s in ipairs(M.SLIDERS) do SLIDER_BY_KEY[s.key] = s end
do
  local claimed = {}
  for _, z in ipairs(terrain.ZONES) do
    if z.scale ~= nil then
      if not SLIDER_BY_KEY[z.scale] then
        error("zone-scale: zone " .. z.role .. " claims unknown slider " .. tostring(z.scale))
      end
      claimed[z.scale] = true
    end
  end
  for _, s in ipairs(M.SLIDERS) do
    if not claimed[s.key] then
      error("zone-scale: slider " .. s.control .. " scales no zone")
    end
  end
end

-- The nominal centre of the middle band (the warp's anchor; spawn sits here).
function M.centre(cfg)
  local mid = terrain.role_band(terrain.BUILDING_ROLE, cfg)
  return (mid.lo + mid.hi) / 2
end

-- The ordered SEGMENTS of one side of the ribbon, from the centre outward: each is
-- { w = nominal width in tiles, key = slider key or nil }. The middle band is split
-- at the centre, so its two halves belong to the two sides. `side` is "hot" (sunward,
-- ascending p) or "cold" (nightward). Pure.
function M.segments(side, cfg)
  local widths = terrain.widths(cfg)
  local mid_i = building_index()
  local mid = terrain.role_band(terrain.BUILDING_ROLE, cfg)
  local c = (mid.lo + mid.hi) / 2
  local mid_zone = terrain.ZONES[mid_i]

  local segs = {}
  if side == "hot" then
    segs[1] = { w = mid.hi - c, key = mid_zone.scale, role = mid_zone.role }
    -- terrain.ZONES runs hot -> cold, so sunward of the middle is DOWN the list.
    for i = mid_i - 1, 1, -1 do
      segs[#segs + 1] = { w = widths[i], key = terrain.ZONES[i].scale, role = terrain.ZONES[i].role }
    end
  else
    segs[1] = { w = c - mid.lo, key = mid_zone.scale, role = mid_zone.role }
    for i = mid_i + 1, #terrain.ZONES do
      segs[#segs + 1] = { w = widths[i], key = terrain.ZONES[i].scale, role = terrain.ZONES[i].role }
    end
  end
  return segs
end

-- The WORLD width of every segment of one side, as algebra values, given the slider
-- multipliers `scales` (a key -> algebra value table). The side's TOTAL world width
-- always equals its nominal total, so the map edge never moves:
--   * a scaled zone asks for nominal * slider,
--   * if the asks together would leave the side's unscaled zones (the ocean) less
--     than their floor, every ask is shrunk by one shared factor so they fit,
--   * the unscaled zones split whatever is left, in proportion to their nominal
--     widths -- so they GIVE width when the sliders grow and TAKE it back when the
--     sliders shrink.
-- Returns (list of { w = nominal, world = algebra value }, side total).
function M.side_plan(A, side, scales, cfg)
  local segs = M.segments(side, cfg)

  local total, free_total, free_floor = 0, 0, 0
  local scaled = {}
  for _, s in ipairs(segs) do
    total = total + s.w
    if s.key then
      scaled[#scaled + 1] = s
    else
      free_total = free_total + s.w
      free_floor = free_floor + math.min(s.w, M.MIN_WALL)
    end
  end

  -- The width the scaled zones ask for, and the shared shrink that makes it fit.
  local ask = A.lit(0)
  for _, s in ipairs(scaled) do
    ask = A.add(ask, A.mul(A.lit(s.w), clamped_scale(A, scales[s.key])))
  end
  local shrink = A.lit(1)
  if #scaled > 0 then
    -- ask > 0 always (a scaled zone is at least 1 tile wide and MIN_SCALE > 0).
    shrink = A.min(A.lit(1), A.div(A.lit(total - free_floor), ask))
  end

  local out = {}
  local taken = A.mul(ask, shrink)
  for _, s in ipairs(segs) do
    local world
    if s.key then
      world = A.mul(A.mul(A.lit(s.w), clamped_scale(A, scales[s.key])), shrink)
    else
      -- The leftover, split across the unscaled zones by nominal share.
      world = A.mul(A.sub(A.lit(total), taken), A.lit(s.w / free_total))
    end
    out[#out + 1] = { w = s.w, role = s.role, key = s.key, world = world }
  end
  return out, total
end

-- ---------------------------------------------------------------------------
-- The warp itself.
-- ---------------------------------------------------------------------------

-- The displacement (in `to` units) a coordinate `d` tiles out from the centre has
-- crossed, walking one side's segments outward. Each segment contributes its FULL
-- `to` width once `d` is past it, and a linear fraction inside it; past the last
-- segment the sum saturates -- which is exactly the pinned ocean plateau at the map
-- edge. `pick_from`/`pick_to` select which width is the input scale and which the
-- output, so the same walk gives both directions of the warp.
-- A plan's nominal widths are plain numbers; its world widths are already algebra
-- values. Push the numbers through the algebra's literal so the symbolic path formats
-- them (and folds identities) instead of concatenating a raw Lua number.
local function val(A, v)
  if type(v) == "number" then return A.lit(v) end
  return v
end

local function crossed(A, plan, d, pick_from, pick_to)
  local sum = A.lit(0)
  local at = A.lit(0) -- the running boundary, in `from` units
  for _, seg in ipairs(plan) do
    local from_w, to_w = val(A, pick_from(seg)), val(A, pick_to(seg))
    sum = A.add(sum, A.mul(to_w, clamp01(A, A.div(A.sub(d, at), from_w))))
    at = A.add(at, from_w)
  end
  return sum
end

local function nominal_w(seg) return seg.w end
local function world_w(seg) return seg.world end

-- A complete slider table: a caller may pass a partial one (or none), and a missing
-- slider is simply at its default. A plain 1 works in BOTH algebras (the symbolic ops
-- concatenate it as the literal "1"), so this needs no per-algebra branch.
local function resolved(scales)
  local out = {}
  for _, s in ipairs(M.SLIDERS) do
    local v = scales and scales[s.key]
    out[s.key] = (v ~= nil) and v or 1
  end
  return out
end

-- Both sides' plans + the anchor, for one algebra. The NUMERIC plan for the live
-- (settings-derived) geometry is memoised on the slider values: the runtime sweeps ask
-- for it once per entity, and rebuilding seven segments per call would be pure waste.
-- Startup zone widths cannot change while a game runs, so a live plan is stable.
local numeric_plans = {}
local function plans(A, scales, cfg)
  local key
  if A == M.NUMERIC and cfg == nil then
    key = ""
    for _, s in ipairs(M.SLIDERS) do key = key .. tostring(scales[s.key]) .. "/" end
    local hit = numeric_plans[key]
    if hit then return hit end
  end
  local built = {
    centre = M.centre(cfg),
    hot = M.side_plan(A, "hot", scales, cfg),
    cold = M.side_plan(A, "cold", scales, cfg),
  }
  if key then numeric_plans[key] = built end
  return built
end

-- The WARP: world perpendicular coordinate -> NOMINAL perpendicular coordinate, in
-- the given algebra. Anchored at the middle's centre; the sunward sum runs positive
-- and the nightward sum negative, and only one of them is ever non-zero, so the two
-- sides compose into one branch-free expression.
function M.warp(A, p, scales, cfg)
  local pl = plans(A, resolved(scales), cfg)
  local C = A.lit(pl.centre)
  local q = A.add(C, crossed(A, pl.hot, A.sub(p, C), world_w, nominal_w))
  return A.sub(q, crossed(A, pl.cold, A.sub(C, p), world_w, nominal_w))
end

-- The INVERSE warp: nominal -> world (the same walk with the widths swapped). Used by
-- the systems that place things AT a nominal band position (the freeze emitter line)
-- and so need to know where that band actually is on the ground.
function M.unwarp(A, q, scales, cfg)
  local pl = plans(A, resolved(scales), cfg)
  local C = A.lit(pl.centre)
  local p = A.add(C, crossed(A, pl.hot, A.sub(q, C), nominal_w, world_w))
  return A.sub(p, crossed(A, pl.cold, A.sub(C, q), nominal_w, world_w))
end

-- ---------------------------------------------------------------------------
-- Slider values.
-- ---------------------------------------------------------------------------

-- The identity scales (every slider at its default): the geometry the zone table and
-- the startup settings describe, untouched.
function M.default_scales()
  local out = {}
  for _, s in ipairs(M.SLIDERS) do out[s.key] = 1 end
  return out
end

-- Slider multipliers read from a map-gen `autoplace_controls` table (the shape both
-- MapGenSettings and LuaSurface.map_gen_settings use: name -> { frequency, size,
-- richness }). A control that is absent reads as its default 1; the warp clamps, so
-- even a 0 ("None") never collapses a band. Pure.
function M.scales_from_controls(controls)
  local out = M.default_scales()
  if type(controls) ~= "table" then return out end
  for _, s in ipairs(M.SLIDERS) do
    local c = controls[s.control]
    local v = type(c) == "table" and c[M.SLIDER_PROPERTY] or nil
    if type(v) == "number" then out[s.key] = v end
  end
  return out
end

-- The slider multipliers in force on `surface` (its own map-gen settings). Cached per
-- surface: map-gen settings never change after a surface is created (the only runtime
-- write is the driver's one-time finite-dimension pin), and reading them rebuilds a
-- large table, which the per-entity sweeps must not pay for.
-- The cache is keyed by surface index and validated against the surface NAME, so a
-- deleted surface whose index the engine later reuses cannot serve stale sliders.
local surface_cache = {}
function M.for_surface(surface)
  if not (surface and surface.valid) then return M.default_scales() end
  local hit = surface_cache[surface.index]
  if hit and hit.name == surface.name then return hit.scales end
  local ok, mgs = pcall(function() return surface.map_gen_settings end)
  local scales = M.scales_from_controls(ok and mgs and mgs.autoplace_controls or nil)
  surface_cache[surface.index] = { name = surface.name, scales = scales }
  return scales
end

-- Forget a cached surface (a surface was deleted, or a test rewrote its settings).
function M.forget(surface_index)
  if surface_index == nil then surface_cache = {} else surface_cache[surface_index] = nil end
end

-- ---------------------------------------------------------------------------
-- The two runtime entry points + the data-stage emitter.
-- ---------------------------------------------------------------------------

-- The NOMINAL perpendicular coordinate of a world position -- what every band, curve
-- and zone lookup in the mod wants. `scales` comes from M.for_surface (pass it in
-- once per sweep, like `orient`); omit it for the unscaled geometry.
function M.nominal_perp(x, y, orient, scales, cfg)
  return M.warp(M.NUMERIC, axis.perp(x, y, orient), scales or M.default_scales(), cfg)
end

-- The nominal coordinate of a world perpendicular coordinate (when the caller already
-- resolved the orientation).
function M.to_nominal(p, scales, cfg)
  return M.warp(M.NUMERIC, p, scales or M.default_scales(), cfg)
end

-- Where a NOMINAL band position actually sits, in world tiles.
function M.to_world(q, scales, cfg)
  return M.unwarp(M.NUMERIC, q, scales or M.default_scales(), cfg)
end

-- The warp as a noise-expression string: the sunward-positive NOMINAL coordinate,
-- for the map-gen. Reads the raw world axis (orientation-resolved) and the three
-- slider variables, which resolve to 1 everywhere except on Cindra (see
-- prototypes/zone-sliders.lua) -- so this expression is the identity off Cindra and
-- on a default-slider Cindra.
function M.perp_expr(cfg, orient)
  local scales = {}
  for _, s in ipairs(M.SLIDERS) do scales[s.key] = s.var end
  return M.warp(M.SYMBOLIC, axis.raw_perp_expr(orient), scales, cfg)
end

return M
