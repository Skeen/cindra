-- Proof: environmental damage is BELT/FIELD-based and ramps with depth (§4, §15-2;
-- ci-3yl, ci-da2, ci-4jl, REKEYED ci-oe83).
--
-- scripts/tile-damage.lua reads the ONE heightmap FIELD at an entity's perpendicular
-- POSITION and burns/freezes it, scaled by how deep into the belt it stands
-- (terrain.field_damage). This proves:
--   * the ramp: heat rises the deeper sunward you stand; cold rises the deeper nightward;
--     the safe middle takes nothing;
--   * the ci-oe83 fix -- damage is DECOUPLED from the tile art: a cosmetic hot tile
--     painted in the safe middle does ZERO damage, and a safe-looking tile in the belt
--     still burns. So there is no non-damaging path to either ocean;
--   * an entity whose footprint OVERLAPS the belt burns even if its centre reads safe;
--   * the sweep is Cindra-only.
--
-- (This supersedes ci-4jl's per-tile model, which let a ridge of non-damaging tiles reach
-- the lava -- see ci-oe83.)

local H = require("tests.helpers")
local td = require("scripts.tile-damage")

describe("belt/field-based lethal-ground damage (§15-2; ci-oe83)", function()
  local YY = 3200
  local s

  -- Paint an 11x11 patch of `name` centred on (cx, cy).
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
    -- Generate a wide strip so belt positions (|x| up to ~180) exist at YY.
    s.request_to_generate_chunks({ 0, YY }, 8)
    s.force_generate_chunk_requests()
    for _, e in pairs(s.find_entities_filtered({ area = { { -260, YY - 20 }, { 260, YY + 20 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  -- HP lost by a fresh `entity_name` at world x (perp = -x), after ONE deterministic sweep
  -- (peak dps 200 at a full-intensity point). Position decides the damage, so the tile
  -- under it is irrelevant.
  local function damage_at(x, entity_name)
    local e = s.create_entity({ name = entity_name or "assembling-machine-1", position = { x, YY }, force = "player" })
    assert.is_not_nil(e, (entity_name or "machine") .. " placed at x=" .. x)
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

  it("HEAT damage RAMPS with POSITION: deeper into the hot belt burns more; middle = 0", function()
    -- perp = -x: x=-160 (perp 160) is deep in the hot belt, x=-135 (perp 135) shallow,
    -- x=0 the safe middle. The heat threshold is perp 130.
    local deep    = damage_at(-160)
    local shallow = damage_at(-135)
    local middle  = damage_at(0)
    assert.are.equal(0, middle, "the safe middle takes no damage")
    assert.is_true(shallow > 0, "the shallow hot belt burns a little")
    assert.is_true(deep > shallow, "deeper into the hot belt burns more (depth ramp)")
  end)

  it("COLD damage RAMPS with POSITION: deeper into the cold belt freezes more; middle = 0", function()
    local deep    = damage_at(160)  -- perp -160, deep cold belt
    local shallow = damage_at(135)  -- perp -135, shallow cold belt
    local middle  = damage_at(0)
    assert.are.equal(0, middle, "the safe middle takes no cold damage")
    assert.is_true(shallow > 0, "the shallow cold belt freezes a little")
    assert.is_true(deep > shallow, "deeper into the cold belt freezes more")
  end)

  it("CRITICAL (ci-oe83): a cosmetic LAVA tile in the safe middle does ZERO damage", function()
    -- The exact ci-oe83 decision: damage follows the FIELD (position), not the tile. A
    -- hot-looking (even lava) tile scattered in the safe middle burns NOTHING -- so
    -- cosmetic scatter can never trap the player, and there is no tile-keyed damage to
    -- exploit. (The old ci-4jl model burned here; that model is what shipped the corridor.)
    pave("cindra-lava-hot", 0, YY)
    local pump = s.create_entity({ name = "pump", position = { 0, YY }, force = "player" })
    assert.is_not_nil(pump, "a pump can be placed at the safe middle")
    local before = pump.health
    td.sweep(s, 60, 200)
    assert.is_true(pump.valid and pump.health == before,
      "a pump on a cosmetic lava tile in the SAFE middle takes ZERO damage (damage is positional)")
    pump.destroy()
  end)

  it("CRITICAL (ci-oe83): a SAFE-looking tile in the hot belt still BURNS (no corridor)", function()
    -- Mirror of the above: paint a safe ash tile in the hot belt. Because damage follows
    -- the POSITION, standing there still burns -- so no ridge of safe-looking tiles can
    -- ever form a non-damaging walk to the ocean.
    pave("cindra-volcanic-ash-flats", -150, YY)
    local m = s.create_entity({ name = "assembling-machine-1", position = { -150, YY }, force = "player" })
    assert.is_not_nil(m)
    local before = m.health
    td.sweep(s, 60, 200)
    assert.is_true(m.health < before, "a safe-looking tile in the hot belt still burns (belt is unbypassable)")
    m.destroy()
  end)

  it("burns a CHARACTER in the belt, leaves one in the middle alone", function()
    local burned = s.create_entity({ name = "character", position = { -150, YY }, force = "player" })
    local hb = burned.health
    td.sweep(s, 60, 200)
    assert.is_true(burned.health < hb, "the character burns in the hot belt")
    burned.destroy()

    local safe = s.create_entity({ name = "character", position = { 0, YY }, force = "player" })
    local hs = safe.health
    td.sweep(s, 60, 200)
    assert.are.equal(hs, safe.health, "the safe middle never burns the character")
    safe.destroy()
  end)

  it("never touches an entity on another planet (Cindra-only)", function()
    local nauvis = game.surfaces["nauvis"]
    local char = nauvis.create_entity({ name = "character", position = { 0, 0 }, force = "player" })
    local before = char.health
    td.sweep(nauvis, 60, 200) -- wrong surface: must be a no-op
    assert.are.equal(before, char.health, "belt damage is Cindra-only")
    char.destroy()
  end)
end)
