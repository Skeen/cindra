-- Proof: the lethal Cindra tiles damage EVERYTHING standing on them -- the player
-- AND machines/entities alike (§4, §15-2; ci-3yl "a tile that damages everything").
--
-- scripts/tile-damage.lua reads the VISIBLE ground: only the molten edge (hot-lava
-- + lava = heat) and the deep smooth-ice (cold) tiles bite; the walkable volcanic /
-- dirt / frost margins and the sand centre are safe. This is the tile-based area
-- damage the design calls for (Factorio has no native per-tick damaging-tile field).
-- It replaces the old coordinate-ramp, character-only edge damage.
--
-- Scoped to the "cindra" surface; a sweep on any other planet is a no-op.

local H = require("tests.helpers")
local td = require("scripts.tile-damage")

describe("tile-based lethal-edge damage (§15-2; ci-3yl)", function()
  -- Work far from the other tests' area; the driver is off so only our explicit
  -- sweep applies. Each patch is paved with a single tile so the outcome is
  -- deterministic regardless of where the noise map-gen would put the bands.
  local YL, YS = 3000, 3120 -- lethal-patch and safe-patch rows
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
    s.request_to_generate_chunks({ 0, YL }, 3)
    s.request_to_generate_chunks({ 0, YS }, 3)
    s.force_generate_chunk_requests()
    for _, e in pairs(s.find_entities_filtered({ area = { { -20, YL - 20 }, { 20, YS + 20 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  it("damage_amount is dps * seconds (pure, linear in time)", function()
    assert.are.equal(100, td.damage_amount(300, 20), "300 dps over 20 ticks = 100 HP")
    assert.are.equal(200, td.damage_amount(300, 40), "twice the ticks = twice the HP")
  end)

  it("burns BOTH a player and a machine standing on a lava tile", function()
    pave("cindra-lava", 0, YL)
    local char = s.create_entity({ name = "character", position = { -3, YL }, force = "player" })
    local mach = s.create_entity({ name = "assembling-machine-1", position = { 3, YL }, force = "player" })
    assert.is_not_nil(char, "a character can stand on the (buildable) lava tile")
    assert.is_not_nil(mach, "a machine can be BUILT on the lava tile")
    local hc, hm = char.health, mach.health

    td.sweep(s, 60, 200) -- explicit dps so it's deterministic

    assert.is_true(char.health < hc, "the lava tile burns the player")
    assert.is_true(mach.health < hm, "the lava tile burns the machine too (damage hits machines)")
    char.destroy(); mach.destroy()
  end)

  it("freezes a machine on a deep-ice tile (cold damage type)", function()
    pave("cindra-smooth-ice", 0, YL)
    local mach = s.create_entity({ name = "assembling-machine-1", position = { 0, YL }, force = "player" })
    assert.is_not_nil(mach)
    local hm = mach.health
    td.sweep(s, 60, 200)
    assert.is_true(mach.health < hm, "the deep-ice tile freezes the machine")
    mach.destroy()
  end)

  it("leaves the walkable volcanic / frost margins and the sand centre SAFE", function()
    for _, safe in ipairs({ "cindra-volcanic-cracks-hot", "cindra-aquilo-dust", "cindra-sand" }) do
      pave(safe, 0, YS)
      local char = s.create_entity({ name = "character", position = { -3, YS }, force = "player" })
      local mach = s.create_entity({ name = "assembling-machine-1", position = { 3, YS }, force = "player" })
      local hc, hm = char.health, mach.health
      td.sweep(s, 60, 200)
      assert.are.equal(hc, char.health, safe .. " is walkable/safe for the player")
      assert.are.equal(hm, mach.health, safe .. " is safe for machines too")
      char.destroy(); mach.destroy()
    end
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
