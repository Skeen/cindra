# Power diode PoC -- feasibility verdict (ci-gcd, ci-8l4)

**Question:** can a device move electric power *one way* between two networks --
so e.g. capacitors DUMP into batteries but power never flows back -- and can we
prove it headless?

**Verdict: FEASIBLE.** Approach (a), a scripted bridge between two electric-energy-
interface buffers, works, is robust, and is fully provable under `factorio-test`.
Approach (b), a pure-prototype directional trick, was investigated and is **not
viable** (see below). This PoC ships approach (a) as a minimal working building
plus a headless proof; it is deliberately isolated from the main Cindra economy
(no recipe / tech / worldgen wiring).

**ci-8l4 rework:** playtest feedback rejected the original *two separately-placed
poles paired by proximity* shape. The device is now ONE building that works
**like a power-switch** -- a single placed entity with TWO copper wire connection
points. You wire the source network to one side and the sink network to the
other, and it shifts power one direction between them. The two-buffer transfer
engine below is unchanged; only the packaging (one switch building + hidden guts,
explicit wiring instead of proximity) changed.

## The constraint

Factorio's electric grid is a single shared pool: every entity wired into one
network draws from and feeds the same pot, and there is **no directional flow
within a network**. So "one-way transfer" is only meaningful *between two
separate networks*, bridged by a device that moves energy A->B and never B->A.

## Approach (a) -- one power-switch building + scripted buffer bridge (SHIPPED)

The player-facing device is a reskinned vanilla **power-switch**
(`prototypes/power-diode.lua`, `C.DEVICE`): one building, two copper wire
connection points. On build (`scripts/diode.lua` `attach`, off `on_built` /
`script_raised_built` / robot / platform events) the runtime spawns its hidden
guts and copper-wires them:

* two hidden `electric-energy-interface` **buffers** the script shuttles energy
  between;
* two hidden **tap poles**, one co-located with each buffer, each copper-wired to
  one switch connector. An EEI has no copper connector of its own (it joins a
  network only via a pole's supply area), so the tap pole is how each buffer
  lands on the network the player wired to that side. The tap's `supply_area` is
  trimmed to ~1 so it powers *only* its own buffer, never the other side's.

| buffer | usage_priority     | input_flow_limit | output_flow_limit | role |
|--------|--------------------|------------------|-------------------|------|
| input  | `secondary-input`  | rate             | **0**             | a LOAD on the source network: draws power to fill its buffer, can never feed it back |
| output | `secondary-output` | **0**            | rate              | a SOURCE on the sink network: feeds its buffer into the sink, can never draw from it |

The switch is **forced OPEN** (`power_switch_state = false`) on build and every
sweep, so it can never bridge the two networks into one -- it stays a one-way
valve, not a two-way switch. Each sweep (its own nth-tick 7) moves buffered joules
from the input buffer to the output buffer, rate-capped at `rate/60` J per tick,
and only when the two buffers sit on **separate** networks. The energy path is
therefore strictly:

```
source net --(charge <= rate)--> input.buffer --(script)--> output.buffer --(discharge <= rate)--> sink net
```

### Demand-driven transfer (ci-76if)

The sweep is a **metered controller**, not a "keep both buffers topped up" loop.
Each sweep it measures the interval just elapsed -- how much the source actually
charged into the input buffer, and how much the sink actually pulled out of the
output buffer -- carries *only* that real source contribution across, and then
sizes the *next* interval's source pull to the sink's realized demand (plus a
small probe so a hungry sink ramps to the full rate). Both buffers rest near
**empty**. Consequences, each a test:

* **no parasitic draw** -- an idle / satisfied far side pulls nothing, so the
  controller pulls ~nothing from the source (`transfer = min(source supplied,
  far-side demand)`);
* **no free generation** -- the output buffer only ever gains what was pulled
  this interval, so a dark source yields zero at the sink and there is no
  self-charged reservoir to dump once the source dies (`energy out <= energy in`);
* **on/off gate** -- a disabled diode fully blocks: output emptied (nothing to
  the sink), input parked full (no load on the source).

This replaced the original oversized (50 MJ) self-charging buffers, which rested
FULL: they drew a constant ~10 MW from the source regardless of far-side demand
and could deliver megajoules of free energy to the sink after the source went
dark.

**One-way is guaranteed three independent ways**, any one of which alone blocks
reverse flow:
1. the input buffer has `output_flow_limit = 0` -- it cannot push power into the source;
2. the output buffer has `input_flow_limit = 0` -- it cannot pull power out of the sink;
3. the script only ever *subtracts* from the input buffer and *adds* to the
   output buffer, and the move is clamped `>= 0`.

**Configurable rate:** `scripts/diode-config.lua` `RATE_W` (default 10 MW); both
buffers' flow limits are sized to match so the script cap is the binding limit.

### Design note (why not `tertiary`/accumulator buffers)

An accumulator-priority buffer only charges from network **surplus** (production >
consumption). An input buffer built that way would never fill unless the source
network *already* had spare power. The `secondary-input` / `secondary-output`
priorities charge/discharge on **demand**, which is what a conduit needs -- so a
"dynamic" producer (the usual test power source) feeds it directly. This was the
one non-obvious pitfall; both the prototype comments and the tests record it.

### One building, two inputs (why the composite)

A device that "straddles two networks" cannot be a single entity that itself
*joins* both -- an entity joins exactly one electric network. The vanilla
power-switch is the one primitive that exposes **two copper connection points on
one building**, and its long wire reach lets one compact device tap two far-apart
networks (a substation's supply area cannot: two substations within 18 tiles
auto-wire into one network). So the diode reuses the switch for the two inputs and
records the input<->output link **on placement** (keyed by the device's
`unit_number`), replacing the original proximity `find_partner` heuristic. Removal
(mine / die / script-destroy) tears the hidden guts down and forgets the link.

## Approach (b) -- pure-prototype trick (NOT viable)

Considered: an accumulator/EEI pairing that achieves directionality with no
script -- e.g. a discharge-only accumulator feeding a generator. This fails
because directionality *within* a network is meaningless (single shared pool),
and *between* two networks there is no prototype that spans both: an entity has
exactly one electric connection, on one network. Nothing in the data stage moves
energy across a network boundary; only a script can read one network's buffer and
write another's. The flow-limit asymmetry (input_flow_limit / output_flow_limit)
gives the *directionality*, but a script is still required to carry joules across
the gap. So (b) collapses into (a).

## Proof (headless)

* `unit-tests/test_diode.lua` -- the pure transfer arithmetic: rate cap binds,
  supply/headroom bind, and the clamp is never negative (no reverse flow).
* `tests/test_power_diode.lua` -- under the real engine:
  1. energy flows A->B up to the rate cap, and the cap binds every step;
  2. energy never flows B->A (empty source + full destination moves nothing);
  3. two networks stay isolated (distinct `electric_network_id`);
  4. energy crosses A->B end-to-end through two real isolated networks;
  5. power never reaches A even when B is flooded and A is dark -- the output
     pole cannot even soak B's power (input_flow_limit 0);
  6. (ci-76if) OFF -> the far side gets 0 and the source draw is 0;
  7. (ci-76if) ON + a satisfied/idle far side -> ~0 source draw (no parasitic
     load);
  8. (ci-76if) ON + a far-side deficit -> transfer ramps up to the demand, one
     direction only;
  9. (ci-76if) no free generation -- prime the buffers from a live source, kill
     it, and the sink receives ~nothing further (the output collapses to ~0).

## What this could enable later

The capacitor->battery topology from the flare power system (§5): let a fast
capacitor bank DUMP its catch into a bulk battery bank on a separate network,
with no back-drain when the battery is fuller. Out of scope for this spike;
recorded here as the motivating use case.
