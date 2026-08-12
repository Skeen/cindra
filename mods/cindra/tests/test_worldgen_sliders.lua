-- Proof: the ribbon's PLAYABLE WIDTH and its HOT / COLD ZONE DEPTHS are real
-- world-gen-screen sliders (ci-i4z), and moving one changes the world a player walks.
--
-- ci-i8a put stone + ice DENSITY on the map-gen screen. The ribbon GEOMETRY was startup
-- mod settings only, because the engine has no custom scalar slider there; it now rides
-- on the SIZE multiplier of three "terrain" autoplace-controls, which the map-gen warps
-- the whole ribbon through (scripts/zone-scale.lua).
--
-- These assertions are all things a PLAYER sees, measured off freshly generated
-- surfaces made from the real planet's map-gen settings with only a slider moved:
--   1. Habitable band at Size 2: the safe ground you can build on around the landing
--      spot is ~120 tiles WIDER, measured tile by tile.
--   2. The lethal ground really moved: the exact spot that BURNS you on the default
--      world is safe ground on the widened one (and the tile under you says so).
--   3. Hot zone at Size 2: the heat belt starts much further sunward, and the lava sea
--      with it. Cold zone at Size 2: the same nightward.
--   4. The map itself does not change: same finite width, both oceans still solid at
--      the edges, void beyond -- the oceans pay for the widened bands, not the map.
--   5. Default sliders generate the reference world (the warp is the identity), so no
--      existing world or test moves.
--   6. The sliders exist on the map-gen screen (terrain category, not disableable) and
--      are wired into the planet's own map-gen settings.
--
-- The warp's maths (and that the map-gen expression and the runtime agree point for
-- point) is proven off-game in unit-tests/test_zone_scale.lua.

local terrain = require("scripts.terrain")
local zone_scale = require("scripts.zone-scale")
local tile_damage = require("scripts.tile-damage")

describe("cindra worldgen: the ribbon geometry sliders (ci-i4z)", function()
  local surfaces = {}
  local ready = false

  -- The strip we measure: the whole perpendicular span, a few chunks of the long axis.
  local SCAN_Y = { -8, 0, 8, 24 }

  local function base_settings()
    local base = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    local mgs = base.map_gen_settings
    mgs.seed = 13579
    -- State BOTH axes (ci-65p): a ribbon is bounded on exactly one of them, and a
    -- copied settings table must not inherit a bound on the long axis.
    local bounds = terrain.map_gen_bounds()
    mgs.width, mgs.height = bounds.width, bounds.height
    return mgs
  end

  -- A surface generated with `sliders` (control name -> Size) applied.
  local function make(name, sliders)
    local mgs = base_settings()
    mgs.autoplace_controls = mgs.autoplace_controls or {}
    for control, size in pairs(sliders) do
      local c = mgs.autoplace_controls[control] or {}
      c.size = size
      c.frequency = c.frequency or 1
      c.richness = c.richness or 1
      mgs.autoplace_controls[control] = c
    end
    local s = game.surfaces[name] or game.create_surface(name, mgs)
    -- Generate a strip covering the whole ribbon width around the origin (much cheaper
    -- than a 15-chunk disc, and the whole ribbon reads the same along its long axis).
    for cx = -448, 448, 64 do s.request_to_generate_chunks({ cx, 0 }, 1) end
    s.force_generate_chunk_requests()
    return s
  end

  before_each(function()
    if ready then return end
    surfaces.base = make("cindra-slider-base", {})
    surfaces.wide = make("cindra-slider-wide", { ["cindra-habitable-band"] = 2 })
    surfaces.hot = make("cindra-slider-hot", { ["cindra-hot-zone"] = 2 })
    surfaces.cold = make("cindra-slider-cold", { ["cindra-cold-zone"] = 2 })
    ready = true
  end)

  -- Vertical orientation (the default): the perpendicular axis is -x, hot to the west.
  -- The damage a player takes is a function of the TILE they stand on
  -- (terrain.tile_damage, scripts/tile-damage.lua), so "is this ground safe" is read
  -- exactly the way the damage sweep reads it.
  local function damage_at(s, x, y)
    return terrain.tile_damage(s.get_tile(x, y).name)
  end

  -- The width, in world tiles, of the contiguous SAFE (no environmental damage) ground
  -- containing the landing spot -- the band you can actually build in. Averaged over a
  -- few rows because the band boundaries are deliberately wavy.
  local function safe_band_width(s)
    local total = 0
    for _, y in ipairs(SCAN_Y) do
      local lo, hi = 0, 0
      while damage_at(s, math.floor(lo) - 1, y) == 0 and lo > -399 do lo = lo - 1 end
      while damage_at(s, math.floor(hi) + 1, y) == 0 and hi < 399 do hi = hi + 1 end
      total = total + (hi - lo)
    end
    return total / #SCAN_Y
  end

  -- How far from the landing spot the first tile that DAMAGES you sits, sunward
  -- (dir = -1, west) or nightward (dir = 1, east). Averaged over the same rows.
  local function first_lethal(s, dir, kind)
    local total = 0
    for _, y in ipairs(SCAN_Y) do
      local d = 399
      for step = 1, 399 do
        local i, k = damage_at(s, dir * step, y)
        if i > 0 and k == kind then d = step break end
      end
      total = total + d
    end
    return total / #SCAN_Y
  end

  -- 1 + 5. THE HABITABLE BAND -------------------------------------------------------
  it("generates the REFERENCE world at default sliders (the warp is the identity)", function()
    -- Safe ground spans the middle plus the two safe slopes: 120 + 70 + 70 = 260 tiles.
    local w = safe_band_width(surfaces.base)
    assert.is_true(math.abs(w - 260) <= 12,
      "default sliders must generate the reference 260-tile safe band; got " .. w)
    local mg = surfaces.base.map_gen_settings
    local bounds = terrain.map_gen_bounds()
    assert.are.equal(bounds.width, mg.width, "and the reference map width")
    -- The long axis stays UNBOUNDED. We ask for 0 (infinite); the engine echoes an
    -- unbounded dimension back as its max map size, so read it the way
    -- test_worldgen.lua does rather than pinning the engine's spelling of "infinite".
    assert.are.equal(0, bounds.height, "the ribbon is bounded on ONE axis only")
    assert.is_true(mg.height == 0 or mg.height > 100000,
      "with the long axis still infinite; got height=" .. tostring(mg.height))
  end)

  it("Habitable band Size 2 really widens the ground you build on (~120 tiles)", function()
    local base = safe_band_width(surfaces.base)
    local wide = safe_band_width(surfaces.wide)
    assert.is_true(wide - base > 90,
      "the safe band must grow by about the middle band's own width; " ..
      base .. " -> " .. wide)
    assert.is_true(math.abs((wide - base) - 120) <= 24,
      "and by ROUGHLY that much, not arbitrarily; " .. base .. " -> " .. wide)
  end)

  -- 2. THE LETHAL GROUND MOVED WITH IT ---------------------------------------------
  it("moves the lethal ground: the spot that BURNS you at default is safe when widened", function()
    -- perp 150 (x = -150) sits 20 tiles inside the heat belt on the default world, and
    -- 40 tiles clear of it once the habitable band is doubled.
    local X, Y = -150, 0
    local bi, bk = damage_at(surfaces.base, X, Y)
    assert.is_true(bi > 0, "the default world burns at x=" .. X)
    assert.are.equal("heat", bk, "and it burns as HEAT")
    local wi = damage_at(surfaces.wide, X, Y)
    assert.are.equal(0, wi, "the widened world is SAFE ground at the same spot")

    -- Read through the real damage decision a player is subject to: the worst tile
    -- under an entity's footprint (scripts/tile-damage.footprint_damage -- what the
    -- periodic sweep damages from; the sweep itself is gated to the live "cindra"
    -- surface, so a generated test surface reads the decision directly).
    local function footprint_kind(s)
      -- Clear whatever the map-gen scattered here (a volcanic rock, a resource patch) so
      -- the character has the spot to itself.
      for _, e in pairs(s.find_entities_filtered({ area = { { X - 2, Y - 2 }, { X + 2, Y + 2 } } })) do
        if e.valid then e.destroy() end
      end
      local c = s.create_entity({ name = "character", position = { X, Y }, force = "player" })
      assert.is_not_nil(c, "a character must be placeable at x=" .. X)
      local i, k = tile_damage.footprint_damage(s, c)
      c.destroy()
      return i, k
    end
    local fi, fk = footprint_kind(surfaces.base)
    assert.is_true(fi > 0 and fk == "heat", "standing there on the default world burns")
    local wfi, wfk = footprint_kind(surfaces.wide)
    assert.are.equal(0, wfi, "standing there on the widened world does not")
    assert.is_nil(wfk, "with no damage kind at all")
  end)

  -- 3. THE ZONE DEPTHS -------------------------------------------------------------
  it("Hot zone Size 2 pushes the heat belt (and the lava sea) further sunward", function()
    local base = first_lethal(surfaces.base, -1, "heat")
    local deep = first_lethal(surfaces.hot, -1, "heat")
    assert.is_true(deep - base > 45,
      "the heat belt must start much further out; " .. base .. " -> " .. deep)
    -- The lava sea is pushed out with it: 220 tiles sunward is deep in the lava ocean on
    -- the default world, and still walkable volcanic crust on the deepened one.
    assert.is_true(terrain.is_walkable(surfaces.hot.get_tile(-220, 0).name),
      "the deepened hot zone is walkable ground where the default world had lava, got " ..
      surfaces.hot.get_tile(-220, 0).name)
    assert.is_false(terrain.is_walkable(surfaces.base.get_tile(-220, 0).name),
      "(the default world really is lava there)")
    -- The cold side is untouched: one slider never moves the other side's bands.
    assert.is_true(math.abs(first_lethal(surfaces.hot, 1, "cold") - first_lethal(surfaces.base, 1, "cold")) <= 12,
      "the hot slider must not move the cold belt")
  end)

  it("Cold zone Size 2 pushes the cold belt (and the ice sea) further nightward", function()
    local base = first_lethal(surfaces.base, 1, "cold")
    local deep = first_lethal(surfaces.cold, 1, "cold")
    assert.is_true(deep - base > 45,
      "the cold belt must start much further out; " .. base .. " -> " .. deep)
    assert.are.equal("cindra-ice-smooth", surfaces.base.get_tile(250, 0).name,
      "(the default world is deep ice 250 tiles nightward)")
    assert.are_not.equal("cindra-ice-smooth", surfaces.cold.get_tile(250, 0).name,
      "the deepened cold zone has pushed the ice sea further out")
    assert.is_true(math.abs(first_lethal(surfaces.cold, -1, "heat") - first_lethal(surfaces.base, -1, "heat")) <= 12,
      "the cold slider must not move the heat belt")
  end)

  -- 4. THE MAP IS THE SAME MAP -----------------------------------------------------
  it("keeps the map the same size and both ocean walls at the edges, every setting", function()
    local extreme = make("cindra-slider-extreme", {
      ["cindra-habitable-band"] = 6, ["cindra-hot-zone"] = 6, ["cindra-cold-zone"] = 6,
    })
    for name, s in pairs({ base = surfaces.base, wide = surfaces.wide, hot = surfaces.hot,
                           cold = surfaces.cold, extreme = extreme }) do
      assert.are.equal(terrain.map_gen_bounds().width, s.map_gen_settings.width,
        name .. ": the ribbon keeps its finite width")
      assert.are.equal("out-of-map", s.get_tile(-410, 0).name, name .. ": void beyond the sunward edge")
      assert.are.equal("out-of-map", s.get_tile(410, 0).name, name .. ": void beyond the nightward edge")
      -- The walls: molten lava sunward, deep ice nightward, right up to the edge.
      assert.are.equal("cindra-lava-hot", s.get_tile(-396, 0).name, name .. ": lava sea at the sunward edge")
      assert.is_false(terrain.is_walkable(s.get_tile(-396, 0).name), name .. ": and it is impassable")
      assert.are.equal("cindra-ice-smooth", s.get_tile(396, 0).name, name .. ": ice sea at the nightward edge")
      -- ...and the landing spot is still safe, walkable, buildable ground (a rock or a
      -- resource patch may sit on it, so this reads the GROUND, not a placement test).
      local spawn_damage = damage_at(s, 0, 0)
      assert.are.equal(0, spawn_damage, name .. ": the landing spot takes no damage")
      assert.is_true(terrain.is_walkable(s.get_tile(0, 0).name),
        name .. ": the landing spot is walkable ground, got " .. s.get_tile(0, 0).name)
    end
  end)

  -- 6. THE SLIDERS ARE ON THE SCREEN -----------------------------------------------
  it("exposes the three geometry sliders on the map-gen screen (terrain, not disableable)", function()
    for _, s in ipairs(zone_scale.SLIDERS) do
      local ctrl = prototypes.autoplace_control[s.control]
      assert.is_not_nil(ctrl, s.control .. " autoplace-control exists")
      assert.are.equal("terrain", ctrl.category, s.control .. " is a terrain slider")
      assert.is_false(ctrl.can_be_disabled, s.control .. " cannot be switched off (a zone must exist)")
      assert.is_false(ctrl.richness, s.control .. " has no richness (it is not a resource)")
    end
  end)

  it("wires the sliders into the planet's own map-gen settings, and only there", function()
    local mg = base_settings()
    for _, s in ipairs(zone_scale.SLIDERS) do
      assert.is_not_nil(mg.autoplace_controls[s.control],
        s.control .. " is shown for Cindra (it is in the planet's controls)")
      assert.are.equal(zone_scale.reader_name(s.key), mg.property_expression_names[s.var],
        s.var .. " reads the map-gen screen on Cindra")
      -- The identity default exists globally, so every OTHER surface resolves the warp
      -- to the raw axis and no foreign world is ever asked for a Cindra control.
      assert.is_not_nil(prototypes.named_noise_expression[s.var],
        s.var .. " has a global identity default (off-Cindra safety)")
      assert.is_not_nil(prototypes.named_noise_expression[zone_scale.reader_name(s.key)],
        s.key .. " slider reader exists")
    end
    assert.is_not_nil(prototypes.named_noise_expression[zone_scale.PERP_EXPR],
      "the warped nominal axis every band reads exists")
    assert.is_not_nil(prototypes.named_noise_expression[zone_scale.PERP_NEG_EXPR],
      "and its nightward twin")
  end)
end)
