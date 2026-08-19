-- Proof: Any Planet Start is INSTALLED, Cindra is on its menu, and the player
-- started somewhere else (ci-e9sj). This is a normal way to play -- install APS
-- plus our companion mod and leave the picker alone -- and it is the world the
-- other four APS suites were wrongly asserting against, because control.lua used
-- to register them on APS being loaded rather than on Cindra being CHOSEN.
--
-- The mod set (see README "APS installed, another start chosen"):
--
--   space-age quality elevated-rails recycler env-scanner
--   any-planet-start cindra-start            (NO cindra-dev-default)
--
-- APS's `aps-planet` picker then keeps its own default ("none"), so APS's
-- data-final-fixes returns early and APS changes NOTHING about the game.
--
-- What is still true here, and worth pinning, splits cleanly in two:
--
--   * The REGISTRATION half of test_aps_start: cindra-start's settings-stage
--     APS.add_choice("cindra") ran, so Cindra is offered in the picker. That is
--     the whole visible product of installing cindra-start next to APS.
--   * The mirror image of the three start-only suites (test_aps_start's rewrite
--     half, test_aps_foundry, test_aps_kit, test_aps_bootstrap): none of those
--     guarantees may have fired. A player who started on Nauvis must find
--     Cindra exactly as an APS-less player does -- still behind its discovery
--     tech, with no free research and no free machines.
--
-- That second half is the load-bearing part: cindra-start's runtime grants are
-- gated on `is_cindra_start()`, and a broken gate would silently hand every
-- Nauvis game the Cindra tech chain and a foundry. Asserting it costs nothing
-- and is exactly the failure the old registration could not see.

local H = require("tests.helpers")

-- The tech chain cindra-start pre-researches on a Cindra start
-- (cindra-start/control.lua PRE_RESEARCHED). Here, none of it may be granted.
-- The chain's third entry, the vanilla `foundry` tech, is left out on purpose:
-- it is reachable by ordinary play on the planets this run DOES start on, so its
-- researched flag would not identify cindra-start as the culprit. The two Cindra
-- techs below can only come from the pre-research.
local START_ONLY_TECHS = {
  "cindra-improvised-metallurgy",
  "cindra-lava",
}

-- The machines the ci-8wu bootstrap kit hands over. Here, none of them may
-- appear for free.
local KIT_MACHINES = { "foundry", "cindra-lava-manufacturer" }

describe("cindra with APS installed but another start chosen (ci-e9sj)", function()
  it("only applies to APS-loaded-but-not-Cindra (sanity)", function()
    assert.is_true(H.aps_loaded(), "any-planet-start must be active for this suite")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    assert.is_false(H.aps_cindra_start(),
      "this suite asserts the NOT-chosen world; the picker must not be cindra (got " ..
      tostring(settings.startup["aps-planet"] and settings.startup["aps-planet"].value) .. ")")
  end)

  -- =========================================================================
  -- The registration half: installing cindra-start next to APS puts Cindra on
  -- the menu. This is the one thing the companion mod does in this world, and
  -- it is what the player sees on the picker before they start a game.
  -- =========================================================================
  it("offers Cindra in the APS planet picker (add_choice took effect)", function()
    local picker = prototypes.mod_setting["aps-planet"]
    assert.is_not_nil(picker, "APS's aps-planet picker setting must exist")
    local offered = {}
    for _, v in pairs(picker.allowed_values or {}) do offered[v] = true end
    assert.is_true(offered["cindra"],
      "cindra-start must add Cindra to the picker's choices even when it is not picked")
  end)

  it("does not make itself the DEFAULT start (nothing forced on the player)", function()
    -- Offering Cindra and hijacking the start are different things.
    -- set_default_choice is cindra-dev-default's job -- a dev mod deliberately
    -- kept out of a normal install -- so plain APS + cindra-start must leave the
    -- picker's DEFAULT on APS's own "none" and let the player choose. Read the
    -- default off the setting prototype rather than the current value, so this
    -- says something about what cindra-start did rather than about what this
    -- run happens to be configured with.
    local picker = prototypes.mod_setting["aps-planet"]
    assert.are.equal("string", type(picker.default_value),
      "sanity: the picker must actually expose a default (else the check below is vacuous)")
    if script.active_mods["cindra-dev-default"] then
      assert.are.equal("cindra", picker.default_value,
        "cindra-dev-default, when loaded, is the mod that defaults the picker to Cindra")
    else
      assert.are_not.equal("cindra", picker.default_value,
        "cindra-start alone must not make Cindra the DEFAULT start")
    end
  end)

  -- =========================================================================
  -- The mirror of the start-only suites: APS did not pick Cindra, so none of
  -- the Cindra-start rewrites or grants may have happened.
  -- =========================================================================
  it("keeps Cindra behind its normal discovery gate (no APS start rewrite)", function()
    -- The inverse of test_aps_start's "prerequisites cleared". APS only strips
    -- the chosen planet's discovery tech; Cindra was not chosen, so a player who
    -- started on Nauvis must still have to research their way out to it (§6) --
    -- exactly as an APS-less player does (test_aps_absent asserts the same).
    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "the discovery tech prototype must exist")
    local prereqs = {}
    for _, p in pairs(tech.prerequisites) do prereqs[p.name] = true end
    assert.is_true(prereqs["planet-discovery-vulcanus"],
      "Cindra keeps its Vulcanus discovery prereq when it is not the chosen start")
    assert.is_not_nil(prototypes.space_location["cindra"], "cindra must still exist as a destination")
  end)

  it("hands out NO free Cindra research (the pre-research gate held)", function()
    -- cindra-start pre-researches the lava->metal spine on a Cindra start so the
    -- from-nothing opening cannot soft-lock (test_aps_foundry). On any other
    -- start the player has a normal game to play, and handing them the chain
    -- would skip a whole planet's progression for free.
    -- Read the TECH flags on the shared force, not its recipe-enabled state:
    -- suites earlier in the run legitimately unlock individual recipes on
    -- forces["player"] to drive their own machines (test_lava, test_bootstrap,
    -- test_science, ...), so recipe state there says nothing about who unlocked
    -- it. The recipe half of the same claim is asserted on a FRESH force below,
    -- where the slate is clean.
    local force = game.forces["player"]
    for _, name in ipairs(START_ONLY_TECHS) do
      assert.is_false(force.technologies[name].researched,
        name .. " must NOT be pre-researched: this is not a Cindra start")
    end
  end)

  it("re-checks the gate for a force created AFTER init (the MP path)", function()
    -- cindra-start also grants the chain from on_force_created, so the gate has
    -- to hold on THAT path too -- a multiplayer team joining a Nauvis game must
    -- not be handed Cindra's tech tree. The positive twin of this assertion is
    -- test_aps_foundry's ci-xs6 case.
    local name = "cindra-not-started-test-force"
    if game.forces[name] then game.merge_forces(name, "player") end
    local force = game.create_force(name) -- fires on_force_created -> the gate

    for _, tech in ipairs(START_ONLY_TECHS) do
      assert.is_false(force.technologies[tech].researched,
        tech .. " must NOT be granted to a force created after init on a non-Cindra start")
    end
    -- A fresh force starts from the prototypes' own enabled flags, untouched by
    -- whatever the rest of the run unlocked on forces["player"] -- so here the
    -- RECIPE state is a clean read of what a landing player would actually be
    -- able to craft. Nothing from the Cindra start may be craftable.
    assert.is_false(force.recipes["cindra-field-foundry"].enabled,
      "a force created after init must not get the Cindra field foundry")
    assert.is_false(force.recipes["cindra-lava"].enabled,
      "a force created after init must not get manufactured lava")

    game.merge_forces(name, "player") -- clean up so the surrounding suite is untouched
  end)

  it("hands out NO free bootstrap kit (the kit gate held)", function()
    -- The ci-8wu kit exists to rescue a from-nothing Cindra landing. On another
    -- start the player has a normal opening, and a free foundry would be a
    -- windfall that skips most of a playthrough.
    --
    -- Drive the LANDING itself rather than just reading the world afterwards:
    -- `simulate_player_landing` replays cindra-start's on_player_created path
    -- gate and all, with a crashed ship already sitting on the Cindra surface
    -- (the branch that stocks fastest). If the gate ever came off, that wreck --
    -- or the player -- would end up holding a foundry.
    local s = H.cindra_surface()
    local ship = s.create_entity({ name = "crash-site-spaceship", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(ship, "the crash-site spaceship must be placeable for this assertion")
    local player = game.players[1]
    assert.is_not_nil(player, "this assertion needs a player")
    local inv = player.get_main_inventory()

    assert.is_false(remote.call("cindra-start", "simulate_player_landing", player.index),
      "landing on a non-Cindra start must deliver no kit at all")

    local ship_inv = ship.get_inventory(defines.inventory.chest)
    for _, item in ipairs(KIT_MACHINES) do
      assert.are.equal(0, ship_inv.get_item_count(item),
        "the wreck must not be stocked on a non-Cindra start (" .. item .. ")")
      assert.are.equal(0, inv.get_item_count(item),
        "the bootstrap kit must not reach the player on a non-Cindra start (" .. item .. ")")
    end
    ship.destroy()
  end)

  it("still loads cindra-start's remote seam (the mod is present, just inert)", function()
    -- The interface registers unconditionally; what is gated is the runtime
    -- HANDOUT above. Pinning this keeps the two apart: "inert" must mean the
    -- grants did not fire, not that the mod half-loaded.
    assert.is_not_nil(remote.interfaces["cindra-start"],
      "cindra-start must still register its remote interface in this world")
  end)
end)
