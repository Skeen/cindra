-- Tuning constants for the one-way power-transfer PoC (the "power diode", ci-gcd).
--
-- FEASIBILITY SPIKE, deliberately ISOLATED from the main Cindra economy chain:
-- it wires into NO recipe / tech / worldgen. It exists to answer one question --
-- can a device move power A->B between two electric networks and NEVER B->A? --
-- and to leave a minimal working building + headless proof behind. See
-- scripts/diode.lua for the transfer logic and docs/power-diode-poc.md for the
-- feasibility verdict.
--
-- This module is PURE (no game.* / data.* / prototypes.*), so it loads in the
-- data stage, the control stage, and the plain-Lua unit tests alike (mirrors
-- scripts/flare-config.lua).

local C = {}

-- The two poles of the diode. A device that "straddles two networks" cannot be a
-- single entity: an entity joins exactly ONE electric network. So the diode is a
-- PAIR -- an input pole that sits on network A and an output pole that sits on
-- network B -- linked by the runtime, which moves buffered energy A->B only.
C.INPUT = "cindra-power-diode-input"
C.OUTPUT = "cindra-power-diode-output"

-- Configurable maximum transfer rate (W). The runtime never moves more than
-- rate/60 joules per tick per diode; both poles' network<->buffer flow limits are
-- sized to match so the script cap -- not the engine -- is the binding limit.
C.RATE_W = 10e6 -- 10 MW

-- Each pole's buffer (J). Big enough to hold several ticks of transfer so a slow
-- sweep interval never starves the output pole; small relative to a real battery
-- so the diode is a conduit, not a store.
C.BUFFER_J = 50e6 -- 50 MJ

-- Network<->buffer flow caps (W). Input pole charges from network A up to this;
-- output pole discharges into network B up to this. Set to the transfer rate so
-- the buffer keeps pace with the script move and neither side throttles below it.
C.INPUT_FLOW_W = C.RATE_W
C.OUTPUT_FLOW_W = C.RATE_W

-- Sweep cadence (ticks). DISTINCT from every other Cindra periodic system
-- (tile-damage 20, flare 23, panel-damage 29, building-heat 47) -- on_nth_tick is
-- REPLACE-not-add, so each system owns its own N.
C.TICK_INTERVAL = 7

return C
