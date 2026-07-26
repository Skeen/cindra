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

- [ ] **Ribbon reads as a ribbon (once §15-2 lands).** When the lethal-edge damage
  + hard-wall geometry is implemented, confirm in-game that the playable band
  feels long east–west and constrained north–south, and that walking sunward
  heats / nightward chills as the axis predicts. (The axis *value* is unit-tested;
  the *felt geometry* is a playtest.)
