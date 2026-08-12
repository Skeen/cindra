-- Pure frost-coverage auditor for Cindra's custom crafting machines (ci-u92y).
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
-- Measured in-engine (tests/test_frost.lua): the arc furnace and the oxidizer
-- carry 100kW and freeze on the nightside; the glass furnace clears it
-- (prototypes/lava.lua drops "the Aquilo cold-planet heating draw"; whether that
-- exemption is intended is ci-6qyk) and NEVER freezes, though it still reports
-- is_freezable true. So freezability of the TYPE is
-- not enough -- requiring frost from a machine that cannot freeze would demand
-- art no player can ever see. This is the honest predicate.
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

return M
