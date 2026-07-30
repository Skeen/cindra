-- Proof of the signature PIVOT (ci-84s): the cryo-quench + cryo-hardened alloy
-- are GONE, and ALUMINIUM is Cindra's signature product + primary export.
--
-- The old two-temperature-quench thesis (a single craft needing a HOT and a COLD
-- input) is dropped. This suite is the regression guard for the bead's MANDATORY
-- items, and it FAILS on main (where the cryo prototypes still exist and the
-- science pack is alloy-based):
--
--   1. NO cryo-quench / cryo-hardened-alloy prototypes remain (entity, items,
--      recipes, tech, private recipe-category) -- a clean drop, no dangling refs.
--   2. The headline SCIENCE PACK is re-based onto aluminium (and is free of the
--      old alloy), keeping it petrochemical-free + native.
--   3. ALUMINIUM is EXPORTABLE via the mass driver -- the launch chain is pressed
--      from Cindra aluminium, so the signature product is also the launch cargo.
--   4. The cold economy that the quench used is trimmed to exactly the quench-
--      only pieces: ice -> water and the other nightside uses survive; the
--      cryo-coolant (which existed ONLY to feed the quench) is gone.

local ALUMINIUM = "cindra-aluminium"

describe("pivot: no cryo-quench / cryo-hardened-alloy prototype survives", function()
  it("has no cryo entity, items, recipes, or tech", function()
    -- Entities.
    assert.is_nil(prototypes.entity["cindra-cryo-quench"],
      "the cryo-quench building must be gone")
    -- Items.
    assert.is_nil(prototypes.item["cindra-cryo-hardened-alloy"],
      "the cryo-hardened alloy item must be gone")
    assert.is_nil(prototypes.item["cindra-cryo-coolant"],
      "the cryo-coolant item (fed the quench only) must be gone")
    assert.is_nil(prototypes.item["cindra-cryo-quench"],
      "the cryo-quench place-item must be gone")
    -- Recipes.
    assert.is_nil(prototypes.recipe["cindra-cryo-hardened-alloy"],
      "the alloy recipe must be gone")
    assert.is_nil(prototypes.recipe["cindra-cryo-coolant"],
      "the cryo-coolant recipe must be gone")
    assert.is_nil(prototypes.recipe["cindra-cryo-quench"],
      "the cryo-quench build recipe must be gone")
    -- Technology.
    assert.is_nil(prototypes.technology["cindra-cryo-quenching"],
      "the cryo-quenching tech must be gone")
  end)

  it("leaves no recipe in the private cindra-quenching category", function()
    -- The quench used a private recipe category; with the quench gone, nothing
    -- may still declare it (a dangling category is a dangling reference).
    for name, recipe in pairs(prototypes.recipe) do
      local cats = recipe.categories
      if cats then
        assert.is_nil(cats["cindra-quenching"],
          "recipe '" .. name .. "' still lives in the removed cindra-quenching category")
      end
    end
  end)

  it("no surviving recipe consumes or produces the dropped cryo items", function()
    local DROPPED = {
      ["cindra-cryo-hardened-alloy"] = true,
      ["cindra-cryo-coolant"] = true,
    }
    for name, recipe in pairs(prototypes.recipe) do
      for _, ing in pairs(recipe.ingredients) do
        assert.is_nil(DROPPED[ing.name],
          "recipe '" .. name .. "' still consumes dropped cryo item '" .. ing.name .. "'")
      end
      for _, prod in pairs(recipe.products) do
        assert.is_nil(DROPPED[prod.name],
          "recipe '" .. name .. "' still produces dropped cryo item '" .. prod.name .. "'")
      end
    end
  end)
end)

describe("pivot: aluminium is the signature product", function()
  it("still exists as the power-manufactured metal", function()
    assert.is_not_nil(prototypes.item[ALUMINIUM], "aluminium must exist")
    assert.is_not_nil(prototypes.recipe[ALUMINIUM], "the aluminium recipe must exist")
  end)

  it("the headline science pack is re-based onto aluminium (and free of the old alloy)", function()
    local r = prototypes.recipe["cindra-science-pack"]
    assert.is_not_nil(r, "the science-pack recipe must exist")
    local has_aluminium = false
    for _, ing in pairs(r.ingredients) do
      if ing.name == ALUMINIUM then has_aluminium = true end
      assert.are_not.equal("cindra-cryo-hardened-alloy", ing.name,
        "the science pack must no longer consume the dropped cryo-hardened alloy")
    end
    assert.is_true(has_aluminium,
      "the science pack must consume the signature aluminium (the pivot's re-base)")
  end)

  it("is EXPORTABLE via the mass driver: the launch chain is pressed from aluminium", function()
    -- The mass driver assembles its launch vehicle INSIDE itself from raw aluminium
    -- (ci-loa: no pre-crafted can). Assert the launch-charge recipe (the silo's
    -- fixed_recipe) consumes aluminium, so the signature product is literally what
    -- leaves the planet.
    local charge = prototypes.recipe["cindra-launch-charge"]
    assert.is_not_nil(charge, "the launch-charge recipe (the internal launch vehicle) must exist")
    local from_aluminium = false
    for _, ing in pairs(charge.ingredients) do
      if ing.name == ALUMINIUM then from_aluminium = true end
    end
    assert.is_true(from_aluminium,
      "the launch vehicle must be built from raw aluminium -- the signature product is the export")

    -- And the driver is a rocket-silo (native cross-surface delivery), so a launch
    -- really does leave the planet.
    local driver = prototypes.entity["cindra-mass-driver"]
    assert.is_not_nil(driver, "the mass driver must exist")
    assert.are.equal("rocket-silo", driver.type,
      "the mass driver must be a rocket-silo so aluminium cargo delivers to orbit")
  end)
end)

describe("pivot: the cold economy survives (only the quench-specific bits are cut)", function()
  it("keeps ice -> water and the nightside chain", function()
    -- The bead keeps ice->water + the nightside/cold economy; only the quench-
    -- and alloy-specific pieces are removed. Prove the retained cold economy.
    assert.is_not_nil(prototypes.recipe["ice-melting"],
      "ice -> water must survive via the vanilla chemical-plant recipe (a core nightside use, not quench-specific)")
    assert.is_not_nil(prototypes.recipe["cindra-oxide-asteroid-crushing"],
      "the deep-nightside ice-crushing chain (a science-pack input, ci-ml1) must survive")
    assert.is_not_nil(prototypes.recipe["cindra-alumina"],
      "aluminium's alumina refine (stone + ice-chain calcite) must survive")
  end)
end)
