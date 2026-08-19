-- ci-r7w4: "you must reach Cindra first" -- asserted as a player-observable
-- reachability claim, in whichever world is loaded.
--
-- WHAT THE PLAYER OBSERVES
--   * Normal play (Cindra is a DESTINATION). Research everything the tech tree
--     will ever offer you EXCEPT the Cindra discovery, and you still cannot craft
--     a drop of Cindra's signature content: no manufactured lava, no aluminium, no
--     science pack, no field foundry, no mass driver. Reaching the planet is the
--     gate, and nothing routes around it.
--   * Any-Planet-Start CINDRA START (Cindra is HOME). That gate is retired on
--     purpose -- you begin on the planet -- and nothing may be left stranded
--     behind it: every one of those recipes is still reachable, so the start
--     cannot soft-lock.
--
-- Both halves are measured by DRIVING A FRESH FORCE through the tech tree the way
-- a player would: repeatedly research whatever the tree actually offers (a hidden
-- technology is unresearchable, so it is never offered) until nothing more opens
-- up, then look at what that force can craft. That is why this suite exists as
-- well as the per-chain gating tests in test_lava / test_aluminium /
-- test_foundry_bootstrap: those name one prerequisite EDGE each, and three of them
-- described only the default world -- which is what made the documented with-APS
-- invocation exit non-zero on clean main (ci-r7w4). A reachability sweep states
-- the same intent in terms a player can see, and holds in both worlds.
--
-- Deliberately NOT "every cindra-* tech sits behind the discovery": some do not,
-- by design (cindra-flare-storage rides the vanilla accumulator tech,
-- cindra-electric-heating the heating tower). The claim is about the SIGNATURE
-- CHAIN -- the content DESIGN §6 puts after arriving on Cindra.

local H = require("tests.helpers")

-- The signature content the discovery gate is there to hold back. Named by RECIPE,
-- because a recipe the force cannot craft is the thing the player actually runs
-- into -- not a prerequisite list.
local SIGNATURE = {
  { recipe = "cindra-lava",           why = "the manufactured-lava metal spine (§8)" },
  { recipe = "cindra-aluminium",      why = "the signature product (ci-84s)" },
  { recipe = "cindra-science-pack",   why = "the headline science pack (§15-12)" },
  { recipe = "cindra-field-foundry",  why = "the Cindra-buildable field foundry (ci-arw)" },
  { recipe = "cindra-crude-lubricant", why = "native lubricant, the bootstrap tier (ci-arw)" },
  { recipe = "cindra-mass-driver",    why = "the orbital export path (§15-11)" },
}

local PROBE = "cindra-discovery-probe"

-- A force holding nothing, so a reachability sweep starts from zero. On an APS
-- Cindra start `game.create_force` fires cindra-start's pre-research (it hands a
-- real start the foundry chain), which would make the sweep below vacuous -- so
-- everything is wound back to unresearched first.
local function blank_force()
  local force = game.forces[PROBE] or game.create_force(PROBE)
  for _, tech in pairs(force.technologies) do
    if tech.researched then tech.researched = false end
  end
  return force
end

-- Research everything this force could ever get its hands on, skipping the names in
-- `blocked`. A player can only research what the tech tree offers, so hidden and
-- disabled technologies are skipped -- that is precisely how APS retires the
-- discovery tech. Multi-level/infinite technologies are skipped too: they never
-- gate content, and an infinite one never reads as `researched` (it would spin
-- this loop forever).
local function research_all_available(force, blocked)
  local progressed = true
  while progressed do
    progressed = false
    for name, tech in pairs(force.technologies) do
      local proto = tech.prototype
      if not tech.researched and not blocked[name] and tech.enabled and not proto.hidden
        and proto.level == proto.max_level then
        local ready = true
        for _, prereq in pairs(tech.prerequisites) do
          if not prereq.researched then
            ready = false
            break
          end
        end
        if ready then
          tech.researched = true
          progressed = true
        end
      end
    end
  end
  return force
end

describe("cindra discovery gate: reaching the planet is what unlocks it", function()
  it("the loaded mod set really is the world this suite thinks it is", function()
    -- Guards the branch below from being taken in the wrong world (a skip that
    -- silently applies everywhere would prove nothing anywhere).
    if H.aps_cindra_start() then
      assert.is_true(H.tech_is_retired(H.DISCOVERY_TECH),
        "an APS Cindra start must retire " .. H.DISCOVERY_TECH .. " -- the player is already there")
    else
      assert.is_false(H.tech_is_retired(H.DISCOVERY_TECH),
        H.DISCOVERY_TECH .. " must be a live, researchable technology in normal play -- it IS the gate")
    end
  end)

  it("nothing signature is stranded: a player can reach all of it (no soft-lock, either world)", function()
    local force = research_all_available(blank_force(), {})
    for _, entry in ipairs(SIGNATURE) do
      local recipe = force.recipes[entry.recipe]
      assert.is_not_nil(recipe, entry.recipe .. " must exist -- " .. entry.why)
      assert.is_true(recipe.enabled,
        entry.recipe .. " is unreachable: no researchable chain unlocks it (" .. entry.why
          .. "). On an APS Cindra start that is a soft-locked start.")
    end
  end)

  it("in normal play NONE of it is reachable until you reach Cindra", function()
    -- The APS Cindra start has no discovery gate by design (the test above proves
    -- it is retired there), so this half is the normal-play world only. It is the
    -- strict one: it fails if any signature chain ever grows a route that skips
    -- reaching the planet.
    if H.aps_cindra_start() then return end

    local force = research_all_available(blank_force(), { [H.DISCOVERY_TECH] = true })
    for _, entry in ipairs(SIGNATURE) do
      assert.is_false(force.recipes[entry.recipe].enabled,
        entry.recipe .. " is craftable without ever reaching Cindra -- the discovery gate leaks ("
          .. entry.why .. ")")
    end

    -- ...and it is genuinely the discovery tech doing that, not a dead tree: with
    -- the gate allowed, the same sweep hands all of it over.
    local reached = research_all_available(blank_force(), {})
    for _, entry in ipairs(SIGNATURE) do
      assert.is_true(reached.recipes[entry.recipe].enabled,
        entry.recipe .. " must become craftable once Cindra is reached (" .. entry.why .. ")")
    end
  end)
end)
