-- Where each Cindra resource lives on the ribbon axis, and how rich it is (§5,
-- §15 item 3; rebanded to the ci-da2 zones). PURE module (no game.* /
-- prototypes.*): it maps a perpendicular coordinate to a per-band richness, so the
-- placement geometry is deterministic and unit-testable off the game entirely.
--
-- The ONE source of truth for every Cindra resource's placement, read entirely at
-- the DATA stage (prototypes/resources.lua): stone / ice patches and the finite
-- bootstrap rocks are ALL placed by NATIVE map-gen autoplace (spot-noise patches,
-- not a script grid), CONSTRAINED to their zone by multiplying the autoplace
-- probability/richness by a perpendicular-axis MASK this module emits as a
-- noise-expression string. There is NO runtime placement (ci-3yl).
--
-- The single organising idea (the planet's thesis, §1): ENERGY sunward, MATTER
-- nightward, and the BEST of everything at the lethal margins (edge-pushing).
--
--   stone      the building ribbon + the SAFE hot margin, richer toward the hot
--              edge, but stopping SHORT of the heat damage zone (ci-fb9); never
--              into the cold zone.
--   ice        the SAFE cold margin east of the building band, richer DEEPER
--              (colder), but stopping SHORT of the cold-lethal deep-ice cap
--              (ci-fb9); never into the hot/temperate zone.
--   sandy rocks   finite bootstrap scatter across the WARM part of the building band,
--              fading out before the frosty cold zones (ci-18n): no rock-on-ice.
--   ice-rocks  finite bootstrap scatter across the SAFE cold band (cold of the
--              divider, warm of the lethal deep-ice cap); yields ice + stone (ci-18n).
--              ICEBERG art in two sizes since ci-w87.
--   volcanic rocks  finite scatter across the volcanic-tile region, clustered toward
--              the lava; yields stone + coal (ci-qy0, tightened to volcanic tiles ci-18n).
--              Each size in a COOL and a HOT (glowing) model, split at the lava edge
--              so the model matches the ground it stands on (ci-w87).
--
-- HARVESTABLE FIELDS NEVER SPAWN IN THE LETHAL DAMAGE ZONE (ci-fb9, margin added
-- ci-4iw): a resource on the unreachable lethal cap/wall is visible-but-unreachable.
-- stone + ice are clamped to the damage-free band via field_bounds (reads
-- terrain.damage_bounds -- the SAME positional lethal-zone boundary the design and the
-- worldgen use), and pulled a further FIELD_DAMAGE_MARGIN back so the ore visibly stops
-- before the lethal ground. Fields still reach INTO the survivable edge margin (zone 4
-- warm-cracks, zone 10 rough-ice: "best resources reachable at a cost"), which is the
-- intended edge-push, NOT the death zone. Volcanic rocks are the one deliberate
-- exception -- they live IN the hot region as the hazard-reward.
--
-- ...and NO FIELD EVER LIES ON GROUND THAT DAMAGES YOU (ci-bgpm), which the positional
-- margin above cannot deliver on its own: the tile family is chosen from the noisy
-- heightmap VALUE, so a lethal tile surfaces ~20 tiles inside the nominal safe side
-- (measured) -- ci-4iw's 9.5-tile budget was ~6x too small and only held at default
-- sliders by luck. The guarantee is M.field_tile_restriction: the resources may generate
-- only on tiles that deal no damage, so a bled lethal tile carries no ore however far it
-- bled, and both bands keep their full width (the edge-push reward is untouched).
--
-- The zone boundaries come from scripts/terrain.lua (M.resource_bounds), the SAME
-- geometry that lays the tile gradient, so resources and terrain share one source
-- of truth: stone on the hot ribbon, ice on the cold cap, split at the one divider
-- (the cold edge of the building band) so the purity guarantee (ci-7w0) holds --
-- stone can NEVER generate in the icy zone, ice NEVER in the hot/temperate zone.

local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

local M = {}

-- The perpendicular (sunward-positive) axis as a noise-expression string. The
-- ORIENTATION (scripts/axis.lua) decides whether "hot vs cold" is x or y; the band
-- masks read this ONE expression so they never re-derive it. Default vertical
-- orientation: "(0 - x)" (hot on the left / west).
M.PERP_AXIS = axis.perp_expr()

-- Cindra resource / entity prototype names (defined in prototypes/resources.lua).
M.STONE = "cindra-stone"
M.ICE = "cindra-ice"
M.ROCK = "cindra-rock"

-- Ice-rocks (ci-18n): a cold-side counterpart to the sandy bootstrap rock. A finite
-- hand-minable simple-entity that generates in the SAFE cold/ice band and yields an
-- early ICE + STONE trickle (prototypes/resources.lua). Named here with the other
-- Cindra worldgen entity names so resources.lua, the planet.lua autoplace allow-list
-- and the tests all read the SAME name.
--
-- TWO SIZES since ci-w87, because the ART is now Aquilo's LITHIUM-ICEBERG family
-- rather than a blue-tinted brown boulder: the icebergs ship as a huge and a big
-- entity model (plus medium/small/tiny DECORATIVES, which ride the decorative
-- catalogue in scripts/decorative-field.lua). Both sizes share the one cold-band
-- placement rule below; only the model and the yield magnitude differ.
M.ICE_ROCK = "cindra-ice-rock"
M.ICE_ROCK_HUGE = "cindra-ice-rock-huge"
function M.ice_rock_names()
  return { M.ICE_ROCK, M.ICE_ROCK_HUGE }
end

-- Burned volcanic rocks (ci-qy0): charred Vulcanus-style boulders that generate in
-- the HOT / lava region only, clustered toward the lava edge so they read as "in
-- the lava areas". Size variants for visual variety; all are finite
-- simple-entities that yield STONE + COAL only (see prototypes/resources.lua).
-- The names live here (with the other Cindra worldgen entity names) so
-- prototypes/resources.lua, prototypes/planet.lua's autoplace allow-list, and the
-- tests all read the SAME list.
--
-- Since ci-w87 each size comes in a COOL and a HOT model. Vulcanus draws its rocks
-- two ways -- a plain charred boulder, and a `-hot` twin whose art carries an
-- emissive glow layer -- and gates them BY TILE, so a rock standing on glowing crust
-- glows too. Cindra does the same (M.burned_rock_tile_restriction): the hot model may
-- stand only on ground that burns and the cool model only on ground that does not, so
-- which model you see tells you what the ground under it will do to you.
M.BURNED_ROCK = "cindra-volcanic-rock"
M.BURNED_ROCK_HUGE = "cindra-volcanic-rock-huge"
M.BURNED_ROCK_HOT = "cindra-volcanic-rock-hot"
M.BURNED_ROCK_HUGE_HOT = "cindra-volcanic-rock-huge-hot"
function M.burned_rock_names()
  return { M.BURNED_ROCK, M.BURNED_ROCK_HUGE, M.BURNED_ROCK_HOT, M.BURNED_ROCK_HUGE_HOT }
end

-- The burned rocks that carry the HOT (emissive) model, i.e. the ones gated to the
-- lava area. The complement is the cool set.
M.BURNED_ROCK_HOT_SET = {
  [M.BURNED_ROCK_HOT] = true,
  [M.BURNED_ROCK_HUGE_HOT] = true,
}
function M.is_hot_burned_rock(name) return M.BURNED_ROCK_HOT_SET[name] == true end

-- Node richness (resource `amount`) starting points, all (tune).
M.STONE_BASE = 600
M.STONE_PEAK = 5000     -- at the hot (lava-crust) margin (best stone)
M.ICE_BASE = 600
M.ICE_PEAK = 5000       -- deep cold cap (best ice)

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

-- The zone boundaries (perp-space) resources band against, from the tile geometry.
local function bounds(cfg)
  return terrain.resource_bounds(cfg)
end

-- Keep-back MARGIN (tiles) from the lethal-zone boundary (ci-4iw): the bands stop this
-- far short of the nominal damage boundary so the ore VISIBLY stops before the lethal
-- ground rather than running right up to it. It is a COSMETIC/positional keep-back and
-- nothing more -- the GUARANTEE that no ore lies on lethal ground is
-- M.field_tile_restriction below, which reads the TILE.
--
-- It used to be the guarantee, budgeting the tile-boundary wiggle plus the per-tile
-- speckle (NOISE_AMPLITUDE + SPECKLE_AMPLITUDE, quoted as "= 14" from the pre-ci-qqt
-- amplitudes and never re-derived). That budget was never the right shape (ci-bgpm): the
-- tile FAMILY is picked from the heightmap VALUE, and the speckle that makes co-present
-- value bands interpenetrate is SPECKLE_H (0.012) in FIELD units, which on the gentle
-- outer slopes (~0.002 H per tile) is worth ~6 tiles for EACH of the two tiles competing
-- at a boundary. Measured in-engine (seed 24680, 8192 rows) heat-damaging crust reaches
-- 18 tiles warmward of its nominal boundary and cold-damaging snow 20 tiles middle-ward
-- of its own -- twice this margin. Widening the margin to cover that would have cost the
-- richest ~12 tiles at BOTH band edges (the edge-push reward); gating on the tile costs
-- nothing and cannot be out-bled at all.
M.FIELD_DAMAGE_MARGIN = terrain.NOISE_AMPLITUDE + terrain.SPECKLE_AMPLITUDE + 6

-- WHICH GROUND A FIELD MAY LIE ON IS DECIDED BY THE TILE, NOT BY THE COORDINATE
-- (ci-bgpm; the ci-w87 lesson, applied to the harvestable fields). You mine a patch by
-- STANDING on it, so a patch tile on burning crust or on frozen ground is ore you cannot
-- harvest without taking damage -- the visible-but-unreachable UX ci-fb9 forbids.
--
-- Positions and tiles do not agree near a band edge and cannot be made to: the tile is
-- chosen from the noisy field VALUE, so a lethal tile turns up ~20 tiles inside the
-- nominal safe side (measured; see M.FIELD_DAMAGE_MARGIN). Any positional keep-back is
-- therefore either too narrow (ore on lethal ground) or wide enough to eat the
-- edge-push reward. An autoplace `tile_restriction` naming exactly the Cindra tiles that
-- deal NO damage makes the disagreement impossible instead of merely small: a bled
-- lethal tile carries no ore however far it bled, and the bands keep their full width.
--
-- Derived from terrain.tiles_by_damage, so a retuned value ramp moves this list with it.
function M.field_tile_restriction()
  return terrain.tiles_by_damage(nil)
end

-- The damage-EXCLUDED band edges for HARVESTABLE FIELDS (ci-fb9, margin ci-4iw). A
-- field (stone / ice patch) must NEVER generate in the LETHAL damage zone: a resource
-- on the unreachable cap/wall is visible-but-unreachable, forbidden UX. So clamp the
-- stone band's hot edge below the heat-damage boundary and the ice band's cold edge
-- above the cold-damage boundary (both from terrain.damage_bounds -- the SAME
-- positional lethal-zone boundary the tile gradient and worldgen use), then pull each
-- a further FIELD_DAMAGE_MARGIN into the safe side so the ore stops visibly short of the
-- lethal ground instead of at it (ci-4iw: ci-fb9 clamped EXACTLY to the boundary). The
-- fields still reach INTO the survivable edge margin (zone 4 / zone 10), the intended
-- edge-push reward. What keeps ore off an individual BLED lethal tile is not this margin
-- but M.field_tile_restriction (ci-bgpm) -- see there for why it cannot be a position.
--
-- Only stone + ice need this. Volcanic rocks are the deliberate hazard-reward
-- exception and keep the raw walkable hot_edge (they read as "in the lava"); the
-- bootstrap rocks already sit inside the safe building band (|p| <= building_half).
local function field_bounds(cfg)
  local b = bounds(cfg)
  local d = terrain.damage_bounds(cfg)
  local margin = M.FIELD_DAMAGE_MARGIN
  local hot_edge = b.hot_edge
  if d.hot_from and (d.hot_from - margin) < hot_edge then hot_edge = d.hot_from - margin end
  local cold_edge = b.cold_edge
  if d.cold_from and (d.cold_from + margin) > cold_edge then cold_edge = d.cold_from + margin end
  return {
    building_half = b.building_half,
    building_lo = b.building_lo,
    hot_edge = hot_edge,    -- stone lives STRICTLY below this (margin short of the heat cap)
    cold_edge = cold_edge,  -- ice lives STRICTLY above this (margin short of the cold cap)
  }
end

-- The mutually-exclusive placement RULE (ci-7w0): stone on the building ribbon +
-- the SAFE (non-lethal) hot margin (p in [building_lo, hot_edge)); ice on the SAFE
-- cold margin (p in (cold_edge, building_lo)); both keyed off the SAME divider at
-- building_lo. Because the two zones share that one divider and never overlap it,
-- STONE can NEVER generate in the cold zone and ICE can NEVER generate in the
-- hot/temperate zone -- the purity guarantee, expressed as pure geometry. The outer
-- edges come from field_bounds, so both bands also stop STRICTLY short of the damage
-- zones (ci-fb9): no field tile is ever visible-but-unreachable. `y` is the signed
-- perpendicular coordinate (sunward-positive).
function M.stone_zone(y, cfg)
  local b = field_bounds(cfg)
  return y >= b.building_lo and y < b.hot_edge
end

function M.ice_zone(y, cfg)
  local b = field_bounds(cfg)
  return y < b.building_lo and y > b.cold_edge
end

-- Stone: from the cold edge of the building band out to the SAFE hot margin (short
-- of the heat band), richest toward the hot edge so pushing sunward is rewarded.
-- Returns 0 where stone should not appear (the cold zone and the heat damage zone).
function M.stone_richness(y, cfg)
  local b = field_bounds(cfg)
  if not M.stone_zone(y, cfg) then return 0 end
  local span = math.max(1, b.hot_edge - b.building_lo)
  local f = clamp((y - b.building_lo) / span, 0, 1)
  return math.floor(lerp(M.STONE_BASE, M.STONE_PEAK, f))
end

-- Ice: east of the building band, richer the DEEPER (colder) you go, out to the SAFE
-- cold margin (short of the cold-lethal cap). Returns 0 in the hot/temperate zone
-- and in the cold damage zone.
function M.ice_richness(y, cfg)
  local b = field_bounds(cfg)
  if not M.ice_zone(y, cfg) then return 0 end
  local span = math.max(1, b.building_lo - b.cold_edge)
  local depth = b.building_lo - y                     -- tiles past the divider, coldward
  local f = clamp(depth / span, 0, 1)
  return math.floor(lerp(M.ICE_BASE, M.ICE_PEAK, f))
end

-- Sandy bootstrap rocks scatter across the TEMPERATE/WARM part of the building band,
-- along the WHOLE ribbon (not just near spawn). Finiteness is a property of the
-- ENTITY (a mined rock is a destroyed simple-entity, one-shot, off every loop
-- recipe), not of the placement (§6).
--
-- ci-18n: the cold edge is pulled a MARGIN warmward of the building band's cold edge
-- (building_lo) so the sandy rocks FADE OUT BEFORE the frosty cold zones. The hot
-- (sunward) edge stays at the middle's hot edge -- that neighbour is the cool volcanic
-- hot outer slope, never ice, so it needs no pull.
--
-- THE MARGIN IS A COSMETIC FADE, NOT A GUARANTEE (ci-pxlz). ci-18n sized it against the
-- noise AMPLITUDES (NOISE_AMPLITUDE + SPECKLE_AMPLITUDE, 3.5 tiles since the ci-qqt
-- thin-ribbon compression) and read that as "so no sandy rock can sit on a frost tile".
-- That is not what a tile family's bleed is worth: the speckle is a FIELD-unit tie-break,
-- so on the shallow middle slope a cold-slope dust tile reaches far further warmward than
-- 5 tiles (ci-bgpm measured ~20 at the damage boundaries). A sandy rock on a frost-LOOKING
-- dust tile is a looks-only mismatch (both tiles are safe ground) and this margin is what
-- softens it; the rule that must actually HOLD -- no rock planted in ground that damages
-- you -- gates on the TILE instead (M.bootstrap_rock_tile_restriction, and for the ore
-- fields and burned rocks M.field_tile_restriction / M.burned_rock_tile_restriction).
M.ROCK_COLD_MARGIN = 5
function M.rock_zone(y, cfg)
  local b = bounds(cfg)
  return y <= b.building_half and y >= b.building_lo + M.ROCK_COLD_MARGIN
end

-- Per-tile spawn probability inside the rock band (sparse hand-gathered scatter).
M.ROCK_PROBABILITY = 0.006

-- Ice-rocks (ci-18n) scatter across the SAFE cold/ice band: cold of the building
-- band's cold edge (building_lo, the stone/ice divider) but WARM of the lethal
-- deep-ice damage zone (zone 11, p <= damage cold_from). So they read as "on the
-- icy side". Finite simple-entities like the sandy rock (one-shot on mining), yielding
-- an early ice + stone trickle.
--
-- ci-18n also claimed this positional clamp kept them "hand-gatherable with no cold
-- damage -- the damage-zone exclusion the resource-reachability rule asks for". It did
-- NOT (ci-pxlz): cold-damaging snow bleeds ~20 tiles middle-ward of the boundary this
-- clamps to, and unlike the ore fields there is no keep-back margin here at all, so 10
-- of 579 ice-rocks were planted in freezing ground. What actually delivers the
-- no-damage promise is M.bootstrap_rock_tile_restriction, which reads the TILE; this
-- bound stays for what it honestly is -- the band's SHAPE, keeping the scatter out of
-- the deep-ice cap entirely rather than trimming it tile by tile out there.
function M.ice_rock_zone(y, cfg)
  local b = bounds(cfg)
  local d = terrain.damage_bounds(cfg)
  return y <= b.building_lo and y > d.cold_from
end

-- Per-tile spawn probability inside the ice-rock band (sparse, like the sandy rock).
-- HALVED from the original 0.006 (ci-tizx): the ice-rock chunks share the cold outer
-- band with the frost decals, and at 0.006 the two together buried the ground tiles.
-- The band is 70 tiles deep and runs the WHOLE length of the ribbon, so 0.003 still
-- leaves an ample hand-mined ice + stone bootstrap, just with ground showing between
-- the chunks.
M.ICE_ROCK_PROBABILITY = 0.003

-- How ICE_ROCK_PROBABILITY is SPLIT between the two iceberg sizes (ci-w87). The shares
-- SUM TO 1, so adding the big model alongside the huge one changes only which model you
-- see, never how much of the cold band is covered -- the ci-tizx "you can still see the
-- ground" density budget is untouched by the art swap. Big is the common one; the huge
-- berg is the occasional landmark.
M.ICE_ROCK_SHARE = {
  [M.ICE_ROCK] = 0.7,
  [M.ICE_ROCK_HUGE] = 0.3,
}

-- Burned volcanic rocks (ci-qy0) live in the HOT region only, in the VOLCANIC-TILE
-- region proper (terrain.cliff_band: hot_inner .. hot_outer), from the middle's hot
-- edge out to the walkable hot margin (the hot inner-slope edge, just short of the lava
-- ocean). EXCLUDES the habitable middle and the ENTIRE cold/ice side, and stops at the
-- walkable hot edge (never into the impassable lava ocean, where a simple-entity could
-- not place), so they read as "in the lava areas". Boolean, pure.
function M.burned_rock_zone(y, cfg)
  local v = terrain.cliff_band(cfg)
  return y > v.lo and y <= v.hi
end

-- The LAVA-AREA edge (ci-w87): the warmward boundary of the heat-lethal band, i.e. the
-- nominal perpendicular position where the field crosses HOT_DMG and the ground turns
-- into glowing crust (scripts/terrain.lua owns it; we read it, never re-derive it).
-- Sunward of this line the ground burns you; that is what "inside the lava areas"
-- means. It is the PROSE boundary only -- see below for why the model gate is a tile
-- restriction and not this number.
function M.lava_edge(cfg)
  return terrain.damage_bounds(cfg).hot_from
end

-- WHICH VOLCANIC MODEL GOES WHERE IS DECIDED BY THE TILE, NOT BY THE COORDINATE
-- (ci-w87). The glowing `-hot` boulders may stand only on ground that burns, and the
-- plain charred ones only on ground that does not, so what the player sees is always a
-- truthful read of what they are standing on.
--
-- It has to be the tile. The nominal boundary is M.lava_edge, but the tile bands are
-- painted through a boundary wiggle plus a per-tile speckle expressed in FIELD units,
-- and on the gentle hot slope that speckle is worth roughly six TILES of bleed: glowing
-- crust really does appear several tiles warmward of the line. A position-gated model
-- therefore puts plain rocks on burning ground (and glowing ones on cool ground) in a
-- band either side of the edge -- measured, not hypothetical. Gating on the tile makes
-- the disagreement impossible instead of merely small, and it is what Vulcanus itself
-- does with its own hot/cold rock pair.
--
-- The two restrictions are disjoint and together cover every Cindra tile, so wherever
-- the band mask says "a rock here", exactly one model qualifies -- no ground is left
-- rock-free by the split.
function M.burned_rock_tile_restriction(name)
  if M.is_hot_burned_rock(name) then return terrain.tiles_by_damage("heat") end
  return terrain.tiles_by_damage(nil)
end

-- A HAND-GATHERED ROCK IS PLANTED IN GROUND YOU CAN STAND IN (ci-pxlz) -- decided by the
-- TILE, not by the coordinate, the same way and for the same reason as the volcanic
-- models above and the ore fields.
--
-- The bootstrap rocks (sandy + ice) are the ONE thing on Cindra you harvest by walking
-- to it and waiting: you spot the rock, cross to it, and hold the mine key for a couple
-- of seconds. If the rock is planted in burning crust or freezing snow, that whole trip
-- costs health -- and it is the LANDING-TIER trip, made before you have any heat/cold
-- gear at all. So a rock on lethal ground is the visible-but-unreachable UX ci-fb9
-- forbids, in its most expensive form.
--
-- The positional bounds those two scatters carry (M.rock_zone's ROCK_COLD_MARGIN,
-- M.ice_rock_zone's clamp at the cold-damage boundary) cannot deliver that, and
-- ci-18n's comment claiming they did was simply wrong. The tile FAMILY comes from the
-- noisy heightmap VALUE, so cold-damaging snow surfaces ~20 tiles middle-ward of the
-- boundary the ice-rock band stops AT -- measured in-engine, seed 24680 over 2800 rows:
-- 10 of 579 ice-rocks planted in freezing ground (35 touching some freezing tile), and
-- the sandy scatter has only the 5-tile ROCK_COLD_MARGIN standing between it and the
-- same class of leak. Widening those margins is not the answer either: covering a
-- 20-tile bleed would eat the outer third of the ice-rock band, which is exactly where
-- ci-18n wanted the cold-side bootstrap to read as "out on the ice".
--
-- Naming the damage-free tiles instead costs the band nothing: it removes only the
-- scattered rocks that were standing in bled lethal ground (measured: 579 -> 569 ice
-- rocks, ~1.7%, with the scatter still reaching the same distance out), and no
-- coordinate can put a rock and its ground out of step again.
--
-- Derived from terrain.tiles_by_damage, so a retuned value ramp moves this list with it.
-- The GLOWING volcanic boulders are the deliberate exception and keep their own
-- restriction above: they belong in the lava area, where they are hazard signage rather
-- than a resource you set out to collect.
function M.bootstrap_rock_tile_restriction()
  return terrain.tiles_by_damage(nil)
end

-- Per-tile spawn probability at the two ends of the hot region: sparse at the
-- inner (safe-band) edge, densest toward the lava (lethal) edge and beyond, so the
-- rocks cluster where the lava is. The emitter below ramps between them.
M.BURNED_ROCK_PROBABILITY_MIN = 0.003
M.BURNED_ROCK_PROBABILITY_MAX = 0.02

-- ---------------------------------------------------------------------------
-- Native-autoplace band masks (§15-v2 item 1: patches, not a grid).
--
-- These emit Factorio noise-expression STRINGS that prototypes/resources.lua
-- multiplies into each resource's autoplace probability/richness so the spot-noise
-- patches only appear inside the zone. A comparison in the DSL yields 1/0, so
-- multiplying two of them is a logical AND; multiplying a resource's probability by
-- the mask zeroes it outside the band. The boundaries MATCH the numeric richness_*
-- fns above (they read the SAME terrain.resource_bounds), so the emitted patches
-- land exactly where the pure geometry says they should.
-- ---------------------------------------------------------------------------

-- Format a number for the DSL (trim to avoid float noise; integers stay clean).
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.6g", v)
end

local Y = M.PERP_AXIS -- the sunward-positive perpendicular axis expression.

-- Stone: p in [building_lo, hot_edge). Encodes M.stone_zone as a noise-expression
-- string, so the map-gen zeroes stone probability/richness in the cold zone AND in
-- the heat damage zone (hot_edge is clamped to the heat boundary; ci-fb9).
function M.stone_mask_expr(cfg)
  local b = field_bounds(cfg)
  return "(" .. Y .. " >= " .. num(b.building_lo) .. ")" ..
         " * (" .. Y .. " < " .. num(b.hot_edge) .. ")"
end

-- Ice: p in (cold_edge, building_lo). Encodes M.ice_zone, so the map-gen zeroes ice
-- probability/richness across the whole hot + temperate zone AND the cold damage
-- zone (cold_edge is clamped to the cold boundary; ci-fb9).
function M.ice_mask_expr(cfg)
  local b = field_bounds(cfg)
  return "(" .. Y .. " < " .. num(b.building_lo) .. ")" ..
         " * (" .. Y .. " > " .. num(b.cold_edge) .. ")"
end

-- Sandy bootstrap rocks: a native simple-entity autoplace confined to the WARM part
-- of the building band -- the hot edge (building_half) down to a MARGIN warm of the
-- building band's cold edge (building_lo + ROCK_COLD_MARGIN) -- but present along the
-- WHOLE ribbon. The warmward cold bound (ci-18n) keeps sandy rocks off the frosty
-- cold-zone tiles (no rock-on-ice). A comparison yields 1/0, so the product is a
-- logical AND masking the constant per-tile probability to the band.
function M.rock_probability_expr(cfg)
  local b = bounds(cfg)
  local hi = b.building_half
  local lo = b.building_lo + M.ROCK_COLD_MARGIN
  return "(" .. Y .. " <= " .. num(hi) .. ")" ..
         " * (" .. Y .. " >= " .. num(lo) .. ")" ..
         " * " .. num(M.ROCK_PROBABILITY)
end

-- Ice-rocks (ci-18n): a native simple-entity autoplace confined to the SAFE cold/ice
-- band -- cold of the divider (building_lo) but warm of the lethal deep-ice damage
-- zone (damage cold_from) -- present along the WHOLE cold cap. Encodes M.ice_rock_zone
-- as a noise-expression string (a comparison yields 1/0, so the product is a logical
-- AND), masking the constant per-tile probability to the band. The mask zeroes
-- probability across the whole hot/temperate zone AND the lethal deep-ice cap, so
-- ice-rocks can NEVER generate there (matches M.ice_rock_zone; keep the two in step).
--
-- `name` (optional, ci-w87) picks one iceberg SIZE and scales the probability by that
-- size's share of the scatter (M.ICE_ROCK_SHARE). Omitted, it returns the band's TOTAL
-- probability -- the sum over the sizes -- which is what the density guards measure.
function M.ice_rock_probability_expr(cfg, name)
  local b = bounds(cfg)
  local d = terrain.damage_bounds(cfg)
  local share = 1
  if name ~= nil then
    share = M.ICE_ROCK_SHARE[name]
    assert(share, "resource-field: no ice-rock share for " .. tostring(name))
  end
  return "(" .. Y .. " <= " .. num(b.building_lo) .. ")" ..
         " * (" .. Y .. " > " .. num(d.cold_from) .. ")" ..
         " * " .. num(M.ICE_ROCK_PROBABILITY * share)
end

-- Burned volcanic rocks (ci-qy0): a native simple-entity autoplace confined to the
-- VOLCANIC-TILE region (terrain.cliff_band: hot_inner .. hot_outer) and CLUSTERED
-- toward the lava. The inner edge sits at the middle's hot edge (the cool volcanic
-- slope), so the rocks sit on volcanic tiles. Encodes M.burned_rock_zone as a
-- noise-expression string (a comparison yields 1/0, so the product is a logical AND
-- masking probability to the band), then ramps the per-tile probability from MIN at
-- the inner (safe) edge to MAX at the lethal lava edge and beyond -- so density rises
-- toward the lava and the rocks read as "in the lava areas". The mask zeroes
-- probability across the habitable middle and the whole cold/ice side (matches
-- M.burned_rock_zone; keep the two in lockstep).
--
-- Every volcanic model shares this ONE band expression: the hot/cool choice is made by
-- the tile restriction (M.burned_rock_tile_restriction), not here, so splitting the
-- family across models cannot change how much of the hot region carries rock.
function M.burned_rock_probability_expr(cfg)
  local v = terrain.cliff_band(cfg)
  local S, L = v.lo, v.hi
  local in_zone = "(" .. Y .. " > " .. num(S) .. ")" ..
                  " * (" .. Y .. " <= " .. num(L) .. ")"
  -- Fraction of the way from the volcanic band's cold edge to the walkable lava edge
  -- (clamped), so density ramps from sparse near the ribbon to densest at the lava.
  local span = math.max(1, L - S)
  local frac = "clamp((" .. Y .. " - " .. num(S) .. ") / " .. num(span) .. ", 0, 1)"
  local prob = "lerp(" .. num(M.BURNED_ROCK_PROBABILITY_MIN) .. ", " ..
               num(M.BURNED_ROCK_PROBABILITY_MAX) .. ", " .. frac .. ")"
  return "(" .. in_zone .. ") * (" .. prob .. ")"
end

-- Edge-pushing richness multiplier (>= 1): scales the native patch richness so
-- the BEST nodes sit at the lethal margins, honouring the planet's thesis. The
-- ramp shape mirrors the numeric richness_* gradients (peak/base ratio), so a
-- patch at the hot/cold edge is richer than one near the terminator.
local function lerp_expr(from, to, frac_expr)
  return "lerp(" .. num(from) .. ", " .. num(to) .. ", clamp(" .. frac_expr .. ", 0, 1))"
end

function M.stone_richness_mult_expr(cfg)
  local b = field_bounds(cfg)
  local span = math.max(1, b.hot_edge - b.building_lo)
  local frac = "(" .. Y .. " - " .. num(b.building_lo) .. ") / " .. num(span)
  return lerp_expr(1, M.STONE_PEAK / M.STONE_BASE, frac)
end

function M.ice_richness_mult_expr(cfg)
  local b = field_bounds(cfg)
  local span = math.max(1, b.building_lo - b.cold_edge)
  local frac = "(" .. num(b.building_lo) .. " - " .. Y .. ") / " .. num(span)
  return lerp_expr(1, M.ICE_PEAK / M.ICE_BASE, frac)
end

return M
