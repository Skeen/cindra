#!/usr/bin/env python3
# Animated working-light layers for Cindra's flare-storage buildings (ci-z94).
# Deterministic: pure analytic fields, same bytes every run, no RNG.
#
# WHY THIS EXISTS: ci-pru delivered the capacitor / molten-salt battery /
# dissipator as SINGLE STATIC FRAMES and filed the upgrade as a follow-up. A
# static building is a real gameplay problem here, not just a cosmetic one: these
# three are the flare-surplus routing kit (DESIGN.md §5), and the whole skill of
# the flare loop is reading, at a glance across a field of them, WHICH ones are
# taking the surge and which are idle. Vanilla says that with motion -- the
# accumulator's charge/discharge animations -- and Cindra's kit said nothing.
#
# WHAT THIS GENERATES: an emissive glow STRIP per building state, drawn as an
# additive `draw_as_glow` layer OVER the existing idle body (which is untouched).
# The engine picks the state, so the motion is not decoration -- it is a readout:
#
#   capacitor-charge     arc filaments crawling the plates, surging brighter
#   capacitor-discharge  a core flash and an expanding shock ring (it dumps fast)
#   battery-charge       molten salt heating, convection cells rolling (slow)
#   battery-discharge    heat draining outward in rings (slow, leaky)
#   dissipator-heat      the radiator fins glowing under a sweeping heat wave
#
# HOW IT STAYS REGISTERED: the glow is painted in the ROOF's own coordinate space
# -- `gen_entity_art.top_quad`, the same function that builds the body block -- so
# it lands on the actual roof motif rather than on a re-guessed copy of those
# numbers. It is then HARD-MASKED to the body's alpha, so no glow floats off the
# silhouette. The off-body aura is the prototype's `charge_light` / `light`,
# which is what the engine has light for.
#
# Output (run via scripts/render-entity-anim.sh which supplies numpy+pillow):
#   mods/cindra/graphics/entity/<building>/<building>-<state>.png
#     A FRAMES-cell sheet, LINE_LENGTH cells per row, each cell the same 256px
#     frame geometry as the idle body, so the prototype wires it at the body's
#     own scale/shift (prototypes/storage.lua).
#
# Guarded by mods/cindra/unit-tests/test_entity_anim.py (pixel invariants: the
# frames actually move, the cycle loops, nothing glows off the building) and
# mods/cindra/unit-tests/test_storage_graphics.lua (the wiring + sheet geometry).

import importlib.util
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

# Load the sibling art generator as a module (its filename has dashes, so it is
# not importable by name). It owns the Cindra palette and the block geometry;
# reusing both is what keeps the glow in the same visual family and on the roof.
_spec = importlib.util.spec_from_file_location(
    "gen_entity_art", os.path.join(HERE, "gen-entity-art.py"))
art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(art)

# -- Sheet geometry ----------------------------------------------------------
# One cell per frame, matching the idle body's 256px frame so the prototype can
# wire the glow at the body's own scale and shift. 16 frames at 4 per row.
FRAME_PX = art.ENTITY_PX          # 256, the idle-body frame size
FRAMES = 16
LINE_LENGTH = 4
FOOTPRINT = 0.78                  # entity_sprite's default; the body was built with it


# -- Field helpers (pure numpy; no RNG, no filters -> byte-stable) ------------
def roof_space(size, footprint=FOOTPRINT):
    """Per-pixel (u, v) roof coordinates and the roof mask.

    The top face is the diamond |u| + |v| <= 1, with u running W->E and v N->S,
    so a painter can be written in building terms and stays correct if the block
    geometry in gen-entity-art.py ever moves.
    """
    top, _ = art.top_quad(size, footprint)
    cx = (top[1][0] + top[3][0]) / 2.0
    cy = (top[0][1] + top[2][1]) / 2.0
    w = (top[1][0] - top[3][0]) / 2.0
    h = (top[2][1] - top[0][1]) / 2.0
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    u = (xs + 0.5 - cx) / w
    v = (ys + 0.5 - cy) / h
    # Soft roof edge (a couple of pixels) so the glow does not stair-step.
    roof = np.clip((1.0 - (np.abs(u) + np.abs(v))) * 12.0, 0.0, 1.0)
    return u, v, roof


def bell(x, sigma):
    """Gaussian falloff -- the soft-glow primitive, analytic so no blur is needed."""
    return np.exp(-(x / sigma) ** 2)


def wave(t, phase=0.0):
    """A 0..1 cosine breath over the cycle. Periodic in t, so the loop is seamless."""
    return 0.5 - 0.5 * np.cos(2.0 * math.pi * (t + phase))


def ramp(intensity, stops):
    """Map a 0..1 intensity field through a colour ramp (list of RGB triples).

    Low intensity reads as the deep/banked colour, high as the near-white core --
    the same hot-core-in-a-deep-shell read the static art and the icons use.
    """
    n = len(stops) - 1
    x = np.clip(intensity, 0.0, 1.0) * n
    idx = np.clip(np.floor(x), 0, n - 1).astype(np.int32)
    frac = (x - idx)[..., None]
    cols = np.array(stops, np.float64)
    return cols[idx] * (1.0 - frac) + cols[idx + 1] * frac


# -- State painters ----------------------------------------------------------
# Each returns a 0..1 intensity field for phase `t` in [0, 1). Every term is
# periodic in t, so frame FRAMES-1 flows back into frame 0 with no visible seam
# (except the discharge strobes, where the hard reset IS the dump).

def capacitor_charge(u, v, t):
    """Arc filaments crawling the plates, surging brighter as charge piles on."""
    level = 0.30 + 0.70 * wave(t)
    inten = np.zeros_like(u)
    # Three filaments arcing W->E, each sagging under a travelling sine.
    for amp, freq, phase in ((0.30, 2.0, 0.00), (0.20, 3.0, 0.37), (0.38, 1.0, 0.68)):
        sag = amp * np.sin(freq * math.pi * u + 2.0 * math.pi * (t + phase))
        span = np.clip((0.92 - np.abs(u)) * 6.0, 0.0, 1.0)  # stop short of the corners
        inten = np.maximum(inten, bell(v - sag, 0.085) * span)
    inten *= level
    # The two plate terminals stay lit and pulse with the charge level.
    for side in (-0.78, 0.78):
        inten = np.maximum(inten, bell(np.hypot(u - side, v), 0.16) * (0.35 + 0.65 * level))
    return inten


def capacitor_discharge(u, v, t):
    """A core flash and an expanding shock ring: the spike catcher dumping."""
    r = np.hypot(u, v)
    decay = (1.0 - t) ** 2
    ring = bell(r - (0.10 + 0.95 * t), 0.13) * (1.0 - t)
    core = bell(r, 0.24) * decay
    return np.clip(np.maximum(ring, core) * 1.15, 0.0, 1.0)


def battery_charge(u, v, t):
    """Molten salt heating: the tank fills with ember, convection cells rolling."""
    r = np.hypot(u, v)
    tank = np.clip((0.44 - r) * 3.5, 0.0, 1.0)      # the salt pool on the roof
    level = 0.32 + 0.58 * wave(t)                    # slow: the bulk store is sluggish
    cells = 0.55 + 0.45 * (np.sin(5.0 * math.pi * u + 2.0 * math.pi * t)
                           * np.sin(5.0 * math.pi * v - 2.0 * math.pi * t))
    return np.clip(tank * level * cells, 0.0, 1.0)


def battery_discharge(u, v, t):
    """Heat draining outward in slow rings -- the leaky bulk store giving it back."""
    r = np.hypot(u, v)
    pool = np.clip((0.62 - r) * 4.0, 0.0, 1.0)
    rings = 0.5 - 0.5 * np.cos(2.0 * math.pi * (3.0 * r - t))
    return np.clip(pool * (0.22 + 0.78 * rings) * 0.85, 0.0, 1.0)


def dissipator_heat(u, v, t):
    """Radiator fins glowing under a heat wave sweeping W->E, plus a vent pulse.

    Fin spacing is read from the static roof motif (gen-entity-art's
    roof_dissipator draws five lines at S*0.05 spacing over the top face), so the
    glow lands ON the fins instead of between them.
    """
    top, _ = art.top_quad(FRAME_PX, FOOTPRINT)
    fin_dv = (FRAME_PX * 0.05) / ((top[2][1] - top[0][1]) / 2.0)
    fins = np.zeros_like(u)
    for i in (-2, -1, 0, 1, 2):
        fins = np.maximum(fins, bell(v - i * fin_dv, 0.075))
    span = np.clip((0.74 - np.abs(u)) * 5.0, 0.0, 1.0)
    sweep = 0.40 + 0.60 * (0.5 - 0.5 * np.cos(2.0 * math.pi * (t - 0.6 * u)))
    vent = bell(np.hypot(u, v), 0.17) * (0.55 + 0.45 * wave(t))
    return np.clip(np.maximum(fins * span * sweep, vent), 0.0, 1.0)


# -- Assets ------------------------------------------------------------------
# Colour families straight from the Cindra palette (gen-entity-art.py): the
# capacitor is ENERGY (violet), the battery and the dissipator are HOT (ember),
# because one stores the surplus as charge and the others as heat.
VIOLET_RAMP = [art.VIOLET_DEEP, art.VIOLET, art.VIOLET_LIT, art.SPARK_WHITE]
EMBER_RAMP = [art.EMBER_DEEP, art.EMBER, art.ORANGE, art.HOT_YELLOW]
HOT_RAMP = [art.EMBER_DEEP, art.EMBER, art.ORANGE, art.HOT_WHITE]

SPECS = [
    {"building": "capacitor", "state": "charge",
     "paint": capacitor_charge, "ramp": VIOLET_RAMP},
    {"building": "capacitor", "state": "discharge",
     "paint": capacitor_discharge, "ramp": VIOLET_RAMP},
    {"building": "molten-salt-battery", "state": "charge",
     "paint": battery_charge, "ramp": EMBER_RAMP},
    {"building": "molten-salt-battery", "state": "discharge",
     "paint": battery_discharge, "ramp": EMBER_RAMP},
    {"building": "dissipator", "state": "heat",
     "paint": dissipator_heat, "ramp": HOT_RAMP},
]


def body_alpha(root, building):
    """The idle body's alpha -- the hard mask every glow frame is clipped to."""
    path = os.path.join(root, "mods/cindra/graphics/entity", building, building + ".png")
    body = np.asarray(Image.open(path).convert("RGBA"), np.uint8)
    return body[..., 3].astype(np.float64) / 255.0


def frame(paint, colour_ramp, t, mask, u, v, roof):
    """One glow frame: painted in roof space, coloured, masked to the body."""
    inten = np.clip(paint(u, v, t), 0.0, 1.0) * roof
    rgb = ramp(inten, colour_ramp)
    out = np.zeros(u.shape + (4,), np.uint8)
    out[..., :3] = np.clip(rgb + 0.5, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(inten * mask * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return out


def sheet(spec, root):
    """The full FRAMES-cell strip for one building state."""
    u, v, roof = roof_space(FRAME_PX)
    mask = body_alpha(root, spec["building"])
    rows = -(-FRAMES // LINE_LENGTH)
    canvas = Image.new("RGBA", (LINE_LENGTH * FRAME_PX, rows * FRAME_PX), (0, 0, 0, 0))
    for i in range(FRAMES):
        cell = frame(spec["paint"], spec["ramp"], i / FRAMES, mask, u, v, roof)
        canvas.paste(Image.fromarray(cell, "RGBA"),
                     ((i % LINE_LENGTH) * FRAME_PX, (i // LINE_LENGTH) * FRAME_PX))
    return canvas


def dest_of(spec, root):
    return os.path.join(root, "mods/cindra/graphics/entity", spec["building"],
                        "%s-%s.png" % (spec["building"], spec["state"]))


def main(argv):
    root = argv[1] if len(argv) > 1 else os.path.dirname(HERE)
    for spec in SPECS:
        dest = dest_of(spec, root)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        sheet(spec, root).save(dest)
        print("wrote " + os.path.relpath(dest, root))


if __name__ == "__main__":
    main(sys.argv)
