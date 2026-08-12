-- Pure graphics-presence auditor for Cindra's custom entities (ci-sop).
--
-- WHY THIS EXISTS: the engine renders an entity from a TYPE-SPECIFIC graphics
-- field. A sprite placed in the wrong field is silently ignored and the entity
-- is INVISIBLE in world -- exactly the capacitor bug (art assigned to a
-- top-level `picture` on an accumulator, whose art must live in
-- `chargable_graphics`). The runtime prototype API (LuaEntityPrototype) exposes
-- NO graphics accessor, so this cannot be checked from a factorio-test; it is a
-- DATA-STAGE guard (prototypes/graphics-audit.lua) backed by this pure module.
--
-- PURE: no game.* / data.* / prototypes.* access. It takes a data.raw-like table
-- and a list of {type=, name=} specs and returns the names that render nothing.
-- That makes the audit logic unit-testable off the game
-- (unit-tests/test_graphics_audit.lua) and reusable by the data-stage guard.

local M = {}

-- The graphics field(s) the ENGINE actually renders, per prototype type. An
-- entity of a listed type is visible iff at least one of these fields
-- (recursively) contains a sprite reference. Field names verified against the
-- vanilla source of each cloned entity (accumulator, crusher, chemical-plant,
-- electric-furnace, assembling-machine-3, heating-tower, steel-chest, huge-rock).
M.RENDER_FIELDS = {
  ["accumulator"]               = { "chargable_graphics" },
  ["assembling-machine"]        = { "graphics_set", "animation", "animations" },
  ["furnace"]                   = { "graphics_set", "animation", "animations" },
  ["reactor"]                   = { "picture", "graphics_set", "lower_layer_picture" },
  ["electric-energy-interface"] = { "picture", "pictures", "animation", "animations" },
  ["simple-entity"]             = { "picture", "pictures", "animations" },
  ["container"]                 = { "picture", "pictures" },
}

-- Recursively true if `v` (a Sprite / Animation / layered graphics table)
-- contains any real sprite reference: a non-empty `filename`, or a non-empty
-- `filenames` list (stripes / multi-file sheets).
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

-- Is one of `type`'s engine render fields populated with a sprite on `proto`?
function M.is_visible(proto, proto_type)
  if type(proto) ~= "table" then return false end
  local fields = M.RENDER_FIELDS[proto_type]
  if not fields then
    -- Unknown type: fall back to any graphics-ish sprite anywhere on the proto.
    -- (Add the type to RENDER_FIELDS when a new entity kind is introduced.)
    return has_sprite(proto)
  end
  for _, f in ipairs(fields) do
    if has_sprite(proto[f]) then return true end
  end
  return false
end

-- === Animated-state audit (ci-z94) =========================================
-- A SECOND class of invisible-to-the-player bug: an entity that renders fine but
-- never MOVES. Cindra's flare-storage kit (capacitor / molten-salt battery /
-- dissipator) is read at a glance across a field of units -- which ones are
-- taking the surge, which are idle -- and a static building says nothing. ci-pru
-- shipped all three as single frames; ci-z94 animated them. This audit is what
-- stops the next one from shipping static: the class is enumerated LIVE from
-- data.raw, so a NEW player-placeable Cindra power building cannot load without
-- its working animation.
--
-- Each entry lists field PATHS that must every one resolve to a real multi-frame
-- animation on a member of the class.
M.REQUIRED_ANIMATIONS = {
  -- An accumulator shows its two states through chargable_graphics; a single
  -- `picture` is the idle body only.
  ["accumulator"] = {
    { "chargable_graphics", "charge_animation" },
    { "chargable_graphics", "discharge_animation" },
  },
  -- An electric-energy-interface scales `animation` to its energy consumption,
  -- so the animation IS the load readout. A bare `picture` cannot show load.
  ["electric-energy-interface"] = {
    { "animation" },
  },
}

-- Recursively true if `v` holds a real ANIMATION -- more than one frame of
-- motion -- rather than a still image. A single-frame sprite parked in an
-- `animation` field passes has_sprite but the player still sees nothing move.
local function has_animation(v)
  if type(v) ~= "table" then return false end
  if type(v.frame_count) == "number" and v.frame_count > 1 then return true end
  if type(v.filenames) == "table" and #v.filenames > 1 then return true end
  if type(v.stripes) == "table" and #v.stripes > 0 then return true end
  for _, child in pairs(v) do
    if has_animation(child) then return true end
  end
  return false
end
M.has_animation = has_animation

-- Is this prototype a building the PLAYER places and looks at? Only those owe an
-- animated state. Hidden helper phantoms (the power diode's buffer/tap
-- electric-energy-interfaces, which deliberately draw nothing) and unminable
-- test rigs (the flare measurement sink) are not part of the class.
function M.is_player_building(proto)
  if type(proto) ~= "table" then return false end
  if proto.hidden then return false end
  return proto.minable ~= nil
end

-- Given `raw` and `specs`, return the list of "name (path)" descriptions for
-- every player-placed entity of an animated class that is missing one.
function M.static_offenders(raw, specs)
  local bad = {}
  for _, spec in ipairs(specs) do
    local paths = M.REQUIRED_ANIMATIONS[spec.type]
    local proto = raw[spec.type] and raw[spec.type][spec.name]
    if paths and M.is_player_building(proto) then
      for _, path in ipairs(paths) do
        local node = proto
        for _, key in ipairs(path) do
          node = type(node) == "table" and node[key] or nil
        end
        if not has_animation(node) then
          bad[#bad + 1] = spec.name .. " (" .. table.concat(path, ".") .. ")"
        end
      end
    end
  end
  return bad
end

-- Given `raw` (a data.raw-like table) and `specs` (list of {type=, name=}),
-- return the list of spec names whose entity is absent or renders nothing.
function M.offenders(raw, specs)
  local bad = {}
  for _, spec in ipairs(specs) do
    local proto = raw[spec.type] and raw[spec.type][spec.name]
    if not M.is_visible(proto, spec.type) then
      bad[#bad + 1] = spec.name
    end
  end
  return bad
end

-- Discover every custom Cindra entity (name prefixed "cindra-") across the known
-- graphics-bearing entity types in `raw`, skipping any name matching an entry in
-- `skip_prefixes`. Returns a spec list suitable for M.offenders. This makes the
-- guard a STANDING audit of "every custom entity", not a hand-maintained list.
function M.discover(raw, skip_prefixes)
  skip_prefixes = skip_prefixes or {}
  local specs = {}
  for proto_type in pairs(M.RENDER_FIELDS) do
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
