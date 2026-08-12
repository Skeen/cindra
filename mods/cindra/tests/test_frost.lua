-- FREEZE + FROST COVERAGE proof (ci-u92y, widened mod-wide by ci-qha1): on the
-- real Cindra surface, EVERY entity the mod adds either freezes in the dark or is
-- excused for a reason this suite MEASURES.
--
-- WHY THIS SUITE EXISTS. Freezing on the nightside is Cindra's core mechanic, and
-- for two releases the glass furnace was quietly immune to it: prototypes/lava.lua
-- cleared `heating_energy` to shed the foundry's Aquilo-sized power cost, not
-- knowing the engine also uses that field as the freeze switch. It ran forever in
-- the dark while an arc furnace beside it froze solid, wearing frost art it could
-- never show. Nothing failed; a human had to notice in a playtest (ci-6qyk). The
-- HUMAN RULING that followed -- "It should not be immune, I don't think anything
-- should be" -- is a MOD-WIDE invariant, so this suite measures the whole class,
-- not three hand-picked machines.
--
-- The class is enumerated LIVE from prototypes.entity, so an entity added later is
-- measured here without anyone remembering to list it, and the partition into
-- "must freeze" / "excused" comes from the SAME pure tables the load guard uses
-- (scripts/frost-audit.lua) -- the guard and the measurement can never disagree
-- about who is excused.
--
-- WHY MEASURE AT ALL, when the guard already reads heating_energy: because the
-- prototype tree LIES about this in both directions. `is_freezable` reports TRUE
-- for an entity whose heating_energy is 0, so it never actually freezes (that is
-- cindra-electric-heater today); and the engine silently IGNORES heating_energy on
-- some prototype types, so a declared draw is no protection at all (that is every
-- accumulator, solar panel and electric-energy-interface -- measured in ci-qha1).
-- Only the world can be believed, so:
--   * MUST-FREEZE entities are placed on never-heated ground and must end FROZEN,
--     and placed beside a hot emitter and must stay THAWED (frost is not
--     always-on).
--   * Entities excused because THE ENGINE REFUSES their type are asserted
--     `is_freezable == false`. That assertion IS what earns the exemption: if a
--     future Factorio starts freezing accumulators, this suite goes RED and the
--     exemption must be re-argued rather than quietly persisting.
--   * The one entity excused BY DESIGN (the electric heater, the thaw source) is
--     asserted to be freezable-in-principle yet never frozen -- proving the
--     immunity is our deliberate choice and not an engine limit.
--
-- The frost ART itself cannot be read back at runtime (LuaEntityPrototype exposes
-- no graphics accessor), so it is guarded where it can be: the data-stage audit
-- (prototypes/frost-audit.lua) and a pixel test on the created layer
-- (unit-tests/test_frost_layer.py). Both rest on ONE claim about the world -- that
-- these machines freeze at all -- and that claim is what this suite proves.
--
-- RELIABILITY (the ci-b5i lesson, same as tests/test_freeze.lua): a hot heat
-- source warms the ground TILES in reach and they DO NOT COOL on any test
-- timescale, so measurements that share ground contaminate each other. Worse, the
-- emitter's reach is a 101-tile Chebyshev SQUARE (scripts/freeze.lua), which is far
-- wider than it looks: an emitter dropped on a probe row silently thaws ~200 tiles
-- of it. So every row here works on its own FRESH, never-heated ground, far from
-- every other suite's and far from the warm row.

local H = require("tests.helpers")
local freeze = require("scripts.freeze")
local audit = require("scripts.frost-audit")

-- Fresh-ground base, parked far from tests/test_freeze.lua's cursor (100000+)
-- and from the origin work area. Rows are separated by more than the emitter's
-- 101-tile reach so the warm row cannot leak heat onto the cold one.
local BASE = 300000
-- Tiles between probes. Must clear the WIDEST Cindra entity: the mass driver is a
-- rocket-silo (9x9), so 14 (which cleared the 4x4 machines) is not enough.
local SPACING = 24

-- Every Cindra-added entity, live from the registry.
local function cindra_entities()
  local names = {}
  for name in pairs(prototypes.entity) do
    if name:sub(1, 7) == "cindra-" then names[#names + 1] = name end
  end
  table.sort(names) -- deterministic placement order
  return names
end

-- Split the class the same way the load guard does, from the SAME tables.
local function partition()
  local must, engine_refuses, by_design = {}, {}, {}
  for _, name in ipairs(cindra_entities()) do
    local proto = prototypes.entity[name]
    if audit.UNFREEZABLE_TYPES[proto.type] then
      engine_refuses[#engine_refuses + 1] = name
    elseif audit.FREEZE_EXEMPT[name] then
      by_design[#by_design + 1] = name
    else
      must[#must + 1] = name
    end
  end
  return must, engine_refuses, by_design
end

-- Generate + pave a flat, never-heated slab so probes never land on generated
-- lava/ice/void.
local function slab(s, x0, x1, y0, y1)
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local rad = math.ceil(math.max(x1 - x0, y1 - y0) / 2 / 32) + 2
  s.request_to_generate_chunks({ cx, cy }, rad)
  s.force_generate_chunk_requests()
  local tiles = {}
  for x = math.floor(x0), math.ceil(x1) do
    for y = math.floor(y0), math.ceil(y1) do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
end

-- Tear the probes back down. MANDATORY here, unlike in most suites: this one
-- places one of EVERY Cindra entity, and sibling suites count entities
-- surface-wide -- the five solar-band variants and the dissipator left lying at
-- BASE+3000 silently broke tests/test_panel_overload (9 panels found where 4 were
-- built) and tests/test_panel_damage_runtime's disposal sum. A measurement rig
-- must not become part of the world it measures.
local function clear(entities)
  for _, e in pairs(entities) do
    if e and e.valid then e.destroy() end
  end
end

describe("freeze coverage, mod-wide (ci-qha1)", function()
  it("EVERY Cindra entity that CAN freeze does freeze in the cold, and thaws by a heat source", function()
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false -- hand-placed heat only on this ground

    local machines = partition()
    -- The signature machines, the mass driver and the power diode all belong to
    -- this class; if it ever shrinks below that, something opted out.
    assert.is_true(#machines >= 5,
      "the must-freeze class must not shrink (arc furnace, glass furnace, oxidizer,"
      .. " mass driver, power diode at least), got " .. #machines
      .. ": " .. table.concat(machines, ", "))

    -- COLD ROW: no heat source anywhere near -- these must all freeze.
    local cold_y = BASE
    slab(s, -12, SPACING * (#machines + 1), cold_y - 12, cold_y + 12)
    -- WARM ROW: one hot emitter per machine, right beside it -- these must NOT
    -- freeze, so a frost sheen is never simply always-on.
    local warm_y = BASE + 1000
    slab(s, -12, SPACING * (#machines + 1), warm_y - 12, warm_y + 12)

    local cold, warm, emitters = {}, {}, {}
    for i, name in ipairs(machines) do
      local x = SPACING * i
      cold[name] = s.create_entity({ name = name, position = { x, cold_y }, force = "player" })
      assert.is_not_nil(cold[name], "failed to place " .. name .. " on the cold row")

      local e = s.create_entity({ name = freeze.EMITTER_NAME, position = { x - 6, warm_y }, force = "player" })
      assert(e, "failed to create lava-heat emitter for " .. name)
      e.temperature = freeze.EMITTER_TEMPERATURE
      emitters[#emitters + 1] = e
      warm[name] = s.create_entity({ name = name, position = { x, warm_y }, force = "player" })
      assert.is_not_nil(warm[name], "failed to place " .. name .. " on the warm row")
    end

    async(6000)
    after_ticks(5000, function()
      -- UNCONDITIONAL, for every entity in the class (ci-6qyk, widened ci-qha1).
      -- This loop used to branch on `heating_energy > 0` and merely assert that an
      -- entity WITHOUT a heating draw never freezes -- which is a restatement of
      -- the engine rule, not an invariant: anything could opt itself out of the
      -- planet's core mechanic by clearing one field, and the suite would go green
      -- agreeing with it. The glass furnace did exactly that for two releases. The
      -- expectation is now the design rule instead: on Cindra, EVERYTHING freezes
      -- in the dark. Something that should not must be named in
      -- scripts/frost-audit.lua's FREEZE_EXEMPT, with its reason.
      for _, name in ipairs(machines) do
        assert.is_true(cold[name].frozen,
          name .. " must FREEZE on never-heated ground with no heat source -- a Cindra"
          .. " entity that keeps working in the dark is exempt from the planet's core"
          .. " mechanic (usually because its prototype cleared heating_energy, which is"
          .. " also the engine's freeze switch: see ci-6qyk)")
        -- The other half, and it is load-bearing: something that is simply ALWAYS
        -- frozen would satisfy the assertion above and be just as broken.
        assert.is_false(warm[name].frozen,
          name .. " must stay THAWED beside a hot heat source (frost is not always-on)")

        -- Crafting machines additionally report the frozen STATUS, so a frozen one
        -- reads as stopped rather than working. Only this class is checked: other
        -- types (a power switch, a rocket silo) carry their own status vocabulary.
        local t = prototypes.entity[name].type
        if t == "assembling-machine" or t == "furnace" then
          assert.are.equal(defines.entity_status.frozen, cold[name].status,
            name .. " must report the frozen status (reads as stopped, not working)")
          assert.are_not.equal(defines.entity_status.frozen, warm[name].status,
            name .. " beside heat must not report frozen")
        end
      end
      clear(cold); clear(warm); clear(emitters)
      done()
    end)
  end)

  -- The exemptions, MEASURED rather than asserted by comment. This is what stops
  -- scripts/frost-audit.lua's allowlist from becoming a place to hide an accident.
  it("every entity excused because THE ENGINE REFUSES its type really is unfreezable", function()
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false

    local _, engine_refuses = partition()
    assert.is_true(#engine_refuses > 0, "the engine-refuses group must not be empty")

    -- Own ground, far from the freeze rows above.
    local y = BASE + 3000
    slab(s, -12, SPACING * (#engine_refuses + 1), y - 12, y + 12)

    local placed = {}
    for i, name in ipairs(engine_refuses) do
      local e = s.create_entity({ name = name, position = { SPACING * i, y }, force = "player" })
      assert.is_not_nil(e, "failed to place " .. name)
      placed[#placed + 1] = e
      -- No wait needed: is_freezable is the engine's own statement that it will
      -- never freeze this entity, and it is the whole justification for the
      -- exemption. Read it immediately -- some of these (the overload spark) reap
      -- themselves within a few ticks.
      assert.is_false(e.is_freezable,
        name .. " is excused from the freeze invariant because the ENGINE REFUSES its"
        .. " type (" .. prototypes.entity[name].type .. ", see UNFREEZABLE_TYPES in"
        .. " scripts/frost-audit.lua) -- but the engine now says it IS freezable, so"
        .. " that exemption is stale: fix the entity (give it heating_energy) or"
        .. " re-earn the exemption with a fresh measurement")
    end
    clear(placed)
  end)

  it("the electric heater is immune BY DESIGN, not by engine limit", function()
    -- The one named exemption (b): it is the THAW SOURCE, and a heater that
    -- freezes cannot thaw itself, so the nightside would be unrecoverable. Both
    -- halves matter. The engine WOULD freeze a reactor (is_freezable is true), so
    -- this is our deliberate choice -- and the choice actually holds in the world:
    -- on never-heated ground with no heat in reach, it keeps running.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false

    local _, _, by_design = partition()
    assert.are.same({ "cindra-electric-heater" }, by_design,
      "the design-exemption list is deliberately this short: a new entry needs a"
      .. " written reason in FREEZE_EXEMPT and its own measurement here")

    local y = BASE + 5000
    slab(s, -12, SPACING * (#by_design + 1), y - 12, y + 12)

    local placed = {}
    for i, name in ipairs(by_design) do
      placed[name] = s.create_entity({ name = name, position = { SPACING * i, y }, force = "player" })
      assert.is_not_nil(placed[name], "failed to place " .. name)
      assert.is_true(placed[name].is_freezable,
        name .. " is exempt BY DESIGN, so the engine must be able to freeze its type"
        .. " -- if it cannot, the honest home for it is UNFREEZABLE_TYPES (an engine"
        .. " limit), not FREEZE_EXEMPT (a design choice)")
    end

    async(6000)
    after_ticks(5000, function()
      for name, e in pairs(placed) do
        assert.is_false(e.frozen,
          name .. " must keep working on never-heated ground: it is the thaw source,"
          .. " and a frozen heater cannot thaw itself (the nightside would be"
          .. " permanently unrecoverable). See FREEZE_EXEMPT in scripts/frost-audit.lua")
      end
      clear(placed)
      done()
    end)
  end)

  it("the load guard's entity classification matches the engine's own registry", function()
    -- The data-stage guard cannot ask the engine what an entity is, so it decides
    -- from data.raw bucket names (ENTITY_TYPES / NON_ENTITY_TYPES). This is the
    -- cross-check that keeps those lists honest: at RUNTIME prototypes.entity IS
    -- the authoritative set of entities, so every type carrying a Cindra entity
    -- must classify as "entity" -- if it is misfiled as a non-entity, or in
    -- neither list, the guard cannot audit the entity's freeze behaviour and an
    -- immune entity could ship.
    local seen = {}
    for _, name in ipairs(cindra_entities()) do
      local t = prototypes.entity[name].type
      assert.equals("entity", audit.classify(t),
        name .. " is a real entity of type '" .. t .. "', but scripts/frost-audit.lua"
        .. " classifies that type as '" .. audit.classify(t) .. "' -- the load guard"
        .. " cannot audit its freeze behaviour, so it could ship immune. Put '" .. t
        .. "' in ENTITY_TYPES (and remove it from NON_ENTITY_TYPES if it is there).")
      seen[t] = true
    end
    -- And the tables must not rot the other way either: an entry describing a type
    -- Cindra no longer ships is dead weight that reads as a live exemption.
    for t in pairs(audit.UNFREEZABLE_TYPES) do
      if t ~= "constant-combinator" then -- the env-scanner's type, a sibling MOD's entity
        assert.is_true(seen[t] == true,
          "UNFREEZABLE_TYPES excuses type '" .. t .. "' but Cindra ships no entity of"
          .. " that type any more -- drop the stale exemption")
      end
    end
    for name in pairs(audit.FREEZE_EXEMPT) do
      assert.is_not_nil(prototypes.entity[name],
        "FREEZE_EXEMPT excuses '" .. name .. "' but no such entity exists any more"
        .. " -- drop the stale exemption")
    end
  end)

  it("ENTITY_TYPES is COMPLETE against every entity type the engine defines (ci-3ed3)", function()
    -- The other half of ci-3ed3. Classification is now two POSITIVE lists with an
    -- "unrecognised" third state that stops the load, which fixes the misleading
    -- message -- but only completeness stops the load from stopping needlessly.
    -- Both lists were enumerated in ONE PASS from this registry rather than grown
    -- one load failure at a time, and THIS is the assertion that keeps them
    -- complete: prototypes.entity is the engine's own authoritative list of entity
    -- prototypes, so every type appearing in it must already be classified as an
    -- entity. If Factorio (or a mod in the test set) introduces a new entity type,
    -- this fails here -- in a test naming the type -- instead of at some future
    -- author's data stage when they first ship a prototype of it.
    local missing = {}
    for _, proto in pairs(prototypes.entity) do
      if audit.classify(proto.type) ~= "entity" then missing[proto.type] = true end
    end
    local names = {}
    for t in pairs(missing) do names[#names + 1] = t end
    table.sort(names)
    assert.equals("", table.concat(names, ", "),
      "the engine defines entity prototype type(s) that scripts/frost-audit.lua does"
      .. " not classify as entities. Add each to ENTITY_TYPES (removing it from"
      .. " NON_ENTITY_TYPES if it is misfiled there): a Cindra entity of such a type"
      .. " would stop the load asking to be classified.")
  end)

  it("no type the engine calls an entity is filed as a NON-entity (ci-3ed3)", function()
    -- The dangerous misclassification, checked mod-wide rather than only over the
    -- types Cindra happens to ship today: a real entity type sitting in
    -- NON_ENTITY_TYPES would make the guard skip that entity silently, and silence
    -- is exactly how the glass furnace stayed immune for two releases (ci-6qyk).
    for _, proto in pairs(prototypes.entity) do
      assert.is_falsy(audit.NON_ENTITY_TYPES[proto.type],
        "'" .. proto.type .. "' is a real entity prototype type (e.g. " .. proto.name
        .. ") but is listed in NON_ENTITY_TYPES in scripts/frost-audit.lua -- a Cindra"
        .. " entity of that type would be skipped by the freeze guard entirely."
        .. " Move it to ENTITY_TYPES.")
    end
  end)
end)
