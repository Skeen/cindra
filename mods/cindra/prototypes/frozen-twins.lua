-- FROZEN TWINS for the buildings the engine refuses to freeze (ci-de55).
--
-- Cindra's planet carries `entities_require_heating`, so the nightside freezes --
-- but the engine only honours that on 26 prototype types, and an accumulator, a
-- solar panel and an electric-energy-interface are on none of them (measured,
-- ci-qha1). So the capacitor, the molten-salt battery, the sunward solar bands
-- and the dissipator kept humming in the deep dark: exactly the immunity the
-- human ruling ("nothing should be immune") rejected.
--
-- WHY A SECOND PROTOTYPE RATHER THAN A RUNTIME SWITCH. Measured in-engine:
-- `LuaEntity.frozen` is READ ONLY, `LuaEntity.active` is READ ONLY on all three
-- types, and `electric_buffer_size` is writable only on an
-- electric-energy-interface. There is no field to flip. The one thing a script
-- CAN change about a placed building is WHICH PROTOTYPE IT IS, so each script
-- freezable building gets a twin -- same footprint, same buffer, zero flow, zero
-- production, wearing ice -- and scripts/script-freeze.lua swaps a building to its
-- twin when it falls outside every heat source's reach, and back when heat
-- returns.
--
-- The twin also solves the visible-cue half of the ruling for free. These types
-- have no `frozen_patch` field for the engine to draw, so a scripted freeze is
-- INVISIBLE by default -- a battery that silently stops working reads as a mod
-- bug and teaches the player nothing. The twin carries the frost in its own art,
-- the way a natively frozen machine does, with no per-entity render object for the
-- sweep to bookkeep. scripts/frost-audit.lua's load guard fails the build if a
-- script-frozen building's twin is missing or wears no frost, so the cue cannot be
-- dropped by a later author.
--
-- THE CLASS IS DISCOVERED LIVE from data.raw (scripts/frost-audit.lua
-- script_freeze_specs), never hand-listed: a new Cindra accumulator or solar band
-- gets its twin here automatically. What is NOT automatic is how to neutralise a
-- new TYPE -- that is a decision, so an unknown type stops the load asking for one.
--
-- Runs late in data.lua: it deep-copies finished prototypes, so every file that
-- edits the originals (art, surface conditions, tech gating) must already have run.

local util = require("util")
local audit = require("scripts.frost-audit")

local FROST_DIR = "__cindra__/graphics/entity/frost/"

-- Per-entity frost patches, DERIVED FROM THE BODY they are drawn over
-- (scripts/gen-frost-layer.py), so the rime settles on the machine's real shapes.
-- A building with no entry falls back to the generic rime decal below, which is
-- why a new one cannot ship without a cue.
local BODY_PATCH = {
  ["cindra-capacitor"] = FROST_DIR .. "capacitor-frost.png",
  ["cindra-molten-salt-battery"] = FROST_DIR .. "molten-salt-battery-frost.png",
  ["cindra-dissipator"] = FROST_DIR .. "dissipator-frost.png",
}

-- The fallback: a free-standing rime crust, scaled to the building's own
-- footprint. Used where the body art is VANILLA (the sunward solar bands are
-- deep-copies of the base game's panel), so there is no sprite of ours to derive
-- a patch from.
local GENERIC_PATCH = FROST_DIR .. "rime-generic.png"
local GENERIC_PX = 256
local PIXELS_PER_TILE = 32

-- Fields that turn a still image into a moving one. A frozen building does not
-- move, and -- load-bearing, not cosmetic -- every layer of a layered Animation
-- must run the SAME number of frames, so a single-frame frost layer cannot simply
-- be appended to one. Stripping these turns any animation into its first frame.
local MOTION_FIELDS = {
  "frame_count", "line_length", "animation_speed", "repeat_count", "frame_sequence",
  "direction_count", "stripes", "filenames", "slice", "dice", "dice_x", "dice_y",
}

-- The body layers of `art` as a STILL picture: its first frame, with the working
-- glow strips dropped (a frozen machine is not lit up from inside).
local function still_layers(art)
  local src = art and (art.layers or { art }) or {}
  local out = {}
  for _, layer in ipairs(src) do
    if not (layer.draw_as_glow or layer.blend_mode == "additive") then
      local copy = util.table.deepcopy(layer)
      for _, f in ipairs(MOTION_FIELDS) do copy[f] = nil end
      out[#out + 1] = copy
    end
  end
  return out
end

-- The first non-shadow layer: the BODY the frost has to register against.
local function body_layer(layers)
  for _, layer in ipairs(layers) do
    if not layer.draw_as_shadow then return layer end
  end
  return layers[1]
end

-- The frost layer for the building named `name` with footprint `box`. A
-- body-derived patch is generated at the body frame's own pixel size, so it
-- inherits the body layer's geometry EXACTLY and registers pixel-for-pixel --
-- copied rather than restated, so the two cannot drift apart when the art is
-- retuned. The generic decal has no such twin geometry, so it is sized from the
-- entity's own selection box instead.
local function frost_layer(name, box, layers)
  local patch = BODY_PATCH[name]
  if patch then
    local body = body_layer(layers) or {}
    return {
      filename = patch,
      width = body.width, height = body.height,
      scale = body.scale, shift = body.shift,
    }
  end
  box = box or { { -0.5, -0.5 }, { 0.5, 0.5 } }
  local lt, rb = box[1], box[2]
  local tiles = math.max(rb[1] - lt[1], rb[2] - lt[2])
  return {
    filename = GENERIC_PATCH,
    width = GENERIC_PX, height = GENERIC_PX,
    scale = tiles * PIXELS_PER_TILE / GENERIC_PX,
  }
end

local function frosted(base, art)
  local layers = still_layers(art)
  layers[#layers + 1] = frost_layer(base.name, base.selection_box, layers)
  return { layers = layers }
end

local function zero_flow(source)
  local s = util.table.deepcopy(source or { type = "electric" })
  s.input_flow_limit = "0W"
  s.output_flow_limit = "0W"
  return s
end

-- An INERT BODY: a fresh electric-energy-interface that is in the power network
-- and takes nothing out of it and puts nothing into it, wearing `base`'s art
-- under ice. Built field by field rather than deep-copied, because it is a
-- different prototype type from its base and a copied-over field the new type
-- does not know is a load error.
local function inert_body(base)
  return {
    type = "electric-energy-interface",
    icon = base.icon, icons = base.icons,
    icon_size = base.icon_size, icon_mipmaps = base.icon_mipmaps,
    flags = util.table.deepcopy(base.flags),
    max_health = base.max_health,
    collision_box = util.table.deepcopy(base.collision_box),
    collision_mask = util.table.deepcopy(base.collision_mask),
    selection_box = util.table.deepcopy(base.selection_box),
    corpse = base.corpse,
    dying_explosion = base.dying_explosion,
    impact_category = base.impact_category,
    energy_source = {
      type = "electric", usage_priority = "tertiary",
      buffer_capacity = "1J", input_flow_limit = "0W", output_flow_limit = "0W",
    },
    energy_production = "0W",
    energy_usage = "0W",
    gui_mode = "none",
    picture = frosted(base, base.picture),
  }
end

-- How each type is taken out of the power economy, and where its still art goes.
-- The NEUTRALISATION is the whole point: a twin that merely looks frozen would be
-- the silent-lie version of this feature. Every one of these is engine-native and
-- destroys nothing -- the stored joules stay in the buffer, they simply cannot
-- move (scripts/script-freeze.lua copies `energy` across the swap, and
-- tests/test_power_conservation.lua measures that the grid total is unchanged).
--
-- Each entry either EDITS a deep copy of the building (same prototype type, which
-- is what an accumulator needs so its charge survives) or REBUILDS it as
-- something inert (which is what a solar panel needs, since the engine forbids a
-- panel that produces nothing -- see FROZEN_TWIN_TYPE in scripts/frost-audit.lua).
local NEUTRALISE = {
  ["accumulator"] = { edit = function(twin)
    twin.energy_source = zero_flow(twin.energy_source)
    local g = twin.chargable_graphics or {}
    twin.chargable_graphics = { picture = frosted(twin, g.picture) }
  end },
  ["solar-panel"] = { rebuild = inert_body },
  ["electric-energy-interface"] = { edit = function(twin)
    twin.energy_usage = "0W"
    twin.energy_production = "0W"
    twin.energy_source = zero_flow(twin.energy_source)
    twin.picture = frosted(twin, twin.animation or twin.picture)
    twin.animation = nil
    twin.light = nil
  end },
}

local twins = {}
for _, spec in ipairs(audit.script_freeze_specs(data.raw)) do
  local base = data.raw[spec.type][spec.name]
  local how = NEUTRALISE[spec.type]
  if not how then
    -- Unreachable in a healthy load: scripts/frost-audit.lua's script-freeze audit
    -- already stops an unhandled type with a message that says what to decide.
    -- Kept as a belt-and-braces guard because shipping a twin that is a working
    -- copy of the building would be WORSE than shipping no twin at all.
    error("cindra: no frozen-twin neutralisation for prototype type '" .. spec.type
      .. "' (" .. spec.name .. ") -- add one to NEUTRALISE in"
      .. " prototypes/frozen-twins.lua, matching SCRIPT_FROZEN_TYPES in"
      .. " scripts/frost-audit.lua. See ci-de55.")
  end

  local twin = how.rebuild and how.rebuild(base) or util.table.deepcopy(base)
  twin.name = audit.frozen_name(spec.name)
  -- Not a thing the player builds, researches or reads about: it is a STATE of a
  -- building they already built. Hiding it also excuses it from the sibling
  -- animated-state audit (scripts/graphics-audit.lua is_player_building) -- a
  -- frozen machine that animated would be the bug, not the fix.
  twin.hidden = true
  twin.next_upgrade = nil
  -- Mining a frozen building returns the ORDINARY item, and a blueprint or
  -- pipette maps back to it, so the frozen state is never something a player can
  -- end up holding in their inventory.
  if base.minable and base.minable.result then
    twin.minable = util.table.deepcopy(base.minable)
    twin.placeable_by = { item = base.minable.result, count = 1 }
  end
  twin.localised_name = { "cindra-message.frozen-entity",
    base.localised_name or { "entity-name." .. spec.name } }
  twin.localised_description = { "cindra-message.frozen-entity-description",
    base.localised_description or { "entity-description." .. spec.name } }
  if how.edit then how.edit(twin) end
  twins[#twins + 1] = twin
end

data:extend(twins)
