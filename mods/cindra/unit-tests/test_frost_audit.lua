-- Plain-Lua unit test for the pure frost auditor (scripts/frost-audit.lua).
-- Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_frost_audit.lua
--
-- Proves the auditor catches a Cindra crafting machine that would FREEZE BARE --
-- bespoke art assigned over the clone's graphics_set, taking the inherited
-- frozen_patch with it, so the machine freezes on the nightside showing no frost
-- while every building beside it wears one. That exact bug shipped twice
-- (ci-z7nu: oxidizer + glass furnace; ci-u92y: arc furnace), caught only by a
-- human playtest. The data-stage guard (prototypes/frost-audit.lua) runs this
-- same logic against the real prototypes and errors the load.

package.path = package.path .. ";./?.lua;./?/init.lua"
local audit = require("scripts.frost-audit")

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok - " .. name)
  else
    failed = failed + 1
    print("not ok - " .. name .. ": " .. tostring(err))
  end
end

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

local function assert_false(x, msg)
  if x then error(msg or "expected false", 2) end
end

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

-- A machine wearing bespoke art, with and without the frost layer. Machines
-- carry a heating draw (so they freeze) unless a test says otherwise.
local function bespoke(frozen_patch, reset, heating_energy)
  return {
    heating_energy = heating_energy == nil and "100kW" or heating_energy,
    graphics_set = {
      animation = { layers = { { filename = "__cindra__/graphics/entity/x/x.png" } } },
      frozen_patch = frozen_patch,
      reset_animation_when_frozen = reset,
    },
  }
end

local FROST = { filename = "__cindra__/graphics/entity/x/x-hr-frozen.png", width = 320, height = 320 }

test("a machine whose bespoke graphics_set dropped the frost patch is an offender", function()
  assert_false(audit.has_frost(bespoke(nil, true), "assembling-machine"),
    "a graphics_set with no frozen_patch must read as freezing bare")
end)

test("a machine with a created frost patch passes", function()
  assert_true(audit.has_frost(bespoke(FROST, true), "assembling-machine"))
  assert_true(audit.has_frost(bespoke(FROST, true), "furnace"), "furnaces use the same field")
end)

test("a Sprite4Way frost patch spelled per-direction also passes", function()
  local four_way = { north = FROST, east = FROST, south = FROST, west = FROST }
  assert_true(audit.has_frost(bespoke(four_way, true), "assembling-machine"),
    "a per-direction Sprite4Way patch is still a wired frost sheen")
end)

test("an EMPTY frozen_patch table does not count as frost", function()
  assert_false(audit.has_frost(bespoke({}, true), "assembling-machine"),
    "a patch with no sprite reference draws nothing")
end)

test("a machine with no graphics_set at all is an offender", function()
  assert_false(audit.has_frost({}, "assembling-machine"))
end)

test("types with no frozen-patch field are never required to have one", function()
  -- Accumulators / containers / heat pipes have no such engine field, so the
  -- audit must not demand art that could never render.
  assert_true(audit.has_frost({}, "accumulator"), "accumulator has no frozen-patch field")
  assert_true(audit.has_frost({}, "container"), "container has no frozen-patch field")
end)

test("a frozen machine must also halt its animation (reset_animation_when_frozen)", function()
  assert_false(audit.resets_animation(bespoke(FROST, nil), "assembling-machine"),
    "a frozen machine still running its work cycle under the ice reads as alive")
  assert_true(audit.resets_animation(bespoke(FROST, true), "assembling-machine"))
end)

-- === Only machines that ACTUALLY freeze need art ============================
-- Freezing needs heating_energy > 0 (the prototype API rule, measured in-engine in
-- tests/test_frost.lua, where every Cindra machine now carries a draw and freezes).
-- Demanding a frost layer from a machine that cannot freeze would be art no player can
-- ever see, so the predicate stays -- but note that clearing the field is a way to
-- switch OFF the planet's core mechanic for a machine, which is the ci-6qyk bug the
-- glass furnace shipped with; test_frost.lua is what stops that recurring.
test("heating_energy decides whether a machine can freeze at all", function()
  assert_true(audit.freezes({ heating_energy = "100kW" }))
  assert_true(audit.freezes({ heating_energy = "1MW" }))
  assert_true(audit.freezes({ heating_energy = 100000 }), "a numeric draw counts too")
  assert_false(audit.freezes({ heating_energy = "0kW" }), "a zero draw never freezes")
  assert_false(audit.freezes({ heating_energy = 0 }))
  assert_false(audit.freezes({}), "no heating draw at all: the machine never freezes")
end)

test("a machine that never freezes is NOT required to carry frost art", function()
  -- A synthetic machine only: bespoke art, no frost patch, heating draw cleared. No
  -- Cindra machine is shaped like this any more (the glass furnace was, until ci-6qyk),
  -- and tests/test_frost.lua now fails if one ever is again.
  local unheated = bespoke(nil, nil)
  unheated.heating_energy = nil
  local raw = { ["assembling-machine"] = { ["cindra-unheated-machine"] = unheated } }
  local bad = audit.offenders(raw, audit.discover(raw, {}))
  assert_eq(0, #bad, "a machine that cannot freeze needs no frost layer")
end)

-- === The standing audit: discover + offenders ===============================
test("discover enumerates EVERY cindra- crafting machine, not a hand-kept list", function()
  local raw = {
    ["assembling-machine"] = {
      ["cindra-arc-furnace"] = bespoke(FROST, true),
      ["cindra-lava-manufacturer"] = bespoke(FROST, true),
      ["assembling-machine-3"] = bespoke(nil, nil), -- vanilla: not ours to audit
    },
    ["furnace"] = { ["cindra-electrolysis-cell"] = bespoke(FROST, true) },
    ["accumulator"] = { ["cindra-capacitor"] = {} }, -- no frozen-patch field
  }
  local specs = audit.discover(raw, {})
  local names = {}
  for _, s in ipairs(specs) do names[s.name] = true end
  assert_true(names["cindra-arc-furnace"], "the arc furnace must be audited")
  assert_true(names["cindra-lava-manufacturer"], "the glass furnace must be audited")
  assert_true(names["cindra-electrolysis-cell"], "the oxidizer (a furnace) must be audited")
  assert_false(names["assembling-machine-3"], "vanilla prototypes are not ours to audit")
  assert_false(names["cindra-capacitor"], "an accumulator has no frozen-patch field to require")
  assert_eq(0, #audit.offenders(raw, specs), "a fully frosted set has no offenders")
end)

test("a NEW machine that ships without frost is caught by the standing audit", function()
  -- The whole point of discovering the class live: nobody has to remember to add
  -- the new machine to a list for the guard to fail.
  local raw = {
    ["assembling-machine"] = {
      ["cindra-arc-furnace"] = bespoke(FROST, true),
      ["cindra-brand-new-machine"] = bespoke(nil, true), -- bespoke art, frost dropped
    },
  }
  local bad = audit.offenders(raw, audit.discover(raw, {}))
  assert_eq(1, #bad, "exactly the bare machine is reported")
  assert_true(bad[1]:find("cindra-brand-new-machine", 1, true) ~= nil,
    "the offender must be named so the error says what to fix, got: " .. tostring(bad[1]))
end)

test("skip prefixes exclude a machine whose art is mid-rework", function()
  local raw = { ["assembling-machine"] = { ["cindra-mass-driver-x"] = bespoke(nil, nil) } }
  assert_eq(0, #audit.discover(raw, { "cindra-mass-driver" }), "the skipped prefix is not audited")
  assert_eq(1, #audit.discover(raw, {}), "without the skip it would be audited")
end)

-- ============================================================================
-- FREEZE IMMUNITY (ci-qha1): the guard must FAIL the load on an immune entity
-- ============================================================================
-- The guard's whole value is that it FAILS, so these tests prove the failure --
-- not merely that today's prototypes happen to pass. A guard that has never been
-- seen to reject anything is indistinguishable from no guard.

local function machine(heating)
  return { heating_energy = heating, graphics_set = { frozen_patch = FROST, reset_animation_when_frozen = true } }
end

test("a NEW Cindra entity of a freezable type with NO heat draw FAILS the guard", function()
  local raw = {
    ["assembling-machine"] = {
      ["cindra-arc-furnace"] = machine("100kW"),
      ["cindra-brand-new-machine"] = machine(nil), -- immune: nothing to freeze
    },
  }
  local bad = audit.freeze_immune(raw)
  assert_eq(1, #bad, "exactly the immune entity is reported")
  assert_true(bad[1]:find("cindra-brand-new-machine", 1, true) ~= nil,
    "the offender must be NAMED so the error says what to fix, got: " .. tostring(bad[1]))
  assert_true(bad[1]:find("assembling-machine", 1, true) ~= nil,
    "the offender's type must be reported too, got: " .. tostring(bad[1]))
end)

test("a heat draw of ZERO is still immune -- the exact glass-furnace shape", function()
  -- prototypes/lava.lua cleared the foundry's draw to shed its Aquilo-sized power
  -- cost, not knowing that field is also the freeze switch (ci-6qyk). A literal
  -- "0kW" reads as "configured" to a human skimming the file, which is why it must
  -- be caught rather than trusted.
  for _, dead in ipairs({ "0kW", 0, "0W" }) do
    local raw = { ["furnace"] = { ["cindra-glass-furnace"] = machine(dead) } }
    assert_eq(1, #audit.freeze_immune(raw), "heating_energy=" .. tostring(dead) .. " must not pass")
  end
end)

test("giving it a draw clears the guard", function()
  local raw = { ["assembling-machine"] = { ["cindra-brand-new-machine"] = machine("100kW") } }
  assert_eq(0, #audit.freeze_immune(raw))
end)

test("vanilla prototypes are not ours to police", function()
  -- The invariant is about entities CINDRA ADDS; vanilla keeps vanilla behaviour.
  local raw = { ["assembling-machine"] = { ["assembling-machine-3"] = machine(nil) } }
  assert_eq(0, #audit.freeze_immune(raw))
end)

test("an entity of a type the ENGINE REFUSES to freeze is excused", function()
  -- Measured in ci-qha1: heating_energy is accepted at the data stage and then
  -- ignored on these types, so demanding one would be a lie, not a fix.
  local raw = {
    ["accumulator"] = { ["cindra-capacitor"] = {} },
    ["solar-panel"] = { ["cindra-solar-band-b05"] = {} },
    ["electric-energy-interface"] = { ["cindra-dissipator"] = {} },
    ["resource"] = { ["cindra-ice"] = {} },
    ["simple-entity"] = { ["cindra-rock"] = {} },
  }
  assert_eq(0, #audit.freeze_immune(raw), "engine-refused types carry no requirement")
end)

test("a NAMED exemption is excused, and only by name", function()
  local raw = { ["reactor"] = { ["cindra-electric-heater"] = { heating_energy = nil } } }
  assert_eq(0, #audit.freeze_immune(raw), "the thaw source is exempt (reason in FREEZE_EXEMPT)")
  -- A reactor that is NOT the named heater gets no free ride: `reactor` is a
  -- freezable type (measured: cindra-electric-heater reports is_freezable=true).
  local other = { ["reactor"] = { ["cindra-second-heater"] = { heating_energy = nil } } }
  assert_eq(1, #audit.freeze_immune(other),
    "exemptions are per-entity, never per-type -- a second reactor must argue its own case")
end)

test("the guard FAILS CLOSED on an entity of an unrecognised type", function()
  -- The one way this guard could rot silently is by not recognising a new entity
  -- kind at all. An unknown bucket is therefore assumed to be a freezable entity:
  -- worst case someone must classify it, versus worst case something ships immune.
  local raw = { ["some-type-nobody-listed"] = { ["cindra-mystery-building"] = {} } }
  assert_eq(1, #audit.freeze_immune(raw),
    "an unknown entity type must be REQUIRED to freeze, not quietly skipped")
end)

test("non-entity prototypes are not entities", function()
  -- Items, recipes and technologies share the "cindra-" prefix and obviously
  -- cannot freeze; the discovery must not drag them in.
  local raw = {
    ["item"] = { ["cindra-aluminium"] = {} },
    ["recipe"] = { ["cindra-lava"] = {} },
    ["technology"] = { ["cindra-science"] = {} },
    ["tile"] = { ["cindra-ice-smooth"] = {} },
    ["optimized-decorative"] = { ["cindra-ice-decal"] = {} },
  }
  assert_eq(0, #audit.entity_specs(raw), "no entities here")
  assert_eq(0, #audit.freeze_immune(raw))
end)

test("a DATA-ONLY prototype does not trip the freeze guard", function()
  -- REGRESSION (ci-ndm9 x ci-qha1): this guard fails CLOSED, so any bucket it does
  -- not recognise is assumed to hold entities. A `mod-data` prototype is not an
  -- entity -- it is an inert record the data stage leaves for the runtime to read
  -- -- but it was absent from NON_ENTITY_TYPES, so the guard classified Cindra's
  -- backend marker as an immune building and hard-errored the whole load. The
  -- error message even prescribed adding heating_energy, which for a data record
  -- is nonsense: there is nothing there to freeze.
  --
  -- Fail-closed is the right default and stays; this pins the classification so
  -- the specific regression cannot return.
  local raw = {
    ["mod-data"] = {
      ["cindra-surface-conditions"] = { data = { backend = "cindra" } },
    },
  }
  assert_eq(0, #audit.entity_specs(raw), "a mod-data record is not an entity")
  assert_eq(0, #audit.freeze_immune(raw),
    "a data-only prototype must not be required to carry a heat draw")
  assert_eq(0, #audit.dead_heating(raw),
    "and it must not be reported by the inverse guard either")
end)

test("a heat draw on a type the engine IGNORES is reported as a dead field", function()
  -- The subtler offence: it freezes nothing AND it reads as protection to the next
  -- person who greps for heating_energy.
  local raw = { ["accumulator"] = { ["cindra-capacitor"] = { heating_energy = "100kW" } } }
  local dead = audit.dead_heating(raw)
  assert_eq(1, #dead, "the no-op draw must be reported")
  assert_true(dead[1]:find("cindra-capacitor", 1, true) ~= nil, "named, got: " .. tostring(dead[1]))
  assert_eq(0, #audit.dead_heating({ ["accumulator"] = { ["cindra-capacitor"] = {} } }),
    "no draw declared, nothing to report")
  assert_eq(0, #audit.dead_heating({ ["furnace"] = { ["cindra-x"] = { heating_energy = "100kW" } } }),
    "a draw on a type the engine DOES honour is the correct state, not an offence")
end)

test("entity_specs enumerates the class LIVE and in a stable order", function()
  local raw = {
    ["furnace"] = { ["cindra-electrolysis-cell"] = {} },
    ["assembling-machine"] = { ["cindra-arc-furnace"] = {}, ["assembling-machine-3"] = {} },
    ["accumulator"] = { ["cindra-capacitor"] = {} },
    ["item"] = { ["cindra-aluminium"] = {} },
  }
  local specs = audit.entity_specs(raw)
  assert_eq(3, #specs, "three Cindra entities, no items, no vanilla")
  assert_eq("cindra-arc-furnace", specs[1].name, "sorted, so load errors are deterministic")
  assert_eq("cindra-capacitor", specs[2].name)
  assert_eq("cindra-electrolysis-cell", specs[3].name)
  assert_eq("accumulator", specs[2].type, "the type travels with the name")
end)

test("EVERY exemption carries a written reason", function()
  -- The ci-qha1 rule: an exemption is a sentence someone had to write, not a flag.
  -- An empty reason is how an accident would dress itself up as a decision.
  local n = 0
  for name, reason in pairs(audit.FREEZE_EXEMPT) do
    n = n + 1
    assert_eq("string", type(reason), name .. " must state WHY it is exempt")
    assert_true(#reason > 30, name .. "'s reason must be a real explanation, not a word")
  end
  assert_true(n <= 3, "the design-exemption list must stay SHORT; got " .. n .. " entries")
  for t, reason in pairs(audit.UNFREEZABLE_TYPES) do
    assert_eq("string", type(reason), t .. " must state why the engine refuses it")
    assert_true(#reason > 30, t .. "'s reason must be a real explanation, not a word")
  end
end)

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
