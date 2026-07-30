-- Full-screen heat/cold damage-feedback tint sprite (§15 v2 item 4; ci-7tl).
--
-- The runtime (scripts/damage-feedback.lua) draws this sprite screen-filling and
-- character-anchored via the rendering API -- warm/red while a player takes HEAT
-- damage in a lethal band, frost/blue while they take COLD damage -- so the
-- environmental damage is UNMISTAKABLE and the player sees WHY they are losing
-- health. It is a plain white fill TINTED at draw time: the heat/cold colour and
-- its alpha (which scales with how deep into the lethal band the player stands)
-- both ride on the runtime tint, so ONE sprite serves both effects at every
-- intensity. Drawn on the `cursor` render layer (over the world, under the GUI)
-- and scaled huge so it covers the viewport at any zoom.
--
-- This upgrades the old GUI-banner placeholder (the salvaged worldgen-v2 design)
-- to a proper render-layer screen effect, as ci-7tl asks.
--
-- v1 art: the stock 10x10 white square, tinted at runtime -- a functional flat
-- tint that already reads clearly as "you are burning / freezing". A bespoke soft
-- radial vignette (darker at the edges, clearer in the centre) is an art/PLAYTEST
-- follow-up; see PLAYTEST.md.
--
-- 🚨 A `sprite` prototype only: it adds NOTHING to any entity and changes no other
-- planet. The runtime that uses it is scoped to `surface.name == "cindra"`.

data:extend({
  {
    type = "sprite",
    name = "cindra-damage-vignette",
    filename = "__core__/graphics/white-square.png",
    size = 10,
    flags = { "no-crop" },
  },
})
