-- Which vanilla MODEL every Cindra worldgen rock wears (ci-w87), and the audit that
-- proves it still wears it.
--
-- WHY THIS EXISTS. A rock's model is the whole of what the player knows about it: you
-- see a boulder before you ever click it, and the silhouette is what tells you "that is
-- ice" or "that ground burns". Cindra shipped a cold-side rock built from the brown
-- huge-rock art under a pale blue multiply-tint, and the playtest read it for exactly
-- what it was -- "blue-tinted normal rocks" -- because a tint recolours rubble but
-- cannot give it the faceted silhouette of ice. The fix is to wear the RIGHT vanilla
-- model (Space Age already ships icebergs and glowing volcanic rocks), and the guard
-- against sliding back is to check the art the entity actually draws.
--
-- The engine renders a simple-entity from its `pictures`, so "which model is this" is
-- answerable from the sprite FILENAMES: a clone that draws the same files as its
-- declared vanilla source is wearing that source's model, and one that draws huge-rock
-- files under a tint is not, however blue the tint. That comparison needs no game
-- state, which is the point -- the runtime prototype API (LuaEntityPrototype) exposes
-- NO graphics accessor, so a factorio-test cannot see sprites at all. This module is
-- therefore PURE (no game.* / data.* / prototypes.*): it takes a data.raw-like table,
-- so the same logic backs a DATA-STAGE guard (prototypes/rock-models.lua, which errors
-- the load) and a plain-Lua unit test (unit-tests/test_rock_models.lua).
--
-- It is also the ONE source of truth for the mapping: prototypes/resources.lua builds
-- each rock by cloning `clone_from` from here, so the audit can never be checking a
-- different intention than the one the rocks were built from.

local field = require("scripts.resource-field")

local M = {}

-- Every Cindra worldgen ROCK, and the vanilla simple-entity whose model it wears.
--   name        the Cindra prototype
--   clone_from  the vanilla simple-entity it is deep-copied from (its MODEL)
--   tint        the deliberate recolour, if any (a key of scripts/rock_tint.lua), or
--               nil for "wears the source art untouched". A rock that is NOT declared
--               tinted here and turns up tinted is the ci-w87 regression.
--   place_order the entity's `autoplace.order`. MUST BE UNIQUE -- see below.
--
-- 🚨 WHY EVERY ROCK NEEDS ITS OWN `place_order`. Two autoplace entities that share an
-- order share the per-tile random stream the engine rolls their probability against, so
-- they succeed on exactly the SAME tiles -- and the loser of every tie is dropped for
-- colliding with the winner. The second entity then generates ZERO times, everywhere,
-- silently. That is not hypothetical: `cindra-volcanic-rock-huge` shipped with no
-- autoplace order alongside `cindra-volcanic-rock` and never once generated on a live
-- surface; nothing caught it because the tests summed the family's counts. Distinct
-- orders give each rock its own stream. Vanilla does the same thing (`a[rock]-a[huge]`
-- vs `a[rock]-b[big]`), and the BIGGER model sorts FIRST so the rare landmark boulder
-- claims its tile before the common one crowds it out.
M.ROCKS = {
  -- Warm-side bootstrap rock: genuinely a STONE boulder, so the brown rubble model is
  -- right and the warm tint (ci-jvc) only pulls it toward vanilla sandstone. This is
  -- the one rock whose recolour is intended.
  { name = field.ROCK, clone_from = "huge-rock", tint = "STONE_TINT",
    place_order = "a[cindra-rock]-a[sandy]" },

  -- Cold-side rocks: Aquilo's LITHIUM ICEBERG models. Untinted -- the art is already
  -- ice, and a tint on top is precisely what the playtest rejected.
  { name = field.ICE_ROCK_HUGE, clone_from = "lithium-iceberg-huge",
    place_order = "a[cindra-rock]-b[ice]-a[huge]" },
  { name = field.ICE_ROCK, clone_from = "lithium-iceberg-big",
    place_order = "a[cindra-rock]-b[ice]-b[big]" },

  -- Hot-side rocks: Vulcanus's charred volcanic boulders, each size in the plain model
  -- and the `-hot` twin whose art layers an emissive glow. Untinted: the two models
  -- already differ in the engine's own art, and which one you see is a truthful read of
  -- whether the ground under it burns (scripts/resource-field.lua restricts each to the
  -- tiles that match it).
  { name = field.BURNED_ROCK_HUGE, clone_from = "huge-volcanic-rock",
    place_order = "a[cindra-rock]-c[volcanic]-a[huge]" },
  { name = field.BURNED_ROCK_HUGE_HOT, clone_from = "huge-volcanic-rock-hot",
    place_order = "a[cindra-rock]-c[volcanic]-b[huge-hot]" },
  { name = field.BURNED_ROCK, clone_from = "big-volcanic-rock",
    place_order = "a[cindra-rock]-c[volcanic]-c[big]" },
  { name = field.BURNED_ROCK_HOT, clone_from = "big-volcanic-rock-hot",
    place_order = "a[cindra-rock]-c[volcanic]-d[big-hot]" },
}

-- The autoplace order declared for a Cindra rock. Errors rather than returning nil:
-- an order-less rock is the silent never-generates bug described above.
function M.place_order(name)
  for _, spec in ipairs(M.ROCKS) do
    if spec.name == name then
      assert(spec.place_order, "rock-models: " .. name .. " declares no place_order")
      return spec.place_order
    end
  end
  error("rock-models: no declared model for rock " .. tostring(name))
end

-- The vanilla model source declared for a Cindra rock (nil if it has no entry).
function M.clone_from(name)
  for _, spec in ipairs(M.ROCKS) do
    if spec.name == name then return spec.clone_from end
  end
  return nil
end

function M.spec(name)
  for _, spec in ipairs(M.ROCKS) do
    if spec.name == name then return spec end
  end
  return nil
end

-- Every sprite filename referenced anywhere inside a graphics table, sorted. Walks
-- both shapes a SpriteVariations takes (a flat array of Sprites, and Sprites carrying
-- `layers`) plus the `filenames` list form, so it sees the whole model whatever shape
-- the vanilla art happens to use.
function M.sprite_filenames(pictures)
  local out = {}
  local function walk(v)
    if type(v) ~= "table" then return end
    if type(v.filename) == "string" and v.filename ~= "" then out[#out + 1] = v.filename end
    if type(v.filenames) == "table" then
      for _, f in ipairs(v.filenames) do
        if type(f) == "string" and f ~= "" then out[#out + 1] = f end
      end
    end
    for _, child in pairs(v) do walk(child) end
  end
  walk(pictures)
  table.sort(out)
  return out
end

-- True if any leaf sprite in a graphics table carries a `tint` (i.e. the art is being
-- RECOLOURED rather than drawn as authored).
function M.is_tinted(pictures)
  local found = false
  local function walk(v)
    if found or type(v) ~= "table" then return end
    if v.tint ~= nil then found = true return end
    for _, child in pairs(v) do walk(child) end
  end
  walk(pictures)
  return found
end

local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

-- Audit a data.raw-like table. Returns a list of human-readable problems (empty when
-- every Cindra rock wears its declared model):
--
--   1. MODEL      a rock whose sprite filenames are not its declared source's -- it is
--                 drawing some other boulder.
--   2. RECOLOUR   a rock tinted without a declared tint (the ci-w87 regression: the
--                 wrong model repainted instead of replaced), or a declared-tinted rock
--                 that lost its tint.
--   3. COVERAGE   a Cindra simple-entity that AUTOPLACES (i.e. the player meets it in
--                 the world) with no catalogue entry at all. This is what stops the
--                 next rock from shipping unaudited: the class is enumerated LIVE from
--                 the prototype table, not from a list someone has to remember to edit.
--   4. PLACEMENT  a rock registered without its declared unique `autoplace.order`, or
--                 sharing one with another rock. Two rocks on one order share the
--                 engine's per-tile random stream and the second never generates
--                 anywhere -- invisibly, since it is still a perfectly valid prototype.
function M.offenders(data_raw)
  local out = {}
  local entities = (data_raw and data_raw["simple-entity"]) or {}

  local declared, order_owner = {}, {}
  for _, spec in ipairs(M.ROCKS) do
    declared[spec.name] = true
    local proto_order = entities[spec.name] and entities[spec.name].autoplace
      and entities[spec.name].autoplace.order
    if spec.place_order == nil then
      out[#out + 1] = spec.name .. ": declares no autoplace order (it would never generate)"
    elseif order_owner[spec.place_order] then
      out[#out + 1] = spec.name .. ": shares its autoplace order with "
        .. order_owner[spec.place_order] .. " (one of them would never generate)"
    else
      order_owner[spec.place_order] = spec.name
      if entities[spec.name] and proto_order ~= spec.place_order then
        out[#out + 1] = spec.name .. ": registered autoplace order is "
          .. tostring(proto_order) .. ", not its declared " .. spec.place_order
      end
    end
    local proto = entities[spec.name]
    local src = entities[spec.clone_from]
    if not proto then
      out[#out + 1] = spec.name .. ": declared rock is not registered"
    elseif not src then
      out[#out + 1] = spec.name .. ": model source " .. spec.clone_from .. " does not exist"
    else
      local mine = M.sprite_filenames(proto.pictures)
      local theirs = M.sprite_filenames(src.pictures)
      if #mine == 0 then
        out[#out + 1] = spec.name .. ": draws no sprite at all"
      elseif not same(mine, theirs) then
        out[#out + 1] = spec.name .. ": does not wear the " .. spec.clone_from .. " model"
      end
      local tinted = M.is_tinted(proto.pictures)
      if tinted and not spec.tint then
        out[#out + 1] = spec.name .. ": is recoloured, but its model must be drawn as authored"
      elseif spec.tint and not tinted then
        out[#out + 1] = spec.name .. ": lost its declared " .. spec.tint .. " recolour"
      end
    end
  end

  for name, proto in pairs(entities) do
    if type(name) == "string" and name:match("^cindra%-")
      and type(proto) == "table" and proto.autoplace ~= nil and not declared[name] then
      out[#out + 1] = name .. ": generates in the world with no declared model (add it to scripts/rock-models.lua)"
    end
  end

  table.sort(out)
  return out
end

return M
