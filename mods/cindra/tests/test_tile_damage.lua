-- Proof: environmental damage is TILE-BASED and ramps with depth (§4, §15-2;
-- ci-3yl, redefined ci-da2, reworked ci-4jl).
--
-- scripts/tile-damage.lua reads the TILE(S) under an entity's collision footprint
-- and burns/freezes it from the MOST-LETHAL one, scaled by that tile's intensity
-- (terrain.tile_damage). This proves:
--   * the ramp: hot-lava burns hardest, then lava, cracks-hot, warm crust; the
--     smooth-ice cap freezes hardest, then rough ice; temperate ground is safe;
--   * the exploit fix: a pump/machine whose footprint OVERLAPS a lava tile burns
--     and dies, while the same entity on temperate ground takes nothing;
--   * the sweep is Cindra-only.
--
-- Method: create the entity on safe ground, then paint the tile(s) under it, so
-- the outcome depends only on the tile the entity sits on. Scoped to "cindra".

local H = require("tests.helpers")
local td = require("scripts.tile-damage")

describe("tile-based lethal-ground damage (§15-2; ci-4jl)", function()
  -- Work far from the other tests' area; the driver is off so only our explicit
  -- sweep applies.
  local YY = 3200
  local CX = 0
  local s

  -- Paint an 11x11 patch of `name` centred on (cx, cy) -- big enough that any
  -- entity's footprint sits entirely on it.
  local function pave(name, cx, cy)
    local tiles = {}
    for x = cx - 5, cx + 5 do
      for y = cy - 5, cy + 5 do
        tiles[#tiles + 1] = { name = name, position = { x, y } }
      end
    end
    s.set_tiles(tiles, true)
  end

  before_each(function()
    s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    s.request_to_generate_chunks({ CX, YY }, 3)
    s.force_generate_chunk_requests()
    for _, e in pairs(s.find_entities_filtered({ area = { { CX - 40, YY - 20 }, { CX + 40, YY + 20 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  -- HP lost by a fresh `entity_name` sitting on a uniform patch of `tile_name`
  -- after ONE deterministic sweep (peak dps 200 at a full-intensity tile). The tile
  -- is painted BEFORE the entity is created: set_tiles(correct_tiles=true) would
  -- destroy an entity sitting on a newly-impassable lava tile, whereas
  -- create_entity spawns it regardless of the tile under it (mirrors a machine
  -- overlapping the lava edge).
  local function damage_on(tile_name, entity_name)
    pave(tile_name, CX, YY)
    local e = s.create_entity({ name = entity_name, position = { CX, YY }, force = "player" })
    assert.is_not_nil(e, entity_name .. " placed on " .. tile_name)
    local before = e.health
    td.sweep(s, 60, 200)
    local lost = before - e.health
    e.destroy()
    return lost
  end

  it("damage_amount is dps * seconds (pure, linear in time)", function()
    assert.are.equal(100, td.damage_amount(300, 20), "300 dps over 20 ticks = 100 HP")
    assert.are.equal(200, td.damage_amount(300, 40), "twice the ticks = twice the HP")
  end)

  it("HEAT damage RAMPS with tile: hot-lava > lava > cracks-hot > warm > temperate=0", function()
    local hot_lava   = damage_on("cindra-lava-hot", "assembling-machine-1")
    local lava       = damage_on("cindra-lava", "assembling-machine-1")
    local cracks_hot = damage_on("cindra-volcanic-cracks-hot", "assembling-machine-1")
    local warm       = damage_on("cindra-volcanic-cracks-warm", "assembling-machine-1")
    local temperate  = damage_on("cindra-sand-1", "assembling-machine-1")

    assert.are.equal(0, temperate, "temperate ground deals NO damage")
    assert.is_true(warm > 0, "warm crust deals a little damage (gentle edge)")
    assert.is_true(cracks_hot > warm, "glowing crust burns more than warm crust")
    assert.is_true(lava > cracks_hot, "lava burns more than crust")
    assert.is_true(hot_lava > lava, "hot-lava is the peak burn")
  end)

  it("COLD damage RAMPS with tile: smooth-ice > rough-ice > temperate=0", function()
    local smooth = damage_on("cindra-ice-smooth", "assembling-machine-1")
    local rough  = damage_on("cindra-ice-rough", "assembling-machine-1")
    local safe   = damage_on("cindra-sand-1", "assembling-machine-1")

    assert.are.equal(0, safe, "temperate ground deals no cold damage")
    assert.is_true(rough > 0, "rough ice freezes a little")
    assert.is_true(smooth > rough, "the smooth-ice cap is the peak freeze")
  end)

  it("CRITICAL: a pump sitting on a lava tile at a 'safe' COORDINATE burns and dies (exploit fix)", function()
    -- This is the exact exploit. CX = 0, so perp = -x = 0: the OLD positional model
    -- read this as the SAFE building centre (lethal_at(0) == nil) and dealt ZERO
    -- damage, so a pump on a lava tile here never died. The NEW tile-based model
    -- reads the ACTUAL tile under the pump (hot lava) and burns it, regardless of
    -- the coordinate. Painting the lava BEFORE creating the pump mirrors building a
    -- pump onto a lava tile.
    pave("cindra-lava-hot", CX, YY)
    local pump = s.create_entity({ name = "pump", position = { CX, YY }, force = "player" })
    assert.is_not_nil(pump, "a pump can be placed on the lava tile")

    -- One sweep of hot-lava (intensity 1.0) is enough to kill a pump outright, so
    -- "took damage" means it lost health OR was destroyed.
    local before = pump.health
    td.sweep(s, 60, 200)
    assert.is_true((not pump.valid) or pump.health < before,
      "the pump on lava takes damage (old model would deal none at this coordinate)")

    -- Keep sweeping: it must die (the exploit is that it survived on lava).
    for _ = 1, 5 do
      if not pump.valid then break end
      td.sweep(s, 60, 200)
    end
    assert.is_true(pump == nil or not pump.valid, "a pump on lava eventually dies")
  end)

  it("the SAME pump on temperate ground takes NO damage", function()
    pave("cindra-sand-1", CX, YY)
    local pump = s.create_entity({ name = "pump", position = { CX, YY }, force = "player" })
    assert.is_not_nil(pump)
    local before = pump.health
    td.sweep(s, 60, 200)
    assert.are.equal(before, pump.health, "temperate ground never damages the pump")
    pump.destroy()
  end)

  it("burns a CHARACTER standing on lava, leaves one on safe ground alone", function()
    -- Character on lava (paint the lava BEFORE creating so set_tiles can't remove it).
    pave("cindra-lava-hot", CX, YY)
    local burned = s.create_entity({ name = "character", position = { CX, YY }, force = "player" })
    local hb = burned.health
    td.sweep(s, 60, 200)
    assert.is_true(burned.health < hb, "the character burns on lava")
    burned.destroy()

    -- Character on safe ground.
    pave("cindra-sand-1", CX, YY)
    local safe = s.create_entity({ name = "character", position = { CX, YY }, force = "player" })
    local hs = safe.health
    td.sweep(s, 60, 200)
    assert.are.equal(hs, safe.health, "safe ground never burns the character")
    safe.destroy()
  end)

  it("never touches an entity on another planet (Cindra-only)", function()
    local nauvis = game.surfaces["nauvis"]
    local char = nauvis.create_entity({ name = "character", position = { 0, 0 }, force = "player" })
    local before = char.health
    td.sweep(nauvis, 60, 200) -- wrong surface: must be a no-op
    assert.are.equal(before, char.health, "tile damage is Cindra-only")
    char.destroy()
  end)
end)
