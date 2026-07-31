-- Tuning constants for the one-way power-transfer device -- the "power diode"
-- (ci-gcd, reworked in ci-8l4 to a power-SWITCH-style single building).
--
-- FEASIBILITY SPIKE, deliberately ISOLATED from the main Cindra economy chain:
-- it wires into NO recipe / tech / worldgen. It answers one question -- can a
-- single building take TWO power inputs (like a power-switch) and SHIFT power one
-- direction between them, never back? -- and leaves a minimal working building +
-- headless proof behind. See scripts/diode.lua for the transfer logic and
-- docs/power-diode-poc.md for the feasibility verdict + the switch rework.
--
-- This module is PURE (no game.* / data.* / prototypes.*), so it loads in the
-- data stage, the control stage, and the plain-Lua unit tests alike (mirrors
-- scripts/flare-config.lua).

local C = {}

-- THE DEVICE. A single placed building, reskinned from the vanilla POWER-SWITCH,
-- so it exposes the switch's TWO copper wire connection points: the player wires
-- the SOURCE network to the left connector and the SINK network to the right.
-- (A device that "straddles two networks" cannot be one entity that itself joins
-- both -- an entity joins exactly ONE network -- so the switch's two copper
-- connectors are how one compact building reaches two far-apart networks. The
-- old design used two separately-placed poles paired by proximity; ci-8l4
-- replaces that with this explicit, single-building, two-input switch.)
C.DEVICE = "cindra-power-diode"

-- The two HIDDEN buffers the runtime shuttles energy between. Each is an
-- electric-energy-interface the script owns; they are NOT player-placeable (no
-- item) -- placing the DEVICE spawns them and copper-wires each to one switch
-- connector via a hidden tap pole, so each buffer lands on the network the player
-- wired to that side.
--   * INPUT  -- a LOAD on the source network (charge-only, output_flow_limit 0).
--   * OUTPUT -- a SOURCE on the sink network (discharge-only, input_flow_limit 0).
C.INPUT = "cindra-power-diode-input"
C.OUTPUT = "cindra-power-diode-output"

-- The two HIDDEN tap poles. An electric-energy-interface has no copper connector
-- of its own (it joins a network only by sitting in a pole's SUPPLY AREA), so
-- each buffer needs a tiny co-located pole that IS copper-wired to the switch
-- connector. The tap pole joins the wired network; its supply area covers only
-- its own buffer, carrying that network to the buffer.
C.INPUT_TAP = "cindra-power-diode-input-tap"
C.OUTPUT_TAP = "cindra-power-diode-output-tap"

-- Tap offset (tiles) from the device centre. The input pair sits at -TAP_DX, the
-- output pair at +TAP_DX, far enough apart that the tap poles' supply areas do
-- NOT cross-cover the other side's buffer (which would blur the two networks).
C.TAP_DX = 3

-- Configurable maximum transfer rate (W). The runtime never moves more than
-- rate/60 joules per tick per diode; both buffers' network<->buffer flow limits
-- are sized to match so the script cap -- not the engine -- is the binding limit.
C.RATE_W = 10e6 -- 10 MW

-- Each buffer's capacity (J). Big enough to hold several ticks of transfer so a
-- slow sweep interval never starves the output buffer; small relative to a real
-- battery so the diode is a conduit, not a store.
C.BUFFER_J = 50e6 -- 50 MJ

-- Network<->buffer flow caps (W). Input buffer charges from the source network up
-- to this; output buffer discharges into the sink network up to this. Set to the
-- transfer rate so the buffer keeps pace with the script move and neither side
-- throttles below it.
C.INPUT_FLOW_W = C.RATE_W
C.OUTPUT_FLOW_W = C.RATE_W

-- Sweep cadence (ticks). DISTINCT from every other Cindra periodic system
-- (tile-damage 20, flare 23, panel-damage 29, building-heat 47) -- on_nth_tick is
-- REPLACE-not-add, so each system owns its own N.
C.TICK_INTERVAL = 7

return C
