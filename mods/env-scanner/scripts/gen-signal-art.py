#!/usr/bin/env python3
# Bespoke virtual-signal icons for the environmental scanner (ci-kuu, a ci-3o3
# follow-up). Deterministic: seeded, same bytes every run.
#
# WHY procedural: the scanner emits seven virtual signals whose icons shipped as
# base-game placeholders (accumulator / solar-panel / substation / radar / lab /
# iron-plate / copper-plate). Those read as "some other machine," not "a reading
# off my scanner." This authors a bespoke, self-consistent set the same way the
# Cindra planet + entity art is authored: code, PIL primitives, no external
# download, so there is nothing to attribute and re-runs are byte-stable.
#
# Art direction (mirrors mods/cindra/graphics/ART-MANIFEST.md so the two mods
# read as one world): a shared dark rounded-steel signal plate with a coloured
# glyph. GENERIC surface readings (daytime / daylight / solar / tick-of-day) use
# the warm-sun + cyan-night palette; the CINDRA FLARE forecast block (countdown
# / phase / intensity) uses the ember/orange flare palette so a player can tell
# the two clusters apart at a glance in the signal picker.
#
# Output (run via scripts/render-signal-art.sh which supplies numpy+pillow):
#   mods/env-scanner/graphics/icons/signals/<signal>.png  (64x64 RGBA, wired
#   with icon_size = 64 in prototypes/scanner.lua)

import os
import sys
import math
from PIL import Image, ImageDraw, ImageFilter

# The seven signal file stems must match readings.SIGNALS (prototypes/scanner.lua
# wires by this stem). Kept as a plain list so a rename there fails the graphics
# unit test loudly rather than silently drawing the wrong glyph.
SIGNALS = [
    "env-daytime",
    "env-daylight",
    "env-solar",
    "env-tick-of-day",
    "env-flare-countdown",
    "env-flare-phase",
    "env-flare-intensity",
]

ICON = 64          # Factorio icon_size
SS = 8             # supersample: draw at 512, downscale to 64 for clean edges
BIG = ICON * SS

# ── Palette (shared with the Cindra visual family) ───────────────────
STEEL_DARK   = (30, 34, 42)
STEEL_MID    = (70, 78, 90)
STEEL_LIGHT  = (150, 162, 178)
STEEL_EDGE   = (206, 214, 224)

EMBER        = (214, 66, 20)
ORANGE       = (255, 122, 32)
HOT_YELLOW   = (255, 208, 78)
HOT_WHITE    = (255, 246, 210)

CRYO_DEEP    = (10, 44, 60)
CRYO         = (34, 132, 170)
ICE          = (96, 210, 232)
NIGHT        = (22, 30, 58)
STAR         = (196, 214, 255)

VIOLET       = (150, 92, 240)
VIOLET_LIT   = (198, 158, 255)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def new_layer():
    return Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))


def plate():
    """The shared dark rounded-steel signal plate every icon sits on: a bevelled
    tile that makes the coloured glyphs pop and ties the seven icons together."""
    img = new_layer()
    d = ImageDraw.Draw(img)
    m = int(BIG * 0.06)          # margin
    r = int(BIG * 0.20)          # corner radius
    box = [m, m, BIG - m, BIG - m]
    # Outer bevel highlight, then the dark face inset a hair so an edge shows.
    d.rounded_rectangle(box, radius=r, fill=rgba(STEEL_EDGE))
    inset = int(BIG * 0.018)
    d.rounded_rectangle(
        [box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset],
        radius=r, fill=rgba(STEEL_DARK),
    )
    # Soft top-left interior light so the plate looks lit, not flat.
    sheen = new_layer()
    sd = ImageDraw.Draw(sheen)
    sd.rounded_rectangle(
        [box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset],
        radius=r, fill=rgba(STEEL_MID, 90),
    )
    sheen = sheen.filter(ImageFilter.GaussianBlur(BIG * 0.05))
    # Clip the sheen to the plate face and bias it upward-left.
    face = Image.new("L", (BIG, BIG), 0)
    fd = ImageDraw.Draw(face)
    fd.rounded_rectangle(
        [box[0] + inset, box[1] + inset, box[2] - inset, int(BIG * 0.52)],
        radius=r, fill=110,
    )
    img.paste(sheen, (0, 0), face)
    return img


def glow(layer, radius_frac, alpha=170):
    """A soft additive-ish glow behind a bright glyph."""
    g = layer.filter(ImageFilter.GaussianBlur(BIG * radius_frac))
    a = g.split()[3].point(lambda v: min(255, int(v * alpha / 255)))
    g.putalpha(a)
    return g


def sun_disc(d, cx, cy, r, core, edge):
    """A filled sun disc with a subtle radial-ish warm edge."""
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(edge))
    ri = int(r * 0.72)
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=rgba(core))


def rays(d, cx, cy, r0, r1, color, n=8, width=None, phase=0.0):
    width = width or int(BIG * 0.028)
    for i in range(n):
        a = phase + (2 * math.pi * i / n)
        x0 = cx + r0 * math.cos(a)
        y0 = cy + r0 * math.sin(a)
        x1 = cx + r1 * math.cos(a)
        y1 = cy + r1 * math.sin(a)
        d.line([x0, y0, x1, y1], fill=rgba(color), width=width)


# ── Per-signal glyphs ────────────────────────────────────────────────
# Each returns an RGBA glyph layer (no plate); compose() stacks plate + glow +
# glyph. Coordinates are in the BIG (512) supersampled space.

def glyph_daytime():
    """Day/night dial: a disc split sun (warm) | night (cool) with a star."""
    g = new_layer()
    d = ImageDraw.Draw(g)
    cx = cy = BIG // 2
    r = int(BIG * 0.30)
    # Night half (right), day half (left).
    d.pieslice([cx - r, cy - r, cx + r, cy + r], -90, 90, fill=rgba(NIGHT))
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 90, 270, fill=rgba(ORANGE))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=rgba(STEEL_EDGE), width=int(BIG * 0.022))
    # Sun pip on the day side, star on the night side.
    d.ellipse([cx - int(r * 0.62), cy - int(r * 0.20), cx - int(r * 0.22), cy + int(r * 0.20)],
              fill=rgba(HOT_WHITE))
    sx, sy = cx + int(r * 0.42), cy - int(r * 0.02)
    rays(d, sx, sy, int(r * 0.10), int(r * 0.26), STAR, n=4, width=int(BIG * 0.020), phase=math.pi / 4)
    return g


def glyph_daylight():
    """Daylight fraction: a bright rayed sun."""
    g = new_layer()
    d = ImageDraw.Draw(g)
    cx = cy = BIG // 2
    r = int(BIG * 0.19)
    rays(d, cx, cy, int(r * 1.35), int(r * 2.0), HOT_YELLOW, n=8, width=int(BIG * 0.030))
    rays(d, cx, cy, int(r * 1.35), int(r * 1.75), ORANGE, n=8, width=int(BIG * 0.030),
         phase=math.pi / 8)
    sun_disc(d, cx, cy, r, HOT_WHITE, HOT_YELLOW)
    return g


def glyph_solar():
    """Solar output: a sun overlaid with an energy bolt (violet = power)."""
    g = new_layer()
    d = ImageDraw.Draw(g)
    cx = cy = BIG // 2
    r = int(BIG * 0.20)
    rays(d, cx, cy, int(r * 1.3), int(r * 1.85), HOT_YELLOW, n=8, width=int(BIG * 0.028))
    sun_disc(d, cx, cy, r, HOT_WHITE, ORANGE)
    # Lightning bolt over the disc.
    bx, by = cx, cy
    s = r
    bolt = [
        (bx + 0.10 * s, by - 0.85 * s),
        (bx - 0.35 * s, by + 0.12 * s),
        (bx - 0.02 * s, by + 0.12 * s),
        (bx - 0.12 * s, by + 0.85 * s),
        (bx + 0.38 * s, by - 0.18 * s),
        (bx + 0.04 * s, by - 0.18 * s),
    ]
    d.polygon(bolt, fill=rgba(VIOLET_LIT), outline=rgba(VIOLET), width=int(BIG * 0.012))
    return g


def glyph_tick():
    """Tick-of-day: a clock face with hands."""
    g = new_layer()
    d = ImageDraw.Draw(g)
    cx = cy = BIG // 2
    r = int(BIG * 0.29)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(STEEL_LIGHT),
              outline=rgba(STEEL_EDGE), width=int(BIG * 0.020))
    ri = int(r * 0.82)
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=rgba(CRYO_DEEP))
    # Tick marks at the quarters.
    for i in range(12):
        a = 2 * math.pi * i / 12
        r0 = int(r * (0.62 if i % 3 else 0.52))
        r1 = int(r * 0.74)
        w = int(BIG * (0.014 if i % 3 else 0.024))
        d.line([cx + r0 * math.cos(a), cy + r0 * math.sin(a),
                cx + r1 * math.cos(a), cy + r1 * math.sin(a)], fill=rgba(ICE), width=w)
    # Hands: hour up-right, minute up-left.
    d.line([cx, cy, cx + int(r * 0.34) * math.cos(-math.pi / 6),
            cy + int(r * 0.34) * math.sin(-math.pi / 6)], fill=rgba(HOT_WHITE), width=int(BIG * 0.026))
    d.line([cx, cy, cx + int(r * 0.55) * math.cos(-2 * math.pi / 3),
            cy + int(r * 0.55) * math.sin(-2 * math.pi / 3)], fill=rgba(ICE), width=int(BIG * 0.020))
    d.ellipse([cx - int(BIG * 0.02), cy - int(BIG * 0.02), cx + int(BIG * 0.02), cy + int(BIG * 0.02)],
              fill=rgba(HOT_WHITE))
    return g


def _flare_burst(d, cx, cy, r, core=HOT_WHITE, mid=ORANGE, outer=EMBER):
    """A shared ember flare burst: spiky corona + hot core (the flare motif)."""
    n = 12
    pts = []
    for i in range(2 * n):
        a = math.pi * i / n - math.pi / 2
        rr = r if i % 2 == 0 else int(r * 0.52)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=rgba(mid))
    d.polygon([(cx + (r * 0.62 if i % 2 == 0 else r * 0.32) * math.cos(math.pi * i / n - math.pi / 2),
                cy + (r * 0.62 if i % 2 == 0 else r * 0.32) * math.sin(math.pi * i / n - math.pi / 2))
               for i in range(2 * n)], fill=rgba(outer))
    d.ellipse([cx - int(r * 0.42), cy - int(r * 0.42), cx + int(r * 0.42), cy + int(r * 0.42)],
              fill=rgba(HOT_YELLOW))
    d.ellipse([cx - int(r * 0.22), cy - int(r * 0.22), cx + int(r * 0.22), cy + int(r * 0.22)],
              fill=rgba(core))


def glyph_flare_countdown():
    """Flare countdown: a flare inside a dashed countdown ring."""
    g = new_layer()
    d = ImageDraw.Draw(g)
    cx = cy = BIG // 2
    R = int(BIG * 0.34)
    # Dashed countdown ring (arc segments) around the flare.
    seg = 10
    for i in range(seg):
        if i % 2:
            continue
        a0 = 360 * i / seg - 90
        a1 = 360 * (i + 1) / seg - 90
        d.arc([cx - R, cy - R, cx + R, cy + R], a0, a1, fill=rgba(HOT_YELLOW), width=int(BIG * 0.030))
    _flare_burst(d, cx, cy, int(BIG * 0.22))
    return g


def glyph_flare_phase():
    """Flare phase: a five-segment ramp arc (calm -> decay), warming L->R."""
    g = new_layer()
    d = ImageDraw.Draw(g)
    cx = cy = BIG // 2
    R = int(BIG * 0.32)
    cols = [CRYO, ICE, HOT_YELLOW, ORANGE, EMBER]
    span = 300.0
    start = 120.0
    for i, c in enumerate(cols):
        a0 = start + span * i / len(cols)
        a1 = start + span * (i + 1) / len(cols) - 6
        d.arc([cx - R, cy - R, cx + R, cy + R], a0, a1, fill=rgba(c), width=int(BIG * 0.10))
    # A small marker pip at the plateau (hot) segment to read as "current phase."
    am = math.radians(start + span * 3.5 / len(cols))
    px, py = cx + R * math.cos(am), cy + R * math.sin(am)
    d.ellipse([px - int(BIG * 0.05), py - int(BIG * 0.05), px + int(BIG * 0.05), py + int(BIG * 0.05)],
              fill=rgba(HOT_WHITE), outline=rgba(STEEL_EDGE), width=int(BIG * 0.012))
    return g


def glyph_flare_intensity():
    """Flare intensity: a big flare with a rising gauge bar."""
    g = new_layer()
    d = ImageDraw.Draw(g)
    cx = int(BIG * 0.42)
    cy = int(BIG * 0.46)
    _flare_burst(d, cx, cy, int(BIG * 0.26))
    # Rising intensity bars up the right side.
    bx = int(BIG * 0.72)
    bw = int(BIG * 0.10)
    base = int(BIG * 0.72)
    heights = [0.14, 0.24, 0.36]
    cols = [HOT_YELLOW, ORANGE, EMBER]
    for i, (h, c) in enumerate(zip(heights, cols)):
        top = base - int(BIG * h)
        x0 = bx
        d.rounded_rectangle([x0, top, x0 + bw, base], radius=int(BIG * 0.02), fill=rgba(c))
        base_y = base
        d.line([x0, base_y, x0 + bw, base_y], fill=rgba(STEEL_EDGE), width=int(BIG * 0.008))
        base = base  # bars share a baseline; drawn tallest last visually
    return g


GLYPHS = {
    "env-daytime": glyph_daytime,
    "env-daylight": glyph_daylight,
    "env-solar": glyph_solar,
    "env-tick-of-day": glyph_tick,
    "env-flare-countdown": glyph_flare_countdown,
    "env-flare-phase": glyph_flare_phase,
    "env-flare-intensity": glyph_flare_intensity,
}


def compose(stem):
    base = plate()
    gl = GLYPHS[stem]()
    base.alpha_composite(glow(gl, 0.03, alpha=150))
    base.alpha_composite(gl)
    return base.resize((ICON, ICON), Image.LANCZOS)


def main():
    out_root = sys.argv[1] if len(sys.argv) > 1 else "mods/env-scanner/graphics"
    out_dir = os.path.join(out_root, "icons", "signals")
    os.makedirs(out_dir, exist_ok=True)
    for stem in SIGNALS:
        if stem not in GLYPHS:
            raise SystemExit("no glyph for signal: " + stem)
        img = compose(stem)
        path = os.path.join(out_dir, stem + ".png")
        img.save(path)
        print("wrote", path)
    print("done:", len(SIGNALS), "signal icons ->", out_dir)


if __name__ == "__main__":
    main()
