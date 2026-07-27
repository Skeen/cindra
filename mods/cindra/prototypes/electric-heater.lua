-- The Cindra electric heater (§15-10; DESIGN.md §5, §7 tuning table).
--
-- A heat SOURCE with a CAPPED heat output (600 C, below a reactor, above the
-- steam threshold) and an UNCAPPED electric power DRAW. On Cindra it is the
-- surplus-power sink that matters: it turns the flare's excess electricity into
-- heat for nightside warmth, water boil-off, and safe dissipation. Unlike the
-- vanilla heating tower (which BURNS chemical fuel), this one eats electricity,
-- so it is the natural home for the star's surplus.
--
-- SITUATIONAL-NOT-STRICTLY-BETTER (§12 guardrail): its heat ceiling is 600 C vs
-- the heating tower's 1000 C, and it needs an electric supply rather than a fuel
-- belt. It is superb where power is free and overflowing (Cindra at flare) and
-- clumsy anywhere you would rather burn fuel. Exportable, never a plain upgrade.
--
-- IMPLEMENTATION: a clone of the space-age heating-tower reactor. We reuse the
-- vanilla art (v1 art policy) but swap the burner energy source for electric and
-- lower the heat cap. We DEEP-COPY the shared vanilla prototype before touching
-- any nested table (heat_buffer) so we never mutate space-age's heating tower
-- (the never-mutate-other-planets invariant).
--
-- NATIVE-INGREDIENT GATE (partial): the design wants this gated behind a native
-- Cindra material so it is awkward to build off-world. For now the recipe is
-- built from vanilla intermediates and unlocked by a dedicated tech.
-- TODO(ci-txh): fold the signature aluminium into the ingredient list to make
-- the "clumsy off-world" import gate real (the old cryo-alloy plan is dropped).

local HEAT_CAP = 600 -- C, (tune) §7: below a reactor (1000), above steam boil.
local DRAW = "40MW" -- (tune) §7: the "uncapped" electric draw (no artificial cap).

-- Clone the heating-tower reactor. table.deepcopy guarantees we never alias the
-- shared space-age prototype or its nested tables.
local heater = table.deepcopy(data.raw["reactor"]["heating-tower"])

heater.name = "cindra-electric-heater"
heater.minable = { mining_time = 0.5, result = "cindra-electric-heater" }

-- Uncapped electric draw: eats power, never fuel. No effectivity fiddling; the
-- consumption value below IS the draw.
heater.energy_source = { type = "electric", usage_priority = "primary-input" }
heater.consumption = DRAW

-- Capped heat output.
heater.heat_buffer = table.deepcopy(heater.heat_buffer)
heater.heat_buffer.max_temperature = HEAT_CAP

-- It no longer burns anything: drop the burner fire glow / combustion cues so
-- the building does not read as a furnace. (Vanilla base picture is kept.)
heater.working_light_picture = nil
heater.temperature_to_suppress_energy_icons = nil

heater.localised_name = { "entity-name.cindra-electric-heater" }
heater.localised_description = { "entity-description.cindra-electric-heater" }

-- Item: clone the heating-tower item so we inherit a valid subgroup + vanilla
-- icon (v1 art reuse), then point it at our entity.
local item = table.deepcopy(data.raw["item"]["heating-tower"])
item.name = "cindra-electric-heater"
item.place_result = "cindra-electric-heater"
item.order = "b[cindra]-a[electric-heater]"
item.localised_name = { "item-name.cindra-electric-heater" }
item.localised_description = { "item-description.cindra-electric-heater" }

local recipe = {
  type = "recipe",
  name = "cindra-electric-heater",
  enabled = false, -- gated: unlocked by cindra-electric-heating below.
  energy_required = 8,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "heat-pipe", amount = 10 },
    { type = "item", name = "copper-plate", amount = 20 },
  },
  results = { { type = "item", name = "cindra-electric-heater", amount = 1 } },
}

local technology = {
  type = "technology",
  name = "cindra-electric-heating",
  -- v1 art reuse: the vanilla heating-tower icon.
  icon = "__space-age__/graphics/technology/heating-tower.png",
  icon_size = 256,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-electric-heater" },
  },
  -- Framed as an electric variant of the heating tower: that tech teaches heat
  -- management AND unlocks the heat-pipe this recipe needs. This unlock is the
  -- heater's own, distinct from the Cindra science tree (ci-3or).
  prerequisites = { "heating-tower" },
  unit = {
    count = 200,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  },
}

data:extend({ heater, item, recipe, technology })
