-- Pure freeze/frost auditor for Cindra's custom entities (ci-u92y, ci-qha1,
-- ci-3ed3, ci-de55).
--
-- THREE invariants live here:
--   1. FREEZE COVERAGE (ci-qha1, bottom half) -- no Cindra-added entity may be
--      IMMUNE to the planet's freeze mechanic. The durable half: it decides
--      whether a Cindra entity is allowed to keep working in the dark at all.
--   2. SCRIPT FREEZE (ci-de55, after it) -- the engine refuses to freeze some
--      prototype types AT ALL, so for those Cindra freezes the BUILDINGS itself.
--      Every refused type is sorted into "we freeze it" or "here is why not".
--   3. FROST COVERAGE (ci-u92y, this half) -- anything that freezes, natively or
--      by script, must wear the ice, so the freeze is visible.
-- All three are enforced as a load-time guard (prototypes/frost-audit.lua) over
-- the class discovered LIVE from the registry, so a new entity cannot ship immune
-- or bare by accident.
--
-- Between them sits the question they all depend on and none can duck: is a given
-- data.raw bucket an ENTITY bucket at all? The data stage cannot ask the engine,
-- so it is answered by two positive lists plus an explicit "unrecognised" state
-- (M.classify, ci-3ed3). And because a load failure's whole value is the sentence
-- it prints, the report is returned as DATA (M.problems) rather than assembled
-- inside the guard -- so the text a developer reads is itself under test.
--
-- WHY THIS EXISTS: Cindra's planet carries `entities_require_heating`, so its
-- machines FREEZE for real on the nightside, and the engine draws the frost
-- sheen ONLY from a `frozen_patch` sprite. Every Cindra signature machine is a
-- vanilla clone wearing bespoke art, and that art REPLACES the clone's
-- `graphics_set` wholesale -- which silently takes the inherited `frozen_patch`
-- with it. The machine then freezes with NO frost while every building beside it
-- wears one. That has now happened TWICE: the oxidizer + glass furnace (ci-z7nu)
-- and the arc furnace (ci-u92y). Nothing failed either time; a human had to
-- notice in a playtest.
--
-- So the invariant is enforced as a STANDING audit rather than three hand-written
-- assertions: every Cindra crafting machine must define a frost patch, and a NEW
-- one cannot ship without it (prototypes/frost-audit.lua errors the load, so the
-- whole test suite fails to boot).
--
-- SCOPE -- crafting machines that ACTUALLY FREEZE, deliberately.
-- `assembling-machine` and `furnace` both render through a
-- CraftingMachineGraphicsSet, the one field pair (`graphics_set.frozen_patch` +
-- `reset_animation_when_frozen`) where this bug class lives, and their freezing
-- is measured in-engine (tests/test_frost.lua). A machine that cannot freeze
-- (see M.freezes) is passed over -- demanding frost art it can never show would
-- be busywork, not a guard.
-- Other Cindra entity types are NOT audited yet:
--   * the power diode (a power-switch clone) takes a TOP-LEVEL frozen_patch, and
--     the mass driver (rocket-silo) is mid-rework and skipped by the sibling
--     graphics audit too. Neither has a created frost layer yet.
--   * accumulators / containers / heat pipes / poles have no frozen-patch field
--     in the engine at all, so there is nothing to require.
-- Extend FROST_FIELDS (and create the art) when one of those grows a frost layer.
--
-- PURE: no game.* / data.* / prototypes.* access. It takes a data.raw-like table
-- and returns the names that would freeze bare, so the logic is unit-testable off
-- the game (unit-tests/test_frost_audit.lua) and reusable by the data-stage guard.

local M = {}

-- Where the ENGINE reads a frozen patch from, per prototype type: the graphics
-- field, then the key inside it. Verified against the vanilla wiring
-- (space-age/prototypes/entity/base-frozen-graphics.lua) and the prototype API
-- (frozen_patch + reset_animation_when_frozen live on CraftingMachineGraphicsSet).
M.FROST_FIELDS = {
  ["assembling-machine"] = { set = "graphics_set", key = "frozen_patch" },
  ["furnace"]            = { set = "graphics_set", key = "frozen_patch" },
}

-- Does this machine actually FREEZE? Per the prototype API, an entity can freeze
-- only if `heating_energy` is larger than zero -- it is the heat draw the machine
-- must be fed to stay thawed. Space Age sets it on the vanilla machines in its
-- DATA stage (space-age/data.lua requires base-data-updates), so a Cindra clone
-- inherits it unless the clone deliberately clears it.
--
-- Measured in-engine (tests/test_frost.lua): today EVERY Cindra crafting machine
-- carries a draw and freezes on the nightside, so this predicate passes them all.
-- It is kept as a predicate rather than hard-coded true because freezability of the
-- TYPE is not enough: `is_freezable` reports true even for a machine whose
-- heating_energy is cleared, and demanding frost art from a machine that can never
-- show it would be busywork. This is the honest predicate.
--
-- It is NOT an invitation to clear the field. The glass furnace did exactly that for
-- two releases -- prototypes/lava.lua dropped "the Aquilo cold-planet heating draw",
-- not realising it was also switching off the planet's core nightside mechanic for
-- that machine -- and this audit dutifully stopped requiring the frost art it was
-- already wearing. That is fixed (ci-6qyk), and tests/test_frost.lua now requires
-- every machine in this class to actually freeze, so the two guards can no longer
-- agree with each other about a machine that quietly opted out.
function M.freezes(proto)
  if type(proto) ~= "table" then return false end
  local e = proto.heating_energy
  if e == nil then return false end
  if type(e) == "number" then return e > 0 end
  -- Energy values are strings like "100kW" / "0kW"; the unit cannot rescue a
  -- leading zero, so the numeric part alone decides.
  local n = tonumber(tostring(e):match("^%s*([%d%.]+)"))
  return n ~= nil and n > 0
end

-- Recursively true if `v` holds a real sprite reference (a non-empty `filename`,
-- or a non-empty `filenames` list). A Sprite4Way frozen patch may spell the
-- sprite directly or per-direction, so both shapes have to count.
local function has_sprite(v)
  if type(v) ~= "table" then return false end
  if type(v.filename) == "string" and v.filename ~= "" then return true end
  if type(v.filenames) == "table" and #v.filenames > 0 then return true end
  for _, child in pairs(v) do
    if has_sprite(child) then return true end
  end
  return false
end
M.has_sprite = has_sprite

-- Does `proto` wear a frost patch the engine will actually draw for its type?
function M.has_frost(proto, proto_type)
  if type(proto) ~= "table" then return false end
  local field = M.FROST_FIELDS[proto_type]
  if not field then return true end -- type has no frozen-patch field: nothing to require
  local set = proto[field.set]
  if type(set) ~= "table" then return false end
  return has_sprite(set[field.key])
end

-- Does a frozen machine halt its animation on frame 0 (reading as stopped, the
-- vanilla behaviour) instead of running its work cycle under the ice?
function M.resets_animation(proto, proto_type)
  local field = M.FROST_FIELDS[proto_type]
  if not field then return true end
  local set = proto[field.set]
  return type(set) == "table" and set.reset_animation_when_frozen == true
end

-- Given `raw` (a data.raw-like table) and `specs` (list of {type=, name=}),
-- return the list of spec names that WILL freeze but show no frost sheen, or
-- whose animation keeps running while frozen. Each entry is "name (reason)".
-- Machines that never freeze are passed over: they need no art.
function M.offenders(raw, specs)
  local bad = {}
  for _, spec in ipairs(specs) do
    local proto = raw[spec.type] and raw[spec.type][spec.name]
    if M.freezes(proto) then
      if not M.has_frost(proto, spec.type) then
        bad[#bad + 1] = spec.name .. " (freezes, no " .. M.FROST_FIELDS[spec.type].key .. ")"
      elseif not M.resets_animation(proto, spec.type) then
        bad[#bad + 1] = spec.name .. " (freezes, no reset_animation_when_frozen)"
      end
    end
  end
  return bad
end

-- Discover every custom Cindra entity (name prefixed "cindra-") of a type that
-- HAS a frozen-patch field, skipping any name matching an entry in
-- `skip_prefixes`. Enumerating the class LIVE from the registry -- not from a
-- hand-kept list -- is what makes a NEW machine unable to ship bare.
function M.discover(raw, skip_prefixes)
  skip_prefixes = skip_prefixes or {}
  local specs = {}
  for proto_type in pairs(M.FROST_FIELDS) do
    local bucket = raw[proto_type]
    if bucket then
      for name in pairs(bucket) do
        if name:sub(1, 7) == "cindra-" then
          local skip = false
          for _, prefix in ipairs(skip_prefixes) do
            if name:sub(1, #prefix) == prefix then skip = true break end
          end
          if not skip then specs[#specs + 1] = { type = proto_type, name = name } end
        end
      end
    end
  end
  return specs
end

-- ============================================================================
-- FREEZE COVERAGE (ci-qha1): no Cindra-added entity may be IMMUNE to the freeze
-- ============================================================================
--
-- HUMAN RULING (2026-08-12): "It should not be immune, I don't think anything
-- should be." Freezing on the nightside is Cindra's CORE mechanic, so a Cindra
-- building that keeps working in the dark is not a balance detail -- it opts out
-- of the planet.
--
-- Before ci-qha1 exactly ONE line in the whole mod touched `heating_energy`
-- (prototypes/lava.lua, which CLEARED it): every other Cindra entity inherited
-- its freeze behaviour from whichever vanilla prototype it was deep-copied from.
-- Freeze behaviour was an accident of ancestry, not a decision. This audit makes
-- it a decision: heating_energy > 0 IS the engine's freeze switch, so every
-- Cindra entity either carries a draw, or is exempt for a reason WRITTEN DOWN
-- below.
--
-- MEASURED, NOT REASONED. Everything in the two tables below was measured
-- in-engine on the real Cindra surface (tests/test_frost.lua re-measures it every
-- run). That matters, because the prototype tree lies about this in both
-- directions: `is_freezable` reports TRUE for an entity whose heating_energy is 0
-- (so it never actually freezes), and the engine silently IGNORES heating_energy
-- on some prototype types altogether (so a draw is no protection at all).

-- === PROTOTYPE CLASSIFICATION (ci-3ed3) =====================================
-- "Is this data.raw bucket an ENTITY bucket?" is answered by TWO POSITIVE lists,
-- and a bucket in neither is UNRECOGNISED -- a third state, not a default.
--
-- WHY IT IS SHAPED THIS WAY. This started as a single DENY-list: every bucket was
-- an entity bucket unless its type was listed as non-entity. That is fail-closed,
-- which is right -- but it lies about the SIZE of the mistake it caught. A brand
-- new NON-entity type (`mod-data`, a pure data-storage prototype with no owner,
-- no health and no freeze) was audited as an entity, found to carry no
-- heating_energy, and hard-failed the load with
--
--   entity/entities IMMUNE to the planet's freeze mechanic:
--   cindra-surface-conditions (mod-data, heating_energy=nil)
--
-- which is false in every clause and sends the reader off to add a heat draw to a
-- prototype that has nothing to heat (ci-3ed3, observed live; it blocked ci-ndm9).
-- The deny-list's polarity GUARANTEED that recurrence: the default classification
-- for a type nobody had thought about was "entity".
--
-- The fail-closed intent is preserved and in fact strengthened. An unrecognised
-- type STILL fails the load -- see M.unclassified + the guard in
-- prototypes/frost-audit.lua -- it just fails with the true statement ("classify
-- this type") instead of a fabricated one ("this entity is immune"). And it now
-- fails even when the mystery prototype happens to carry a heating_energy, which
-- the deny-list waved through. So there is no path by which a new Cindra ENTITY
-- ships immune: either its type is in ENTITY_TYPES and the freeze audit below
-- applies to it, or the load stops until someone classifies it.
--
-- Both lists were enumerated in ONE PASS from the running engine (Factorio 2.1
-- base + Space Age: 132 entity types, and every remaining data.raw bucket), so
-- they are COMPLETE rather than discovered one load failure at a time.
-- tests/test_frost.lua re-derives the entity set from the engine's own registry
-- every run and fails if a type is missing or misfiled, so completeness is
-- checked rather than claimed.
--
-- Scope note: the guard runs at the END of cindra's own data stage, so it sees
-- every Cindra prototype and nothing added later. The sibling mods (cindra-start,
-- cindra-dev-default) and third-party libraries (PlanetsLib) reach us from
-- data-updates / data-final-fixes, i.e. AFTER this -- deliberately out of scope,
-- since policing another mod's prototypes is not this guard's job.

-- data.raw buckets that ARE entity prototypes (LuaEntityPrototype). A Cindra
-- prototype in one of these must satisfy the freeze invariant below.
M.ENTITY_TYPES = {
  ["accumulator"] = true, ["agricultural-tower"] = true,
  ["ammo-turret"] = true, ["arithmetic-combinator"] = true,
  ["arrow"] = true, ["artillery-flare"] = true,
  ["artillery-projectile"] = true, ["artillery-turret"] = true,
  ["artillery-wagon"] = true, ["assembling-machine"] = true,
  ["asteroid"] = true, ["asteroid-collector"] = true, ["beacon"] = true,
  ["beam"] = true, ["boiler"] = true, ["burner-generator"] = true,
  ["capture-robot"] = true, ["car"] = true, ["cargo-bay"] = true,
  ["cargo-landing-pad"] = true, ["cargo-pod"] = true,
  ["cargo-wagon"] = true, ["character"] = true,
  ["character-corpse"] = true, ["cliff"] = true, ["combat-robot"] = true,
  ["constant-combinator"] = true, ["construction-robot"] = true,
  ["container"] = true, ["corpse"] = true, ["curved-rail-a"] = true,
  ["curved-rail-b"] = true, ["decider-combinator"] = true,
  ["deconstructible-tile-proxy"] = true, ["display-panel"] = true,
  ["electric-energy-interface"] = true, ["electric-pole"] = true,
  ["electric-turret"] = true, ["elevated-curved-rail-a"] = true,
  ["elevated-curved-rail-b"] = true,
  ["elevated-half-diagonal-rail"] = true,
  ["elevated-straight-rail"] = true, ["entity-ghost"] = true,
  ["explosion"] = true, ["fire"] = true, ["fish"] = true,
  ["fluid-turret"] = true, ["fluid-wagon"] = true, ["furnace"] = true,
  ["fusion-generator"] = true, ["fusion-reactor"] = true, ["gate"] = true,
  ["generator"] = true, ["half-diagonal-rail"] = true,
  ["heat-interface"] = true, ["heat-pipe"] = true,
  ["highlight-box"] = true, ["infinity-cargo-wagon"] = true,
  ["infinity-container"] = true, ["infinity-pipe"] = true,
  ["inserter"] = true, ["item-entity"] = true,
  ["item-request-proxy"] = true, ["lab"] = true, ["lamp"] = true,
  ["land-mine"] = true, ["lane-splitter"] = true,
  ["legacy-curved-rail"] = true, ["legacy-straight-rail"] = true,
  ["lightning"] = true, ["lightning-attractor"] = true,
  ["linked-belt"] = true, ["linked-container"] = true, ["loader"] = true,
  ["loader-1x1"] = true, ["locomotive"] = true,
  ["logistic-container"] = true, ["logistic-robot"] = true,
  ["market"] = true, ["mining-drill"] = true, ["offshore-pump"] = true,
  ["particle-source"] = true, ["pipe"] = true, ["pipe-to-ground"] = true,
  ["plant"] = true, ["power-switch"] = true,
  ["programmable-speaker"] = true, ["projectile"] = true,
  ["proxy-container"] = true, ["pump"] = true, ["radar"] = true,
  ["rail-chain-signal"] = true, ["rail-ramp"] = true,
  ["rail-remnants"] = true, ["rail-signal"] = true,
  ["rail-support"] = true, ["reactor"] = true, ["resource"] = true,
  ["roboport"] = true, ["rocket-silo"] = true,
  ["rocket-silo-rocket"] = true, ["rocket-silo-rocket-shadow"] = true,
  ["segment"] = true, ["segmented-unit"] = true,
  ["selector-combinator"] = true, ["simple-entity"] = true,
  ["simple-entity-with-force"] = true, ["simple-entity-with-owner"] = true,
  ["smoke-with-trigger"] = true, ["solar-panel"] = true,
  ["space-platform-hub"] = true, ["speech-bubble"] = true,
  ["spider-leg"] = true, ["spider-unit"] = true, ["spider-vehicle"] = true,
  ["splitter"] = true, ["sticker"] = true, ["storage-tank"] = true,
  ["straight-rail"] = true, ["stream"] = true,
  ["temporary-container"] = true, ["thruster"] = true,
  ["tile-ghost"] = true, ["train-stop"] = true, ["transport-belt"] = true,
  ["tree"] = true, ["turret"] = true, ["underground-belt"] = true,
  ["unit"] = true, ["unit-spawner"] = true, ["valve"] = true,
  ["wall"] = true,
}

-- data.raw buckets that are NOT entity prototypes: items, recipes, achievements,
-- equipment, GUI/utility singletons, and the data-only prototypes. A Cindra
-- prototype here has no owner, no health and no freeze, so the freeze invariant
-- does not apply and must not be reported against it.
--
-- Two entries earn a note, because they are the ones that have actually bitten:
--   * `optimized-decorative` -- decoratives are their OWN prototype class
--     (LuaDecorativePrototype), not entities. It reads like an entity type and is
--     not one.
--   * `mod-data` -- a pure data-storage prototype (ci-3ed3): the type whose
--     misclassification is the reason this file now has two lists instead of one.
M.NON_ENTITY_TYPES = {
  ["achievement"] = true, ["active-defense-equipment"] = true,
  ["airborne-pollutant"] = true, ["ambient-sound"] = true, ["ammo"] = true,
  ["ammo-category"] = true, ["ammo-item"] = true, ["armor"] = true,
  ["asteroid-chunk"] = true,
  ["autoplace-control"] = true, ["battery-equipment"] = true,
  ["belt-immunity-equipment"] = true, ["blueprint"] = true,
  ["blueprint-book"] = true, ["build-entity-achievement"] = true,
  ["burner-usage"] = true, ["capsule"] = true,
  ["chain-active-trigger"] = true, ["change-surface-achievement"] = true,
  ["collision-layer"] = true, ["combat-robot-count-achievement"] = true,
  ["complete-objective-achievement"] = true,
  ["construct-with-robots-achievement"] = true, ["copy-paste-tool"] = true,
  ["create-platform-achievement"] = true, ["custom-input"] = true,
  ["damage-type"] = true, ["deconstruct-with-robots-achievement"] = true,
  ["deconstruction-item"] = true, ["delayed-active-trigger"] = true,
  ["deliver-by-robots-achievement"] = true, ["deliver-category"] = true,
  ["deliver-impact-combination"] = true,
  ["deplete-resource-achievement"] = true,
  ["destroy-cliff-achievement"] = true,
  ["dont-build-entity-achievement"] = true,
  ["dont-craft-manually-achievement"] = true,
  ["dont-kill-manually-achievement"] = true,
  ["dont-research-before-researching-achievement"] = true,
  ["dont-use-entity-in-energy-production-achievement"] = true,
  ["editor-controller"] = true,
  ["electric-energy-interface-equipment"] = true,
  ["energy-shield-equipment"] = true, ["equip-armor-achievement"] = true,
  ["equipment-category"] = true, ["equipment-ghost"] = true,
  ["equipment-grid"] = true, ["fluid"] = true, ["font"] = true,
  ["fuel-category"] = true, ["generator-equipment"] = true,
  ["god-controller"] = true, ["group-attack-achievement"] = true,
  ["gui-style"] = true, ["gun"] = true, ["impact-category"] = true,
  ["inventory-bonus-equipment"] = true, ["item"] = true,
  ["item-group"] = true, ["item-subgroup"] = true,
  ["item-with-entity-data"] = true, ["kill-achievement"] = true,
  ["map-gen-presets"] = true, ["map-settings"] = true, ["mod-data"] = true,
  ["module"] = true, ["module-category"] = true,
  ["module-transfer-achievement"] = true, ["mouse-cursor"] = true,
  ["movement-bonus-equipment"] = true, ["night-vision-equipment"] = true,
  ["noise-expression"] = true, ["noise-function"] = true,
  ["optimized-decorative"] = true, ["optimized-particle"] = true,
  ["place-equipment-achievement"] = true, ["planet"] = true,
  ["player-damaged-achievement"] = true, ["procession"] = true,
  ["procession-layer-inheritance-group"] = true,
  ["produce-achievement"] = true, ["produce-per-hour-achievement"] = true,
  ["quality"] = true, ["rail-planner"] = true, ["recipe"] = true,
  ["recipe-category"] = true, ["remote-controller"] = true,
  ["repair-tool"] = true, ["research-achievement"] = true,
  ["research-with-science-pack-achievement"] = true,
  ["resource-category"] = true, ["roboport-equipment"] = true,
  ["selection-tool"] = true, ["shoot-achievement"] = true,
  ["shortcut"] = true, ["solar-panel-equipment"] = true, ["sound"] = true,
  ["space-connection"] = true,
  ["space-connection-distance-traveled-achievement"] = true,
  ["space-location"] = true, ["space-platform-starter-pack"] = true,
  ["spectator-controller"] = true, ["spidertron-remote"] = true,
  ["sprite"] = true, ["surface"] = true, ["surface-property"] = true,
  ["technology"] = true, ["tile"] = true, ["tile-effect"] = true,
  ["tips-and-tricks-item"] = true,
  ["tips-and-tricks-item-category"] = true, ["tool"] = true,
  ["train-path-achievement"] = true, ["trigger-target-type"] = true,
  ["trivial-smoke"] = true, ["tutorial"] = true, ["upgrade-item"] = true,
  ["use-entity-in-energy-production-achievement"] = true,
  ["use-item-achievement"] = true, ["utility-constants"] = true,
  ["utility-sounds"] = true, ["utility-sprites"] = true,
  ["virtual-signal"] = true,
}

-- "entity" | "non-entity" | "unknown". The third answer is the point: it is what
-- lets the guard demand a CLASSIFICATION instead of inventing a freeze problem.
function M.classify(proto_type)
  if M.ENTITY_TYPES[proto_type] then return "entity" end
  if M.NON_ENTITY_TYPES[proto_type] then return "non-entity" end
  return "unknown"
end

-- Prototype types the ENGINE REFUSES TO FREEZE -- exemption (a), and by far the
-- largest group. Each was MEASURED (ci-qha1): heating_energy = "100kW" was set on
-- a Cindra entity of the type, and the entity was then placed on never-heated
-- Cindra ground with no heat source in reach. All of them still reported
-- `is_freezable = false` and never froze. The engine ACCEPTS the field at the
-- data stage and then ignores it.
--
-- SINCE ci-de55 THIS IS NO LONGER A FREE PASS. The engine limit stands, but the
-- HUMAN RULING ("nothing should be immune") does not bend to it: a Cindra
-- BUILDING of one of these types is now frozen BY SCRIPT instead
-- (scripts/script-freeze.lua). Every type below is therefore additionally sorted,
-- one screen down, into SCRIPT_FROZEN_TYPES (we freeze it ourselves) or
-- SCRIPT_FREEZE_EXEMPT_TYPES (with a written reason why freezing it is
-- meaningless or incoherent) -- and a type in neither stops the load.
--
-- Cross-check, same conclusion: Space Age assigns heating_energy to 26 prototype
-- types (assembling-machine, furnace, inserter, belts, pipe, pump, beacon, radar,
-- roboport, storage-tank, rocket-silo, power-switch, turrets, valves, combinators,
-- mining-drill, lab, generator, agricultural-tower, ...) and to NONE of the types
-- below -- and vanilla Aquilo agrees: accumulators and solar panels work there.
--
-- So these are NOT inheritance accidents to fix; they are a wall. The one already
-- known before ci-qha1 is the env-scanner radio station (a constant-combinator,
-- measured in ci-u92y): re-typing it to something freezable would destroy the
-- writable output section the entity exists for (ci-6jz). The same is true of the
-- rest -- an accumulator that is not an accumulator is not a battery bank.
--
-- THIS TABLE IS A MEASUREMENT, NOT A RULING, and that is why ci-de55 left it
-- standing rather than deleting the entries it now script-freezes. It records
-- what the ENGINE does, and that has not changed: removing `accumulator` from it
-- would make the freeze audit below demand a heating_energy on the capacitor --
-- a field the engine ignores -- which the dead-heating audit would then correctly
-- report as fake protection. What ci-de55 changed is that being on this list no
-- longer EXCUSES anything (see the split below).
--
-- Adding a type here requires the measurement, not an argument. tests/test_frost.lua
-- asserts `is_freezable == false` for every entity of a type in this table, so if a
-- future Factorio starts freezing accumulators the suite goes RED and the
-- classification has to be re-earned.
M.UNFREEZABLE_TYPES = {
  ["accumulator"] = "the engine never freezes an accumulator (measured with a"
    .. " 100kW draw set): cindra-capacitor + cindra-molten-salt-battery",
  ["solar-panel"] = "the engine never freezes a solar panel (measured): the"
    .. " cindra-solar-band-* output variants",
  ["electric-energy-interface"] = "the engine never freezes an"
    .. " electric-energy-interface (measured): cindra-dissipator, and the power"
    .. " diode's hidden buffers -- which are script-freeze exempt BY NAME, invisible helpers",
  ["electric-pole"] = "the engine never freezes a pole (measured): the power"
    .. " diode's hidden taps -- script-freeze exempt by TYPE, inert conductors",
  ["heat-pipe"] = "the engine never freezes a heat pipe (measured). This is where"
    .. " cindra-lava-heat lands: the ambient emitter IS the thaw mechanism, so a"
    .. " frozen one would be incoherent -- script-freeze exempt by TYPE for exactly"
    .. " that reason",
  ["constant-combinator"] = "the engine never freezes a constant combinator"
    .. " (measured in ci-u92y with a 20kW draw set) -- the env-scanner radio"
    .. " station's wall; re-typing it would destroy its writable output section",
  ["explosion"] = "an explosion is a transient visual effect that reaps itself,"
    .. " not a building: cindra-panel-overload-spark",
  ["simple-entity"] = "worldgen scenery (rocks/icebergs), not a building: the"
    .. " engine has no freeze for it and there is nothing to stop working",
  ["resource"] = "an ore patch is not a building: cindra-stone + cindra-ice",
}

-- ============================================================================
-- SCRIPT FREEZE (ci-de55): the engine's refusal is not the last word
-- ============================================================================
--
-- MAYOR'S RULING (2026-08-12, on the human's "nothing should be immune"): the
-- buildings above are frozen BY SCRIPT. The engine will not do it, and pairing
-- each with a hidden freezable companion was rejected on UPS grounds (a solar
-- farm would double its entity count), so the runtime does it directly: a slow
-- per-surface sweep swaps a building that sits outside every hot heat source's
-- reach for a FROZEN TWIN prototype -- same buffer, zero flow, zero production,
-- wearing frost -- and swaps it back when heat returns
-- (scripts/script-freeze.lua, prototypes/frozen-twins.lua).
--
-- WHY A TWIN RATHER THAN A FLAG. Measured in-engine: `LuaEntity.frozen` and
-- `LuaEntity.active` are both READ ONLY on these types, and `electric_buffer_size`
-- is writable only on an electric-energy-interface. There is no runtime switch to
-- flip, so the only way to make an accumulator stop moving joules -- or a solar
-- panel stop making them -- is to make it a DIFFERENT PROTOTYPE for as long as it
-- is frozen. That also gets the visual cue for free: the twin's own art carries
-- the frost, exactly as a natively-frozen machine's `frozen_patch` does, instead
-- of a per-entity render object the sweep would have to bookkeep.
--
-- The two lists below split UNFREEZABLE_TYPES in half, and the split is a
-- PARTITION (checked in unit-tests/test_frost_audit.lua): every type the engine
-- refuses is either one we freeze ourselves or one we have written down a reason
-- not to. A type in neither stops the load -- the same fail-closed shape as
-- classification, for the same reason: the alternative is a new building quietly
-- inheriting immunity.

-- Suffix of a frozen twin. A name carrying it IS the frozen form of the name
-- without it, so the twins are excluded from the script-freeze class itself
-- (they are the destination, not a candidate).
M.FROZEN_SUFFIX = "-frozen"

function M.frozen_name(name) return name .. M.FROZEN_SUFFIX end

function M.is_frozen_name(name)
  return #name > #M.FROZEN_SUFFIX and name:sub(-#M.FROZEN_SUFFIX) == M.FROZEN_SUFFIX
end

-- The live name a frozen twin thaws back to, or nil if `name` is not a twin.
function M.thawed_name(name)
  if not M.is_frozen_name(name) then return nil end
  return name:sub(1, #name - #M.FROZEN_SUFFIX)
end

-- Types the runtime knows how to neutralise, and HOW. The neutralisation is what
-- makes the freeze real rather than cosmetic, so it is stated here beside the
-- type rather than buried in the twin builder: each is the engine-native way to
-- take that type out of the power economy without destroying a joule.
M.SCRIPT_FROZEN_TYPES = {
  ["accumulator"] = "input_flow_limit + output_flow_limit driven to 0: the stored"
    .. " charge is still there (the twin keeps the same buffer_capacity and the swap"
    .. " copies `energy` across) but nothing can enter or leave it",
  ["solar-panel"] = "the twin is an inert electric-energy-interface wearing the"
    .. " panel's art -- see FROZEN_TWIN_TYPE for why it cannot stay a solar panel",
  ["electric-energy-interface"] = "energy_usage + input_flow_limit driven to 0: a"
    .. " frozen dissipator swallows nothing, so it stops being disposal capacity",
}

-- A twin is normally the SAME prototype type as the building it replaces -- the
-- point is a building that looks and sits exactly where it did, only dead.
-- ONE type cannot manage that, and the reason is an engine rule, not a choice:
--
--   Error while loading entity prototype "cindra-solar-band-b05-frozen"
--   (solar-panel): production must be > 0.
--
-- A solar panel is REQUIRED to produce. Left at the smallest legal value it still
-- leaks -- measured, three frozen bands delivered 3 kJ over 600 ticks at the flare
-- plateau, because Cindra's solar multiplier scales even 1 W into something real --
-- and "a frozen panel makes almost nothing" is the kind of small lie this mod has
-- already been bitten by. So the frozen twin of a panel is not a panel: it is an
-- inert electric-energy-interface, zero production, zero draw, zero buffer,
-- wearing the panel's own art under ice. A panel stores nothing, so nothing is
-- lost in the change (contrast an accumulator, whose twin MUST stay an accumulator
-- to hold the charge).
--
-- Deliberately an electric-energy-interface rather than a decoration: it stays a
-- type the engine refuses to freeze, so every policy table here keeps applying to
-- the twin unchanged, and it stays a POWER prototype, so the mod-wide conservation
-- coverage guard (tests/test_power_conservation.lua) still demands a case for it.
M.FROZEN_TWIN_TYPE = {
  ["solar-panel"] = "electric-energy-interface",
}

-- The prototype type a `proto_type` building's frozen twin is registered under.
function M.frozen_twin_type(proto_type)
  return M.FROZEN_TWIN_TYPE[proto_type] or proto_type
end

-- Types the engine refuses AND that we deliberately do not script-freeze either.
-- Every entry is a reason freezing would be meaningless or incoherent, not a
-- reason it is inconvenient.
M.SCRIPT_FREEZE_EXEMPT_TYPES = {
  ["heat-pipe"] = "cindra-lava-heat IS the thaw mechanism -- the ambient emitter"
    .. " that decides what freezes. A frozen thaw source is a contradiction (and"
    .. " would make the nightside permanently unrecoverable), the same reason the"
    .. " electric heater is exempt from the native freeze",
  ["electric-pole"] = "a pole is an inert conductor with no energy of its own; the"
    .. " only Cindra ones are the power diode's INVISIBLE tap poles, which have no"
    .. " behaviour to stop and no art to frost",
  ["constant-combinator"] = "the env-scanner radio station belongs to a SIBLING MOD"
    .. " (ci-6jz), and this guard deliberately polices only Cindra's own prototypes",
  ["explosion"] = "a transient visual effect that reaps itself within a few ticks:"
    .. " cindra-panel-overload-spark. There is no working state to stop",
  ["simple-entity"] = "worldgen scenery (rocks/icebergs). It does nothing, so"
    .. " freezing it stops nothing -- and the engine already draws it under snow",
  ["resource"] = "an ore patch is not a building; a frozen ore patch is just ore",
}

-- Individual Cindra entities of a SCRIPT_FROZEN_TYPE that are nonetheless excused
-- BY NAME. Short and adversarial, like FREEZE_EXEMPT: this is exactly where an
-- accident would hide, so each entry says why the entity is not a building a
-- player can see stop working.
M.SCRIPT_FREEZE_EXEMPT = {
  ["cindra-measurement-sink"] = "a test-only measuring accumulator, registered only"
    .. " in factorio-test builds and never shipped -- it is the INSTRUMENT the"
    .. " conservation suite reads the grid with, so freezing it would break the"
    .. " measurement rather than the game",
  ["cindra-power-diode-input"] = "an INVISIBLE hidden buffer inside the power"
    .. " diode, not a placeable building. The diode DEVICE itself is a power-switch,"
    .. " which the engine freezes natively -- freezing that is what stops the"
    .. " transfer, so its guts need no separate treatment",
  ["cindra-power-diode-output"] = "the other half of the same hidden pair; see"
    .. " cindra-power-diode-input",
}

-- Is this Cindra entity spec one the runtime must script-freeze?
function M.must_script_freeze(spec)
  return M.SCRIPT_FROZEN_TYPES[spec.type] ~= nil
    and not M.SCRIPT_FREEZE_EXEMPT[spec.name]
    and not M.is_frozen_name(spec.name)
end

-- The class the script freeze governs: every Cindra entity of a type the engine
-- refuses to freeze that is a real building. Discovered LIVE from `raw` (never a
-- hand-kept list), so a new accumulator or solar variant is script-frozen -- and
-- gets its twin -- without anyone remembering to add it.
function M.script_freeze_specs(raw)
  local specs = {}
  for _, spec in ipairs(M.entity_specs(raw)) do
    if M.must_script_freeze(spec) then specs[#specs + 1] = spec end
  end
  return specs
end

-- The fail-closed half: a Cindra entity of a type the ENGINE refuses that we
-- neither script-freeze nor have excused. It would ship immune in both directions
-- at once -- the engine will not freeze it and neither will we -- which is the
-- precise hole ci-de55 exists to close.
function M.script_freeze_unhandled(raw)
  local bad = {}
  for _, spec in ipairs(M.entity_specs(raw)) do
    if M.UNFREEZABLE_TYPES[spec.type]
      and not M.SCRIPT_FROZEN_TYPES[spec.type]
      and not M.SCRIPT_FREEZE_EXEMPT_TYPES[spec.type] then
      bad[#bad + 1] = string.format("%s (type '%s')", spec.name, spec.type)
    end
  end
  return bad
end

-- A frozen twin must WEAR the freeze. The engine draws no frost for these types
-- (there is no frozen_patch field on an accumulator / solar-panel /
-- electric-energy-interface -- that is the whole reason they cannot freeze
-- natively), so a script freeze is INVISIBLE unless the twin's own art carries
-- the ice. A silent disable is worse than the immunity it fixes: it reads as a
-- mod bug and teaches the player nothing.
--
-- The check is deliberately crude and structural -- does the twin's art reference
-- a sprite from the frost asset folder -- because it has to hold for a type whose
-- art field this module does not know the shape of. It cannot judge the picture;
-- it can guarantee one was wired.
M.FROST_ASSET_DIR = "/graphics/entity/frost/"

local function references_frost(v, seen)
  if type(v) ~= "table" then return false end
  seen = seen or {}
  if seen[v] then return false end
  seen[v] = true
  if type(v.filename) == "string" and v.filename:find(M.FROST_ASSET_DIR, 1, true) then
    return true
  end
  for _, child in pairs(v) do
    if references_frost(child, seen) then return true end
  end
  return false
end
M.references_frost = references_frost

-- Every script-frozen entity whose twin is MISSING, or whose twin wears no frost.
function M.frozen_twin_problems(raw)
  local bad = {}
  for _, spec in ipairs(M.script_freeze_specs(raw)) do
    local bucket = raw[M.frozen_twin_type(spec.type)]
    local twin = bucket and bucket[M.frozen_name(spec.name)]
    if type(twin) ~= "table" then
      bad[#bad + 1] = M.frozen_name(spec.name) .. " (missing)"
    elseif not references_frost(twin) then
      bad[#bad + 1] = M.frozen_name(spec.name) .. " (no frost art)"
    end
  end
  return bad
end

-- Entities of a type the engine CAN freeze that are nonetheless DELIBERATELY
-- immune. Every entry states its reason here, in code, and is the short list the
-- ci-qha1 ruling allows. Be sceptical of adding one: an accident is not an
-- exemption, and this table is exactly where an accident would hide.
M.FREEZE_EXEMPT = {
  -- Exemption (b), CONFIRMED for our heater specifically (ci-qha1). The electric
  -- heater is the THAW SOURCE. A frozen heater draws no power and emits no heat,
  -- so it cannot thaw itself: the first heater placed on the deep nightside would
  -- be dead on arrival and the nightside would be permanently unrecoverable --
  -- a soft-lock, not a difficulty. Being electric rather than fuelled does not
  -- change that (the bead asked; the deadlock is identical either way, since a
  -- frozen entity stops consuming). Vanilla is consistent: NO reactor, including
  -- the heating tower, carries a heating_energy.
  -- Note this one really is our choice, not an engine limit -- `reactor` IS a
  -- freezable type (cindra-electric-heater measures is_freezable = true with
  -- heating_energy = 0), which is why it needs an entry here at all.
  ["cindra-electric-heater"] = "IT IS THE THAW SOURCE: a heater that freezes"
    .. " cannot thaw itself, so the nightside becomes unrecoverable. Vanilla"
    .. " reactors (incl. the heating tower) are exempt for the same reason",
}

-- Every Cindra-added prototype in `raw` whose type classifies as `want`, as a
-- sorted list of {type=, name=}. Sorted so a load error lists offenders
-- deterministically. Enumerating from the registry LIVE (rather than from a
-- hand-kept list of names) is what makes a NEW entity unable to ship immune.
local function specs_classified(raw, want)
  local specs = {}
  for proto_type, bucket in pairs(raw) do
    if type(bucket) == "table" and M.classify(proto_type) == want then
      for name in pairs(bucket) do
        if name:sub(1, 7) == "cindra-" then
          specs[#specs + 1] = { type = proto_type, name = name }
        end
      end
    end
  end
  table.sort(specs, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.type < b.type
  end)
  return specs
end

-- Every Cindra-added ENTITY in `raw` -- the class the freeze invariant governs.
function M.entity_specs(raw)
  return specs_classified(raw, "entity")
end

-- Cindra prototypes of a type in NEITHER list: the audit does not know whether
-- they are entities, so it refuses to guess in either direction. This is the
-- fail-closed half, relocated out of the freeze report: the load still stops (see
-- M.problems), but what it asks for is a CLASSIFICATION rather than a heat draw.
function M.unclassified(raw)
  local bad = {}
  for _, spec in ipairs(specs_classified(raw, "unknown")) do
    bad[#bad + 1] = string.format("%s (type '%s')", spec.name, spec.type)
  end
  return bad
end

-- Is this entity REQUIRED to carry a heat draw? False only when the engine cannot
-- freeze its type, or when it is a named, reasoned exemption.
function M.must_freeze(spec)
  return not M.UNFREEZABLE_TYPES[spec.type] and not M.FREEZE_EXEMPT[spec.name]
end

-- The offenders: Cindra entities that CAN freeze, are not exempt, and carry no
-- heat draw -- so they keep working in the deep dark, immune to the planet.
-- Each entry names the entity, its type and what it currently declares.
function M.freeze_immune(raw)
  local bad = {}
  for _, spec in ipairs(M.entity_specs(raw)) do
    if M.must_freeze(spec) then
      local proto = raw[spec.type][spec.name]
      if not M.freezes(proto) then
        bad[#bad + 1] = string.format("%s (%s, heating_energy=%s)",
          spec.name, spec.type, tostring(type(proto) == "table" and proto.heating_energy))
      end
    end
  end
  return bad
end

-- The INVERSE offence: a heat draw declared on a type the engine ignores. It
-- freezes nothing and it READS AS PROTECTION -- the most dangerous shape this bug
-- class has, because the next person greps for heating_energy, finds one, and
-- moves on. Either the entity must be re-typed to something the engine freezes,
-- or the dead field must go (and the type's exemption stands).
function M.dead_heating(raw)
  local bad = {}
  for _, spec in ipairs(M.entity_specs(raw)) do
    if M.UNFREEZABLE_TYPES[spec.type] and M.freezes(raw[spec.type][spec.name]) then
      bad[#bad + 1] = string.format("%s (%s)", spec.name, spec.type)
    end
  end
  return bad
end

-- ============================================================================
-- THE OPERATOR-FACING REPORT (ci-3ed3)
-- ============================================================================
-- The messages live HERE, not in the data-stage guard, for one reason: the error
-- text IS the deliverable. What a load failure tells the reader to do is the part
-- that went wrong in ci-3ed3 -- a `mod-data` prototype was announced as an
-- "entity IMMUNE to the planet's freeze mechanic", so the honest fix (classify
-- the type) was the one thing the message did not mention. Text nobody can assert
-- on is text that drifts back to lying, so it is returned as data and pinned by
-- unit-tests/test_frost_audit.lua.
--
-- Returns an ordered list of {kind=, message=}; empty means the load is clean.
-- CLASSIFICATION IS REPORTED FIRST because it decides whether the other audits
-- even apply to a prototype -- reporting a freeze verdict on a type we cannot
-- classify is exactly the bug. After it the order is by size of hole: an entity
-- nothing will ever freeze, then one that will freeze invisibly, then a dead heat
-- draw, then missing frost art.
function M.problems(raw, skip_prefixes)
  local out = {}
  local function add(kind, message) out[#out + 1] = { kind = kind, message = message } end

  local unknown = M.unclassified(raw)
  if #unknown > 0 then
    add("unclassified", "cindra: UNRECOGNISED prototype type(s) carrying a Cindra"
      .. " prototype: " .. table.concat(unknown, ", ")
      .. " -- this audit cannot tell whether these are entities, so it will not"
      .. " guess. CLASSIFY THE TYPE in scripts/frost-audit.lua: add it to"
      .. " ENTITY_TYPES if it really is an entity prototype (the freeze invariant"
      .. " then applies to it, so expect a follow-up error asking for a"
      .. " heating_energy), or to NON_ENTITY_TYPES if it is not an entity at all"
      .. " (items, recipes, equipment, mod-data and other data-only prototypes"
      .. " have no owner, no health and no freeze -- there is NOTHING to add to"
      .. " them here). Do NOT add a heating_energy to make this go away. See"
      .. " ci-3ed3.")
  end

  local immune = M.freeze_immune(raw)
  if #immune > 0 then
    add("immune", "cindra: entity/entities IMMUNE to the planet's freeze mechanic: "
      .. table.concat(immune, ", ")
      .. " -- give each a heating_energy > 0 (that field IS the engine's freeze"
      .. " switch, not merely a power cost; match the vanilla sibling it was cloned"
      .. " from, e.g. 100kW for a machine, 300kW for a rocket-silo, 20kW for a"
      .. " power-switch). If it must NOT freeze, add it to FREEZE_EXEMPT in"
      .. " scripts/frost-audit.lua WITH A WRITTEN REASON, and extend"
      .. " tests/test_frost.lua. If the engine ignores heating_energy on its"
      .. " prototype type, MEASURE that and add the type to UNFREEZABLE_TYPES."
      .. " Every name above is of a type listed in ENTITY_TYPES, so it IS an"
      .. " entity -- if that classification is wrong, fix it there. See ci-qha1.")
  end

  local unhandled = M.script_freeze_unhandled(raw)
  if #unhandled > 0 then
    add("script-freeze-unhandled", "cindra: entity/entities of a type the ENGINE"
      .. " REFUSES to freeze that Cindra does not script-freeze either, so they are"
      .. " immune from BOTH directions at once: " .. table.concat(unhandled, ", ")
      .. " -- decide which it is in scripts/frost-audit.lua. If it is a BUILDING a"
      .. " player watches work, add its type to SCRIPT_FROZEN_TYPES stating how the"
      .. " runtime neutralises it (scripts/script-freeze.lua then freezes it and"
      .. " prototypes/frozen-twins.lua builds its frozen twin). If freezing it would"
      .. " be meaningless or incoherent (scenery, ore, a transient effect, the thaw"
      .. " source itself), add the type to SCRIPT_FREEZE_EXEMPT_TYPES WITH A WRITTEN"
      .. " REASON -- or, for a one-off like a hidden helper, name it in"
      .. " SCRIPT_FREEZE_EXEMPT. See ci-de55.")
  end

  local twins = M.frozen_twin_problems(raw)
  if #twins > 0 then
    add("frozen-twin", "cindra: script-frozen building(s) whose FROZEN TWIN is"
      .. " missing or wears no frost: " .. table.concat(twins, ", ")
      .. " -- the engine draws no frost for these prototype types, so a scripted"
      .. " freeze the player cannot SEE is worse than the immunity it fixes: the"
      .. " building silently stops working and reads as a mod bug. Every twin is"
      .. " generated by prototypes/frozen-twins.lua, which layers a frost patch from"
      .. " " .. M.FROST_ASSET_DIR .. " over the body; if a new building needs its own"
      .. " body-derived patch, add it to SPECS in scripts/gen-frost-layer.py and"
      .. " re-run scripts/render-frost-layer.sh. See ci-de55.")
  end

  local dead = M.dead_heating(raw)
  if #dead > 0 then
    add("dead-heating", "cindra: heating_energy declared on prototype type(s) the"
      .. " ENGINE IGNORES, so it freezes nothing and only LOOKS like protection: "
      .. table.concat(dead, ", ")
      .. " -- either drop the dead field (the type's exemption in UNFREEZABLE_TYPES"
      .. " already covers it) or re-type the entity to something the engine freezes."
      .. " See ci-qha1 / ci-de55.")
  end

  local bare = M.offenders(raw, M.discover(raw, skip_prefixes))
  if #bare > 0 then
    add("bare-frost", "cindra: crafting machine(s) that FREEZE with no frost sheen: "
      .. table.concat(bare, ", ")
      .. " -- wire graphics_set.frozen_patch + reset_animation_when_frozen"
      .. " (create the layer with scripts/gen-frost-layer.py if the clone source"
      .. " has no fitting vanilla frost sprite). See prototypes/frost-audit.lua")
  end

  return out
end

return M
