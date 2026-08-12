-- Power-diode prototypes -- the one-way power-transfer device (ci-gcd, reworked
-- to a power-SWITCH-style single building in ci-8l4).
--
-- ISOLATED feasibility spike: a single placed building that takes TWO power
-- inputs (like a power-switch) and SHIFTS power one direction between them, never
-- back. Deliberately wired into NO recipe / tech / worldgen -- the PoC is placed
-- via the editor for its headless proof. See docs/power-diode-poc.md.
--
-- THE SHAPE (why four prototypes for one building):
--   * DEVICE   -- a reskinned vanilla POWER-SWITCH. This is the ONLY thing the
--                player places / sees / mines. It carries the two copper wire
--                connection points; the player wires the source network to the
--                left connector and the sink network to the right.
--   * INPUT / OUTPUT -- two HIDDEN electric-energy-interface buffers the runtime
--                (scripts/diode.lua) shuttles energy between, one way. Not
--                player-placeable (no item): placing the DEVICE spawns them.
--   * INPUT_TAP / OUTPUT_TAP -- two HIDDEN electric poles. An EEI has no copper
--                connector of its own (it joins a network only via a pole's
--                supply area), so each buffer needs a co-located tap pole that
--                the script copper-wires to a switch connector. The tap pole
--                joins the wired network and its supply area carries that network
--                to the buffer.
--
-- We ADD ONLY new prototypes and DEEP-COPY the shared vanilla power-switch /
-- electric-energy-interface / electric-pole before touching them (never-mutate-
-- other-planets). The clones inherit real sprites so they pass the data-stage
-- graphics audit (prototypes/graphics-audit.lua) unchanged; vanilla Nauvis
-- power-switches / EEIs are completely unaffected.
--
-- The DIRECTIONALITY lives in each buffer's energy_source (usage_priority + flow
-- limits), so it holds even without the script:
--   * input buffer  -- a LOAD (usage_priority "secondary-input", output_flow_limit
--                      = 0). It draws power from the source network to fill its
--                      buffer as real demand, and can NEVER feed that network back.
--   * output buffer -- a SOURCE (usage_priority "secondary-output", input_flow_limit
--                      = 0). It feeds its buffer into the sink network as
--                      production, and can NEVER draw power out of it.
-- (A "tertiary"/accumulator buffer would NOT work here: accumulators only charge
-- from network SURPLUS, so an input buffer would never fill unless production
-- already exceeded consumption. The input/output priorities charge/discharge on
-- demand, which is what a conduit needs.)
--
-- These flow-limit/priority asymmetries give the DIRECTIONALITY. They do NOT by
-- themselves decide HOW MUCH crosses: the runtime controller (scripts/diode.lua
-- M.step_pair, ci-76if) rests both buffers near EMPTY and moves only what the
-- source actually supplied against the far side's realized demand. So the buffers
-- are a metered conduit, never a resting store -- the output does not sit full,
-- and there is no self-charging reservoir to draw parasitically or to dump into
-- the sink as free energy once the source goes dark.

local util = require("util")
local C = require("scripts.diode-config")

local function watts(w) return string.format("%dW", math.floor(w)) end
local function joules(j) return string.format("%dJ", math.floor(j)) end

local DEVICE_TINT = { 0.7, 0.9, 1, 1 }

-- THE DEVICE: a deep-copied vanilla power-switch, re-tinted/re-iconed. It keeps
-- the switch's two copper connection points (left/right) and its wire reach so
-- one compact building can straddle two far-apart networks. The switch's OPEN
-- state keeps the two sides isolated (the diode's whole premise); its own
-- open/closed toggle is irrelevant to the transfer -- the script never merges the
-- networks, it shuttles buffered joules across.
local device = util.table.deepcopy(data.raw["power-switch"]["power-switch"])
device.name = C.DEVICE
device.minable = { mining_time = 0.3, result = C.DEVICE }
device.icons = { { icon = "__base__/graphics/icons/power-switch.png", tint = DEVICE_TINT } }
device.localised_name = { "entity-name." .. C.DEVICE }
device.localised_description = { "entity-description." .. C.DEVICE }
device.next_upgrade = nil

-- A hidden, script-owned helper: never in the player's way, never selectable /
-- minable, no map / factoriopedia entry. Shared by the buffers and the tap poles.
local function make_hidden(proto, name)
  proto.name = name
  proto.hidden = true
  proto.hidden_in_factoriopedia = true
  proto.selectable_in_game = false
  proto.minable = nil
  proto.next_upgrade = nil
  -- Collide with nothing: the helpers are phantoms spawned under / next to the
  -- device, so they must never fail to place or block the player's builds.
  proto.collision_mask = { layers = {} }
  proto.localised_name = { "entity-name." .. C.DEVICE }
  proto.flags = { "placeable-off-grid", "not-on-map", "not-deconstructable", "not-blueprintable" }

  -- The helper is a PHANTOM: it draws nothing, so it should claim no drawing
  -- space either. The clones inherit their source's 2x2-ish selection box (and
  -- the pole's 2.2-tile vertical drawing extension), and the drawing box is
  -- derived from those -- a box several tiles wide, sitting TAP_DX tiles off the
  -- device, for an entity with no sprite. Collapse it to a point. (The COLLISION
  -- box is deliberately left alone: the tap pole powers its buffer by the
  -- buffer's bounding box overlapping the tap's supply area, so shrinking that
  -- one to a point would put the buffer exactly on a tile corner and make the
  -- electrical coupling a boundary case. collision_mask is already empty, so the
  -- box blocks nothing.)
  proto.selection_box = { { 0, 0 }, { 0, 0 } }
  proto.drawing_box_vertical_extension = 0

  -- Every OTHER render surface the clone inherited from its vanilla source
  -- (ci-ntgh). ci-qj5k blanked the main sprite field, but each source prototype
  -- carries more art than that one field, and all of it drew in states the
  -- placed-and-idle view never showed:
  --   * radius_visualisation_picture -- the small-pole's supply-area overlay. It
  --     paints whenever the player holds a pole or any powered entity, so the
  --     diode sprouted two stray blue patches TAP_DX tiles either side.
  --   * water_reflection -- the small-pole's mirrored sprite. Over water the
  --     blanked pole still cast a POLE reflection: the leaked model again.
  --   * corpse / dying_explosion -- wreckage + explosion models. A helper killed
  --     by splash damage left battery / power-pole remnants sitting off to the
  --     side of the device, long after the thing that made them was gone.
  --   * damaged_trigger_effect -- hit particles thrown from the phantom.
  --   * alert_when_damaged -- a map alert pinned to the phantom's offset
  --     position rather than to the building the player actually placed.
  -- None of these belong to a hidden internal buffer; the DEVICE is the only
  -- thing that should ever draw, wreck, or raise an alert.
  proto.radius_visualisation_picture = nil
  proto.water_reflection = nil
  proto.corpse = nil
  proto.dying_explosion = nil
  proto.damaged_trigger_effect = nil
  proto.alert_when_damaged = false
  -- Wherever a helper still reaches a list (alerts, debug views), show the
  -- DEVICE's icon -- not the battery / pole it was cloned from.
  proto.icon = nil
  proto.icons = { { icon = "__base__/graphics/icons/power-switch.png", tint = DEVICE_TINT } }
  return proto
end

-- Blank a helper's graphics so ONLY the visible power-switch DEVICE renders
-- (ci-qj5k). The buffers are EEIs cloned from the vanilla accumulator-interface,
-- so they inherit its BATTERY sprite; the tap poles inherit the small-pole sprite.
-- Left alone, those leak through and the diode reads as "two batteries with poles
-- inside" instead of the clean switch. We point the helper's render field at the
-- 1x1 transparent core sprite (invisible in world) and stop the internal
-- copper/circuit wires (tap<->switch) from drawing. util.empty_sprite() still
-- carries a real filename, so the data-stage graphics audit
-- (prototypes/graphics-audit.lua) sees a wired render field and passes -- the
-- helper is intentionally-empty, not the silently-invisible bug audit guards
-- against.
--
-- The render field differs by type: an EEI draws from `picture` (a Sprite); an
-- electric-pole draws from `pictures` (a RotatedSprite, so it needs a
-- direction_count). Blank exactly the field the engine reads and clear the rest.
local function empty_sprite() return util.empty_sprite() end
-- An empty RotatedSprite with `dirs` frames. The engine requires an electric
-- pole's `pictures` direction_count to match its connection_points count, so the
-- blank must carry as many (transparent) directions as the cloned pole had.
local function empty_rotated(dirs)
  local s = util.empty_sprite()
  s.direction_count = dirs
  return s
end
local function hide_wires(proto)
  proto.draw_copper_wires = false
  proto.draw_circuit_wires = false
end

-- THE FLOATING WARNING SYMBOL (ci-ntgh). An electric energy source draws the
-- engine's "no power" bolt / "no network" plug over ITS OWN entity whenever its
-- demand goes unmet. The diode's demand lives in the hidden INPUT buffer, and
-- that buffer sits TAP_DX (3) tiles off the device by construction -- the two tap
-- poles' supply areas must not cross-cover the other side's buffer, or the two
-- networks blur into one and the diode stops being a diode. So the buffer cannot
-- move onto the device, and the icon it raised appeared floating in open ground
-- well outside the model, attached to nothing the player can see.
--
-- The fix is not an offset: it is that a hidden internal buffer has no business
-- raising a player-facing power alert at all. Both flags exist on every energy
-- source for exactly this case, so the buffers opt out and the DEVICE stays the
-- only thing that speaks for the diode. The controller (scripts/diode.lua) keeps
-- the input buffer parked with a small probe of headroom every sweep, so on a
-- source network that cannot fill it the icon was permanent, not a flicker.
local function silence_power_icons(source)
  source.render_no_power_icon = false
  source.render_no_network_icon = false
  return source
end

-- A hidden buffer: an EEI clone with the vanilla editor knobs neutralised (fixed
-- 0 production / usage), so energy only crosses via the network flow limits and
-- the script. Its inherited accumulator/battery sprite is blanked (ci-qj5k).
local function make_buffer(name, source)
  local buf = make_hidden(util.table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"]), name)
  buf.gui_mode = "none"
  buf.energy_production = "0W"
  buf.energy_usage = "0W"
  buf.energy_source = silence_power_icons(source)
  buf.picture = empty_sprite()
  buf.pictures = nil
  buf.animation = nil
  buf.animations = nil
  hide_wires(buf)
  return buf
end

-- INPUT buffer: a charge-only LOAD (output_flow_limit = 0). Draws from the source
-- network and can never push power back into it.
local input = make_buffer(C.INPUT, {
  type = "electric",
  buffer_capacity = joules(C.BUFFER_J),
  usage_priority = "secondary-input",
  input_flow_limit = watts(C.INPUT_FLOW_W),
  output_flow_limit = "0W",
})

-- OUTPUT buffer: a discharge-only SOURCE (input_flow_limit = 0). Feeds the sink
-- network and can never draw power out of it.
local output = make_buffer(C.OUTPUT, {
  type = "electric",
  buffer_capacity = joules(C.BUFFER_J),
  usage_priority = "secondary-output",
  input_flow_limit = "0W",
  output_flow_limit = watts(C.OUTPUT_FLOW_W),
})

-- A hidden tap pole: a small-electric-pole clone whose supply area is trimmed so
-- it powers ONLY its co-located buffer (never the other side's), and whose wire
-- reach spans from the tap offset to the device's copper connector.
local function make_tap(name)
  local tap = make_hidden(util.table.deepcopy(data.raw["electric-pole"]["small-electric-pole"]), name)
  -- Cover just the co-located buffer (radius ~1), so the input tap can never
  -- also power the output buffer -- which would blur the two networks into one.
  tap.supply_area_distance = 1
  -- CRITICAL: keep the reach BELOW the two taps' separation (2*TAP_DX). Electric
  -- poles auto-wire to any neighbour within maximum_wire_distance, so a reach
  -- that spanned the gap would auto-connect the input tap to the output tap and
  -- merge the two networks into one -- silently defeating the diode. TAP_DX+1 is
  -- comfortably past the short script wire to the switch connector (~TAP_DX-0.5,
  -- made with reach_check off) yet short of the far tap (2*TAP_DX).
  tap.maximum_wire_distance = C.TAP_DX + 1
  -- Blank the inherited small-pole sprite and suppress its internal copper wire so
  -- neither the pole nor the tap<->switch link leaks into the world (ci-qj5k). The
  -- electrical connection is unaffected -- draw_copper_wires is render-only.
  tap.pictures = empty_rotated(#tap.connection_points)
  tap.picture = nil
  hide_wires(tap)
  return tap
end

data:extend({
  device,
  input,
  output,
  make_tap(C.INPUT_TAP),
  make_tap(C.OUTPUT_TAP),
})

-- The DEVICE item (the only placeable one). No recipe or tech: the PoC stays off
-- the main progression chain by design, so it is editor-spawn only.
local device_item = util.table.deepcopy(data.raw["item"]["power-switch"])
device_item.name = C.DEVICE
device_item.place_result = C.DEVICE
device_item.order = "e[energy]-z[power-diode]"
device_item.icons = { { icon = "__base__/graphics/icons/power-switch.png", tint = DEVICE_TINT } }
device_item.localised_name = { "item-name." .. C.DEVICE }
device_item.hidden = false
data:extend({ device_item })
