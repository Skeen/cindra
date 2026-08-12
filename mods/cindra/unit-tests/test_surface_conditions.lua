-- Plain-Lua unit test for the surface-condition shim (scripts/surface-conditions.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_surface_conditions.lua
--
-- WHY THIS FILE EXISTS AT ALL (ci-ndm9's stated RISK): the shim has TWO code
-- paths -- delegate to PlanetsLib, or run our own implementation -- and the mod
-- ships without PlanetsLib, so an in-engine suite only ever walks one of them.
-- Off the engine we can drive both: the guard reads two plain globals (`mods` and
-- `PlanetsLib`), so a fake library here exercises the delegation branch, its
-- absence exercises the fallback, and the two are compared against each other.
--
-- The behavioural claims (what a restriction/relaxation/removal DOES) are asserted
-- against the semantics of PlanetsLib 1.23.4 `lib/surface_conditions.lua`, which
-- is the contract the fallback promises to honour. tests/test_planetslib_coload.lua
-- checks the same claims against the REAL library in a real engine.

package.path = package.path .. ";./?.lua;./?/init.lua"
local SC = require("scripts.surface-conditions")

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

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

-- Find the condition for `property`, or nil.
local function cond(proto, property)
  for _, c in ipairs(proto.surface_conditions or {}) do
    if c.property == property then return c end
  end
  return nil
end

local function count(proto)
  return #(proto.surface_conditions or {})
end

-- Make sure each test starts with no library present.
local function no_planetslib()
  _G.mods = nil
  _G.PlanetsLib = nil
end

-- ===========================================================================
-- The guard: which implementation runs.
-- ===========================================================================

test("with no PlanetsLib at all, the fallback is the backend", function()
  no_planetslib()
  assert_eq("cindra", SC.backend())
end)

test("mods['PlanetsLib'] alone is NOT enough -- the API must be reachable", function()
  -- The load-order trap this guard exists for: Cindra declares no dependency on
  -- PlanetsLib, so PlanetsLib may run AFTER us. Then the mod is installed (and
  -- listed in `mods`) while its global does not exist yet. Calling into it there
  -- would crash the load for every player who has both mods installed.
  no_planetslib()
  _G.mods = { PlanetsLib = "1.23.4" }
  assert_eq("cindra", SC.backend(), "installed-but-not-loaded must fall back, not crash")

  -- A half-built global (a future release renaming a helper) is refused too.
  _G.PlanetsLib = { restrict_surface_conditions = function() end }
  assert_eq("cindra", SC.backend(), "a partial API must fall back")
  no_planetslib()
end)

test("with the mod listed AND its API loaded, PlanetsLib is the backend", function()
  no_planetslib()
  _G.mods = { PlanetsLib = "1.23.4" }
  _G.PlanetsLib = {
    restrict_surface_conditions = function() end,
    relax_surface_conditions = function() end,
    remove_surface_condition = function() end,
  }
  assert_eq("PlanetsLib", SC.backend())
  no_planetslib()
end)

test("a loaded PlanetsLib that the player does not have is still refused", function()
  -- Belt and braces: some other mod could leave a `PlanetsLib` global lying
  -- around. `mods` is the authority on what is actually installed.
  no_planetslib()
  _G.PlanetsLib = {
    restrict_surface_conditions = function() end,
    relax_surface_conditions = function() end,
    remove_surface_condition = function() end,
  }
  assert_eq("cindra", SC.backend())
  no_planetslib()
end)

-- ===========================================================================
-- Delegation: when PlanetsLib is there, we must actually call it (and pass the
-- prototype through untouched, not a copy).
-- ===========================================================================

test("delegates each operation to PlanetsLib, forwarding the same arguments", function()
  no_planetslib()
  local calls = {}
  local function record(name)
    return function(proto, arg) calls[#calls + 1] = { name = name, proto = proto, arg = arg } end
  end
  _G.mods = { PlanetsLib = "1.23.4" }
  _G.PlanetsLib = {
    restrict_surface_conditions = record("restrict"),
    relax_surface_conditions = record("relax"),
    remove_surface_condition = record("remove"),
  }

  local proto = { surface_conditions = { { property = "pressure", min = 10 } } }
  SC.restrict(proto, { property = "pressure", min = 20 })
  SC.relax(proto, { property = "pressure", min = 5 })
  SC.remove(proto, "pressure")

  assert_eq(3, #calls, "all three helpers must reach the library")
  assert_eq("restrict", calls[1].name)
  assert_eq("relax", calls[2].name)
  assert_eq("remove", calls[3].name)
  for _, c in ipairs(calls) do
    assert_true(c.proto == proto, "the prototype itself must be handed over, not a copy")
  end
  assert_eq("pressure", calls[1].arg.property)
  assert_eq(20, calls[1].arg.min)
  assert_eq("pressure", calls[3].arg, "a string spec passes through as a string")
  no_planetslib()
end)

test("with PlanetsLib absent, nothing is delegated -- the fallback does the work", function()
  no_planetslib()
  local proto = {}
  SC.restrict(proto, { property = "pressure", min = 10 })
  assert_eq(10, cond(proto, "pressure").min, "the fallback must have applied the restriction itself")
end)

-- ===========================================================================
-- Fallback semantics. These are the contract the delegated path must match.
-- ===========================================================================

test("restrict adds a condition to a prototype that had none", function()
  no_planetslib()
  local proto = {}
  SC.restrict(proto, { property = "pressure", min = 10 })
  assert_eq(1, count(proto))
  assert_eq(10, cond(proto, "pressure").min)
  assert_eq(nil, cond(proto, "pressure").max, "an unbounded side stays unbounded")
end)

test("restrict MERGES with an existing condition, keeping the tighter bound", function()
  -- The reason this is not "assign the table": a restriction must never LOOSEN
  -- what is already there, whichever direction it comes from.
  no_planetslib()
  local proto = { surface_conditions = { { property = "pressure", min = 10, max = 4000 } } }
  SC.restrict(proto, { property = "pressure", min = 500, max = 5000 })
  local c = cond(proto, "pressure")
  assert_eq(1, count(proto), "it must edit the existing condition, not add a second one")
  assert_eq(500, c.min, "the LARGER min wins (tighter)")
  assert_eq(4000, c.max, "the SMALLER max wins (tighter) -- a bigger max is ignored")
end)

test("restrict leaves other properties alone", function()
  no_planetslib()
  local proto = { surface_conditions = { { property = "gravity", min = 1 } } }
  SC.restrict(proto, { property = "pressure", min = 10 })
  assert_eq(2, count(proto))
  assert_eq(1, cond(proto, "gravity").min)
  assert_eq(10, cond(proto, "pressure").min)
end)

test("restrict never mutates the table it was handed (clone safety)", function()
  -- The invariant this protects: a Cindra prototype deep-copied from vanilla can
  -- still SHARE the vanilla surface_conditions table. Editing in place would
  -- change Vulcanus/Nauvis gameplay -- the never-mutate-other-planets rule.
  no_planetslib()
  local shared = { { property = "pressure", min = 10 } }
  local vanilla = { surface_conditions = shared }
  local clone = { surface_conditions = shared }
  SC.restrict(clone, { property = "pressure", min = 4000 })
  assert_eq(10, cond(vanilla, "pressure").min, "the shared vanilla condition must be untouched")
  assert_eq(10, shared[1].min, "the shared table itself must be untouched")
  assert_eq(4000, cond(clone, "pressure").min, "only the clone moves")
end)

test("relax widens an existing bound", function()
  no_planetslib()
  local proto = { surface_conditions = { { property = "pressure", min = 4000, max = 4000 } } }
  SC.relax(proto, { property = "pressure", min = 500, max = 6000 })
  local c = cond(proto, "pressure")
  assert_eq(500, c.min, "the SMALLER min wins (looser)")
  assert_eq(6000, c.max, "the LARGER max wins (looser)")
end)

test("relax refuses to tighten", function()
  no_planetslib()
  local proto = { surface_conditions = { { property = "pressure", min = 10, max = 4000 } } }
  SC.relax(proto, { property = "pressure", min = 500, max = 100 })
  local c = cond(proto, "pressure")
  assert_eq(10, c.min, "relax must never raise a min")
  assert_eq(4000, c.max, "relax must never lower a max")
end)

test("relax only widens bounds that already exist (documented quirk)", function()
  -- Upstream README: "Calling relax_surface_conditions without a min field will
  -- not remove any existing min conditions". The mirror image also holds -- it
  -- will not INVENT a bound. Anyone wanting a gate GONE must use remove.
  no_planetslib()
  local proto = { surface_conditions = { { property = "pressure", min = 4000 } } }
  SC.relax(proto, { property = "pressure", max = 9000 })
  assert_eq(nil, cond(proto, "pressure").max, "no max existed, so none is added")
  assert_eq(4000, cond(proto, "pressure").min, "and the min is untouched")

  SC.relax(proto, { property = "gravity", min = 0 })
  assert_eq(nil, cond(proto, "gravity"), "relaxing an absent property adds nothing")
end)

test("relax never mutates the table it was handed", function()
  no_planetslib()
  local shared = { { property = "pressure", min = 4000 } }
  local vanilla = { surface_conditions = shared }
  local clone = { surface_conditions = shared }
  SC.relax(clone, { property = "pressure", min = 10 })
  assert_eq(4000, cond(vanilla, "pressure").min, "the shared vanilla condition must be untouched")
  assert_eq(10, cond(clone, "pressure").min)
end)

test("remove by property name drops every condition on that property", function()
  no_planetslib()
  local proto = {
    surface_conditions = {
      { property = "pressure", min = 4000, max = 4000 },
      { property = "gravity", min = 1 },
    },
  }
  SC.remove(proto, "pressure")
  assert_eq(1, count(proto))
  assert_eq(nil, cond(proto, "pressure"), "the pressure gate is gone")
  assert_eq(1, cond(proto, "gravity").min, "the other gate survives")
end)

test("remove by exact condition only drops an exact match (documented quirk)", function()
  -- The table form matches on the bounds too, and a bound present on one side
  -- only counts as a mismatch. Preserved from upstream deliberately: code that
  -- relies on the loose behaviour would break the day we adopt the real library.
  no_planetslib()
  local proto = { surface_conditions = { { property = "pressure", min = 4000, max = 4000 } } }
  SC.remove(proto, { property = "pressure", min = 10, max = 4000 })
  assert_eq(1, count(proto), "a different min is not a match")
  SC.remove(proto, { property = "pressure" })
  assert_eq(1, count(proto), "a bare property table does not match a bounded condition")
  SC.remove(proto, { property = "pressure", min = 4000, max = 4000 })
  assert_eq(0, count(proto), "the exact condition is removed")
end)

test("remove on a prototype with no conditions is a no-op, not a crash", function()
  no_planetslib()
  local proto = {}
  SC.remove(proto, "pressure")
  assert_eq(nil, proto.surface_conditions)
end)

test("remove never mutates the table it was handed", function()
  no_planetslib()
  local shared = { { property = "pressure", min = 4000 } }
  local vanilla = { surface_conditions = shared }
  local clone = { surface_conditions = shared }
  SC.remove(clone, "pressure")
  assert_eq(1, #vanilla.surface_conditions, "the shared vanilla condition must survive")
  assert_eq(0, #clone.surface_conditions)
end)

-- ===========================================================================
-- The composite the mod actually leans on: strip a gate, state your own.
-- ===========================================================================

test("remove + restrict re-homes a gate inherited from a vanilla clone", function()
  -- The pattern prototypes/electric-heater.lua and prototypes/mass-driver.lua use
  -- in spirit: an entity deep-copied from vanilla arrives carrying vanilla's
  -- placement gate. Stating the gate makes it ours, so an upstream retune cannot
  -- move it. Proven here end to end: an inherited pressure >= 10 replaced by an
  -- explicit pressure >= 500, with nothing else disturbed.
  no_planetslib()
  local clone = { surface_conditions = { { property = "pressure", min = 10 }, { property = "gravity", min = 1 } } }
  SC.remove(clone, "pressure")
  SC.restrict(clone, { property = "pressure", min = 500 })
  assert_eq(500, cond(clone, "pressure").min)
  assert_eq(1, cond(clone, "gravity").min, "the untouched gate stays")
  assert_eq(2, count(clone), "no duplicate pressure condition is left behind")
end)

test("restricting a gate that is already there changes nothing (idempotent)", function()
  -- Why this matters: both adoption sites RE-STATE the condition their clone
  -- source already carries. That must be a pure declaration -- identical
  -- prototype, no duplicate entry -- or the change would not be behaviour-neutral.
  no_planetslib()
  local proto = { surface_conditions = { { property = "pressure", min = 10 } } }
  SC.restrict(proto, { property = "pressure", min = 10 })
  assert_eq(1, count(proto))
  assert_eq(10, cond(proto, "pressure").min)
  assert_eq(nil, cond(proto, "pressure").max)
  SC.restrict(proto, { property = "pressure", min = 10 })
  assert_eq(1, count(proto), "still idempotent on a second application")
end)

-- ===========================================================================
-- Cross-check: the two paths must be interchangeable. Run the same edits through
-- the fallback and through a "library" that is our own implementation, and prove
-- the results are identical -- the property that lets us ship one path and test
-- the other.
-- ===========================================================================

test("the delegated path and the fallback produce identical prototypes", function()
  no_planetslib()
  local function fresh()
    return { surface_conditions = { { property = "pressure", min = 10, max = 4000 }, { property = "gravity", min = 1 } } }
  end

  local direct = fresh()
  SC.restrict(direct, { property = "pressure", min = 500 })
  SC.relax(direct, { property = "pressure", max = 9000 })
  SC.remove(direct, "gravity")

  _G.mods = { PlanetsLib = "1.23.4" }
  _G.PlanetsLib = {
    restrict_surface_conditions = SC.fallback.restrict,
    relax_surface_conditions = SC.fallback.relax,
    remove_surface_condition = SC.fallback.remove,
  }
  assert_eq("PlanetsLib", SC.backend(), "this half must genuinely go through the library path")
  local delegated = fresh()
  SC.restrict(delegated, { property = "pressure", min = 500 })
  SC.relax(delegated, { property = "pressure", max = 9000 })
  SC.remove(delegated, "gravity")
  no_planetslib()

  assert_eq(count(direct), count(delegated), "same number of conditions")
  for _, c in ipairs(direct.surface_conditions) do
    local other = cond(delegated, c.property)
    assert_true(other ~= nil, "both paths must carry a " .. c.property .. " condition")
    assert_eq(c.min, other.min, c.property .. " min must match across paths")
    assert_eq(c.max, other.max, c.property .. " max must match across paths")
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
