-- Proof: the lethal Cindra ZONES damage EVERYTHING in them -- the player AND
-- machines/entities alike (§4, §15-2; ci-3yl, redefined ci-da2).
--
-- scripts/tile-damage.lua reads POSITION on the perpendicular ribbon axis: the hot
-- zones (1+2+3) burn (heat) and the smooth-ice cap (zone 11) freezes (cold); the
-- walkable middle is safe. ci-da2 makes the zones MIXES of tiles that also appear in
-- safe neighbours, so lethality is keyed to position, not the tile under the entity.
-- Because the tiles are placed by that same axis, the damage still tracks the ribbon.
--
-- Each entity is placed on a paved WALKABLE tile at a chosen X (perp = -x), so the
-- outcome depends only on the position band, deterministically. Scoped to "cindra".

local H = require("tests.helpers")
local td = require("scripts.tile-damage")

describe("positional lethal-zone damage (§15-2; ci-da2)", function()
  -- Work far from the other tests' area; the driver is off so only our explicit
  -- sweep applies.  perp = -x, so the hot band is x <= -300 (perp >= 300) and the
  -- cold cap is x >= 200 (perp <= -200); the building centre (x = 0) is safe.
  local YY = 3000
  local HEAT_X, COLD_X, SAFE_X = -320, 320, 0
  local s

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
    s.request_to_generate_chunks({ 0, YY }, 3)
    s.force_generate_chunk_requests()
    for _, e in pairs(s.find_entities_filtered({ area = { { -360, YY - 20 }, { 360, YY + 20 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
    -- Pave WALKABLE tiles so characters + machines can stand in each band; the
    -- damage is positional, so the exact tile does not matter, only the X.
    pave("cindra-volcanic-cracks-hot", HEAT_X, YY) -- hot zone (heat)
    pave("cindra-ice-rough", COLD_X, YY)           -- smooth-ice cap position (cold)
    pave("cindra-sand-1", SAFE_X, YY)              -- building centre (safe)
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  it("damage_amount is dps * seconds (pure, linear in time)", function()
    assert.are.equal(100, td.damage_amount(300, 20), "300 dps over 20 ticks = 100 HP")
    assert.are.equal(200, td.damage_amount(300, 40), "twice the ticks = twice the HP")
  end)

  it("burns BOTH a player and a machine in the hot zone", function()
    -- The hot zone deals heat damage to anything in it -- player AND machine. This
    -- is "damage hits machines", now keyed to the zone position not the tile.
    local char = s.create_entity({ name = "character", position = { HEAT_X - 3, YY }, force = "player" })
    local mach = s.create_entity({ name = "assembling-machine-1", position = { HEAT_X + 3, YY }, force = "player" })
    assert.is_not_nil(char, "a character can stand in the hot zone")
    assert.is_not_nil(mach, "a machine can be built in the hot zone")
    local hc, hm = char.health, mach.health

    td.sweep(s, 60, 200) -- explicit dps so it's deterministic

    assert.is_true(char.health < hc, "the hot zone burns the player")
    assert.is_true(mach.health < hm, "the hot zone burns the machine too (damage hits machines)")
    char.destroy(); mach.destroy()
  end)

  it("freezes a machine in the smooth-ice cap (cold damage type)", function()
    local mach = s.create_entity({ name = "assembling-machine-1", position = { COLD_X, YY }, force = "player" })
    assert.is_not_nil(mach)
    local hm = mach.health
    td.sweep(s, 60, 200)
    assert.is_true(mach.health < hm, "the cold cap freezes the machine")
    mach.destroy()
  end)

  it("leaves the safe building centre SAFE for the player and machines", function()
    local char = s.create_entity({ name = "character", position = { SAFE_X - 3, YY }, force = "player" })
    local mach = s.create_entity({ name = "assembling-machine-1", position = { SAFE_X + 3, YY }, force = "player" })
    local hc, hm = char.health, mach.health
    td.sweep(s, 60, 200)
    assert.are.equal(hc, char.health, "the building centre is safe for the player")
    assert.are.equal(hm, mach.health, "the building centre is safe for machines too")
    char.destroy(); mach.destroy()
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
