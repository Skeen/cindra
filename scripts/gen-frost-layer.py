#!/usr/bin/env python3
# Frozen-layer (frost patch) generator for Cindra buildings whose bespoke art
# ships NO frozen layer (ci-u92y). Deterministic: seeded, same bytes every run.
#
# WHY THIS EXISTS: on Cindra's nightside `entities_require_heating` freezes
# machines for real, and the engine draws the frost sheen ONLY from a
# `frozen_patch` sprite. ci-z7nu could fix the oxidizer and the glass furnace by
# REUSING the vanilla frost sprite of the machine each was cloned from. The arc
# furnace cannot: its body is Hurricane046's riveted vessel, which looks nothing
# like the assembling-machine-3 it was cloned from, so the vanilla patch would
# sit on the wrong shapes. The frozen layer has to be CREATED -- that is this
# script.
#
# HOW: the frost is DERIVED FROM THE BODY it will be drawn over, so it registers
# on the real shapes instead of being a hand-placed guess. For the body's frozen
# frame we compute where rime would actually settle:
#
#   * UP-FACING SURFACES. In this 3/4 top-down art a surface that faces up is
#     brighter than what lies just below it, so a positive vertical luminance
#     gradient marks the domes, rims and ledges that catch frost. Down-facing
#     flanks score ~0 and stay clear, which is what keeps the machine readable.
#   * SILHOUETTE TOP EDGES. The outline's upper boundary gets a bright ice cap,
#     the same read as snow on a roofline.
#   * PATCHY ACCRETION. Fractal value noise breaks the coverage up so it reads as
#     rime crusting over, not a flat blue wash.
#
# The result is tinted with an ice palette (pale blue-white, cooler in the
# recesses, near-white on the lit caps) and masked HARD to the body alpha, so no
# frost floats off the silhouette. Output alpha stays partial: the machine must
# still read THROUGH the frost as itself, exactly as vanilla frozen machines do.
#
# Output (run via scripts/render-frost-layer.sh which supplies numpy+pillow):
#   mods/cindra/graphics/entity/arc-furnace/arc-furnace-hr-frozen.png
#     A single 320x320 frame matching the body animation's frame geometry, wired
#     as graphics_set.frozen_patch at the body's own scale/shift so it registers
#     pixel-for-pixel (prototypes/red-mud.lua).
#
# Guarded by mods/cindra/unit-tests/test_frost_layer.py (pixel invariants) and
# mods/cindra/unit-tests/test_red_mud_graphics.lua (the wiring).

import os
import sys

import numpy as np
from PIL import Image

# -- Determinism -------------------------------------------------------------
SEED = 0xC1_9D_2A  # the Cindra art seed (scripts/gen-entity-art.py) -- byte-stable

# -- Ice palette -------------------------------------------------------------
# Deliberately the cold end of the Cindra family (gen-entity-art.py ICE_PALE /
# FROST_WHITE), so a frosted building reads as the same planet's ice.
ICE_SHADOW = (150, 186, 214)  # rime in the recesses: bluer, dimmer
ICE_BODY = (198, 224, 240)  # the bulk of the crust
ICE_LIT = (238, 250, 255)  # the lit caps on up-facing edges

# -- Accretion tuning --------------------------------------------------------
UPFACE_PROBE = 5  # px below a pixel used to measure "does this face up?"
UPFACE_GAIN = 12.0  # luminance-slope -> up-face score
EDGE_PROBE = 4  # px above a pixel used to find silhouette top edges
NOISE_OCTAVES = ((4, 1.0), (9, 0.55), (19, 0.30))  # (lattice, amplitude)
NOISE_FLOOR = 0.22  # noise below this never accretes (keeps bare metal showing)
COVER_GAMMA = 0.45  # <1 HARDENS the crust: accreted rime reads as thick ice, not a wash
MAX_ALPHA = 0.95  # the thickest rime still lets the body read through


def _lattice_noise(shape, cells, rng):
    """Deterministic smooth value noise: a random lattice, bicubic-upsampled."""
    h, w = shape
    grid = rng.random((cells, cells)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8), "L")
    return np.asarray(img.resize((w, h), Image.BICUBIC), np.float32) / 255.0


def fractal_noise(shape, rng, octaves=NOISE_OCTAVES):
    """Sum of value-noise octaves, normalised to 0..1."""
    total = np.zeros(shape, np.float32)
    weight = 0.0
    for cells, amp in octaves:
        total += amp * _lattice_noise(shape, cells, rng)
        weight += amp
    total /= weight
    lo, hi = float(total.min()), float(total.max())
    return (total - lo) / max(hi - lo, 1e-6)


def _shift_y(a, dy):
    """Shift an array down by `dy` rows (positive = sample from above), zero-filled."""
    out = np.zeros_like(a)
    if dy == 0:
        return a.copy()
    if dy > 0:
        out[dy:, :] = a[:-dy, :]
    else:
        out[:dy, :] = a[-dy:, :]
    return out


def luminance(rgb):
    """Rec.709 luma of a float 0..1 RGB array."""
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def frost_layer(body_rgba, seed=SEED):
    """Derive a frost patch (uint8 HxWx4 RGBA) from a body sprite frame.

    `body_rgba` is a uint8 HxWx4 array of the frame the patch will be drawn over.
    The returned patch is zero-alpha wherever the body is transparent.
    """
    rng = np.random.default_rng(seed)
    a = body_rgba[..., 3].astype(np.float32) / 255.0
    rgb = body_rgba[..., :3].astype(np.float32) / 255.0
    lum = luminance(rgb) * a  # transparent pixels contribute no brightness

    # 1. Up-facing surfaces: brighter than what sits just below them.
    slope = lum - _shift_y(lum, -UPFACE_PROBE)
    upface = smoothstep(slope * UPFACE_GAIN)

    # 2. Silhouette top edges: body here, empty a few px above -> a snow cap.
    top_edge = np.clip(a - _shift_y(a, EDGE_PROBE), 0.0, 1.0)
    # Spread the cap a little way down the surface it sits on.
    cap = np.zeros_like(top_edge)
    for dy in range(0, EDGE_PROBE * 2):
        cap = np.maximum(cap, _shift_y(top_edge, dy) * (1.0 - dy / (EDGE_PROBE * 2)))

    # 3. Patchy accretion, so the crust is rime rather than a flat wash.
    noise = fractal_noise(lum.shape, rng)
    patchy = smoothstep((noise - NOISE_FLOOR) / (1.0 - NOISE_FLOOR))

    # Combine: frost needs an up-facing surface AND a patch of accretion; a top
    # edge caps regardless (wind-driven rime always crusts the outline).
    accretion = np.maximum(upface * patchy, cap * (0.55 + 0.45 * patchy))
    coverage = np.clip(accretion, 0.0, 1.0) ** COVER_GAMMA

    # Tint: the crust is paler where the surface under it is lit, bluer in the
    # recesses, and brightest on the outline caps -- so it conforms to the form.
    lit = smoothstep((lum - 0.18) / 0.55)[..., None]
    shadow = np.array(ICE_SHADOW, np.float32)
    body = np.array(ICE_BODY, np.float32)
    lit_col = np.array(ICE_LIT, np.float32)
    colour = shadow + (body - shadow) * lit
    colour = colour + (lit_col - colour) * np.clip(cap, 0.0, 1.0)[..., None]

    alpha = coverage * a * MAX_ALPHA  # HARD-masked to the body silhouette

    out = np.zeros(body_rgba.shape, np.uint8)
    out[..., :3] = np.clip(colour, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return out


# -- The generic slab --------------------------------------------------------
# A SYNTHETIC body for the fallback decal (ci-de55). Some script-frozen buildings
# wear VANILLA art (the sunward solar bands are deep-copies of the base game's
# solar panel), so there is no body sprite of ours to derive a patch from and
# nothing we may redistribute a derivative of. Those get a generic rime decal
# instead -- generated by running the SAME accretion model over a body we invent:
# a top-lit rounded slab. The result is original art, it is ice from the same
# palette as every other Cindra frost layer, and the twin builder scales it to the
# building's own footprint (prototypes/frozen-twins.lua), so a NEW script-frozen
# entity gets a correctly sized cue for free instead of shipping bare.
SLAB_PX = 256
SLAB_INSET = 14  # px of clear margin, so the decal never overhangs the footprint
SLAB_CORNER = 34  # corner rounding radius (px)


def _rounded_mask(size, inset, radius):
    """Soft-edged rounded-square alpha mask, float 0..1."""
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    lo, hi = float(inset), float(size - 1 - inset)
    # Distance outside the rounded rectangle (0 inside).
    dx = np.maximum(np.maximum(lo + radius - xs, xs - (hi - radius)), 0.0)
    dy = np.maximum(np.maximum(lo + radius - ys, ys - (hi - radius)), 0.0)
    dist = np.sqrt(dx * dx + dy * dy) - radius
    return smoothstep(1.0 - (dist + 1.5) / 3.0)


GENERIC_FLOOR = 0.44  # noise below this stays bare, so the building reads through
GENERIC_MAX_ALPHA = 0.92
GENERIC_RIM = 3  # px: crystal edges catch the light
GENERIC_GAMMA = 0.30  # harder than the body-derived crust: rime, not a haze
# Finer than the body-derived octaves: with no body shapes to follow, the crystal
# GRAIN is what makes this read as ice rather than as a cloud.
GENERIC_OCTAVES = ((5, 1.0), (11, 0.60), (23, 0.38), (47, 0.22), (89, 0.12))


def generic_rime(size=SLAB_PX, seed=SEED):
    """A free-standing rime crust: patchy ice over a rounded footprint.

    The body-derived model above needs a body -- it reads up-facing surfaces and
    silhouette edges out of the sprite it will be drawn over. There is none here,
    so the crust is grown from noise alone: fractal islands of accretion, thicker
    toward the top (where rime settles), with lit crystal edges where a patch
    breaks. Masked to a rounded square so it never overhangs the footprint the
    twin builder scales it to.
    """
    rng = np.random.default_rng(seed)
    mask = _rounded_mask(size, SLAB_INSET, SLAB_CORNER)

    noise = fractal_noise((size, size), rng, GENERIC_OCTAVES)
    # Rime settles heaviest on the upper face and thins downward, the same read
    # as snow lying on a roof.
    lie = np.linspace(1.14, 0.74, size, dtype=np.float32)[:, None]
    coverage = smoothstep((noise * lie - GENERIC_FLOOR) / (1.0 - GENERIC_FLOOR))
    coverage = coverage ** GENERIC_GAMMA

    # Crystal edges: where the crust breaks, the rim is brighter than the field.
    inner = np.minimum.reduce([
        _shift_y(coverage, GENERIC_RIM), _shift_y(coverage, -GENERIC_RIM),
        np.roll(coverage, GENERIC_RIM, axis=1), np.roll(coverage, -GENERIC_RIM, axis=1),
    ])
    rim = np.clip(coverage - inner, 0.0, 1.0)

    thickness = np.clip(coverage, 0.0, 1.0)[..., None]
    colour = (np.array(ICE_SHADOW, np.float32)
              + (np.array(ICE_BODY, np.float32) - np.array(ICE_SHADOW, np.float32)) * thickness)
    colour = colour + (np.array(ICE_LIT, np.float32) - colour) * np.clip(rim * 1.6, 0, 1)[..., None]

    alpha = np.clip(coverage + rim * 0.5, 0.0, 1.0) * mask * GENERIC_MAX_ALPHA
    out = np.zeros((size, size, 4), np.uint8)
    out[..., :3] = np.clip(colour, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return out


# -- Assets ------------------------------------------------------------------
# Each spec names the SOURCE frame the patch is derived from and the file to
# write. Two flavours:
#
#   * NATIVE frozen_patch (ci-u92y) -- for a crafting machine, whose graphics_set
#     has a frozen_patch field the ENGINE draws. Written beside the body art.
#   * SCRIPT-FREEZE frost (ci-de55) -- for a building the engine refuses to freeze
#     at all, whose frozen TWIN prototype layers this over its body
#     (prototypes/frozen-twins.lua). Written under graphics/entity/frost/, which
#     is the folder the load guard looks for to prove a twin wears its ice
#     (scripts/frost-audit.lua M.FROST_ASSET_DIR) -- so the path is load-bearing,
#     not filing.
FROST_DIR = "mods/cindra/graphics/entity/frost"
SPECS = [
    {
        "name": "arc-furnace",
        "sheet": "mods/cindra/graphics/entity/arc-furnace/arc-furnace-hr-animation-1.png",
        "frame": (0, 0, 320, 320),
        "out": "mods/cindra/graphics/entity/arc-furnace/arc-furnace-hr-frozen.png",
    },
    {
        "name": "capacitor",
        "sheet": "mods/cindra/graphics/entity/capacitor/capacitor.png",
        "frame": (0, 0, 256, 256),
        "out": FROST_DIR + "/capacitor-frost.png",
    },
    {
        "name": "molten-salt-battery",
        "sheet": "mods/cindra/graphics/entity/molten-salt-battery/molten-salt-battery.png",
        "frame": (0, 0, 256, 256),
        "out": FROST_DIR + "/molten-salt-battery-frost.png",
    },
    {
        "name": "dissipator",
        "sheet": "mods/cindra/graphics/entity/dissipator/dissipator.png",
        "frame": (0, 0, 256, 256),
        "out": FROST_DIR + "/dissipator-frost.png",
    },
    {
        "name": "rime-generic",
        "generic": True,
        "out": FROST_DIR + "/rime-generic.png",
    },
]


def patch_for(spec, root):
    """The RGBA frost patch a spec describes."""
    if spec.get("generic"):
        return generic_rime()
    sheet = Image.open(os.path.join(root, spec["sheet"])).convert("RGBA")
    x, y, w, h = spec["frame"]
    return frost_layer(np.asarray(sheet.crop((x, y, x + w, y + h)), np.uint8))


def build(spec, root):
    patch = patch_for(spec, root)
    dest = os.path.join(root, spec["out"])
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    Image.fromarray(patch, "RGBA").save(dest)
    return dest


def main(argv):
    root = argv[1] if len(argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for spec in SPECS:
        dest = build(spec, root)
        print("wrote " + os.path.relpath(dest, root))


if __name__ == "__main__":
    main(sys.argv)
