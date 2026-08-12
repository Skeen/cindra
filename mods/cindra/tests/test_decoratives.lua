-- Proof: Cindra scatters ZONE-APPROPRIATE decoratives on the LIVE map (ci-6fq).
--
-- Cosmetic decals layered on top of the terrain gradient, keyed to the hot/cold
-- ribbon zone. This drives the actual planet map_gen_settings on a fresh, fixed-seed
-- surface (same harness as tests/test_worldgen.lua) and proves, on the default
-- vertical orientation (perp = -x, hot on the LEFT / west):
--   1. ROCKY HOT HALF: volcanic rock + crater + pebble decals actually generate on
--      the hot (west) half.
--   2. ICY COLD HALF: ice + snow decals actually generate on the cold (east) half.
--   3. ZONE PURITY: NO rock/crater decals bleed into the icy zone, and NO ice/snow
--      decals bleed into the rocky/lava zone -- the "no decals in the wrong zone"
--      acceptance, proven on the live surface (mirrors the ci-7w0 stone/ice purity).
--   4. CLEAN CENTRE: the temperate terminator band stays decal-free.
--   5. LEGIBLE COLD GROUND (ci-tizx): the ice/snow decals never touch the BROWN
--      habitable band (they start at the icy-ground edge), they fade in from that
--      edge, and even at full strength they cover only a small fraction of the
--      ground -- the tiles dominate, not the decals.
--   6. HOT RE-GATE ONTO THE HEIGHTMAP TILES (ci-mk5y): every rock/crater decal lies on
--      solid VOLCANIC ground -- inside the slope+crust band, never on the molten lava it
--      used to float on, never on the brown ash middle it used to litter -- while the
--      burning crust out by the lava still gets its share.
--
-- The pure zone geometry is proven off-game in unit-tests/test_decorative_field.lua;
-- this proves it actually generates. The VISUAL read (do the decals look like ice vs
-- rock, do they sit right on the terrain) is a PLAYTEST.md item -- not testable here.

local field = require("scripts.decorative-field")
local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

describe("cindra decoratives: zone-appropriate decal scatter (ci-6fq)", function()
  -- A dedicated surface cloned from the Cindra planet's own map_gen_settings at a
  -- FIXED seed, isolated from the shared "cindra" surface. Same pattern as
  -- tests/test_worldgen.lua (decoratives generate with the chunks).
  local s
  local ready = false

  before_each(function()
    if ready then return end
    local base = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    local mgs = base.map_gen_settings
    mgs.seed = 2468
    -- Replicate the finite perpendicular bound the runtime hook applies to the real
    -- cindra surface (planet prototypes ignore width), so the bands generate identically.
    local fd = terrain.finite_dimension()
    mgs[fd.key] = fd.value
    s = game.surfaces["cindra-decoratives-test"] or game.create_surface("cindra-decoratives-test", mgs)
    s.request_to_generate_chunks({ 0, 0 }, 11) -- ~352-tile radius: covers the whole region
    s.force_generate_chunk_requests()
    ready = true
  end)

  -- Count decoratives of a given name within an X strip (full Y range).
  --
  -- We filter by exact decal position, NOT by passing `area` to
  -- find_decoratives_filtered: decorative area queries are CHUNK-granular (they
  -- return every decal in any 32-tile chunk the area touches), so an X boundary
  -- that falls mid-chunk -- ours sit at the safe-band edge x = +-24 -- would pull
  -- in decals from the adjacent chunk (x = 25..31 / -31..-25) and report a false
  -- cross-zone "bleed". The zone split is enforced per TILE by the probability
  -- expression, so the purity checks must measure per tile too.
  local function count(name, x1, x2)
    local n = 0
    for _, d in ipairs(s.find_decoratives_filtered({ name = name })) do
      local x = d.position.x
      if x >= x1 and x <= x2 then n = n + 1 end
    end
    return n
  end

  -- Sum decorative counts over a list of names within an X strip.
  local function count_any(names, x1, x2)
    local n = 0
    for _, name in ipairs(names) do n = n + count(name, x1, x2) end
    return n
  end

  -- The Cindra decorative names, split by side (read from the ONE source of truth).
  local hot_names, cold_names = {}, {}
  for _, d in ipairs(field.DECORATIVES) do
    if d.side == "hot" then hot_names[#hot_names + 1] = d.name else cold_names[#cold_names + 1] = d.name end
  end

  -- Default geometry: safe_half_width 24, wall_at 128. Perp = -x, so the hot (rocky/
  -- lava) zone is x < -24 (west). The icy decal zone starts only where the ground
  -- itself turns snow/ice (ci-tizx): perp < damage cold_from (-130) -> x > 130 (east).
  -- Everything between is the BROWN habitable band and must carry no ice/snow decal.
  local COLD_X = -terrain.damage_bounds().cold_from -- 130: the icy-ground edge, in x

  -- The rock/crater band in x (ci-mk5y): the volcanic slope + crust, i.e. the field's ash
  -- contour out to just short of the molten one (perp 90.5 .. 154.5 by default -> x -155 .. -91).
  local HOT_BAND = field.hot_band()
  local HOT_X1, HOT_X2 = -HOT_BAND.hi + 1, -HOT_BAND.lo - 1

  -- 1. ROCKY HOT HALF -------------------------------------------------------------
  it("scatters rock / crater / pebble decals across the volcanic slope", function()
    assert.is_true(count_any(hot_names, HOT_X1, HOT_X2) > 0,
      "rock/crater/pebble decals generate on the hot (west) volcanic ground")
    -- The specific families the bead calls for are each present.
    assert.is_true(count("cindra-volcanic-rock-small", HOT_X1, HOT_X2)
      + count("cindra-volcanic-rock-tiny", HOT_X1, HOT_X2)
      + count("cindra-volcanic-rock-medium", HOT_X1, HOT_X2) > 0, "volcanic rock / pebble decals present")
    assert.is_true(count("cindra-crater-small", HOT_X1, HOT_X2)
      + count("cindra-crater-large", HOT_X1, HOT_X2) > 0, "crater decals present")
  end)

  -- 2. ICY COLD HALF --------------------------------------------------------------
  it("scatters ice + snow decals across the icy (cold) ground", function()
    assert.is_true(count_any(cold_names, COLD_X + 1, 340) > 0,
      "ice/snow decals generate on the icy (east) ground")
    assert.is_true(count("cindra-ice-decal", COLD_X + 1, 340) > 0, "ice decals present")
    assert.is_true(count("cindra-snowy-decal", COLD_X + 1, 340)
      + count("cindra-snow-drift-decal", COLD_X + 1, 340) > 0, "light-snow decals present")
  end)

  -- ci-w87: the cold-side ROCKS are Aquilo's lithium ice-formation models now, and the
  -- small end of that same family (medium/small/tiny) ships as decoratives. All three
  -- must actually turn up, or the icy ground jumps straight from bare tile to boulder
  -- with none of the chips and grit that make it read as one material.
  it("scatters the small end of the ICE-FORMATION family on the icy ground (ci-w87)", function()
    for _, name in ipairs({ "cindra-lithium-iceberg-medium", "cindra-lithium-iceberg-small",
                            "cindra-lithium-iceberg-tiny" }) do
      assert.is_true(count(name, COLD_X + 1, 340) > 0, name .. " must generate on the icy ground")
    end
  end)

  -- 3. ZONE PURITY: no bleed into the wrong zone ----------------------------------
  it("keeps rock/crater decals OUT of the entire icy (cold) zone (no pebbles on ice)", function()
    assert.are.equal(0, count_any(hot_names, 25, 128),
      "no rock/crater/pebble decals anywhere in the icy (cold) zone")
  end)

  it("keeps ice/snow decals OUT of the entire hot + temperate zone (no snow in lava)", function()
    assert.are.equal(0, count_any(cold_names, -128, 24),
      "no ice/snow decals anywhere sunward of the icy zone (rocky/lava + temperate)")
  end)

  -- 5. LEGIBLE COLD GROUND (ci-tizx) ----------------------------------------------
  -- The frost used to start at the safe band (x > 24) and so buried the ~100 tiles of
  -- BROWN habitable ground (ash + dust) that run out to the icy edge at x = 130.
  it("keeps ice/snow decals OFF the whole brown habitable band (ci-tizx)", function()
    assert.are.equal(0, count_any(cold_names, -400, COLD_X),
      "no ice/snow decals warmward of the icy-ground edge (x <= " .. COLD_X .. ")")
  end)

  -- The decals fade IN from that edge, so the near strip is markedly sparser than the
  -- deep strip: no stamped line where the frost begins.
  it("fades the frost in from the icy edge instead of stamping a line (ci-tizx)", function()
    local span = field.COLD_FADE_SPAN
    -- Equal-width strips: the first half of the ramp vs deep past it (full density).
    local w = math.floor(span / 2)
    local near = count_any(cold_names, COLD_X + 1, COLD_X + w)
    local deep = count_any(cold_names, COLD_X + 2 * span, COLD_X + 2 * span + w - 1)
    assert.is_true(deep > 0, "the deep icy ground still reads as frosted")
    assert.is_true(near < deep,
      "frost thickens toward the ice wall (near=" .. near .. " deep=" .. deep .. ")")
  end)

  -- The point of the bead: the GROUND must dominate. Even at full fade the cold decals
  -- may cover only a small fraction of the tiles. Measured per tile in a deep strip
  -- (the densest place they get). MEASURED on this fixed seed: 0.182 decals/tile with
  -- the pre-ci-tizx densities, 0.059 after -- the ceiling sits between the two, so a
  -- regression back to the carpet fails here.
  it("leaves the icy ground legible: decals stay a small fraction of it (ci-tizx)", function()
    local x1, x2 = COLD_X + 2 * field.COLD_FADE_SPAN, 340
    local y1, y2 = -200, 200
    local n = 0
    for _, name in ipairs(cold_names) do
      for _, d in ipairs(s.find_decoratives_filtered({ name = name })) do
        local p = d.position
        if p.x >= x1 and p.x <= x2 and p.y >= y1 and p.y <= y2 then n = n + 1 end
      end
    end
    local tiles = (x2 - x1 + 1) * (y2 - y1 + 1)
    local per_tile = n / tiles
    log("ci-tizx cold decal density: " .. n .. " / " .. tiles .. " = " .. per_tile)
    assert.is_true(per_tile > 0, "some frost survives out on the deep ice")
    assert.is_true(per_tile < 0.1,
      "cold decals must stay sparse (" .. string.format("%.4f", per_tile) .. " per tile)")
  end)

  -- 6. HOT RE-GATE ONTO THE HEIGHTMAP TILES (ci-mk5y) -----------------------------
  -- The hot decals used to be gated on the RIBBON's safe band (perp > 24) with no outer
  -- bound at all, so rocks and craters were strewn across the brown ash MIDDLE and out over
  -- the molten LAVA. They now ride the volcanic slope + crust band derived from the field's
  -- own value crossings (field.hot_band).
  -- Every hot decal as { name, position }. A DecorativeResult carries its prototype under
  -- `decorative`, not a `name` field, so we keep the name we filtered by.
  local function hot_decals()
    local out = {}
    for _, name in ipairs(hot_names) do
      for _, d in ipairs(s.find_decoratives_filtered({ name = name })) do
        out[#out + 1] = { name = name, position = d.position }
      end
    end
    return out
  end

  it("confines every rock/crater decal to the volcanic slope band (ci-mk5y)", function()
    local band = field.hot_band()
    -- One tile of slack: the mask gates the tile whose probability the engine SAMPLED, and
    -- the decal is stored somewhere within that tile.
    local TILE = 1
    local all = hot_decals()
    assert.is_true(#all > 0, "rock/crater decals generated at all")
    for _, d in ipairs(all) do
      local p = axis.perp(d.position.x, d.position.y)
      assert.is_true(p > band.lo - TILE and p < band.hi + TILE,
        d.name .. " at perp " .. p .. " is outside the slope band [" ..
        band.lo .. ", " .. band.hi .. "]")
    end
  end)

  it("puts every rock/crater decal on solid VOLCANIC ground -- never on lava (ci-mk5y)", function()
    -- The tile actually under each decal. The gate is a value band, and a tile contour
    -- breathes by a speckle, so the slope's own tiles PLUS the ash-dark convergence it
    -- blends into are acceptable ground -- a molten tile never is.
    local allowed = field.hot_ground_tiles()
    allowed["cindra-volcanic-ash-dark"] = true
    local n, molten, wrong = 0, 0, {}
    for _, d in ipairs(hot_decals()) do
      local tile = s.get_tile(math.floor(d.position.x), math.floor(d.position.y))
      n = n + 1
      if terrain.is_walkable(tile.name) == false then molten = molten + 1 end
      if not allowed[tile.name] then wrong[tile.name] = (wrong[tile.name] or 0) + 1 end
    end
    assert.is_true(n > 0, "rock/crater decals generated at all")
    assert.are.equal(0, molten, "NO rock/crater decal lies on molten lava")
    local names = {}
    for name, c in pairs(wrong) do names[#names + 1] = name .. " x" .. c end
    assert.are.equal(0, #names,
      "rock/crater decals only sit on volcanic slope/crust ground (found on: " ..
      table.concat(names, ", ") .. ")")
  end)

  it("still scatters rocks out on the hot CRUST, not just the cool slope (ci-mk5y)", function()
    -- The sunward gate must not be so tight that the burning crust reads bare: some decals
    -- land beyond the heat-damage boundary (the glowing cracks / warm stone).
    local hot_from = terrain.damage_bounds().hot_from
    local n = 0
    for _, d in ipairs(hot_decals()) do
      if axis.perp(d.position.x, d.position.y) > hot_from then n = n + 1 end
    end
    assert.is_true(n > 0, "rocks/craters reach the lethal hot crust (" .. n .. " decals)")
  end)

  -- 4. CLEAN CENTRE ---------------------------------------------------------------
  it("leaves the temperate terminator band decal-free (clean landing spawn)", function()
    -- |perp| <= safe (x in [-24, 24]) is the safe band: no zone decals at all.
    assert.are.equal(0, count_any(hot_names, -24, 24), "no rock decals on the terminator")
    assert.are.equal(0, count_any(cold_names, -24, 24), "no ice/snow decals on the terminator")
  end)

  -- The decoratives are Cindra-only clones (never the shared vanilla prototype), so
  -- no other planet's worldgen changes (the load-bearing invariant).
  it("registers Cindra-only decorative clones, leaving the vanilla decoratives untouched", function()
    for _, spec in ipairs(field.DECORATIVES) do
      assert.is_not_nil(prototypes.decorative[spec.name], spec.name .. " clone exists")
      -- The vanilla source still exists as its own, separate prototype.
      assert.is_not_nil(prototypes.decorative[spec.clone_from],
        "vanilla source " .. spec.clone_from .. " is untouched (separate prototype)")
      assert.are_not.equal(spec.name, spec.clone_from, "the clone is a distinct prototype")
    end
  end)
end)
