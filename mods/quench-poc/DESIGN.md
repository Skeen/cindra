# Cryo-quench PoC — modeling recommendation

**Bead:** ci-o4r · **For integration into:** ci-4xj · **Spec:** `planet_design.md` §8
("Signature product — cryo-hardened alloy") + §12 item 1.

## What this PoC proves

Factorio 2.1 can express Cindra's signature mechanic: **one craft that requires a
HOT input and a COLD input at the same time**, producing cryo-hardened alloy only
when both are present. The proof is a self-contained mod (`mods/quench-poc/`) with
stub inputs (a dummy hot fluid + a dummy coolant item) and a passing
`factorio-test` suite (`tests/test_quench.lua`, 6/6 green). It does **not** build
the lava/foundry chain — the hot fluid is a stub for the eventual molten-metal
output.

The test suite establishes four runtime facts on a powered quench building:

| Inputs supplied | Alloy crafted? |
|---|---|
| Hot fluid (≥ threshold) **+** cold item | ✅ yes |
| Cold item only (no fluid) | ❌ no |
| Hot fluid only (no cold item) | ❌ no |
| Fluid present **but below** the hot threshold **+** cold item | ❌ no |

The last row is the important one: it is the **empirical proof that fluid
`minimum_temperature` gating actually works** at runtime in 2.1, not just at the
prototype level.

## The modeling question

The spec asks: is "hot vs cold" best expressed as
**(a)** two distinct fluids, **(b)** fluid temperature ranges
(`minimum_temperature`/`maximum_temperature` on the ingredient), or
**(c)** item + fluid?

The key realization is that **(b) is not a standalone option** — it is a
*modifier*. A recipe cannot list the same fluid twice at two temperatures (recipe
ingredients are keyed by name), so temperature ranges alone cannot produce a
"hot input AND cold input" pair. Temperature gating layers on top of (a) or (c).
So the real choice is (a) vs (c), and then whether to add (b) on top.

### (a) Two distinct fluids — hot fluid + cold fluid

- **Pros:** Both inputs are piped, which literally realizes the planet's logistics
  thesis — "lava piped from the warm/central side, cryo-coolant piped from the
  nightward side" (§8). Symmetric and simple to reason about.
- **Cons:** Requires the machine to have **two input fluidboxes** with distinct
  pipe connections (more build friction, more plumbing to align). "Hot" and "cold"
  are **nominal** — enforced only by fluid identity, so nothing stops a player from
  piping in cold "hot-fluid". Doesn't use the engine's temperature system at all,
  which leaves the planet's whole hot/cold identity as flavor text rather than a
  mechanic. Contradicts the spec's "**start simple: cryo-coolant as a consumed
  material**" (a fluid is not a consumed material in the belt sense).

### (c) Item + fluid — hot molten fluid + cold coolant item  ✅ recommended

- **Pros:** Matches the spec directly — the cold input is a **consumed material
  item** delivered by belt, exactly as §8 asks for v1. Needs only **one input
  fluidbox** (the hot molten fluid), so the quench building is a straightforward
  fluid-crafter (this PoC clones the chemical plant). The logistics thesis still
  holds: **fluid from the warm side, item from the cold side** — the machine still
  sits in the ribbon plumbed one way and belted the other. Belt-delivered coolant
  is also the natural on-ramp to the optional advanced **circulating heat-sink
  loop** (swap the consumed item for a returning cold *fluid* later).
- **Cons:** A coolant *item* carries no temperature, so "cold" is nominal on that
  side. Acceptable for v1 — the spec explicitly ships the consumed-material form
  and defers the circulating-coolant depth to an advanced variant.

### (b) Temperature gating — apply to the hot fluid  ✅ recommended add-on

Put `minimum_temperature` on the hot fluid ingredient. This is what makes "hot"
**real and engine-enforced**: molten metal below the threshold will not craft (the
PoC proves this). It ties the signature recipe into genuine heat management — you
must keep the molten stream hot — which is precisely the planet's fire-vs-ice
tension, and it costs nothing extra to add.

## Recommendation for ci-4xj

**Ship (c) + (b): a hot molten *fluid* ingredient gated with `minimum_temperature`,
plus a cold cryo-coolant *item* as a consumed material.**

- Hot half = fluid, temperature-gated → "hot" is enforced by the engine, not by a
  name, and integrates with the lava/foundry molten-metal output as-is.
- Cold half = consumed item → matches the spec's v1 "consumed material", keeps the
  building to a single fluidbox, and belt-feeds cleanly.
- **Upgrade path (advanced variant, not v1):** replace the consumed coolant item
  with a **circulating cold fluid** that warms as it works and must be re-chilled
  on the nightside — i.e. add a second, `maximum_temperature`-gated fluid input.
  That is where approach (a)'s two-fluid, both-sides-piped form becomes the right
  shape; the PoC's temperature-gating proof already covers the cold-side gate.

Reject **(a) as the v1 form** — two fluidboxes add friction for no v1 benefit, the
consumed-material spec wants an item on the cold side, and it leaves temperature
unused. Keep two-distinct-fluids in reserve for the advanced circulating-loop tier.

## Concrete values used in the PoC (all tunable)

| Thing | PoC value | Note |
|---|---|---|
| Hot input | `quench-poc-molten-metal` fluid, 50 / craft | stub for molten metal |
| Hot threshold | `minimum_temperature = 500 °C` | below reactor (1000°), above steam (~500°) |
| Cold input | `quench-poc-cryo-coolant` item, 5 / craft | consumed material |
| Output | `quench-poc-cryo-alloy`, 1 / craft | the signature export |
| Building | chemical-plant clone, electric, custom recipe category | one fluid input box |
| Craft time | `energy_required = 0.5 s` | tune with the rest of the chain |

## How to run the proof

From the repo checkout that carries the Factorio 2.1 install + vendored
`factorio-test` (the full scaffold lives untracked in the sibling working copy):

```sh
nix shell nixpkgs#nodejs -c ./node_modules/.bin/factorio-test run \
  --factorio-path ./factorio/bin/x64/factorio \
  --data-directory ./factorio-test-data-dir \
  --mod-path <path-to>/mods/quench-poc \
  --mods space-age quality elevated-rails recycler
```

`recycler` is a required built-in DLC in 2.1 (`quality`/`space-age` depend on it);
the "Could not download mod: recycler" line is a harmless portal-probe warning —
the built-in `recycler 2.1.9` loads regardless.
