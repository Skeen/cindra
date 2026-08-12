-- PROOF (ci-7k6): NO DEAD KNOBS. Every mod setting Cindra exposes actually changes
-- the world, and the ones that never did are gone.
--
-- WHY THIS FILE EXISTS. A player who moves a slider in the mod-settings screen,
-- generates a world and finds it identical has been lied to -- and there is no error
-- message, no crash and no failing test to tell anyone. Cindra shipped three such
-- sliders (`cindra-ribbon-safe-half-width`, `cindra-ribbon-lethal-at`,
-- `cindra-ribbon-wall-at`): they were read at the data stage into cfg tables and
-- handed downstream, but every consumer had moved to the per-zone width layout
-- (scripts/terrain.lua) whose cfg is keyed by zone ROLE, so the three keys fell on
-- the floor. Nothing was broken enough to notice. The whole suite stayed green.
--
-- So the first test here is a COVERAGE GUARD in the shape tests/test_power_conservation
-- uses for power entities: it discovers every Cindra mod setting LIVE from
-- `prototypes.mod_setting` and fails when one has no declared consumer. A new knob
-- therefore cannot land without a proof that it reaches the world -- the policy
-- enforces itself instead of relying on a reviewer noticing.
--
-- The rest of the file IS those proofs, and each one is a player-observable chain
-- rather than a restatement of the code:
--   * ORIENTATION  -> which world axis the ribbon is bounded across (walk that way
--                     and you hit the void; the other way runs forever).
--   * MAX-DPS      -> the HP a machine standing on a hazard tile actually loses.
--   * ZONE WIDTHS  -> the width of the generated world and where each band sits.
-- A knob whose value cannot be traced to something the player sees does not belong
-- in settings.lua.
--
-- SCOPE: mod SETTINGS (the mod-settings screen). The other family of knobs -- the
-- new-game map-gen controls (ci-i8a's Stone/Ice density, ci-i4z's Habitable band /
-- Hot zone / Cold zone sizes) -- are proven the same way in
-- tests/test_worldgen_sliders.lua, which moves a control and measures the generated
-- ground. If a new control lands, its proof belongs there.

local H = require("tests.helpers")
local axis = require("scripts.axis")
local driver = require("scripts.driver")
local terrain = require("scripts.terrain")
local td = require("scripts.tile-damage")

-- ===========================================================================
-- Coverage guard
-- ===========================================================================

-- Every Cindra setting, and where its effect on the world is proven. Adding a
-- setting to settings.lua WITHOUT adding an entry here fails the guard below.
local CONSUMED = {
  ["cindra-ribbon-orientation"] =
    "scripts/axis.lua -> which axis is perpendicular: the bounded axis of the "
    .. "generated world (below) and the void/fire sides in tests/test_orientation.lua",
  ["cindra-ribbon-max-dps"] =
    "scripts/tile-damage.lua -> HP lost per sweep on a hazard tile (below); the "
    .. "tile-vs-cover behaviour it scales is in tests/test_tile_damage.lua",
}
-- The per-zone width sliders are the ribbon's geometry: each one sets its band's
-- width, and the SUM is the world's finite dimension (proven below; the bands are
-- scanned on a live surface in tests/test_worldgen.lua).
for _, z in ipairs(terrain.ZONES) do
  CONSUMED[z.setting] =
    "scripts/terrain.lua -> the " .. z.role .. " band width, and its share of the "
    .. "world's finite dimension (below); band scan in tests/test_worldgen.lua"
end

-- The knobs ci-7k6 deleted. Named so the guard's failure message can say "this one
-- was removed on purpose" rather than sending the next reader to re-wire it.
local REMOVED = {
  "cindra-ribbon-safe-half-width",
  "cindra-ribbon-lethal-at",
  "cindra-ribbon-wall-at",
}

-- Every mod setting Cindra owns, discovered live. Ownership is by name prefix (the
-- mod's own convention -- the runtime API cannot report which mod added a
-- prototype), which is exact here: the sibling mods (cindra-start,
-- cindra-dev-default) register no settings of their own.
local function cindra_settings()
  local found = {}
  for name in pairs(prototypes.mod_setting) do
    if string.sub(name, 1, 7) == "cindra-" then found[#found + 1] = name end
  end
  table.sort(found)
  return found
end

describe("mod settings - no dead knobs (ci-7k6)", function()
  it("every Cindra setting has a declared, proven consumer", function()
    local orphans = {}
    for _, name in ipairs(cindra_settings()) do
      if not CONSUMED[name] then orphans[#orphans + 1] = name end
    end
    assert.are.equal(0, #orphans,
      "mod setting(s) a player can move with NO proven world effect -- either wire it "
        .. "up and add a proof here, or delete it and its locale entries (ci-7k6, "
        .. "AGENTS.md Definition of Done): " .. table.concat(orphans, ", "))
  end)

  it("the guard actually discovers the known settings (not vacuous)", function()
    -- A self-test in the spirit of tests/no-orphan-suites.test.sh: if discovery ever
    -- goes empty (a renamed prefix, a moved prototype table) the guard above would
    -- pass unconditionally and give false assurance.
    local found = {}
    for _, name in ipairs(cindra_settings()) do found[name] = true end
    assert.is_true(found["cindra-ribbon-orientation"] == true,
      "discovery must find the orientation setting -- the guard is vacuous otherwise")
    assert.is_true(found["cindra-ribbon-max-dps"] == true,
      "discovery must find the max-dps setting")
    for _, z in ipairs(terrain.ZONES) do
      assert.is_true(found[z.setting] == true,
        "discovery must find the zone-width setting " .. z.setting)
    end
  end)

  it("the dead ribbon-geometry sliders are GONE, not merely unread", function()
    -- Leaving them registered but ignored is the exact defect: the settings screen
    -- still offers them. The world geometry they claimed to control now has one
    -- source of truth (the zone widths + the heightmap), so there is nothing here to
    -- re-wire them to.
    for _, name in ipairs(REMOVED) do
      assert.is_nil(prototypes.mod_setting[name],
        name .. " was removed in ci-7k6 (superseded by the per-zone width sliders); "
          .. "do not re-add it as a second source of truth for the ribbon geometry")
      assert.is_nil(settings.startup[name], name .. " must not resolve to a value either")
    end
  end)
end)

-- ===========================================================================
-- Proof: ORIENTATION picks the axis the world is bounded across
-- ===========================================================================

describe("setting effect: cindra-ribbon-orientation", function()
  it("bounds the generated world across the axis the setting names", function()
    local s = H.cindra_surface()
    driver.enforce_finite(s)

    local orient = settings.startup["cindra-ribbon-orientation"].value
    assert.are.equal(orient, axis.orientation(),
      "the axis module must read the live setting, not a hard-coded default")

    -- The lever, stated as the ground under the player's feet: the two orientations
    -- put the SAME world position on DIFFERENT points of the hot-cold axis, so the
    -- setting really does select between two different worlds. Walk far WEST and you
    -- burn when the ribbon runs N-S; the very same spot is safe middle ground when it
    -- runs E-W, where the fire is NORTH instead.
    --
    -- Deliberately NOT phrased as "the two orientations emit different noise
    -- expressions": since ci-i4z every band reads ONE named expression
    -- (`cindra_perp`, the slider-warped nominal axis) in both orientations, so that
    -- comparison is now equal-by-construction and would pass while proving nothing.
    local hot_from = terrain.damage_bounds().hot_from
    assert.are.equal("heat", terrain.lethal_at(axis.perp(-hot_from, 0, axis.VERTICAL)),
      "with a N-S ribbon the fire is WEST: x = -" .. hot_from .. " must burn")
    assert.is_nil(terrain.lethal_at(axis.perp(-hot_from, 0, axis.HORIZONTAL)),
      "that exact spot is safe middle ground when the ribbon runs E-W")
    assert.are.equal("heat", terrain.lethal_at(axis.perp(0, -hot_from, axis.HORIZONTAL)),
      "where the fire is NORTH instead: y = -" .. hot_from .. " must burn")
    -- ...and the map-gen is handed a different world axis to warp in each case.
    assert.are_not.equal(axis.raw_perp_expr(axis.VERTICAL), axis.raw_perp_expr(axis.HORIZONTAL),
      "worldgen must read a different raw world axis per orientation")

    -- ...and the world the player actually gets is bounded on the one the live
    -- setting selects, and open on the other. (tests/test_orientation.lua walks out
    -- to the void on one axis and forever on the other; this pins the setting -> the
    -- surface's own map-gen, which is what makes that difference happen.)
    local finite = terrain.finite_dimension()
    local expected_key = (orient == axis.HORIZONTAL) and "height" or "width"
    assert.are.equal(expected_key, finite.key,
      "the finite axis must follow the orientation setting")
    assert.are.equal(finite.value, s.map_gen_settings[finite.key],
      "the live surface is bounded across the ribbon at the ribbon's own width")
  end)
end)

-- ===========================================================================
-- Proof: MAX-DPS is the HP a machine on a hazard tile actually loses
-- ===========================================================================

describe("setting effect: cindra-ribbon-max-dps", function()
  local YY = 4200
  local HAZARD = "cindra-lava-hot" -- the full-intensity hot core
  local s

  before_each(function()
    s = H.cindra_surface()
    storage.cindra_driver_enabled = false
    s.request_to_generate_chunks({ 0, YY }, 4)
    s.force_generate_chunk_requests()
    for _, e in pairs(s.find_entities_filtered({ area = { { -40, YY - 20 }, { 40, YY + 20 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
    local tiles = {}
    for x = -5, 5 do
      for y = YY - 5, YY + 5 do tiles[#tiles + 1] = { name = HAZARD, position = { x, y } } end
    end
    s.set_tiles(tiles, true)
  end)

  after_each(function()
    storage.cindra_driver_enabled = true
  end)

  -- HP a fresh machine standing on the hazard loses over ONE 60-tick sweep. `dps`
  -- nil = let the sweep read the SETTING, which is the whole point.
  local function hp_lost(dps)
    local e = s.create_entity({ name = "assembling-machine-1", position = { 0, YY }, force = "player" })
    assert.is_not_nil(e, "machine placed on " .. HAZARD)
    local before = e.health
    td.sweep(s, 60, dps)
    local lost = before - e.health
    e.destroy()
    return lost
  end

  it("the slider's value is the burn a player takes on a full-intensity tile", function()
    local slider = settings.startup["cindra-ribbon-max-dps"].value
    local intensity = select(1, terrain.tile_damage(HAZARD))
    assert.is_true(intensity > 0, "precondition: " .. HAZARD .. " is a hazard tile")

    -- The sweep is given NO dps, so anything it inflicts came from the setting.
    local lost = hp_lost(nil)
    assert.are.equal(slider * intensity, lost,
      "one second on the hot core must cost exactly the slider's dps (scaled by the "
        .. "tile's intensity) -- if this is 0 the sweep stopped reading the setting")
  end)

  it("moving the slider moves the burn proportionally", function()
    -- Startup settings cannot be changed mid-run, so the lever is proven by feeding
    -- the sweep the values a player's slider would produce: half the setting burns
    -- half as much, zero burns nothing at all.
    local slider = settings.startup["cindra-ribbon-max-dps"].value
    local full = hp_lost(slider)
    local half = hp_lost(slider / 2)
    assert.is_true(full > 0, "the hot core burns at the shipped setting")
    assert.are.equal(full / 2, half, "halving the slider halves the burn")
    assert.are.equal(0, hp_lost(0), "a player who zeroes the slider takes no burn at all")
  end)
end)

-- ===========================================================================
-- Proof: each ZONE WIDTH slider sizes its band and the world
-- ===========================================================================

describe("setting effect: cindra-zone-width-*", function()
  it("every zone slider is the width the world is actually generated at", function()
    local s = H.cindra_surface()
    driver.enforce_finite(s)

    local widths = terrain.widths()
    local sum = 0
    for i, z in ipairs(terrain.ZONES) do
      local set = settings.startup[z.setting]
      assert.is_not_nil(set, z.setting .. " must exist as a startup setting")
      assert.are.equal(set.value, widths[i],
        "terrain must generate the " .. z.role .. " band at the slider's width")
      sum = sum + set.value
    end

    -- Player-observable: the world is exactly as wide across the ribbon as the
    -- sliders add up to -- walk half that far and you are at the void
    -- (tests/test_orientation.lua). No standalone total-width knob exists, so this is
    -- the ONLY way a player sets the size of their planet.
    local finite = terrain.finite_dimension()
    assert.are.equal(sum, finite.value, "the ribbon's width is the sum of the sliders")
    assert.are.equal(sum, s.map_gen_settings[finite.key],
      "and that is the width the live surface was generated at")
  end)

  it("each slider moves its OWN band, and only its own", function()
    local base_bands, base_total = terrain.bands()
    for i, z in ipairs(terrain.ZONES) do
      local cfg = { [z.role] = terrain.widths()[i] + 100 }
      local bands, total = terrain.bands(cfg)
      assert.are.equal(base_total + 100, total,
        "widening " .. z.setting .. " by 100 must widen the world by 100")
      local base_w = base_bands[i].hi - base_bands[i].lo
      assert.are.equal(base_w + 100, bands[i].hi - bands[i].lo,
        "the extra 100 tiles must land in the " .. z.role .. " band itself")
      for j, other in ipairs(terrain.ZONES) do
        if j ~= i then
          assert.are.equal(base_bands[j].hi - base_bands[j].lo, bands[j].hi - bands[j].lo,
            "widening " .. z.role .. " must not resize the " .. other.role .. " band")
        end
      end
    end
  end)
end)
