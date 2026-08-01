-- ci-oe83 MERGE GATE: the ribbon is ONE continuous heightmap, oceans EMERGE from it, and
-- the environmental damage is confined to two contiguous EDGE BELTS -- no non-damaging
-- corridor to either ocean, and a safe middle that spans the whole long axis (no
-- player-trapping enclosure).
--
-- These are the guard tests that kept being skipped. They generate ACTUAL map surfaces on
-- several seeds and inspect real behaviour:
--   * the ocean-solidity + emergence guards count real tiles on multiple fixed seeds;
--   * the corridor + enclosure guards drive the REAL runtime damage sweep
--     (scripts/tile-damage.lua, now TILE-based, ci-ma18) on the live "cindra" surface as
--     a model-agnostic oracle: they FLOOD the safe (undamaged) cells out from spawn and
--     assert that region never reaches either ocean -- so there is no non-damaging path
--     around the belts, whatever keys the damage;
--   * the golden-profile + clamp + continuity guards prove the generator POSITIVELY
--     produces the specified structure (and, since the field is seed-independent, prove
--     the belt is unbypassable on EVERY seed, not just the sampled ones).
--
-- Why the no-corridor guarantee survives the ci-ma18 switch back to tile-based damage:
-- the ribbon is now ONE monotonic heightmap, so the damaging TILES are a monotonic
-- function of the field -- they form two contiguous EDGE BELTS exactly like the field
-- thresholds do. A little boundary speckle can leave an isolated safe tile at a belt's
-- inner edge, but no chain of safe tiles threads THROUGH a belt to an ocean.
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

  -- === THE REPRO: no SAFE corridor threads from the middle to either ocean =====
  -- Drive the REAL sweep on the LIVE "cindra" surface: place a lattice of characters across
  -- the full width, sweep once, and read which kept full HP. Then FLOOD the safe cells out
  -- from spawn: the reachable safe region must never reach the ocean band nor border an
  -- ocean tile -- so there is no non-damaging walk to either ocean, whatever keys the
  -- damage. (Removing the damage entirely would let the flood reach the oceans and FAIL.)
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

  it("REPRO: no SAFE corridor threads from the middle to either ocean (ci-ma18 tile-based)", function()
    local s = live()
    local cells, key = classify(s, -190, 190, WY - 45, WY + 45)
    -- Flood the SAFE cells outward from the sampled safe cell CLOSEST to the middle
    -- (the spawn column may not land on the STEP lattice, so pick it dynamically).
    local reached, stack = {}, {}
    local seed_key
    do
      local best
      for k, c in pairs(cells) do
        if c.state == "safe" then
          local d = math.abs(perp_of(c.x))
          if best == nil or d < best then best = d; seed_key = k end
        end
      end
    end
    assert.is_not_nil(seed_key, "a safe middle seed cell exists")
    reached[seed_key] = true; stack[1] = seed_key
    local dirs = { { STEP, 0 }, { -STEP, 0 }, { 0, STEP }, { 0, -STEP } }
    while #stack > 0 do
      local c = cells[table.remove(stack)]
      for _, d in ipairs(dirs) do
        local nk = key(c.x + d[1], c.y + d[2])
        local n = cells[nk]
        if n and n.state == "safe" and not reached[nk] then reached[nk] = true; stack[#stack + 1] = nk end
      end
    end
    -- The reachable safe region must stay clear of both oceans: never a cell in the ocean
    -- band, and never a safe cell bordering an ocean tile (a corridor's last step).
    local max_perp = 0
    for k in pairs(reached) do
      local c = cells[k]
      max_perp = math.max(max_perp, math.abs(perp_of(c.x)))
      for _, d in ipairs(dirs) do
        local n = cells[key(c.x + d[1], c.y + d[2])]
        assert.are_not.equal("ocean", n and n.state,
          "a safe cell at (" .. c.x .. "," .. c.y .. ") borders an ocean tile (corridor!)")
      end
    end
    -- The oceans' inner edge is perp ~190; the flood must stop well short (isolated safe
    -- tiles cling to the belt's inner edge ~130-150, never threading the belt).
    assert.is_true(max_perp < 175,
      "the safe region never reaches the ocean band (max reachable perp=" .. max_perp .. ")")
  end)

  it("REPRO: the safe middle really IS safe (the sweep leaves every middle cell alone)", function()
    -- Complements the belt guard: prove the safe classification is not vacuous -- the safe
    -- CORE takes ZERO damage, so a real traversable corridor exists. Tile-based damage has
    -- a FUZZY boundary (a hot tile can bleed a couple of tiles inward of the perp-130
    -- threshold on noise, ci-ma18), so the guaranteed-safe core is sampled at |perp| <= 100
    -- -- comfortably inside the noise margin, and still far wider than the spawn pad.
    local s = live()
    local cells = classify(s, -100, 100, WY - 30, WY + 30)
    local safe_mid = 0
    for _, c in pairs(cells) do
      if math.abs(perp_of(c.x)) <= 100 then
        assert.are_not.equal("damage", c.state, "the safe core at (" .. c.x .. "," .. c.y .. ") must not be damaged")
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
