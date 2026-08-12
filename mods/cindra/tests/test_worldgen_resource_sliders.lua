-- Proof: Cindra's STONE and ICE map-gen sliders actually DO something (ci-y19).
--
-- prototypes/resources.lua puts two resource autoplace-controls on the new-game
-- map-gen screen, each with a Frequency / Size / Richness slider. Until this suite
-- the only assertion was that the two controls EXIST and are category="resource"
-- (tests/test_worldgen.lua) -- which a pair of controls wired to nothing would also
-- satisfy. So this measures the WORLD a player would land on: surfaces generated
-- from the real planet's map-gen settings at a FIXED seed with one slider moved,
-- and the ore actually in the ground counted patch by patch.
--
-- What each slider means to the player, and how it is measured here:
--   RICHNESS -- more ore in the SAME patches. Asserted as an exact footprint
--     identity: every ore tile of the default world is an ore tile of the rich
--     world, none added, none lost, and each one holds ~4x as much at Richness 4.
--   SIZE -- FATTER patches. Same number of patches, each covering more ground and
--     holding more ore.
--   FREQUENCY -- MORE patches, found by clustering the ore tiles.
--   OFF (Size 0) -- the resource is gone from the map entirely, and the OTHER
--     resource is left bit-identical (one slider never moves the other ore).
--   ANY setting -- the band geometry still holds: cranking every slider to 6 can
--     never push stone onto the cold side or ice onto the hot ribbon (the ci-fb9
--     band invariant has to survive the map-gen screen, not just the default world),
--     and no field sits on ground that damages you at EITHER setting (ci-4iw/ci-bgpm,
--     re-measured at this suite's own seed).
--
-- Measured in the strip y in [520, 2568]: regular resource patches fade in from
-- distance 150 to 450 (core resource-autoplace), so a window that starts past 450
-- reads patches at full strength instead of the fade-in ramp. The perpendicular
-- window x in [-128, 132] spans both bands (stone (-120.5, 60], ice (60, 120.5)).
-- Vertical orientation, like the rest of test_worldgen*.
--
-- ONE KNOWN GAP, a bug this suite found and does not assert here, because the fix moves
-- the DEFAULT world (a balance call, not a test change):
--   ci-l3k3 -- raising ICE Frequency above 0.5 is a no-op in the engine: ice asks for
--     40 spots/km2, past the 21-candidate spot budget per 1024x1024 region, so it is
--     saturated at the default setting already. Ice Frequency is therefore asserted
--     DOWNWARD here, where it demonstrably works.
--
-- The suite's OTHER find, ci-bgpm (at maxed sliders 16 stone tiles landed on
-- heat-damaging crust, because FIELD_DAMAGE_MARGIN budgeted 9.5 tiles of tile bleed
-- against a real ~20), is FIXED: the two field resources now carry an autoplace
-- tile_restriction to the damage-free tiles, so the ground the ore lies on decides
-- instead of the coordinate, and the bands kept their full width. The ci-4iw check below
-- therefore runs on the maxed-out world too; tests/test_worldgen_field_ground.lua is that
-- invariant's own home (with the band-reach and per-prototype coverage guards).

local field = require("scripts.resource-field")
local terrain = require("scripts.terrain")

describe("cindra worldgen: the Stone/Ice map-gen sliders really move the ore (ci-y19)", function()
  -- The measured window (see header): both resource bands, past the patch fade-in.
  local X1, X2 = -128, 132
  local Y1, Y2 = 520, 2568
  -- The purity window on the extreme surface: the same run of the ribbon, but the
  -- WHOLE width, so an escaped patch has somewhere to be caught escaping TO.
  local PX1, PX2 = -400, 400
  local PY1, PY2 = 520, 2568

  local surfaces = {}
  local ready = false

  local function base_settings()
    local base = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    local mgs = base.map_gen_settings
    mgs.seed = 24680
    -- State BOTH axes (ci-65p/ci-i4z): a ribbon is bounded on exactly one of them and
    -- a copied settings table must not inherit a bound on the long axis.
    local bounds = terrain.map_gen_bounds()
    mgs.width, mgs.height = bounds.width, bounds.height
    return mgs
  end

  -- A surface generated with `controls` applied, exactly as the map-gen screen would
  -- hand them over: control name -> { frequency =, size =, richness = }, each
  -- defaulting to 1 so a test only states the slider it moves.
  local function make(name, controls, area)
    local mgs = base_settings()
    mgs.autoplace_controls = mgs.autoplace_controls or {}
    for control, v in pairs(controls) do
      local c = mgs.autoplace_controls[control] or {}
      c.frequency = v.frequency or 1
      c.size = v.size or 1
      c.richness = v.richness or 1
      mgs.autoplace_controls[control] = c
    end
    local s = game.surfaces[name] or game.create_surface(name, mgs)
    -- Generate exactly the measured rectangle (chunk by chunk): a disc big enough to
    -- reach y=2568 would be ~40x the chunks for the same measurement.
    for cx = math.floor(area[1] / 32), math.floor(area[2] / 32) do
      for cy = math.floor(area[3] / 32), math.floor(area[4] / 32) do
        s.request_to_generate_chunks({ cx * 32 + 16, cy * 32 + 16 }, 0)
      end
    end
    s.force_generate_chunk_requests()
    return s
  end

  -- What the player can see about one resource in one window: how much ground it
  -- covers, how much ore is in it, and how many SEPARATE patches there are.
  --
  -- Patches are recovered by flood-filling the ore tiles (Chebyshev <= 3, so the
  -- ragged blob edge of one spot stays one patch while genuinely separate spots --
  -- the placement keeps candidate centres ~45 tiles apart -- stay separate).
  local function measure(s, resource, area)
    local ents = s.find_entities_filtered({ name = resource, area = area or { { X1, Y1 }, { X2, Y2 } } })
    local amount, at, list = 0, {}, {}
    for _, e in ipairs(ents) do
      local x, y = math.floor(e.position.x), math.floor(e.position.y)
      amount = amount + e.amount
      at[x .. ":" .. y] = e.amount
      list[#list + 1] = { x = x, y = y }
    end
    local seen, patches, biggest = {}, 0, 0
    for _, p in ipairs(list) do
      if not seen[p.x .. ":" .. p.y] then
        patches = patches + 1
        seen[p.x .. ":" .. p.y] = true
        local n, stack = 0, { p }
        while #stack > 0 do
          local q = table.remove(stack)
          n = n + 1
          for dx = -3, 3 do
            for dy = -3, 3 do
              local k = (q.x + dx) .. ":" .. (q.y + dy)
              if at[k] and not seen[k] then
                seen[k] = true
                stack[#stack + 1] = { x = q.x + dx, y = q.y + dy }
              end
            end
          end
        end
        if n > biggest then biggest = n end
      end
    end
    return {
      tiles = #ents,                                              -- ground covered by ore
      amount = amount,                                            -- ore in the ground
      patches = patches,                                          -- separate deposits
      biggest = biggest,                                          -- tiles in the fattest one
      per_patch = patches > 0 and (#ents / patches) or 0,          -- mean deposit footprint
      at = at,                                                    -- ore amount by tile
    }
  end

  local STONE, ICE = field.STONE, field.ICE

  before_each(function()
    if ready then return end
    local strip = { X1, X2, Y1, Y2 }
    surfaces.base = make("cindra-res-base", {}, strip)
    surfaces.freq_up = make("cindra-res-freq-up", {
      [STONE] = { frequency = 4 }, [ICE] = { frequency = 4 },
    }, strip)
    surfaces.freq_down = make("cindra-res-freq-down", {
      [STONE] = { frequency = 0.25 }, [ICE] = { frequency = 0.25 },
    }, strip)
    surfaces.size_up = make("cindra-res-size-up", {
      [STONE] = { size = 4 }, [ICE] = { size = 4 },
    }, strip)
    surfaces.rich_up = make("cindra-res-rich-up", {
      [STONE] = { richness = 4 }, [ICE] = { richness = 4 },
    }, strip)
    surfaces.stone_off = make("cindra-res-stone-off", { [STONE] = { size = 0 } }, strip)
    surfaces.ice_off = make("cindra-res-ice-off", { [ICE] = { size = 0 } }, strip)
    -- Every slider at maximum, generated across the WHOLE ribbon width for the
    -- band-purity checks.
    surfaces.extreme = make("cindra-res-extreme", {
      [STONE] = { frequency = 6, size = 6, richness = 6 },
      [ICE] = { frequency = 6, size = 6, richness = 6 },
    }, { PX1, PX2, PY1, PY2 })
    ready = true
  end)

  -- THE REFERENCE WORLD ------------------------------------------------------------
  -- Everything below is a comparison against this, so it has to be a real sample:
  -- several separate patches of each resource, with ore in them.
  it("puts real stone AND ice patches in the ground at default sliders", function()
    for _, r in ipairs({ STONE, ICE }) do
      local m = measure(surfaces.base, r)
      assert.is_true(m.patches >= 2,
        r .. ": the default world has several separate patches here; got " .. m.patches)
      assert.is_true(m.tiles > 100, r .. ": covering real ground; got " .. m.tiles .. " tiles")
      assert.is_true(m.amount > 100000, r .. ": with real ore in them; got " .. m.amount)
    end
  end)

  -- RICHNESS: MORE ORE, SAME GROUND -------------------------------------------------
  it("Richness 4 puts ~4x the ore in the SAME patches (same ground, no new patches)", function()
    for _, r in ipairs({ STONE, ICE }) do
      local base, rich = measure(surfaces.base, r), measure(surfaces.rich_up, r)
      -- The footprint is IDENTICAL, tile for tile: richness may not move an ore tile.
      assert.are.equal(base.tiles, rich.tiles, r .. ": the same ground carries ore")
      assert.are.equal(base.patches, rich.patches, r .. ": and the same number of patches")
      local missing, added = 0, 0
      local lo, hi = 99, 0
      for k, v in pairs(base.at) do
        if rich.at[k] then
          local ratio = rich.at[k] / v
          lo, hi = math.min(lo, ratio), math.max(hi, ratio)
        else
          missing = missing + 1
        end
      end
      for k in pairs(rich.at) do if not base.at[k] then added = added + 1 end end
      assert.are.equal(0, missing, r .. ": no ore tile of the default world vanished")
      assert.are.equal(0, added, r .. ": and Richness added no new ore tile")
      -- Every single tile holds 4x as much (integer rounding is the only slack).
      assert.is_true(lo >= 3.9 and hi <= 4.2,
        r .. ": every patch tile holds ~4x the ore; per-tile ratio was [" .. lo .. ", " .. hi .. "]")
      assert.is_true(rich.amount / base.amount >= 3.9,
        r .. ": so the window holds ~4x the ore overall; " .. base.amount .. " -> " .. rich.amount)
    end
  end)

  -- SIZE: FATTER PATCHES ------------------------------------------------------------
  it("Size 4 grows the patches themselves (more ground each, not more of them)", function()
    for _, r in ipairs({ STONE, ICE }) do
      local base, big = measure(surfaces.base, r), measure(surfaces.size_up, r)
      assert.is_true(big.tiles > base.tiles * 1.8,
        r .. ": the patches cover much more ground; " .. base.tiles .. " -> " .. big.tiles .. " tiles")
      assert.is_true(big.per_patch > base.per_patch * 1.5,
        r .. ": each individual patch is fatter; " .. base.per_patch .. " -> " .. big.per_patch .. " tiles/patch")
      assert.is_true(big.biggest > base.biggest * 1.5,
        r .. ": including the biggest one; " .. base.biggest .. " -> " .. big.biggest)
      assert.is_true(big.amount > base.amount * 2.5,
        r .. ": and hold much more ore; " .. base.amount .. " -> " .. big.amount)
      -- Size is not a disguised Frequency: it fattens the deposits, it does not
      -- scatter new ones (one extra is allowed for a fattened patch that grows into
      -- the window edge as a separate blob).
      assert.is_true(big.patches <= base.patches + 1,
        r .. ": Size does not scatter new patches; " .. base.patches .. " -> " .. big.patches)
    end
  end)

  -- FREQUENCY: MORE PATCHES ---------------------------------------------------------
  it("Stone Frequency 4 scatters MORE separate stone patches (and more ore with them)", function()
    local base, up = measure(surfaces.base, STONE), measure(surfaces.freq_up, STONE)
    assert.is_true(up.patches >= base.patches * 2,
      "at least twice as many separate stone patches; " .. base.patches .. " -> " .. up.patches)
    assert.is_true(up.amount > base.amount * 2,
      "with the ore to match; " .. base.amount .. " -> " .. up.amount)
    -- The patches are not merely swollen: the extra ore arrives as extra deposits,
    -- so the mean deposit stays in the same ballpark rather than scaling with the ore.
    assert.is_true(up.per_patch < base.per_patch * 2.5,
      "the individual patches are not what grew; " .. base.per_patch .. " -> " .. up.per_patch)
  end)

  it("Frequency 0.25 leaves FEWER patches of BOTH resources (a sparser world)", function()
    for _, r in ipairs({ STONE, ICE }) do
      local base, down = measure(surfaces.base, r), measure(surfaces.freq_down, r)
      assert.is_true(down.patches < base.patches,
        r .. ": fewer separate patches to find; " .. base.patches .. " -> " .. down.patches)
      assert.is_true(down.tiles < base.tiles,
        r .. ": covering less ground; " .. base.tiles .. " -> " .. down.tiles .. " tiles")
    end
  end)

  -- OFF: THE RESOURCE IS GONE, THE OTHER ONE IS UNTOUCHED ---------------------------
  it("switching a resource OFF (Size 0) removes it from the map and leaves the other one alone", function()
    local cases = {
      { off = STONE, kept = ICE, surface = surfaces.stone_off },
      { off = ICE, kept = STONE, surface = surfaces.ice_off },
    }
    for _, c in ipairs(cases) do
      local gone = measure(c.surface, c.off)
      assert.are.equal(0, gone.tiles, c.off .. " is switched off: not one patch tile generates")
      assert.are.equal(0, gone.amount, c.off .. " is switched off: no ore at all")
      -- ...and the other resource is bit-identical to the default world: a slider
      -- belongs to ONE resource.
      local base, kept = measure(surfaces.base, c.kept), measure(c.surface, c.kept)
      assert.are.equal(base.tiles, kept.tiles, c.kept .. " is untouched by the " .. c.off .. " slider (ground)")
      assert.are.equal(base.amount, kept.amount, c.kept .. " is untouched by the " .. c.off .. " slider (ore)")
      assert.are.equal(base.patches, kept.patches, c.kept .. " is untouched by the " .. c.off .. " slider (patches)")
    end
  end)

  -- NO SETTING BREAKS THE BANDS ----------------------------------------------------
  -- The ore that appears when a player cranks the sliders still has to appear where
  -- the design says ore may be. Measured across the WHOLE ribbon width, so a patch
  -- that escaped its band has somewhere to be caught.
  it("no slider setting can push a field out of its band (Frequency/Size/Richness 6)", function()
    local s = surfaces.extreme
    local window = { { PX1, PY1 }, { PX2, PY2 } }
    local stone = s.find_entities_filtered({ name = STONE, area = window })
    local ice = s.find_entities_filtered({ name = ICE, area = window })
    assert.is_true(#stone > 1000, "the maxed-out world really does have stone to check (" .. #stone .. ")")
    assert.is_true(#ice > 100, "the maxed-out world really does have ice to check (" .. #ice .. ")")

    -- The bands: stone on the middle + safe hot margin (x in (-120.5, 60]), ice on the
    -- safe cold margin (x in (60, 120.5)). One tile of slack for the blob edge.
    local cold_side, hot_side = 0, 0
    for _, e in ipairs(stone) do
      if e.position.x > 61 or e.position.x < -121 then cold_side = cold_side + 1 end
    end
    for _, e in ipairs(ice) do
      if e.position.x < 59 or e.position.x > 121 then hot_side = hot_side + 1 end
    end
    assert.are.equal(0, cold_side, "no stone reaches the cold side or the heat zone")
    assert.are.equal(0, hot_side, "no ice reaches the hot/temperate ribbon or the cold zone")
  end)

  -- ...and nothing minable sits on ground that damages the player standing on it: a
  -- field you cannot survive reaching is not a field (ci-fb9 / ci-4iw). Read through
  -- the real damage decision (terrain.tile_damage, the tile the sweep damages from),
  -- not a hand-listed tile set.
  --
  -- Checked at BOTH settings since ci-bgpm. The default world only ever passed this by
  -- luck (ore covers so little of the band that nothing happened to land on a bled lethal
  -- tile); the maxed-out world found 16 stone tiles of 17681 on cindra-volcanic-cracks-hot,
  -- because the tile family comes from the noisy heightmap VALUE and hot crust reaches ~20
  -- tiles warmward of the nominal boundary while FIELD_DAMAGE_MARGIN budgeted 9.5. The
  -- fields carry a tile_restriction to the damage-free tiles now, so the ground decides
  -- and the count is zero however much ore the sliders pour into the band.
  it("keeps every field off damaging ground, at default AND maxed sliders (ci-4iw/ci-bgpm)", function()
    local cases = {
      { label = "default sliders", surface = surfaces.base, window = { { X1, Y1 }, { X2, Y2 } }, min = 100 },
      { label = "every slider at 6", surface = surfaces.extreme, window = { { PX1, PY1 }, { PX2, PY2 } }, min = 500 },
    }
    for _, c in ipairs(cases) do
      for _, r in ipairs({ STONE, ICE }) do
        local ents = c.surface.find_entities_filtered({ name = r, area = c.window })
        assert.is_true(#ents > c.min,
          r .. " (" .. c.label .. "): sampled real fields (" .. #ents .. ")")
        local hurts, worst = 0, nil
        for _, e in ipairs(ents) do
          local t = c.surface.get_tile(e.position.x, e.position.y).name
          if terrain.tile_damage(t) > 0 then
            hurts = hurts + 1
            worst = t
          end
        end
        assert.are.equal(0, hurts,
          r .. " (" .. c.label .. "): no field tile sits on ground that damages you ("
          .. hurts .. " of " .. #ents .. " found, e.g. " .. tostring(worst) .. ")")
      end
    end
  end)

  -- THE SLIDERS ARE THE ONES THE PLAYER SEES ---------------------------------------
  it("offers all three axes on the map-gen screen, and lets a player switch the ore off", function()
    for _, n in ipairs({ STONE, ICE }) do
      local ctrl = prototypes.autoplace_control[n]
      assert.is_not_nil(ctrl, n .. " autoplace-control exists")
      assert.are.equal("resource", ctrl.category, n .. " is a resource slider")
      -- richness = true is what puts the RICHNESS slider on the screen next to
      -- Frequency and Size; the effect of all three is measured above.
      assert.is_true(ctrl.richness, n .. " shows a Richness slider, not just Frequency/Size")
      assert.is_true(ctrl.can_be_disabled, n .. " can be switched off (measured above)")
    end
  end)
end)
