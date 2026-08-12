-- Surface-condition editing, delegated to PlanetsLib when it is installed
-- (ci-ndm9, stage 2 of the ci-810e PlanetsLib plan; docs/planetslib-evaluation.md).
--
-- A `surface_conditions` list is how a prototype says "this can only be built /
-- crafted where the world reads like this" (Vulcanus's `pressure = 4000` gate on
-- the vanilla foundry recipe is the famous one). Editing those lists correctly is
-- fiddly: a restriction has to MERGE with whatever condition is already there
-- (tightest min wins, tightest max wins) rather than overwrite it, and every edit
-- has to deep-copy first or it mutates the shared vanilla table it was cloned from
-- -- the never-mutate-other-planets invariant, one aliased table away from a bug.
--
-- PlanetsLib ships exactly those three helpers, and the ci-810e spike judged them
-- the ONE part of its API genuinely nicer than hand-rolling. So: when PlanetsLib
-- is loaded we call it; otherwise we run our own implementation of the same three
-- operations. Cindra takes NO dependency on PlanetsLib (see
-- docs/planetslib-evaluation.md §4 for why a hard dependency is forbidden), so
-- the hand-rolled path is the DEFAULT and must stay fully functional forever.
--
-- WHY THE GUARD CHECKS THE GLOBAL, NOT JUST `mods[...]`:
-- `PlanetsLib` is a global its own data.lua creates, so `mods["PlanetsLib"]` can
-- be true while the API does not exist yet -- it says INSTALLED, not LOADED. The
-- `? PlanetsLib` in info.json (ci-dza6) is what orders the library ahead of us
-- and makes the two coincide today; before that dependency landed, Factorio ran
-- PlanetsLib's data.lua AFTER ours (measured: cindra 0.352 s, PlanetsLib 0.389 s)
-- and a bare `mods[...]` check would have crashed the load for every player who
-- owned both mods. The `?` is also, by definition, droppable -- so the guard
-- demands the three functions be ACTUALLY REACHABLE and is evaluated per call
-- (data-stage only, so the cost is nil) rather than cached at require time. A
-- future release that renames a helper degrades to the fallback instead of
-- erroring someone's game.
--
-- BEHAVIOURAL IDENTITY IS THE CONTRACT: the two paths must produce byte-identical
-- prototypes. The fallback below is a faithful reimplementation of PlanetsLib
-- 1.23.4 `lib/surface_conditions.lua`, quirks included (see the notes on each
-- function). unit-tests/test_surface_conditions.lua pins the semantics and
-- exercises BOTH branches off-engine; tests/test_planetslib_coload.lua re-checks
-- the delegated branch in a real engine with PlanetsLib installed.
--
-- PURE: this module touches no `data` / `game` / `prototypes` at load time, so it
-- is reachable from a plain-Lua unit test.

local M = {}

-- Local deep copy: `util.table.deepcopy` only exists inside the game, and this
-- module has to stay loadable off-engine. Surface-condition tables are small,
-- flat, and cycle-free, so a plain recursive copy is enough.
local function deepcopy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = deepcopy(v) end
  return out
end

-- Which implementation would a call use right now: "PlanetsLib" or "cindra".
-- Exposed so tests can assert WHICH path they exercised (a delegation test that
-- silently fell through to the fallback would prove nothing).
function M.backend()
  local mod_list = rawget(_G, "mods")
  local pl = rawget(_G, "PlanetsLib")
  if mod_list and mod_list["PlanetsLib"]
    and type(pl) == "table"
    and type(pl.restrict_surface_conditions) == "function"
    and type(pl.relax_surface_conditions) == "function"
    and type(pl.remove_surface_condition) == "function"
  then
    return "PlanetsLib"
  end
  return "cindra"
end

-- --- The fallback implementations -----------------------------------------
-- Each one deep-copies before writing, so a prototype cloned from vanilla never
-- edits the vanilla table it still shares.

-- Tighten. An existing condition on the same property is MERGED with (never
-- replaced by) the new one: the larger min and the smaller max win, so the result
-- is at least as strict as both. If the property is absent the condition is added.
local function restrict(proto, condition)
  local conditions = proto.surface_conditions and deepcopy(proto.surface_conditions) or {}
  for i = 1, #conditions do
    local existing = conditions[i]
    if existing.property == condition.property then
      if condition.min ~= nil then
        existing.min = existing.min ~= nil and math.max(existing.min, condition.min) or condition.min
      end
      if condition.max ~= nil then
        existing.max = existing.max ~= nil and math.min(existing.max, condition.max) or condition.max
      end
      proto.surface_conditions = conditions
      return
    end
  end
  conditions[#conditions + 1] = {
    property = condition.property,
    min = condition.min,
    max = condition.max,
  }
  proto.surface_conditions = conditions
end

-- Loosen. QUIRK (matches upstream, and the README documents it): relaxing only
-- widens a bound that ALREADY EXISTS -- passing a `min` for a property that has
-- no `min` today adds nothing, and relaxing a property the prototype does not
-- carry at all does nothing. Use `remove` to drop a gate outright.
local function relax(proto, condition)
  local conditions = proto.surface_conditions and deepcopy(proto.surface_conditions) or {}
  for i = 1, #conditions do
    local existing = conditions[i]
    if existing.property == condition.property then
      if condition.min ~= nil and existing.min ~= nil then
        existing.min = math.min(existing.min, condition.min)
      end
      if condition.max ~= nil and existing.max ~= nil then
        existing.max = math.max(existing.max, condition.max)
      end
    end
  end
  proto.surface_conditions = conditions
end

-- Does condition-table `c` match the removal spec? A string spec matches the
-- property alone; a table spec must match the property AND every bound it names,
-- and a bound present on only one side is a mismatch (so `{property = "pressure"}`
-- removes only a bare pressure condition, never `pressure >= 10`). Upstream quirk,
-- preserved deliberately.
local function matches(c, spec)
  if type(spec) == "string" then return c.property == spec end
  return (c.property ~= nil and spec.property ~= nil and c.property == spec.property)
    and (not (spec.min or c.min) or (spec.min and c.min and c.min == spec.min))
    and (not (spec.max or c.max) or (spec.max and c.max and c.max == spec.max))
    and true or false
end

-- Drop condition(s). `spec` is either a property name (removes every condition on
-- that property) or a condition table (removes exact matches, see `matches`).
local function remove(proto, spec)
  if not proto.surface_conditions then return end
  local conditions = deepcopy(proto.surface_conditions)
  local changed = false
  for i = #conditions, 1, -1 do
    if matches(conditions[i], spec) then
      table.remove(conditions, i)
      changed = true
    end
  end
  if changed then proto.surface_conditions = conditions end
end

-- --- The public API: delegate when we can, fall back when we cannot ---------

--- Tighten `proto`'s surface conditions with `condition` ({property=, min=, max=}).
function M.restrict(proto, condition)
  if M.backend() == "PlanetsLib" then
    return PlanetsLib.restrict_surface_conditions(proto, condition)
  end
  return restrict(proto, condition)
end

--- Widen `proto`'s existing bounds on `condition.property`.
function M.relax(proto, condition)
  if M.backend() == "PlanetsLib" then
    return PlanetsLib.relax_surface_conditions(proto, condition)
  end
  return relax(proto, condition)
end

--- Drop conditions matching `spec` (a property name, or a condition table).
function M.remove(proto, spec)
  if M.backend() == "PlanetsLib" then
    return PlanetsLib.remove_surface_condition(proto, spec)
  end
  return remove(proto, spec)
end

-- The fallbacks, reachable for direct testing regardless of what is installed:
-- the unit test has to be able to compare "what we would do" against "what we did"
-- even in a run where a PlanetsLib global is present.
M.fallback = { restrict = restrict, relax = relax, remove = remove }

return M
