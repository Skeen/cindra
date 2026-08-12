-- Proof (ci-ndm9): every machine Cindra gives the player can actually be BUILT on
-- Cindra, and every recipe Cindra unlocks can actually be CRAFTED there.
--
-- WHY THIS SUITE EXISTS. A `surface_conditions` list is an invisible placement /
-- crafting gate: "pressure >= 10", "gravity exactly 0". Cindra builds most of its
-- machines by DEEP-COPYING a vanilla one, and a deep copy inherits the source's
-- gate silently -- nothing in the Cindra file mentions it, and nothing in the
-- suite noticed. Two of our entities carry an inherited gate today (the electric
-- heater from the heating tower, the mass driver from the rocket silo). Both
-- happen to be satisfiable here, so the inheritance has cost nothing so far. But
-- clone the wrong source once -- the crusher (`gravity` exactly 0, i.e. space
-- only) is the obvious trap for a mod that relocates asteroid crushing to the
-- ground -- and the mod ships a building the player owns, sees in the crafting
-- menu, and simply CANNOT PLACE on the planet it was designed for.
--
-- So this is a coverage guard in the sense AGENTS.md means it: the class is
-- enumerated LIVE from `prototypes.*`, so a new Cindra entity or recipe is
-- covered the moment it exists, with no list to remember to update.
--
-- Player-observable throughout: "can I put this building down on this planet"
-- and "can this recipe run on this planet" is the whole of what a surface
-- condition does. See scripts/surface-conditions.lua for the editing helpers
-- (which delegate to PlanetsLib when it is installed) and
-- unit-tests/test_surface_conditions.lua for their semantics.

local H = require("tests.helpers")

-- Vanilla probes for the non-vacuity guard. Nothing Cindra does can change these:
-- the crusher is space-only (`gravity` exactly 0) and the stone furnace wants an
-- atmosphere (`pressure >= 10`), so on Cindra (gravity 20, pressure 500) the
-- first must be refused and the second allowed.
local SPACE_ONLY = "crusher"
local ATMOSPHERE_ONLY = "stone-furnace"

-- The surface properties a condition can name, read live off the surface so the
-- expected values are never hard-coded twice.
local function properties(surface)
  return {
    pressure = surface.get_property("pressure"),
    gravity = surface.get_property("gravity"),
    ["magnetic-field"] = surface.get_property("magnetic-field"),
    ["solar-power"] = surface.get_property("solar-power"),
    ["day-night-cycle"] = surface.get_property("day-night-cycle"),
  }
end

-- Which of `conditions` this surface fails, as a readable list.
local function unmet(conditions, props)
  local bad = {}
  for _, c in pairs(conditions or {}) do
    local actual = props[c.property]
    if actual == nil then
      -- A property we do not know how to read (a library-defined one, say) is
      -- reported rather than silently passed: an unknown gate is still a gate.
      bad[#bad + 1] = c.property .. " (unreadable on this surface)"
    elseif (c.min and actual < c.min) or (c.max and actual > c.max) then
      bad[#bad + 1] = string.format("%s=%s needs [%s, %s]", c.property, tostring(actual),
        tostring(c.min or "-inf"), tostring(c.max or "+inf"))
    end
  end
  return bad
end

-- Every entity the player can hold an item for and place, whose name is Cindra's.
-- Enumerated from ITEMS on purpose: that is exactly the set a player can build,
-- and it skips the hidden internals (the power-diode taps, the ambient heat
-- emitters, the spark explosion) that no one ever places by hand.
local function player_placeable()
  local out = {}
  for name, item in pairs(prototypes.item) do
    local result = item.place_result
    if result and result.name:find("^cindra%-") then
      out[#out + 1] = { item = name, entity = result.name, proto = result }
    end
  end
  table.sort(out, function(a, b) return a.entity < b.entity end)
  return out
end

describe("cindra surface conditions", function()
  it("this planet actually enforces surface conditions (non-vacuity guard)", function()
    -- Everything below is a "yes you can build it" claim, so all of it would pass
    -- vacuously on a surface that ignores conditions entirely. Pin that it does
    -- not, and that the build check we use is the one that sees them.
    local s = H.cindra_surface()
    assert.is_false(s.ignore_surface_conditions,
      "Cindra must enforce surface conditions; if it did not, this whole suite would prove nothing")

    assert.is_true(s.can_place_entity({ name = ATMOSPHERE_ONLY, position = { 20, 20 } }),
      "a stone furnace (pressure >= 10) must be buildable on Cindra (pressure "
        .. tostring(s.get_property("pressure")) .. ")")
    assert.is_false(s.can_place_entity({ name = SPACE_ONLY, position = { 24, 20 } }),
      "a crusher is space-only (gravity exactly 0) and must be REFUSED on the ground;"
        .. " if this passes, can_place_entity is not checking surface conditions and the"
        .. " coverage guard below is worthless")
  end)

  it("every Cindra building the player can hold is placeable on Cindra", function()
    -- THE coverage guard. Enumerated live, so a future clone from a space-gated
    -- vanilla entity fails here the moment it is added, naming itself.
    local s = H.cindra_surface()
    local props = properties(s)
    local placeable = player_placeable()
    assert.is_true(#placeable >= 5,
      "sanity: expected a handful of player-placeable Cindra buildings, found " .. #placeable)

    -- Characters block a manual build check; move any out of the grid first.
    for _, c in pairs(s.find_entities_filtered({ type = "character" })) do
      c.teleport({ 0, 70 })
    end

    for i, p in ipairs(placeable) do
      -- 12-tile spacing on the paved slab: wider than the biggest building here
      -- (the 9x9 mass driver), so a refusal is never just a collision.
      local x = -42 + 12 * ((i - 1) % 8)
      local y = -42 + 12 * math.floor((i - 1) / 8)
      local bad = unmet(p.proto.surface_conditions, props)
      assert.are.equal(0, #bad,
        p.entity .. " carries a surface condition Cindra cannot satisfy: " .. table.concat(bad, "; "))
      assert.is_true(s.can_place_entity({ name = p.entity, position = { x, y }, force = "player" }),
        p.entity .. " (from item " .. p.item .. ") cannot be placed on Cindra at "
          .. x .. "," .. y .. " -- a Cindra machine must be buildable on Cindra")
    end
  end)

  it("every Cindra recipe can be crafted on Cindra", function()
    -- The recipe half of the same trap: a surface-gated recipe shows in the
    -- crafting menu but no machine on this planet will accept it.
    local s = H.cindra_surface()
    local props = properties(s)
    local checked = 0
    for name, recipe in pairs(prototypes.recipe) do
      if name:find("^cindra%-") then
        checked = checked + 1
        local bad = unmet(recipe.surface_conditions, props)
        assert.are.equal(0, #bad,
          name .. " cannot be crafted on Cindra: " .. table.concat(bad, "; "))
      end
    end
    assert.is_true(checked >= 10, "sanity: expected Cindra recipes to enumerate, found " .. checked)
  end)

  it("states the heater's inherited pressure gate instead of inheriting it", function()
    -- Supplement to the placement guard above: the gate the electric heater got
    -- from the fuel-burning heating tower is KEPT (dropping it would hand vanilla
    -- space platforms a new heat source) but is now declared by Cindra, so an
    -- upstream retune cannot move it. Pinning the number is what makes "declared"
    -- mean anything.
    local heater = prototypes.entity["cindra-electric-heater"]
    assert.is_not_nil(heater, "the electric heater must exist")
    local found
    for _, c in pairs(heater.surface_conditions or {}) do
      if c.property == "pressure" then found = c end
    end
    assert.is_not_nil(found, "the heater must carry its pressure gate")
    assert.are.equal(10, found.min, "the heater's declared floor is pressure >= 10 (no space platforms)")
    -- And no ceiling that would strand it: the heater is meant to be EXPORTABLE
    -- (DESIGN §12 -- superb where power is free, clumsy elsewhere), so it must stay
    -- placeable on the highest-pressure world in the game (Vulcanus, 4000). The
    -- engine reports an absent bound as a huge number rather than nil, so accept
    -- either.
    assert.is_true(found.max == nil or found.max >= 4000,
      "an upper pressure bound would ban the heater from Vulcanus; got " .. tostring(found.max))
  end)

  it("states the mass driver's launch-from-a-world gate", function()
    local driver = prototypes.entity["cindra-mass-driver"]
    assert.is_not_nil(driver, "the mass driver must exist")
    local found
    for _, c in pairs(driver.surface_conditions or {}) do
      if c.property == "pressure" then found = c end
    end
    assert.is_not_nil(found, "the mass driver must carry its pressure gate")
    -- Stated independently of the prototype's own constant on purpose: the claim
    -- is "the driver keeps the silo's launch-from-a-world floor", not "the driver
    -- agrees with itself".
    assert.are.equal(1, found.min, "the driver launches from a world, never a space platform")
  end)

  it("never reaches for PlanetsLib in a game that does not have it", function()
    -- The dependency contract, made checkable: Cindra's surface-condition helpers
    -- delegate to PlanetsLib only when the player installed it, and the mod must
    -- be fully functional without it. The data stage writes down which backend it
    -- used (prototypes/surface-conditions.lua); in this run there is no library,
    -- so it must read "cindra". tests/test_planetslib_coload.lua reads the same
    -- record from the other side.
    if script.active_mods["PlanetsLib"] then return end
    local record = prototypes.mod_data["cindra-surface-conditions"]
    assert.is_not_nil(record, "the backend record must exist")
    assert.are.equal("cindra", record.data.backend,
      "with PlanetsLib absent the hand-rolled path must have done the work")
  end)

  it("leaves the vanilla clone sources' own gates untouched", function()
    -- Never-mutate-other-planets: editing conditions on a deep-copied prototype
    -- must not reach back into the vanilla table it came from. If it did, the
    -- vanilla heating tower and rocket silo would change on every planet.
    local function pressure(name)
      for _, c in pairs(prototypes.entity[name].surface_conditions or {}) do
        if c.property == "pressure" then return c end
      end
    end
    local tower = pressure("heating-tower")
    assert.is_not_nil(tower, "sanity: the vanilla heating tower is pressure-gated")
    assert.are.equal(10, tower.min, "Cindra must not have retuned the vanilla heating tower")
    local silo = pressure("rocket-silo")
    assert.is_not_nil(silo, "sanity: the vanilla rocket silo is pressure-gated")
    assert.are.equal(1, silo.min, "Cindra must not have retuned the vanilla rocket silo")
  end)
end)
