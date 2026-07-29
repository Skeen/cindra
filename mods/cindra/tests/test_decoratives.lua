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
--
-- The pure zone geometry is proven off-game in unit-tests/test_decorative_field.lua;
-- this proves it actually generates. The VISUAL read (do the decals look like ice vs
-- rock, do they sit right on the terrain) is a PLAYTEST.md item -- not testable here.

local field = require("scripts.decorative-field")
local terrain = require("scripts.terrain")

describe("cindra decoratives: zone-appropriate decal scatter (ci-6fq)", function()
  -- A dedicated surface cloned from the Cindra planet's own map_gen_settings at a
  -- FIXED seed, isolated from the shared "cindra" surface. Same pattern as
  -- tests/test_worldgen.lua (decoratives generate with the chunks).
  local s
  local ready = false
  local RY = 300

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
  local function count(name, x1, x2)
    return #s.find_decoratives_filtered({ name = name, area = { { x1, -RY }, { x2, RY } } })
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
  -- lava) zone is x < -24 (west) and the icy zone is x > 24 (east).

  -- 1. ROCKY HOT HALF -------------------------------------------------------------
  it("scatters rock / crater / pebble decals across the hot (rocky/lava) half", function()
    assert.is_true(count_any(hot_names, -128, -25) > 0,
      "rock/crater/pebble decals generate on the hot (west) half")
    -- The specific families the bead calls for are each present.
    assert.is_true(count("cindra-volcanic-rock-small", -128, -25)
      + count("cindra-volcanic-rock-tiny", -128, -25)
      + count("cindra-volcanic-rock-medium", -128, -25) > 0, "volcanic rock / pebble decals present")
    assert.is_true(count("cindra-crater-small", -128, -25)
      + count("cindra-crater-large", -128, -25) > 0, "crater decals present")
  end)

  -- 2. ICY COLD HALF --------------------------------------------------------------
  it("scatters ice + snow decals across the icy (cold) half", function()
    assert.is_true(count_any(cold_names, 25, 128) > 0,
      "ice/snow decals generate on the cold (east) half")
    assert.is_true(count("cindra-ice-decal", 25, 128) > 0, "ice decals present")
    assert.is_true(count("cindra-snowy-decal", 25, 128)
      + count("cindra-snow-drift-decal", 25, 128) > 0, "light-snow decals present")
  end)

  it("DEBUG dump", function()
    local msg = "\n"
    msg = msg .. "EXPR cold[1]=" .. field.probability_expr(field.DECORATIVES[6], { safe_half_width = 24, lethal_at = 96, wall_at = 128 }) .. "\n"
    msg = msg .. "EXPR hot[1]=" .. field.probability_expr(field.DECORATIVES[1], { safe_half_width = 24, lethal_at = 96, wall_at = 128 }) .. "\n"
    local function hist(names, tag)
      for _, nm in ipairs(names) do
        local ds = s.find_decoratives_filtered({ name = nm })
        local minx, maxx, cnt = 1e9, -1e9, 0
        local neg, pos = 0, 0
        for _, d in ipairs(ds) do
          local x = d.position.x
          if x < minx then minx = x end
          if x > maxx then maxx = x end
          if x < 0 then neg = neg + 1 else pos = pos + 1 end
          cnt = cnt + 1
        end
        msg = msg .. tag .. " " .. nm .. " n=" .. cnt .. " x=[" .. minx .. "," .. maxx .. "] neg=" .. neg .. " pos=" .. pos .. "\n"
      end
    end
    hist(cold_names, "cold")
    hist(hot_names, "hot")
    assert.is_true(false, msg)
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
