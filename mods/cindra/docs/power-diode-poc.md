# Power diode PoC -- feasibility verdict (ci-gcd)

**Question:** can a device move electric power *one way* between two networks --
so e.g. capacitors DUMP into batteries but power never flows back -- and can we
prove it headless?

**Verdict: FEASIBLE.** Approach (a), a scripted bridge between two electric-energy-
interface poles, works, is robust, and is fully provable under `factorio-test`.
Approach (b), a pure-prototype directional trick, was investigated and is **not
viable** (see below). This PoC ships approach (a) as a minimal working building
plus a headless proof; it is deliberately isolated from the main Cindra economy
(no recipe / tech / worldgen wiring).

## The constraint

Factorio's electric grid is a single shared pool: every entity wired into one
network draws from and feeds the same pot, and there is **no directional flow
within a network**. So "one-way transfer" is only meaningful *between two
separate networks*, bridged by a device that moves energy A->B and never B->A.

## Approach (a) -- scripted two-pole bridge (SHIPPED)

Two `electric-energy-interface` poles (`prototypes/power-diode.lua`):

| pole   | usage_priority     | input_flow_limit | output_flow_limit | role |
|--------|--------------------|------------------|-------------------|------|
| input  | `secondary-input`  | rate             | **0**             | a LOAD on network A: draws power to fill its buffer, can never feed A back |
| output | `secondary-output` | **0**            | rate              | a SOURCE on network B: feeds its buffer into B, can never draw from B |

Each sweep (`scripts/diode.lua`, on its own nth-tick 7) moves buffered joules
from the input pole to the output pole, rate-capped at `rate/60` J per tick. The
energy path is therefore strictly:

```
network A --(charge <= rate)--> input.buffer --(script)--> output.buffer --(discharge <= rate)--> network B
```

**One-way is guaranteed three independent ways**, any one of which alone blocks
reverse flow:
1. the input pole has `output_flow_limit = 0` -- it cannot push power into A;
2. the output pole has `input_flow_limit = 0` -- it cannot pull power out of B;
3. the script only ever *subtracts* from the input buffer and *adds* to the
   output buffer, and the move is clamped `>= 0`.

**Configurable rate:** `scripts/diode-config.lua` `RATE_W` (default 10 MW); both
poles' flow limits are sized to match so the script cap is the binding limit.

### Design note (why not `tertiary`/accumulator poles)

An accumulator-priority pole only charges from network **surplus** (production >
consumption). An input pole built that way would never fill unless the source
network *already* had spare power. The `secondary-input` / `secondary-output`
priorities charge/discharge on **demand**, which is what a conduit needs -- so a
"dynamic" producer (the usual test power source) feeds it directly. This was the
one non-obvious pitfall; both the prototype comments and the tests record it.

### Pairing / placement

A device that "straddles two networks" cannot be a single entity (an entity joins
exactly one network), so the diode is a *pair* of poles. Two genuinely isolated
networks force their poles far apart -- two substations within 18 tiles auto-wire
into one network -- so the poles of a real diode are NOT adjacent. The PoC links
each input pole to the nearest cross-network output pole (`find_partner`). A
shipping device would instead record the input<->output link on placement
(`on_built`) rather than infer it by proximity; nearest-cross-network is enough
for the single-diode PoC.

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
     pole cannot even soak B's power (input_flow_limit 0).

## What this could enable later

The capacitor->battery topology from the flare power system (§5): let a fast
capacitor bank DUMP its catch into a bulk battery bank on a separate network,
with no back-drain when the battery is fuller. Out of scope for this spike;
recorded here as the motivating use case.
