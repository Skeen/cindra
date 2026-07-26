# Playtest checklist

Items pending in-game visual / interactive confirmation — the things
`factorio-test` **structurally cannot reach** (sprite appearance, day/night feel,
audio, UI, multiplayer). **Always prefer a test first** (see [`AGENTS.md`](AGENTS.md));
this list is the last resort when no test path exists.

## Pending

- [ ] **Reach and stand on Cindra (v1 smoke test).** *Repro:* `./play.sh` → New
  Game (with `cindra-dev-default` enabled, Any-Planet-Start lands on Cindra), or
  research `planet-discovery-cindra` from an existing save and travel from
  Vulcanus. *Look for:* the surface loads, the character spawns on buildable
  land, and you can place/mine entities. *Fallback:* the headless `factorio
  --create` load + `test_planet.lua` already prove the prototype loads and the
  surface generates; this entry is only for the interactive "it feels like a
  place you can stand" confirmation.

- [ ] **v1 art is placeholder (vanilla Vulcanus).** *Look for:* the star-map icon
  and orbital approach currently show Vulcanus art. This is expected in v1.
  Replace with bespoke Cindra ribbon/terminator art in a later pass (baked
  star-map + orbital-backdrop maps, terminator terrain tint). Until then, do not
  file this as a bug.

- [ ] **Electric heater reads as electric, not a furnace (§15-10).** The building
  reuses vanilla heating-tower art with the burner fire-glow removed. *Repro:*
  research `cindra-electric-heating`, build a `cindra-electric-heater`, wire it to
  power and a heat-pipe network. *Look for:* it draws power and warms the heat
  network to ~600°C (no higher), shows no combustion flame, and reads as an
  electric heater rather than a fuel-burning tower. (Prototype fields + runtime
  placement are tested in `tests/test_heater.lua`; only the *visual read* is a
  playtest, pending bespoke art.)

- [ ] **Ribbon reads as a ribbon (§15-2/3 landed).** The lethal-edge damage,
  hard-wall backstop, and resource bands are implemented and integration-tested
  (`test_edge_damage`, `test_worldgen`, `test_building_heat`). Confirm in-game the
  *feel*: the playable band reads long east–west and constrained north–south; the
  `out-of-map` void beyond the wall reads as a clean boundary (not a jarring
  cliff); walking sunward visibly cooks and nightward visibly chills the
  character HP; and pushing to the lethal margins for the richest stone/ice/
  volatiles feels like a deliberate, survivable-with-gear risk. (The axis *values*
  and *placement* are tested; the *felt geometry* is a playtest.)

- [ ] **Resource art is placeholder.** Stone/ice/volatiles resources are cloned
  from vanilla `stone` (recoloured via `map_color`) and bootstrap rocks from the
  vanilla `huge-rock`; the volatiles item reuses the vanilla ice icon. Expected in
  v1 — bespoke Cindra resource art is a later pass. Do not file as a bug.

- [ ] **Nightside cold damage vs Aquilo freeze (feel).** Unheated machines past
  the cold threshold take ticking cold damage (the spec's "take cold damage"
  option) rather than a reversible Aquilo-style freeze. Confirm the pace (default
  20 dps) gives enough time to run a heat umbilical out before a machine dies, and
  that it reads as "drag heat with you," not "instant loss." If the reversible
  freeze feels better, that is a future refinement, not a v1 bug.
