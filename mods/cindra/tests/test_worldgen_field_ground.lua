-- Proof: a HARVESTABLE FIELD never sits on ground that damages the player, at ANY
-- map-gen slider setting (ci-bgpm, closing the ci-fb9 / ci-4iw leak).
--
-- You mine a stone or ice patch by standing on it, so a patch tile on burning crust or
-- on frozen ground is a resource you cannot harvest without taking damage -- the
-- "visible but unreachable" UX ci-fb9 forbids. Until ci-bgpm that promise rested
-- entirely on a POSITIONAL keep-back (resource-field.FIELD_DAMAGE_MARGIN, 9.5 tiles):
-- the band mask stops short of the nominal damage boundary by the tile-boundary noise
-- amplitudes.
--
-- That budget is far too small, because the tile FAMILY is chosen from the heightmap
-- VALUE, and the per-tile speckle that makes co-present value bands interpenetrate is
-- worth 0.012 in FIELD units -- about six tiles either way on the gentle outer slopes,
-- for each of the two tiles competing at a boundary. Measured on a generated surface
-- (seed 24680, 8192 rows), heat-damaging crust reaches 18 tiles warmward of its nominal
-- boundary and cold-damaging snow 20 tiles middle-ward of its own. At default sliders
-- ore covers so little of the band that nothing happened to land there -- luck, not
-- geometry: crank every Stone slider to 6 and 16 stone tiles generate on
-- cindra-volcanic-cracks-hot.
--
-- The fix is the ci-w87 lesson applied to the fields: WHERE ORE MAY LIE IS DECIDED BY
-- THE TILE, NOT BY THE COORDINATE. Both field resources carry an autoplace
-- `tile_restriction` naming exactly the Cindra tiles that deal no damage, so a bled
-- lethal tile cannot carry ore however far it bled -- and the bands keep their full
-- width, so the richest nodes stay where the design puts them (at the survivable
-- margins).
--
-- These assertions are what a PLAYER experiences: the ground under every ore tile of a
-- freshly generated world, read through the same damage decision the tile-damage sweep
-- makes (terrain.tile_damage), on the world where the leak is worst -- every Stone and
-- Ice slider at maximum.

local field = require("scripts.resource-field")
local terrain = require("scripts.terrain")

describe("cindra worldgen: no field ever lies on damaging ground (ci-bgpm)", function()
  -- The whole perpendicular span both bands can reach (they live inside |perp| <= 130),
  -- over a long run of the ribbon, past the resource fade-in (distance 150..450) so the
  -- patches read at full strength.
  local X1, X2 = -140, 140
  local Y1, Y2 = 520, 2568

  local surfaces = {}
  local ready = false

  local function make(name, controls)
    local base = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    local mgs = base.map_gen_settings
    mgs.seed = 24680
    -- State BOTH axes (ci-65p): a ribbon is bounded on exactly one of them, and a
    -- copied settings table must not inherit a bound on the long axis.
    local bounds = terrain.map_gen_bounds()
    mgs.width, mgs.height = bounds.width, bounds.height
    mgs.autoplace_controls = mgs.autoplace_controls or {}
    for control, v in pairs(controls) do
      local c = mgs.autoplace_controls[control] or {}
      c.frequency, c.size, c.richness = v.frequency or 1, v.size or 1, v.richness or 1
      mgs.autoplace_controls[control] = c
    end
    local s = game.surfaces[name] or game.create_surface(name, mgs)
    for cx = math.floor(X1 / 32), math.floor(X2 / 32) do
      for cy = math.floor(Y1 / 32), math.floor(Y2 / 32) do
        s.request_to_generate_chunks({ cx * 32 + 16, cy * 32 + 16 }, 0)
      end
    end
    s.force_generate_chunk_requests()
    return s
  end

  before_each(function()
    if ready then return end
    -- Every Stone and Ice slider at maximum: the most ore the map-gen screen can put in
    -- the ground, so the band edges are covered instead of sampled.
    surfaces.extreme = make("cindra-field-ground-extreme", {
      [field.STONE] = { frequency = 6, size = 6, richness = 6 },
      [field.ICE] = { frequency = 6, size = 6, richness = 6 },
    })
    ready = true
  end)

  -- The ground under every ore tile, read through the real damage decision.
  local function on_damaging_ground(s, resource)
    local ents = s.find_entities_filtered({ name = resource, area = { { X1, Y1 }, { X2, Y2 } } })
    local bad, worst = 0, nil
    for _, e in ipairs(ents) do
      local t = s.get_tile(e.position.x, e.position.y).name
      if terrain.tile_damage(t) > 0 then
        bad = bad + 1
        worst = t
      end
    end
    return #ents, bad, worst
  end

  it("puts NO stone and NO ice patch tile on damaging ground, every slider at 6", function()
    -- Measure BOTH resources before asserting either, so a failure names the whole
    -- picture (a leak on one side is rarely alone).
    local measured = {}
    for _, r in ipairs({ field.STONE, field.ICE }) do
      local n, bad, worst = on_damaging_ground(surfaces.extreme, r)
      measured[#measured + 1] = { resource = r, n = n, bad = bad, worst = worst }
    end
    for _, m in ipairs(measured) do
      -- The maxed-out world really is saturated with ore, so this is a dense sample of
      -- the whole band including its lethal-side edge (not a lucky sparse one).
      assert.is_true(m.n > 500,
        m.resource .. ": the maxed-out world has real ore to check (" .. m.n .. ")")
      assert.are.equal(0, m.bad,
        m.resource .. ": " .. m.bad .. " of " .. m.n .. " patch tiles sit on ground that" ..
        " damages you (e.g. " .. tostring(m.worst) .. "); you cannot mine a patch you" ..
        " cannot stand on")
    end
  end)

  -- ...and the bands are still WIDE: the guarantee above must come from the tile the ore
  -- lies on, not from retreating out of the survivable margin the design rewards
  -- (§1 edge-pushing: the best nodes sit as close to lethal as you dare go).
  it("still reaches the survivable margins with the richest ore (no retreat inland)", function()
    local d = terrain.damage_bounds()
    -- Each band's own lethal boundary, as a DEPTH (tiles from the terminator toward that
    -- side's death zone): stone runs sunward to the heat belt, ice nightward to the cold.
    local lethal = { [field.STONE] = d.hot_from, [field.ICE] = -d.cold_from }
    for _, r in ipairs({ field.STONE, field.ICE }) do
      local deepest = 0
      for _, e in ipairs(surfaces.extreme.find_entities_filtered({
        name = r, area = { { X1, Y1 }, { X2, Y2 } },
      })) do
        -- perp = -x (vertical orientation); stone lives at positive perp, ice at negative.
        local depth = (r == field.STONE) and -e.position.x or e.position.x
        if depth > deepest then deepest = depth end
      end
      -- The richest ore must still be found deep in the outer slope, within 15 tiles of
      -- the lethal ground itself -- the reward for pushing out. A fix that instead pulled
      -- the whole band inland (a keep-back wide enough to out-budget the ~20-tile tile
      -- bleed would need ~24 tiles) fails here even with zero ore on lethal ground.
      assert.is_true(deepest > lethal[r] - 15,
        r .. ": the band must still reach the survivable margin; deepest ore " ..
        deepest .. " tiles out, of a lethal boundary at " .. lethal[r])
    end
  end)

  -- COVERAGE GUARD: enumerate the Cindra field resources LIVE, so a new one cannot ship
  -- without the restriction that keeps its ore off lethal ground.
  it("restricts EVERY Cindra field resource to ground that deals no damage", function()
    local safe = {}
    for _, n in ipairs(terrain.tiles_by_damage(nil)) do safe[n] = true end
    local checked = 0
    for name, proto in pairs(prototypes.entity) do
      if proto.type == "resource" and name:find("^cindra%-") then
        checked = checked + 1
        local ap = proto.autoplace_specification
        assert.is_not_nil(ap, name .. " must be placed by autoplace")
        local restriction = ap.tile_restriction
        assert.is_not_nil(restriction,
          name .. " has no tile_restriction: a noise-bled lethal tile could carry its ore")
        assert.is_true(#restriction > 0, name .. ": empty tile_restriction would place nothing")
        for _, entry in ipairs(restriction) do
          -- A restriction entry is a tile name (or a first/second transition pair).
          local tile = entry.first or entry
          assert.is_true(safe[tile] == true,
            name .. " may generate on " .. tostring(tile) .. ", which damages you")
        end
        -- ...and it must allow ALL the safe ground, or the fix would have quietly
        -- shrunk the band instead of excluding the lethal tiles.
        local allowed = {}
        for _, entry in ipairs(restriction) do allowed[entry.first or entry] = true end
        for tile in pairs(safe) do
          assert.is_true(allowed[tile] == true,
            name .. " is barred from safe ground " .. tile .. " (the band would shrink)")
        end
      end
    end
    assert.is_true(checked >= 2, "found the Cindra field resources (got " .. checked .. ")")
  end)
end)
