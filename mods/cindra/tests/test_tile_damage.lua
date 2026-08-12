-- Proof: environmental damage is TILE-based -- a hazard tile burns/freezes whatever
-- stands on it, and a player-placed COVER tile (concrete) SHIELDS it (§4, §15-2;
-- ci-3yl, ci-da2, ci-4jl, RESTORED ci-ma18).
--
-- scripts/tile-damage.lua reads the ACTUAL tile under an entity's collision footprint
-- and burns/freezes it (terrain.tile_damage). This is the ci-ma18 regression guard for
-- BOTH directions of the shipped position-keyed bug:
--   * SHIELD: concrete over hot/cold ground -> ZERO damage (the position model kept
--     burning through a cover);
--   * HAZARD: a hot/cold natural tile burns/freezes wherever it renders, even in the
--     nominally-"safe" middle (the position model left cosmetically-hot tiles harmless);
--   * a machine STRADDLING a hazard tile burns even if its centre is on safe ground;
--   * the safe middle takes nothing; the sweep is Cindra-only.
--
-- (This supersedes ci-oe83's position-keyed model, which shipped concrete-over-lava
-- still burning + hot cracks dealing nothing -- see ci-ma18.)

local H = require("tests.helpers")
local td = require("scripts.tile-damage")
local terrain = require("scripts.terrain")

describe("tile-based lethal-ground damage (§15-2; ci-ma18)", function()
  local YY = 3200
  local s

  -- Paint an 11x11 patch of `name` centred on (cx, cy) (set_tiles bypasses the
  -- no-paving handler, so we can lay any tile -- hazard or cover -- for the test).
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
    s.request_to_generate_chunks({ 0, YY }, 8)
    s.force_generate_chunk_requests()
    for _, e in pairs(s.find_entities_filtered({ area = { { -260, YY - 20 }, { 260, YY + 20 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  -- HP lost by a fresh `entity_name` standing on tile `tile_name` (painted under it) at
  -- (cx, YY), after ONE deterministic sweep (peak dps 200 at a full-intensity tile).
  local function damage_on(tile_name, entity_name, cx)
    cx = cx or 0
    pave(tile_name, cx, YY)
    local e = s.create_entity({ name = entity_name or "assembling-machine-1", position = { cx, YY }, force = "player" })
    assert.is_not_nil(e, (entity_name or "machine") .. " placed on " .. tile_name)
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

  it("HAZARD: a HOT natural burns; a hotter natural burns more; safe ground = 0", function()
    local crust   = damage_on("cindra-volcanic-cracks-hot") -- glowing hot crust
    local hotter  = damage_on("cindra-volcanic-smooth-stone-warm") -- warm crust, hotter
    local safe    = damage_on("cindra-volcanic-ash-flats") -- the safe middle
    assert.are.equal(0, safe, "safe ash ground burns nothing")
    assert.is_true(crust > 0, "the glowing hot crust burns")
    assert.is_true(hotter > crust, "a hotter natural burns more (depth ramp)")
  end)

  it("HAZARD: a COLD natural freezes; a colder natural freezes more", function()
    local snow = damage_on("cindra-snow-crests")
    local ice  = damage_on("cindra-ice-rough")
    assert.is_true(snow > 0, "snow freezes")
    assert.is_true(ice > snow, "rough ice freezes more than snow")
  end)

  it("the FOLDS branch is as harmless as the cracks slope it alternates with (ci-72bw)", function()
    -- The hot slope now paints two texture families over the same field values. A player
    -- walking a folded/pumice stretch must be exactly as safe as on a cracked one -- the
    -- branch is art, never a new hazard (and never a new safe path through a hazard).
    local cracks_warm = damage_on("cindra-volcanic-cracks-warm", "character", -100)
    assert.are.equal(0, cracks_warm, "the cracks slope is safe to stand on (control)")
    for name in pairs(terrain.family_tiles("folds")) do
      assert.are.equal(cracks_warm, damage_on(name, "character", -100),
        name .. " must be exactly as harmless as the cracks slope it replaces")
    end
    -- Control that the sweep is live at that spot: the crust just uphill still burns, so
    -- the zeros above are real safety, not a dead sweep.
    assert.is_true(damage_on("cindra-volcanic-cracks-hot", "character", -100) > 0,
      "the glowing crust still burns there (the sweep is live)")
  end)

  it("SHIELD (ci-ma18): CONCRETE over hot ground stops the burn; over cold stops the freeze", function()
    -- The exact ci-ma18 scenario, at DEEP belt positions where the shipped position model
    -- burned right through the cover (perp = -x: x=-160 is deep hot, x=160 deep cold).
    -- On the old model `covered_*` still burned (the bug); tile-based, the concrete shields.
    local bare_hot = damage_on("cindra-volcanic-cracks-hot", "assembling-machine-1", -160)
    assert.is_true(bare_hot > 0, "bare hot crust burns (control)")
    local covered_hot = damage_on("concrete", "assembling-machine-1", -160)
    assert.are.equal(0, covered_hot, "concrete over the hot belt takes ZERO damage")

    local bare_cold = damage_on("cindra-ice-rough", "assembling-machine-1", 160)
    assert.is_true(bare_cold > 0, "bare rough ice freezes (control)")
    local covered_cold = damage_on("concrete", "assembling-machine-1", 160)
    assert.are.equal(0, covered_cold, "concrete over the cold belt takes ZERO cold damage")
  end)

  it("HAZARD follows the TILE, not the position: a hot tile in the SAFE middle STILL burns", function()
    -- The inverse ci-ma18 symptom: the position model left a cosmetically-hot tile in
    -- the safe middle harmless. Tile-based, it burns wherever it renders. x=0 is the
    -- safe middle (perp 0), yet a hot crust tile painted there still burns.
    local lost = damage_on("cindra-volcanic-cracks-hot", "pump", 0)
    assert.is_true(lost > 0, "a hot crust tile in the safe middle burns (tile-keyed, not positional)")
  end)

  it("a machine STRADDLING a hot tile burns even if its centre is on safe ground", function()
    -- Safe ash everywhere, a single lava-hot tile off-centre under a 3x3 machine.
    pave("cindra-volcanic-ash-flats", 0, YY)
    s.set_tiles({ { name = "cindra-lava-hot", position = { 1, YY } } }, true)
    local m = s.create_entity({ name = "assembling-machine-1", position = { 0, YY }, force = "player" })
    assert.is_not_nil(m, "a 3x3 machine centred on safe ash")
    local before = m.health
    td.sweep(s, 60, 200)
    assert.is_true(m.health < before, "the footprint overlapping the lava tile burns")
    m.destroy()
  end)

  it("burns a CHARACTER on hot ground, leaves one on safe ground alone", function()
    pave("cindra-volcanic-cracks-hot", -20, YY)
    local burned = s.create_entity({ name = "character", position = { -20, YY }, force = "player" })
    local hb = burned.health
    td.sweep(s, 60, 200)
    assert.is_true(burned.health < hb, "the character burns on the hot crust")
    burned.destroy()

    pave("cindra-volcanic-ash-flats", 20, YY)
    local safe = s.create_entity({ name = "character", position = { 20, YY }, force = "player" })
    local hs = safe.health
    td.sweep(s, 60, 200)
    assert.are.equal(hs, safe.health, "safe ash ground never burns the character")
    safe.destroy()
  end)

  it("never touches an entity on another planet (Cindra-only)", function()
    local nauvis = game.surfaces["nauvis"]
    local char = nauvis.create_entity({ name = "character", position = { 0, 0 }, force = "player" })
    local before = char.health
    td.sweep(nauvis, 60, 200) -- wrong surface: must be a no-op
    assert.are.equal(before, char.health, "lethal-ground damage is Cindra-only")
    char.destroy()
  end)
end)
