-- Proof: NO HAND-MINED BOOTSTRAP ROCK IS PLANTED IN GROUND THAT DAMAGES YOU (ci-pxlz).
--
-- What the player does: they spot a rock, walk to it, hold the mine key and wait out its
-- mining time. If the ground it is planted in burns or freezes, that whole trip costs
-- health -- the visible-but-unreachable UX ci-fb9 forbids for the ore fields, and the
-- leak ci-bgpm closed for them. The bootstrap rocks had it too, and worse: the ice-rock
-- band (ci-18n) is clamped POSITIONALLY at the nominal cold-damage boundary with no
-- keep-back at all, while cold-damaging snow bleeds ~20 tiles middle-ward of that
-- boundary because the tile family is picked from the noisy heightmap VALUE. Its comment
-- claimed the rocks were therefore "hand-gatherable with no cold damage". They were not.
--
-- HOW THIS FILE ARGUES IT, and why it cannot pass by restating the code. The bug is in
-- world GENERATION but the harm is a runtime DAMAGE SWEEP, so the proof is a bridge
-- between the two and the sweep itself is the oracle:
--
--   A. Generate a tall fixed-seed strip of the REAL map-gen and collect the ground every
--      bootstrap rock that actually spawned is standing in. No sampling, no allowance
--      around a band edge, no mention of a margin or a tile list.
--   B. Take that ground back to the LIVE Cindra surface, stand a character in it and run
--      the REAL damage sweep (scripts/tile-damage.sweep, the same one the mod runs on
--      nth-tick). Assert the character loses no health -- with a lethal-tile control at
--      the same spot proving the sweep is live, so "no damage" can never mean "no sweep".
--
-- So the assertion is "a character standing where a rock stands takes no damage", not
-- "the prototype carries field X". Widening the allowed tile set, renaming the gate or
-- deleting terrain.tile_damage cannot make it pass; only actually keeping the rocks out
-- of lethal ground can.
--
-- Also asserted, so claim A cannot be satisfied by retreating instead of by fixing:
--   * NO RETREAT -- the ice-rocks must still reach out to within a few tiles of the
--     lethal cold ground, and the scatter must keep its population. A "fix" that hauled
--     the band inland or thinned the cold-side bootstrap fails here.
--   * COVERAGE, enumerated LIVE from the surface -- every Cindra scatter family that
--     generated anywhere across the ribbon is swept, so the next one to ship is covered
--     the day it lands. Exactly one documented exception: the GLOWING volcanic boulders
--     (ci-w87), which belong on burning ground on purpose and are read-the-hazard art
--     rather than a resource you walk out to collect. The exception is itself asserted
--     (they must really be on burning ground), so it cannot rot into a blanket pass.
--
-- MEASURED ON MAIN (seed 24680, 2800 rows): 10 of 579 ice-rocks planted in cold-damaging
-- snow/dust by their own tile, 35 of 579 counting any tile under the berg. Zero after
-- the fix, with the scatter's reach and population unchanged.
--
-- The pure gate (which tiles the restriction names) is unit-tests/test_resource_field;
-- the rotated statement of claim A is tests/test_worldgen_horizontal.

local H = require("tests.helpers")
local field = require("scripts.resource-field")
local terrain = require("scripts.terrain")
local td = require("scripts.tile-damage")

describe("bootstrap rocks are planted in ground you can stand in (ci-pxlz)", function()
  -- Half-width of the ribbon (the whole playable cross-section) and how far along the
  -- long axis we generate. The offending rocks are a small tail of the ice-rock
  -- scatter, so the strip has to be LONG rather than wide: at ICE_ROCK_PROBABILITY over
  -- a ~70-tile band, 2800 rows yields ~580 rocks and tens of offenders on main -- far
  -- past any single-sample fluke.
  local HALF_X = 400
  local FAR_Y = 1400

  local s
  local ready = false

  before_each(function()
    if ready then return end
    local base = H.cindra_surface()
    local mgs = base.map_gen_settings
    -- The seed the bug was measured on, so the counts logged here mean something when
    -- someone re-runs this by hand.
    mgs.seed = 24680
    local fd = terrain.finite_dimension()
    mgs[fd.key] = fd.value
    s = game.surfaces["cindra-rock-ground-test"]
      or game.create_surface("cindra-rock-ground-test", mgs)
    -- Four square requests up and down the long axis: radius 13 chunks = +/-416 tiles,
    -- so together they cover the full ribbon width out to y ~= +/-1664.
    for _, cy in ipairs({ -1248, -416, 416, 1248 }) do
      s.request_to_generate_chunks({ 0, cy }, 13)
    end
    s.force_generate_chunk_requests()
    ready = true
  end)

  local AREA = { { -HALF_X, -FAR_Y }, { HALF_X, FAR_Y } }

  -- Every rock of the named family that actually generated in the strip.
  local function rocks(names)
    local out = {}
    for _, name in ipairs(names) do
      for _, e in ipairs(s.find_entities_filtered({ name = name, area = AREA })) do
        out[#out + 1] = e
      end
    end
    return out
  end

  -- The ground a rock is PLANTED IN: the tile it occupies. That is the ground the player
  -- walks to and works over, and the one thing placement can actually decide -- a big
  -- iceberg's collision box necessarily overlaps its neighbours, so near any band edge
  -- some tile under some berg belongs to the next family along. (The volcanic rocks have
  -- carried the same tile-keyed rule since ci-w87 for the same reason.) The footprint
  -- exposure is measured and logged alongside, so a change that made bergs straddle much
  -- more lethal ground is still visible in the record.
  local function ground_tile(e)
    return s.get_tile(e.position.x, e.position.y).name
  end

  local function ground_damage(e)
    return terrain.tile_damage(ground_tile(e))
  end

  local function offenders(list)
    local bad = {}
    for _, e in ipairs(list) do
      local intensity, kind = ground_damage(e)
      if intensity > 0 then
        bad[#bad + 1] = { e = e, intensity = intensity, kind = kind, tile = ground_tile(e) }
      end
    end
    return bad
  end

  local function describe_bad(bad, cap)
    local parts = {}
    for i = 1, math.min(#bad, cap or 5) do
      local b = bad[i]
      parts[#parts + 1] = string.format("%s at %.1f,%.1f in %s (%s %.2f)",
        b.e.name, b.e.position.x, b.e.position.y, b.tile, tostring(b.kind), b.intensity)
    end
    return table.concat(parts, "; ")
  end

  -- The distinct kinds of ground a family of rocks is planted in, across the whole strip.
  local function grounds_of(list)
    local set, order = {}, {}
    for _, e in ipairs(list) do
      local t = ground_tile(e)
      if not set[t] then set[t] = true; order[#order + 1] = t end
    end
    table.sort(order)
    return order
  end

  local function footprint_exposed(list)
    local n = 0
    for _, e in ipairs(list) do
      if td.footprint_damage(s, e) > 0 then n = n + 1 end
    end
    return n
  end

  -- A. THE GROUND THE ROCKS ARE PLANTED IN -------------------------------------------
  it("no ICE-ROCK is planted in freezing ground (ci-pxlz)", function()
    local list = rocks(field.ice_rock_names())
    assert.is_true(#list > 200,
      "the strip must hold a real ice-rock population to be a proof (" .. #list .. ")")
    local bad = offenders(list)
    log("ci-pxlz ice-rocks scanned: " .. #list .. ", planted in damaging ground: " .. #bad
      .. ", touching any damaging tile: " .. footprint_exposed(list))
    assert.are.equal(0, #bad,
      #bad .. " of " .. #list .. " ice-rocks are planted in ground that damages you: "
        .. describe_bad(bad))
  end)

  it("no SANDY bootstrap rock is planted in burning or freezing ground (ci-pxlz)", function()
    local list = rocks({ field.ROCK })
    assert.is_true(#list > 200,
      "the strip must hold a real sandy-rock population to be a proof (" .. #list .. ")")
    local bad = offenders(list)
    log("ci-pxlz sandy rocks scanned: " .. #list .. ", planted in damaging ground: " .. #bad
      .. ", touching any damaging tile: " .. footprint_exposed(list))
    assert.are.equal(0, #bad,
      #bad .. " of " .. #list .. " sandy rocks are planted in ground that damages you: "
        .. describe_bad(bad))
  end)

  -- B. THE RUNTIME BRIDGE ------------------------------------------------------------
  -- The claim above is about tiles; the HARM is a damage sweep. Close the gap in-engine
  -- rather than by argument: every kind of ground a bootstrap rock was found standing in
  -- gets laid under a character on the LIVE Cindra surface, and the real sweep runs.
  -- This is the assertion that makes the whole file behavioural -- it goes through
  -- scripts/tile-damage end to end, so it cannot pass by restating terrain's tables.
  local SWEEP_Y = 5200
  local SWEEP_DPS = 200

  -- HP a fresh character loses to ONE deterministic sweep while standing in `tile_name`.
  local function hp_lost_standing_in(live, tile_name, cx)
    local tiles = {}
    for x = cx - 3, cx + 3 do
      for y = SWEEP_Y - 3, SWEEP_Y + 3 do
        tiles[#tiles + 1] = { name = tile_name, position = { x, y } }
      end
    end
    live.set_tiles(tiles, true)
    local c = live.create_entity({ name = "character", position = { cx, SWEEP_Y }, force = "player" })
    assert.is_not_nil(c, "character placed in " .. tile_name)
    local before = c.health
    td.sweep(live, 60, SWEEP_DPS)
    local lost = before - c.health
    c.destroy()
    return lost
  end

  it("a character can stand where a bootstrap rock stands and lose no health", function()
    local live = H.cindra_surface()
    storage.cindra_driver_enabled = false
    live.request_to_generate_chunks({ 0, SWEEP_Y }, 4)
    live.force_generate_chunk_requests()
    for _, e in pairs(live.find_entities_filtered({ area = { { -60, SWEEP_Y - 20 }, { 60, SWEEP_Y + 20 } } })) do
      if e.type ~= "character" then e.destroy() end
    end

    local all = rocks(field.ice_rock_names())
    for _, e in ipairs(rocks({ field.ROCK })) do all[#all + 1] = e end
    local grounds = grounds_of(all)
    assert.is_true(#grounds > 2,
      "the rocks must be planted in a real variety of ground (" .. #grounds .. " kinds)")
    log("ci-pxlz ground kinds under the bootstrap rocks: " .. table.concat(grounds, ", "))

    local hurt = {}
    for _, tile_name in ipairs(grounds) do
      local lost = hp_lost_standing_in(live, tile_name, 0)
      if lost > 0 then
        hurt[#hurt + 1] = tile_name .. " (-" .. lost .. " hp)"
      end
    end
    -- CONTROL, at the same spot and through the same sweep: the deep-ice cap really does
    -- freeze a character there. Without this, a broken/disabled sweep would report every
    -- tile as harmless and this test would pass on a completely unfixed mod.
    local control = hp_lost_standing_in(live, "cindra-ice-smooth", 0)
    storage.cindra_driver_enabled = true
    assert.is_true(control > 0,
      "the sweep must actually be live at the test spot (control lost " .. control .. " hp)")
    assert.are.equal(0, #hurt,
      "ground a bootstrap rock stands in that damages a character standing in it: "
        .. table.concat(hurt, ", "))
  end)

  -- C. NO RETREAT --------------------------------------------------------------------
  -- Claim A is trivially satisfiable by deleting the cold scatter or hauling it inland,
  -- and that would be a real regression: the ice-rocks ARE the cold-side bootstrap, and
  -- ci-18n put them out on the icy side on purpose ("they read as on the icy side").
  it("the ice-rocks still reach out onto the icy side, right up to the lethal ground", function()
    local d = terrain.damage_bounds()
    local nearest = math.huge
    for _, e in ipairs(rocks(field.ice_rock_names())) do
      -- Vertical ribbon: perpendicular is -x, sunward-positive; cold is negative, so the
      -- gap is stated as tiles warmward of the real cold-damage boundary and moves with
      -- a retuned ribbon instead of pinning an absolute coordinate.
      local gap = (-e.position.x) - d.cold_from
      if gap < nearest then nearest = gap end
    end
    log("ci-pxlz nearest ice-rock to the cold-damage boundary: " .. nearest .. " tiles")
    -- The tile gate trims a scattered tail; it does not pull the band in. 12 tiles is
    -- generous room for seed noise while still failing any real retreat -- the bleed this
    -- bug is about is ~20 tiles, so a margin-widening "fix" lands well outside it.
    assert.is_true(nearest <= 12,
      "ice-rocks must still reach the icy edge (nearest is " .. nearest
        .. " tiles short of the lethal ground)")
  end)

  it("keeps the cold-side bootstrap trickle worth walking out for", function()
    -- The tile gate removes the small tail that sat in bled snow. That is a trim, not a
    -- cull: the band must still carry essentially its whole population, so a future
    -- change that quietly guts the scatter (or gates it on a far too narrow tile set)
    -- fails here rather than silently starving the cold-side start.
    local n = #rocks(field.ice_rock_names())
    local per_row = n / (2 * FAR_Y)
    log("ci-pxlz ice-rock yield: " .. n .. " rocks over " .. (2 * FAR_Y) .. " rows = "
      .. string.format("%.4f", per_row) .. "/row")
    assert.is_true(per_row > 0.15,
      "the ice-rock scatter stays an ample bootstrap (" .. string.format("%.4f", per_row) .. "/row)")
  end)

  -- D. COVERAGE, ENUMERATED LIVE -----------------------------------------------------
  -- Not a hand-written list of the two families this bead fixed: every Cindra scatter
  -- entity that generated ANYWHERE across the ribbon is swept, so a new one is covered
  -- the day it lands.
  local HAZARD_BY_DESIGN = field.BURNED_ROCK_HOT_SET

  local function cindra_scatter_entities()
    local by_name = {}
    for _, e in ipairs(s.find_entities_filtered({ type = "simple-entity", area = AREA })) do
      if e.name:sub(1, 7) == "cindra-" then
        by_name[e.name] = by_name[e.name] or {}
        local t = by_name[e.name]
        t[#t + 1] = e
      end
    end
    return by_name
  end

  it("EVERY Cindra rock scatter is planted in safe ground, bar the deliberate lava-area one", function()
    local by_name = cindra_scatter_entities()
    local names = {}
    for name in pairs(by_name) do names[#names + 1] = name end
    table.sort(names)
    assert.is_true(#names > 0, "the strip must actually contain Cindra scatter entities")
    log("ci-pxlz scatter families found: " .. table.concat(names, ", "))

    local complaints = {}
    for _, name in ipairs(names) do
      local bad = offenders(by_name[name])
      if HAZARD_BY_DESIGN[name] then
        -- The exception is not a free pass. A glowing boulder that stopped landing on
        -- burning ground would mean the ci-w87 gate had come undone, so state that too.
        assert.is_true(#bad > 0,
          name .. " is exempt because it BELONGS in burning ground -- but none of the "
            .. #by_name[name] .. " that generated is in any")
      elseif #bad > 0 then
        complaints[#complaints + 1] = string.format("%s: %d/%d [%s]",
          name, #bad, #by_name[name], describe_bad(bad, 2))
      end
    end
    assert.are.equal(0, #complaints,
      "scatter entities planted in ground that damages you -- "
        .. table.concat(complaints, " | "))
  end)

  it("the coverage sweep really sees the rocks this bead is about", function()
    -- Guards the guard: if find_entities_filtered ever stopped returning the bootstrap
    -- rocks (a type change, a rename), the sweep above would pass vacuously.
    local by_name = cindra_scatter_entities()
    local expected = { field.ROCK }
    for _, n in ipairs(field.ice_rock_names()) do expected[#expected + 1] = n end
    for _, n in ipairs(field.burned_rock_names()) do expected[#expected + 1] = n end
    for _, name in ipairs(expected) do
      assert.is_truthy(by_name[name], name .. " must be inside the live coverage sweep")
    end
  end)

  -- A negative control for the generation-side measurement: the damage read is not
  -- returning 0 for everything. Somewhere across this strip is ground that DOES hurt.
  it("the generated strip really does contain burning and freezing ground", function()
    local burns, freezes = 0, 0
    for _, x in ipairs({ -260, -150, 150, 260 }) do
      local intensity, kind = terrain.tile_damage(s.get_tile(x, 0).name)
      if intensity > 0 and kind == "heat" then burns = burns + 1 end
      if intensity > 0 and kind == "cold" then freezes = freezes + 1 end
    end
    assert.is_true(burns > 0, "the sunward side of this surface really does burn")
    assert.is_true(freezes > 0, "the nightward side of this surface really does freeze")
  end)
end)
