-- Cindra's two lethal-edge damage types (§4, §15 item 2).
--
-- The ribbon's whole thesis is a single axis with fire at one end and ice at the
-- other. Base Factorio ships no "heat" or "cold" damage type (Aquilo's freeze is
-- a bespoke engine mechanic, not a damage-type prototype), so the gradient
-- ticking damage that makes the edges FELT needs its own types:
--
--   cindra-heat  -> sunward edge  (the molten dayside cooks you)
--   cindra-cold  -> nightward edge (the frozen nightside freezes you)
--
-- These are NEW prototypes (namespaced `cindra-*`), never mutations of a shared
-- vanilla type, so nothing on any other planet is affected. scripts/ribbon.lua
-- stays pure and returns the SEMANTIC strings "heat"/"cold"; scripts/edge-damage
-- .lua maps those to these concrete prototype names when it applies damage.

data:extend({
  { type = "damage-type", name = "cindra-heat" },
  { type = "damage-type", name = "cindra-cold" },
})
