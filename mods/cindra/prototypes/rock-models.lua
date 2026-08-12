-- Data-stage rock-model guard (ci-w87): fail the load if any Cindra worldgen rock is
-- not wearing the vanilla model it declares -- or if a rock that generates in the world
-- has no declared model at all.
--
-- This is the only place the check CAN live. The engine draws a simple-entity from its
-- `pictures`, but the runtime prototype API exposes no graphics accessor, so a
-- factorio-test can never see which boulder the player is actually looking at. Here the
-- sprites are still in hand: a clone that draws its source's files is wearing that
-- model, and one that draws huge-rock files under a blue tint is not -- which is the
-- exact regression the ice-rock playtest reported and this bead fixes.
--
-- The audit logic is the pure, unit-tested scripts/rock-models.lua, which is also the
-- catalogue prototypes/resources.lua clones each rock from -- so guard and rocks share
-- one intention. Runs after resources.lua has registered every rock.

local rock_models = require("scripts.rock-models")

local bad = rock_models.offenders(data.raw)
if #bad > 0 then
  error("cindra: rock model mismatch -- the player would see the wrong boulder:\n  "
    .. table.concat(bad, "\n  ") .. "\n(see prototypes/rock-models.lua)")
end
