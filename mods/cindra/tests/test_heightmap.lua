-- ci-oe83 MERGE GATE: the ribbon is ONE continuous heightmap, oceans EMERGE from it, and
-- the environmental damage is confined to two contiguous EDGE BELTS -- no non-damaging
-- corridor to either ocean, and a safe middle that spans the whole long axis (no
-- player-trapping enclosure).
--
-- These are the guard tests that kept being skipped. They generate ACTUAL map surfaces on
-- several seeds and inspect real behaviour:
--   * the ocean-solidity + emergence guards count real tiles on multiple fixed seeds;
--   * the corridor + enclosure guards drive the REAL runtime damage sweep
--     (scripts/tile-damage.lua) on the live "cindra" surface as a model-agnostic oracle,
--     so they reproduce the live bug on the old per-tile model (which leaves undamaged
--     tiles standing in the belt) and only pass once the damage follows the field;
--   * the golden-profile + clamp + continuity guards prove the generator POSITIVELY
--     produces the specified structure (and, since the field is seed-independent, prove
--     the belt is unbypassable on EVERY seed, not just the sampled ones).
--
-- Vertical orientation (default): ribbon long axis = Y; hot-cold gradient = X, hot on the
-- LEFT / west, so perp = -x.

local terrain = require("scripts.terrain")
local td = require("scripts.tile-damage")
local axis = require("scripts.axis")

describe("ci-oe83: one heightmap, emergent oceans, belt-confined damage", function()
  local RY = 300
  local seeded = {}

  -- A fresh fixed-seed Cindra worldgen surface for TILE-COUNT inspection (the runtime
  -- sweep is gated to the "cindra" surface, so these are only used for tile counts).
  local function gen(seed)
    if seeded[seed] then return seeded[seed] end
    local base = game.surfaces["cindra"]
      or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    local mgs = base.map_gen_settings
    mgs.seed = seed
    local fd = terrain.finite_dimension()
    mgs[fd.key] = fd.value
    local name = "cindra-hm-" .. seed
    local s = game.surfaces[name] or game.create_surface(name, mgs)
    s.request_to_generate_chunks({ 0, 0 }, 15)
    s.force_generate_chunk_requests()
    seeded[seed] = s
    return s
  end

  -- The LIVE "cindra" surface (real worldgen, the name the runtime sweep acts on). Work far
  -- from other suites' paved spawn area so the tiles are untouched worldgen.
  local WY = 1500
  local live_ready = false
  local function live()
    local s = game.surfaces["cindra"] or (game.planets["cindra"] and game.planets["cindra"].create_surface())
    if not live_ready then
      s.request_to_generate_chunks({ 0, WY }, 14) -- covers x in [-400,400], y around WY
      s.force_generate_chunk_requests()
      live_ready = true
    end
    return s
  end

  local LAVA = { ["cindra-lava-hot"] = true, ["cindra-lava"] = true }
  local ICE = { ["cindra-ice-smooth"] = true }
  local function perp_of(x) return axis.perp(x, 0) end

  -- === POSITIVE PROOF: the golden profile ===================================
  it("GOLDEN PROFILE: field is pinned at the edges + clamped through the middle", function()
    local _, total = terrain.bands()
    local half = total / 2
    assert.are.equal(1.0, terrain.field(half), "sunward edge pinned to the lava extreme")
    assert.are.equal(0.0, terrain.field(-half), "nightward edge pinned to the ice extreme")
    local mid = terrain.role_band("middle")
    for p = mid.lo, mid.hi do
      local h = terrain.field(p)
      assert.is_true(h < terrain.HOT_DMG and h > terrain.COLD_DMG,
        "middle field at p=" .. p .. " is clamped strictly between the thresholds (" .. h .. ")")
    end
  end)

  it("GOLDEN PROFILE: tile + damage both derive from the field value at every sample", function()
    local s = gen(2468)
    for x = -395, 395, 5 do
      local p = perp_of(x)
      local _, kind = terrain.field_damage(p)
      local tile = s.get_tile(x, 0).name
      if p >= 190 then
        assert.is_true(LAVA[tile] == true, "deep sunward (p=" .. p .. ") is a lava ocean tile, got " .. tile)
        assert.are.equal("heat", kind, "and the field says heat there")
      elseif p <= -190 then
        assert.is_true(ICE[tile] == true, "deep nightward (p=" .. p .. ") is an ice ocean tile, got " .. tile)
        assert.are.equal("cold", kind, "and the field says cold there")
      elseif p > -110 and p < 110 then
        assert.is_true(not LAVA[tile] and not ICE[tile], "the middle (p=" .. p .. ") never paints an ocean tile, got " .. tile)
        assert.is_nil(kind, "and the field is safe in the middle")
      end
    end
  end)

  -- === EMERGENCE ============================================================
  it("EMERGENCE: both oceans generate SOLID at the edges (field-pinned, not stamped)", function()
    for _, seed in ipairs({ 2468, 111, 99999 }) do
      local s = gen(seed)
      local function gaps(core, x1, x2)
        local g = 0
        for _, name in ipairs(terrain.tile_names()) do
          if name ~= core then g = g + s.count_tiles_filtered({ name = name, area = { { x1, -RY }, { x2, RY } } }) end
        end
        return g
      end
      assert.are.equal(0, gaps("cindra-lava-hot", -396, -204), "seed " .. seed .. ": the lava ocean is a solid sea")
      assert.are.equal(0, gaps("cindra-ice-smooth", 204, 396), "seed " .. seed .. ": the ice ocean is a solid sea")
      assert.is_true(s.count_tiles_filtered({ name = "cindra-lava-hot", area = { { -396, -RY }, { -204, RY } } }) > 1000,
        "large contiguous lava ocean")
      assert.is_true(s.count_tiles_filtered({ name = "cindra-ice-smooth", area = { { 204, -RY }, { 396, RY } } }) > 1000,
        "large contiguous ice ocean")
    end
  end)

  -- === CONTINUITY ===========================================================
  it("CONTINUITY: the field is smooth across the ocean edge -- no stamped cut-off", function()
    for _, edge in ipairs({ 200, -200 }) do
      local prev = terrain.field(edge - 40)
      for p = edge - 39, edge + 40 do
        local h = terrain.field(p)
        assert.is_true(math.abs(h - prev) < 0.01, "no discontinuous field step at p=" .. p)
        prev = h
      end
    end
  end)

  -- === THE REPRO: no undamaged (non-damaging) cell stands in either belt =====
  -- Drive the REAL sweep on the LIVE "cindra" surface: place a lattice of characters across
  -- the full width, sweep once, and read which kept full HP. On the old per-tile model the
  -- belt is a noisy MIX with non-damaging tiles, so undamaged cells stand deep in the belt
  -- (the walk-to-ocean corridor's building blocks); the field/belt model damages EVERY
  -- standable belt position, so there are none.
  local STEP = 3

  -- Classify a lattice on `s` into "safe"/"damage"/"ocean"/"blocked" via one real sweep.
  local function classify(s, x0, x1, y0, y1)
    for _, e in pairs(s.find_entities_filtered({ area = { { x0 - 2, y0 - 2 }, { x1 + 2, y1 + 2 } }, type = "character" })) do
      e.destroy()
    end
    local cells = {}
    local key = function(x, y) return x .. "," .. y end
    for x = x0, x1, STEP do
      for y = y0, y1, STEP do
        local tile = s.get_tile(x, y).name
        local ch = (not LAVA[tile]) and s.create_entity({ name = "character", position = { x, y }, force = "player" }) or nil
        -- Reject a snapped placement (near an obstacle Factorio may shift it): treat as blocked.
        if ch and (math.abs(ch.position.x - x) > 0.6 or math.abs(ch.position.y - y) > 0.6) then
          ch.destroy(); ch = nil
        end
        cells[key(x, y)] = { x = x, y = y, tile = tile, ch = ch, hp = ch and ch.health or nil }
      end
    end
    td.sweep(s, 60, 400)
    for _, c in pairs(cells) do
      if c.ch and c.ch.valid then
        c.state = (c.ch.health < c.hp) and "damage" or "safe"
        c.ch.destroy()
      elseif c.ch then
        c.state = "damage" -- killed outright
      else
        c.state = LAVA[c.tile] and "ocean" or "blocked"
      end
    end
    return cells, key
  end

  it("REPRO: NO undamaged cell stands in either damage belt (no walk-to-ocean corridor)", function()
    local s = live()
    local cells = classify(s, -190, 190, WY - 45, WY + 45)
    local hot_leak, cold_leak, hot_eg, cold_eg = 0, 0, nil, nil
    for _, c in pairs(cells) do
      if c.state == "safe" then
        local p = perp_of(c.x)
        if p >= 132 then hot_leak = hot_leak + 1; hot_eg = hot_eg or (c.x .. "," .. c.y .. " " .. c.tile) end
        if p <= -132 then cold_leak = cold_leak + 1; cold_eg = cold_eg or (c.x .. "," .. c.y .. " " .. c.tile) end
      end
    end
    assert.are.equal(0, hot_leak, "an undamaged cell stands in the HOT belt (corridor): " .. tostring(hot_eg))
    assert.are.equal(0, cold_leak, "an undamaged cell stands in the COLD belt (corridor): " .. tostring(cold_eg))
  end)

  it("REPRO: the safe middle really IS safe (the sweep leaves every middle cell alone)", function()
    -- Complements the belt guard: prove the safe classification is not vacuous -- the middle
    -- band (|perp| <= 120) takes ZERO damage, so a real traversable corridor exists.
    local s = live()
    local cells = classify(s, -120, 120, WY - 30, WY + 30)
    local safe_mid = 0
    for _, c in pairs(cells) do
      if math.abs(perp_of(c.x)) <= 120 then
        assert.are_not.equal("damage", c.state, "the safe middle at (" .. c.x .. "," .. c.y .. ") must not be damaged")
        if c.state == "safe" then safe_mid = safe_mid + 1 end
      end
    end
    assert.is_true(safe_mid > 100, "the middle has a large connected safe region (" .. safe_mid .. " cells)")
  end)

  -- === NO ENCLOSURE + a continuous safe corridor down the long axis =========
  it("NO ENCLOSURE: the safe middle is ONE region spanning the full long axis, reaching both edges", function()
    -- Flood the SAFE cells from spawn across the full width at several Y bands; the reached
    -- region must touch BOTH middle edges and span multiple Y rows -- one open, traversable
    -- corridor, no ring of damage boxing the player in.
    local s = live()
    local cells, key = classify(s, -126, 126, WY - 60, WY + 60)
    local reached, stack = {}, {}
    local seed_key = key(0, WY)
    if cells[seed_key] and cells[seed_key].state == "safe" then reached[seed_key] = true; stack[1] = seed_key end
    while #stack > 0 do
      local c = cells[table.remove(stack)]
      for _, d in ipairs({ { STEP, 0 }, { -STEP, 0 }, { 0, STEP }, { 0, -STEP } }) do
        local nk = key(c.x + d[1], c.y + d[2])
        local n = cells[nk]
        if n and n.state == "safe" and not reached[nk] then reached[nk] = true; stack[#stack + 1] = nk end
      end
    end
    local min_x, max_x, min_y, max_y = 1e9, -1e9, 1e9, -1e9
    for k in pairs(reached) do
      local c = cells[k]
      min_x = math.min(min_x, c.x); max_x = math.max(max_x, c.x)
      min_y = math.min(min_y, c.y); max_y = math.max(max_y, c.y)
    end
    assert.is_true(min_x <= -110, "the safe region reaches the cold-safe edge (min_x=" .. min_x .. ")")
    assert.is_true(max_x >= 110, "the safe region reaches the hot-safe edge (max_x=" .. max_x .. ")")
    assert.is_true(max_y - min_y >= 100, "the safe region spans the long axis (y span=" .. (max_y - min_y) .. ")")
  end)
end)
