#!/usr/bin/env python3
# Procedural entity art for Cindra's signature buildings (icons + in-world
# base sprites). Deterministic: seeded, same output every run.
#
# WHY procedural (not FBSR): scripts/render-entity.sh (FBSR) only *previews*
# entities whose Factorio prototypes already exist; it cannot author new art.
# The buildings here have no prototypes yet (owning tracks build those in
# parallel), so first-pass art is authored the same way the planet art is:
# code, seeded noise, and PIL. Owning tracks wire the assets in later; this
# script only writes into graphics/ (see ART-MANIFEST.md).
#
# Art direction (planet_design.md §8/§10/§11/§12, DESIGN.md): fire/ice tension,
# industrial, one visual family, readable at icon size. Every building shares a
# brushed-steel chassis; a coloured functional core signals its role. Hot roles
# lean ember/orange, cold roles lean cyan/ice, energy roles lean violet.
#
# Output (run via scripts/render-entity-art.sh which supplies numpy+pillow):
#   mods/cindra/graphics/icons/<name>.png     120x64 mip strip (icon_size=64,
#                                              icon_mipmaps=4)
#   mods/cindra/graphics/entity/<name>/<name>.png + <name>-shadow.png (HR,
#                                              256px, static single frame)

import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

# ── Determinism ──────────────────────────────────────────────────────
SEED = 0xC1_9D_2A          # "Cindra" — fixed so re-runs are byte-stable
RNG = np.random.default_rng(SEED)

# ── Palette (the Cindra visual family) ───────────────────────────────
# Brushed-steel chassis shared by every building.
STEEL_DARK   = (34, 38, 46)
STEEL_MID    = (74, 82, 94)
STEEL_LIGHT  = (150, 162, 178)
STEEL_EDGE   = (206, 214, 224)
STEEL_SHADOW = (18, 20, 26)

# Hot side (lava / heat / flare).
EMBER_DEEP   = (96, 22, 10)
EMBER        = (214, 66, 20)
ORANGE       = (255, 122, 32)
HOT_YELLOW   = (255, 208, 78)
HOT_WHITE    = (255, 246, 210)

# Cold side (ice / cryo-coolant / nightside).
CRYO_DEEP    = (10, 44, 60)
CRYO         = (34, 132, 170)
ICE          = (96, 210, 232)
ICE_PALE     = (208, 246, 255)
FROST_WHITE  = (236, 255, 255)

# Energy (capacitor / battery / mass driver arc / science).
VIOLET_DEEP  = (48, 20, 78)
VIOLET       = (150, 92, 240)
VIOLET_LIT   = (198, 158, 255)
SPARK_WHITE  = (245, 238, 255)

SS = 8                      # icon supersample factor: draw @512, downscale @64
ICON = 64                   # base icon size (Factorio icon_size)
MIPS = [64, 32, 16, 8]      # icon_mipmaps = 4


# ── Low-level helpers ────────────────────────────────────────────────
def blank(size, rgba=(0, 0, 0, 0)):
    return Image.new("RGBA", (size, size), rgba)


def Lm(size):
    """A mode-'L' mask canvas. Shapes drawn with fill=255 become opaque.

    (Drawing fill=255 on an RGBA image yields alpha 0 — a silent no-op — so all
    masks MUST be 'L'.)
    """
    return Image.new("L", (size, size), 0)


def mask_and(a, b):
    """Intersection of two 'L' masks."""
    return ImageChops.multiply(a, b)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def linear_gradient(size, c0, c1, angle_deg=90.0):
    """RGB gradient array (size,size,3) along `angle_deg` (0=->right, 90=down)."""
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    xs = np.linspace(-0.5, 0.5, size)
    ys = np.linspace(-0.5, 0.5, size)
    gx, gy = np.meshgrid(xs, ys)
    t = (gx * dx + gy * dy) + 0.5
    t = np.clip(t, 0.0, 1.0)[..., None]
    c0 = np.array(c0, float)
    c1 = np.array(c1, float)
    return (c0 * (1 - t) + c1 * t).astype(np.uint8)


def radial_glow(size, center, radius, color, inner_alpha=255):
    """A soft radial glow sprite (RGBA)."""
    ys, xs = np.mgrid[0:size, 0:size]
    d = np.sqrt((xs - center[0]) ** 2 + (ys - center[1]) ** 2) / max(radius, 1e-6)
    a = np.clip(1.0 - d, 0.0, 1.0) ** 1.8
    out = np.zeros((size, size, 4), np.uint8)
    out[..., 0] = color[0]
    out[..., 1] = color[1]
    out[..., 2] = color[2]
    out[..., 3] = (a * inner_alpha).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def paste_gradient(img, mask, c0, c1, angle):
    """Fill `mask` region of img with a linear gradient."""
    grad = Image.fromarray(linear_gradient(img.size[0], c0, c1, angle), "RGB").convert("RGBA")
    img.paste(grad, (0, 0), mask)


def brushed_metal_overlay(size, strength=10):
    """Faint vertical brushed-steel streaks (deterministic)."""
    noise = RNG.normal(0, strength, (size, 1))
    band = np.repeat(noise, size, axis=1).T  # vertical streaks
    band = np.clip(band, -strength, strength)
    out = np.zeros((size, size, 4), np.uint8)
    v = (128 + band).astype(np.uint8)
    out[..., 0] = out[..., 1] = out[..., 2] = v
    out[..., 3] = 26
    return Image.fromarray(out, "RGBA")


def chassis(size, radius_frac=0.16, tilt=0.0):
    """The shared industrial base plate: a beveled brushed-steel rounded panel.

    Returns (img, mask) where mask is the plate silhouette (for scoping glows).
    """
    img = blank(size)
    d = ImageDraw.Draw(img)
    pad = int(size * 0.10)
    r = int(size * radius_frac)
    box = [pad, pad, size - pad, size - pad]

    mask = blank(size)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle(box, radius=r, fill=(255, 255, 255, 255))

    # Body gradient (top lighter -> bottom darker) scoped to the plate.
    paste_gradient(img, mask, STEEL_MID, STEEL_DARK, 90 + tilt)
    img.alpha_composite(Image.composite(brushed_metal_overlay(size),
                                        blank(size), mask))

    # Bevel: bright top-left inset, dark bottom-right inset.
    inset = box[0] + int(size * 0.012)
    d.rounded_rectangle(box, radius=r, outline=STEEL_SHADOW,
                        width=max(2, size // 110))
    d.arc([inset, inset, box[2], box[3]], 90, 200,
          fill=STEEL_EDGE, width=max(2, size // 160))
    d.arc([box[0], box[1], box[2] - int(size*0.012), box[3] - int(size*0.012)],
          270, 20, fill=STEEL_SHADOW, width=max(2, size // 150))

    # Corner rivets.
    rr = max(2, size // 64)
    for cx, cy in [(pad + r, pad + r), (size - pad - r, pad + r),
                   (pad + r, size - pad - r), (size - pad - r, size - pad - r)]:
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=STEEL_LIGHT)
        d.ellipse([cx - rr, cy - rr, cx + rr*0.4, cy + rr*0.4], fill=STEEL_EDGE)
    return img, mask


def add_glow(img, mask, center, radius, color, alpha=200):
    g = radial_glow(img.size[0], center, radius, color, alpha)
    if mask is not None:
        g = Image.composite(g, blank(img.size[0]), mask)
    img.alpha_composite(g)


# ── Icon compositing pipeline ────────────────────────────────────────
def finalize_icon(hi):
    """Downscale a 512px hi-res icon to a 120x64 mip strip (RGBA)."""
    base = hi.resize((ICON, ICON), Image.LANCZOS)
    strip = Image.new("RGBA", (sum(MIPS), ICON), (0, 0, 0, 0))
    x = 0
    for m in MIPS:
        strip.paste(base.resize((m, m), Image.LANCZOS), (x, 0))
        x += m
    return strip


# ── Per-building icon painters (draw at 512, transparent bg) ─────────
def paint_frame():
    return chassis(ICON * SS)


def icon_cryo_quench():
    """Signature building: split fire|ice core = the two-temperature quench."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    cx = S // 2
    # Central crucible split down the middle: molten left, cryo right.
    box = [int(S*0.28), int(S*0.26), int(S*0.72), int(S*0.74)]
    crucible = Lm(S)
    ImageDraw.Draw(crucible).rounded_rectangle(box, radius=int(S*0.06), fill=255)
    half = Lm(S); ImageDraw.Draw(half).rectangle([box[0], box[1], cx, box[3]], fill=255)
    rmh = Lm(S); ImageDraw.Draw(rmh).rectangle([cx, box[1], box[2], box[3]], fill=255)
    left = mask_and(crucible, half)     # molten half
    right = mask_and(crucible, rmh)     # cryo half
    paste_gradient(img, left, HOT_YELLOW, EMBER, 90)
    paste_gradient(img, right, ICE_PALE, CRYO, 90)
    add_glow(img, left, (int(S*0.38), int(S*0.5)), int(S*0.22), ORANGE, 200)
    add_glow(img, right, (int(S*0.62), int(S*0.5)), int(S*0.22), ICE, 200)
    # Seam where fire meets ice: bright quench flash.
    d.line([cx, box[1], cx, box[3]], fill=FROST_WHITE, width=max(3, S//120))
    add_glow(img, mask, (cx, int(S*0.5)), int(S*0.10), HOT_WHITE, 180)
    # Crucible rim.
    d.rounded_rectangle(box, radius=int(S*0.06), outline=STEEL_EDGE, width=max(3, S//90))
    return img


def icon_lava_manufacturer():
    """1 stone + power -> 5 lava. A crucible pouring molten lava."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Crucible bowl.
    bowl = [int(S*0.24), int(S*0.30), int(S*0.62), int(S*0.66)]
    bmask = Lm(S); ImageDraw.Draw(bmask).pieslice(bowl, 0, 180, fill=255)
    paste_gradient(img, bmask, STEEL_LIGHT, STEEL_DARK, 90)
    d.pieslice(bowl, 0, 180, outline=STEEL_EDGE, width=max(3, S//100))
    # Molten pour spout to the lower right.
    pour = [(int(S*0.58), int(S*0.44)), (int(S*0.64), int(S*0.44)),
            (int(S*0.80), int(S*0.74)), (int(S*0.70), int(S*0.74))]
    d.polygon(pour, fill=ORANGE)
    add_glow(img, mask, (int(S*0.74), int(S*0.72)), int(S*0.18), HOT_YELLOW, 220)
    # Lava surface in bowl.
    surf = [bowl[0]+int(S*0.02), int(S*0.44), bowl[2]-int(S*0.02), int(S*0.50)]
    d.ellipse(surf, fill=HOT_YELLOW)
    add_glow(img, mask, (int(S*0.42), int(S*0.47)), int(S*0.16), HOT_WHITE, 200)
    # Rising heat glow.
    add_glow(img, mask, (int(S*0.42), int(S*0.34)), int(S*0.20), EMBER, 90)
    return img


def icon_ice_crusher():
    """Nightside ice -> water/calcite. Toothed crusher biting an ice block."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Ice block.
    blk = [int(S*0.30), int(S*0.40), int(S*0.70), int(S*0.72)]
    bmask = Lm(S); ImageDraw.Draw(bmask).rectangle(blk, fill=255)
    paste_gradient(img, bmask, ICE_PALE, CRYO, 90)
    add_glow(img, bmask, (int(S*0.5), int(S*0.56)), int(S*0.20), FROST_WHITE, 120)
    d.rectangle(blk, outline=ICE, width=max(2, S//140))
    # Facet lines on the ice.
    for fx in (0.42, 0.56):
        d.line([int(S*fx), blk[1], int(S*(fx+0.05)), blk[3]], fill=FROST_WHITE, width=max(2, S//200))
    # Upper + lower crusher teeth (steel jaws).
    tw = int(S*0.05)
    for i in range(5):
        x0 = int(S*0.30) + i * tw * 1.6
        d.polygon([(x0, int(S*0.40)), (x0+tw, int(S*0.40)), (x0+tw//2, int(S*0.50))], fill=STEEL_LIGHT)
        d.polygon([(x0, int(S*0.72)), (x0+tw, int(S*0.72)), (x0+tw//2, int(S*0.62))], fill=STEEL_MID)
    d.line([int(S*0.30), int(S*0.40), int(S*0.72), int(S*0.40)], fill=STEEL_EDGE, width=max(2, S//120))
    return img


def icon_electric_heater():
    """Electricity -> heat. Glowing element coil in a vented steel block."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Vent slots frame.
    for i in range(4):
        y = int(S*0.30) + i * int(S*0.10)
        d.rounded_rectangle([int(S*0.26), y, int(S*0.74), y+int(S*0.045)],
                            radius=int(S*0.02), fill=STEEL_SHADOW)
    # Glowing heating element (serpentine).
    pts = []
    for i in range(0, 200):
        t = i / 199.0
        x = int(S*0.30 + t * S*0.40)
        y = int(S*0.50 + math.sin(t * math.pi * 4) * S*0.11)
        pts.append((x, y))
    d.line(pts, fill=ORANGE, width=max(4, S//70), joint="curve")
    d.line(pts, fill=HOT_YELLOW, width=max(2, S//150), joint="curve")
    add_glow(img, mask, (S//2, int(S*0.50)), int(S*0.30), EMBER, 140)
    # Lightning bolt inlet (electric).
    bolt = [(int(S*0.46), int(S*0.16)), (int(S*0.54), int(S*0.16)),
            (int(S*0.50), int(S*0.26)), (int(S*0.56), int(S*0.26)),
            (int(S*0.46), int(S*0.40)), (int(S*0.50), int(S*0.28)),
            (int(S*0.44), int(S*0.28))]
    d.polygon(bolt, fill=VIOLET_LIT)
    add_glow(img, mask, (int(S*0.50), int(S*0.26)), int(S*0.12), VIOLET, 150)
    return img


def icon_mass_driver():
    """Launch to orbit on electricity. Angled rail + payload + arc, aimed up."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Angled launch rail (lower-left to upper-right).
    rail_w = int(S*0.11)
    a = (int(S*0.22), int(S*0.80))
    b = (int(S*0.78), int(S*0.24))
    nx, ny = -(b[1]-a[1]), (b[0]-a[0])
    L = math.hypot(nx, ny); nx, ny = nx/L*rail_w, ny/L*rail_w
    rail = [(a[0]-nx, a[1]-ny), (a[0]+nx, a[1]+ny), (b[0]+nx, b[1]+ny), (b[0]-nx, b[1]-ny)]
    rmask = Lm(S); ImageDraw.Draw(rmask).polygon(rail, fill=255)
    paste_gradient(img, rmask, STEEL_LIGHT, STEEL_DARK, 45)
    d.polygon(rail, outline=STEEL_EDGE, width=max(2, S//140))
    # Twin coil rings along the rail (accelerator).
    for t in (0.30, 0.50, 0.70):
        cx = int(a[0] + (b[0]-a[0])*t); cy = int(a[1] + (b[1]-a[1])*t)
        d.ellipse([cx-rail_w, cy-rail_w, cx+rail_w, cy+rail_w], outline=VIOLET, width=max(3, S//110))
    # Payload slug near the muzzle + launch arc.
    d.ellipse([b[0]-int(S*0.05), b[1]-int(S*0.05), b[0]+int(S*0.05), b[1]+int(S*0.05)], fill=HOT_YELLOW)
    add_glow(img, mask, b, int(S*0.16), VIOLET_LIT, 200)
    add_glow(img, mask, b, int(S*0.10), SPARK_WHITE, 220)
    # Electric arc streak off the muzzle.
    arc = [b, (int(S*0.86), int(S*0.14)), (int(S*0.80), int(S*0.10))]
    d.line(arc, fill=SPARK_WHITE, width=max(2, S//160))
    return img


def icon_mass_driver_catcher():
    """Platform-side catcher: an open orbital net/funnel catching a payload."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Funnel (wide top, narrow bottom).
    fun = [(int(S*0.24), int(S*0.30)), (int(S*0.76), int(S*0.30)),
           (int(S*0.58), int(S*0.70)), (int(S*0.42), int(S*0.70))]
    fmask = Lm(S); ImageDraw.Draw(fmask).polygon(fun, fill=255)
    paste_gradient(img, fmask, STEEL_MID, STEEL_DARK, 90)
    d.polygon(fun, outline=STEEL_EDGE, width=max(3, S//110))
    # Net cross-hatch inside the funnel mouth.
    for i in range(1, 5):
        x = int(S*0.24 + i * S*0.104)
        d.line([(x, int(S*0.30)), (int(S*0.42 + i*S*0.04), int(S*0.70))], fill=STEEL_LIGHT, width=max(1, S//260))
    d.line([(int(S*0.24), int(S*0.42)), (int(S*0.76), int(S*0.42))], fill=STEEL_LIGHT, width=max(1, S//260))
    # Incoming payload with descent glow.
    d.ellipse([int(S*0.46), int(S*0.12), int(S*0.54), int(S*0.20)], fill=HOT_YELLOW)
    add_glow(img, mask, (int(S*0.50), int(S*0.18)), int(S*0.12), ORANGE, 170)
    return img


def icon_capacitor():
    """Fast storage: flare first-responder. Charged plates + spark."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Two facing charge plates.
    for x0, col in [(int(S*0.30), VIOLET), (int(S*0.62), VIOLET)]:
        pmask = Lm(S); ImageDraw.Draw(pmask).rounded_rectangle(
            [x0, int(S*0.28), x0+int(S*0.08), int(S*0.72)], radius=int(S*0.02), fill=255)
        paste_gradient(img, pmask, VIOLET_LIT, VIOLET, 90)
        add_glow(img, pmask, (x0+int(S*0.04), int(S*0.50)), int(S*0.10), VIOLET_LIT, 150)
    # Arc jumping the gap.
    d.line([(int(S*0.38), int(S*0.42)), (int(S*0.48), int(S*0.50)),
            (int(S*0.44), int(S*0.52)), (int(S*0.62), int(S*0.60))],
           fill=SPARK_WHITE, width=max(3, S//110))
    add_glow(img, mask, (S//2, int(S*0.50)), int(S*0.20), VIOLET_LIT, 200)
    # + / - terminals.
    d.line([(int(S*0.34), int(S*0.20)), (int(S*0.34), int(S*0.26))], fill=SPARK_WHITE, width=max(3, S//120))
    d.line([(int(S*0.31), int(S*0.23)), (int(S*0.37), int(S*0.23))], fill=SPARK_WHITE, width=max(3, S//120))
    d.line([(int(S*0.63), int(S*0.23)), (int(S*0.69), int(S*0.23))], fill=SPARK_WHITE, width=max(3, S//120))
    return img


def icon_molten_salt_battery():
    """Bulk storage, must stay hot. A warm-glowing salt tank."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Cylindrical tank.
    tank = [int(S*0.30), int(S*0.26), int(S*0.70), int(S*0.74)]
    tmask = Lm(S); ImageDraw.Draw(tmask).rounded_rectangle(tank, radius=int(S*0.10), fill=255)
    paste_gradient(img, tmask, STEEL_LIGHT, STEEL_DARK, 0)
    # Molten-salt level: warm gradient inside.
    fill = [tank[0]+int(S*0.03), int(S*0.40), tank[2]-int(S*0.03), tank[3]-int(S*0.04)]
    fmask = Lm(S); ImageDraw.Draw(fmask).rounded_rectangle(fill, radius=int(S*0.05), fill=255)
    paste_gradient(img, fmask, HOT_YELLOW, EMBER, 90)
    add_glow(img, fmask, (S//2, int(S*0.58)), int(S*0.22), ORANGE, 150)
    d.rounded_rectangle(tank, radius=int(S*0.10), outline=STEEL_EDGE, width=max(3, S//100))
    # Heat-upkeep coils around the base.
    for i in range(3):
        y = int(S*0.60) + i*int(S*0.045)
        d.line([tank[0], y, tank[2], y], fill=EMBER, width=max(2, S//170))
    # Warmth rising.
    add_glow(img, mask, (S//2, int(S*0.30)), int(S*0.18), EMBER, 80)
    return img


def icon_dissipator():
    """Safe waste heat-sink. Radiator fins bleeding surplus to warm air."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Finned radiator stack.
    for i in range(6):
        y = int(S*0.28) + i * int(S*0.075)
        t = i / 5.0
        col = lerp(STEEL_LIGHT, EMBER, t*0.6)
        d.rounded_rectangle([int(S*0.26), y, int(S*0.74), y+int(S*0.045)],
                            radius=int(S*0.015), fill=col)
    # Central heat core.
    add_glow(img, mask, (S//2, int(S*0.52)), int(S*0.26), EMBER, 120)
    d.ellipse([int(S*0.44), int(S*0.46), int(S*0.56), int(S*0.58)], fill=ORANGE)
    add_glow(img, mask, (S//2, int(S*0.52)), int(S*0.09), HOT_WHITE, 200)
    # Rising waste-heat wisps.
    for wx in (0.36, 0.50, 0.64):
        pts = [(int(S*wx), int(S*0.26)), (int(S*(wx+0.02)), int(S*0.18)),
               (int(S*(wx-0.01)), int(S*0.12))]
        d.line(pts, fill=(*ORANGE, ), width=max(2, S//180), joint="curve")
    return img


def icon_solar_panel():
    """Cindra flare-hardened solar tier. Cell grid under a hot-white star."""
    S = ICON * SS
    img, mask = paint_frame()
    d = ImageDraw.Draw(img)
    # Panel array (angled cell grid).
    panel = [int(S*0.24), int(S*0.34), int(S*0.76), int(S*0.74)]
    pmask = Lm(S); ImageDraw.Draw(pmask).rectangle(panel, fill=255)
    paste_gradient(img, pmask, CRYO_DEEP, (20, 30, 52), 90)
    # Cells.
    cols, rows = 4, 3
    cw = (panel[2]-panel[0])/cols; ch = (panel[3]-panel[1])/rows
    for r in range(rows):
        for c in range(cols):
            x0 = panel[0]+c*cw+int(S*0.006); y0 = panel[1]+r*ch+int(S*0.006)
            cell = [x0, y0, x0+cw-int(S*0.012), y0+ch-int(S*0.012)]
            cmask = Lm(S); ImageDraw.Draw(cmask).rectangle(cell, fill=255)
            paste_gradient(img, cmask, CRYO, VIOLET_DEEP, 45)
            d.line([cell[0], cell[1], cell[0]+cw*0.3, cell[1]], fill=ICE, width=max(1, S//300))
    d.rectangle(panel, outline=STEEL_EDGE, width=max(3, S//110))
    # Flare star + hard-light glint (the flare it is hardened against).
    add_glow(img, mask, (int(S*0.66), int(S*0.28)), int(S*0.22), HOT_WHITE, 220)
    for ang in range(0, 360, 45):
        a = math.radians(ang)
        d.line([(int(S*0.66), int(S*0.28)),
                (int(S*0.66+math.cos(a)*S*0.12), int(S*0.28+math.sin(a)*S*0.12))],
               fill=HOT_YELLOW, width=max(2, S//180))
    return img


# ── Item icons ───────────────────────────────────────────────────────
def icon_item_ice():
    """Nightside ice chunk (raw resource item)."""
    S = ICON * SS
    img = blank(S)
    d = ImageDraw.Draw(img)
    poly = [(int(S*0.30), int(S*0.40)), (int(S*0.46), int(S*0.20)),
            (int(S*0.68), int(S*0.28)), (int(S*0.78), int(S*0.54)),
            (int(S*0.60), int(S*0.78)), (int(S*0.32), int(S*0.68))]
    pmask = Lm(S); ImageDraw.Draw(pmask).polygon(poly, fill=255)
    paste_gradient(img, pmask, ICE_PALE, CRYO, 120)
    add_glow(img, pmask, (int(S*0.5), int(S*0.48)), int(S*0.26), FROST_WHITE, 150)
    d.polygon(poly, outline=FROST_WHITE, width=max(3, S//100))
    # Internal facets.
    cx, cy = int(S*0.52), int(S*0.5)
    for vx, vy in [poly[0], poly[2], poly[4]]:
        d.line([(cx, cy), (vx, vy)], fill=(*FROST_WHITE, ), width=max(2, S//170))
    d.line([poly[1], poly[4]], fill=ICE, width=max(1, S//240))
    return img


def icon_item_stone():
    """Cindra stone chunk (ribbon mining, feeds the lava recipe)."""
    S = ICON * SS
    img = blank(S)
    d = ImageDraw.Draw(img)
    poly = [(int(S*0.28), int(S*0.46), ), (int(S*0.40), int(S*0.26)),
            (int(S*0.64), int(S*0.24)), (int(S*0.78), int(S*0.48)),
            (int(S*0.66), int(S*0.76)), (int(S*0.36), int(S*0.74))]
    poly = [(poly[0][0], poly[0][1])] + poly[1:]
    pmask = Lm(S); ImageDraw.Draw(pmask).polygon(poly, fill=255)
    paste_gradient(img, pmask, (150, 132, 116), (78, 62, 52), 120)
    d.polygon(poly, outline=(196, 180, 162), width=max(3, S//110))
    # Warm ember flecks (basalt on a hot world).
    for _ in range(6):
        px = int(RNG.uniform(S*0.36, S*0.68)); py = int(RNG.uniform(S*0.34, S*0.68))
        rr = int(RNG.uniform(S*0.01, S*0.025))
        d.ellipse([px-rr, py-rr, px+rr, py+rr], fill=EMBER)
    add_glow(img, pmask, (int(S*0.5), int(S*0.52)), int(S*0.20), (120, 80, 40), 60)
    return img


def icon_item_volatiles():
    """Frozen volatiles (a science input): a sealed vial of violet-cyan frozen
    gas. Deliberately NOT an ice crystal -- the old placeholder reused the ice
    icon, so a mined ice field looked like it dropped plain ice cubes. A vial of
    captured gas reads as its own thing (ci-9bb)."""
    S = ICON * SS
    img = blank(S)
    d = ImageDraw.Draw(img)
    # A LOCAL rng (not the shared global RNG): consuming the global stream here
    # would shift every icon/sprite generated after this one, spuriously changing
    # already-committed art. A private seed keeps this icon deterministic while
    # leaving the rest of the pipeline byte-stable.
    rng = np.random.default_rng(0xC0_1A_71)
    body_box = [int(S*0.28), int(S*0.30), int(S*0.72), int(S*0.82)]  # bulbous base
    neck = [int(S*0.42), int(S*0.16), int(S*0.58), int(S*0.36)]      # narrow neck
    bmask = Lm(S); bd = ImageDraw.Draw(bmask)
    bd.ellipse(body_box, fill=255)
    bd.rectangle(neck, fill=255)
    # Frozen gas: violet at the cold base, cyan toward the top.
    paste_gradient(img, bmask, VIOLET_LIT, CRYO, 90)
    add_glow(img, bmask, (int(S*0.5), int(S*0.58)), int(S*0.24), VIOLET, 120)
    # Suspended gas bubbles (frost highlights) -- reads as captured gas, not ice.
    for _ in range(5):
        px = int(rng.uniform(S*0.36, S*0.64)); py = int(rng.uniform(S*0.44, S*0.76))
        rr = int(rng.uniform(S*0.015, S*0.04))
        d.ellipse([px-rr, py-rr, px+rr, py+rr], outline=FROST_WHITE, width=max(2, S//200))
    # Glass rim + metal stopper.
    d.ellipse(body_box, outline=ICE_PALE, width=max(3, S//120))
    d.rectangle(neck, outline=ICE_PALE, width=max(2, S//150))
    d.rectangle([int(S*0.40), int(S*0.10), int(S*0.60), int(S*0.18)], fill=STEEL_LIGHT)
    return img


def icon_item_alloy():
    """Cryo-hardened alloy (signature product): a metal ingot, fire+ice sheen."""
    S = ICON * SS
    img = blank(S)
    d = ImageDraw.Draw(img)
    # Trapezoid ingot.
    ing = [(int(S*0.26), int(S*0.62)), (int(S*0.36), int(S*0.42)),
           (int(S*0.64), int(S*0.42)), (int(S*0.74), int(S*0.62)),
           (int(S*0.64), int(S*0.72)), (int(S*0.36), int(S*0.72))]
    imask = Lm(S); ImageDraw.Draw(imask).polygon(ing, fill=255)
    paste_gradient(img, imask, STEEL_EDGE, STEEL_MID, 90)
    # Fire sheen on one facet, ice sheen on the other.
    top = [(int(S*0.36), int(S*0.42)), (int(S*0.64), int(S*0.42)),
           (int(S*0.58), int(S*0.52)), (int(S*0.42), int(S*0.52))]
    tmask = Lm(S); ImageDraw.Draw(tmask).polygon(top, fill=255)
    paste_gradient(img, tmask, HOT_YELLOW, ICE_PALE, 0)
    d.polygon(ing, outline=FROST_WHITE, width=max(3, S//110))
    add_glow(img, imask, (int(S*0.40), int(S*0.60)), int(S*0.14), ORANGE, 90)
    add_glow(img, imask, (int(S*0.62), int(S*0.60)), int(S*0.14), ICE, 90)
    # Frost-crack + ember line meeting in the middle.
    d.line([(int(S*0.50), int(S*0.44)), (int(S*0.50), int(S*0.70))], fill=FROST_WHITE, width=max(2, S//150))
    return img


def icon_science_pack():
    """Cindra science pack: a flask holding split fire/ice fluid (petro-free)."""
    S = ICON * SS
    img = blank(S)
    d = ImageDraw.Draw(img)
    # Rounded flask body (a mask, so it must be mode 'L').
    body = [int(S*0.34), int(S*0.34), int(S*0.66), int(S*0.80)]
    bmask = Lm(S)
    ImageDraw.Draw(bmask).rounded_rectangle(body, radius=int(S*0.14), fill=255)
    ImageDraw.Draw(bmask).rectangle([int(S*0.42), int(S*0.18), int(S*0.58), int(S*0.40)], fill=255)
    # Pale glass tint fills the whole flask so it never reads as empty.
    paste_gradient(img, bmask, (44, 58, 70), (24, 34, 44), 90)
    # Fluid: ice on top, fire below, quench flash between — clipped to the body.
    fluid = [int(S*0.36), int(S*0.50), int(S*0.64), int(S*0.78)]
    fl = Lm(S); ImageDraw.Draw(fl).rounded_rectangle(fluid, radius=int(S*0.10), fill=255)
    fl = mask_and(fl, bmask)
    paste_gradient(img, fl, ICE, EMBER, 90)
    add_glow(img, fl, (S//2, int(S*0.62)), int(S*0.18), HOT_WHITE, 200)
    # Glass.
    glass = blank(S); dd = ImageDraw.Draw(glass)
    dd.rounded_rectangle(body, radius=int(S*0.14), outline=(220, 236, 246, 255), width=max(4, S//90))
    dd.rectangle([int(S*0.42), int(S*0.18), int(S*0.58), int(S*0.40)], outline=(220, 236, 246, 255), width=max(4, S//90))
    # Stopper.
    dd.rounded_rectangle([int(S*0.40), int(S*0.12), int(S*0.60), int(S*0.22)], radius=int(S*0.03), fill=STEEL_LIGHT)
    img.alpha_composite(glass)
    # Highlight streak.
    d.line([(int(S*0.42), int(S*0.40)), (int(S*0.42), int(S*0.72))], fill=(255, 255, 255, 120), width=max(2, S//180))
    return img


# ── In-world entity base sprites (static HR single frame + shadow) ───
def entity_sprite(size, roof_painter, footprint=0.78):
    """A 3/4 industrial block: top face + two side faces, with a roof motif.

    roof_painter(draw, quad) draws the building's signature on the top face,
    where `quad` is the 4 corners of the top parallelogram.
    """
    img = blank(size)
    d = ImageDraw.Draw(img)
    cx, cy = size/2, size*0.52
    w = size * footprint / 2
    h = w * 0.58            # iso squash
    height = w * 0.5        # block wall height
    # Top parallelogram corners (N,E,S,W).
    top = [(cx, cy - h), (cx + w, cy), (cx, cy + h), (cx - w, cy)]
    # Walls.
    left_wall = [top[3], top[2], (top[2][0], top[2][1] + height), (top[3][0], top[3][1] + height)]
    right_wall = [top[2], top[1], (top[1][0], top[1][1] + height), (top[2][0], top[2][1] + height)]
    lmask = Lm(size); ImageDraw.Draw(lmask).polygon(left_wall, fill=255)
    rmask = Lm(size); ImageDraw.Draw(rmask).polygon(right_wall, fill=255)
    paste_gradient(img, lmask, STEEL_MID, STEEL_SHADOW, 0)
    paste_gradient(img, rmask, STEEL_DARK, STEEL_SHADOW, 0)
    d.polygon(left_wall, outline=STEEL_SHADOW, width=max(2, size//200))
    d.polygon(right_wall, outline=STEEL_SHADOW, width=max(2, size//200))
    # Top face.
    tmask = Lm(size); ImageDraw.Draw(tmask).polygon(top, fill=255)
    paste_gradient(img, tmask, STEEL_LIGHT, STEEL_MID, 90)
    img.alpha_composite(Image.composite(brushed_metal_overlay(size), blank(size), tmask))
    d.polygon(top, outline=STEEL_EDGE, width=max(2, size//180))
    # Signature roof motif (scoped to the top face).
    roof_layer = blank(size)
    roof_painter(ImageDraw.Draw(roof_layer), top, size)
    img.alpha_composite(Image.composite(roof_layer, blank(size), tmask))
    return img


def _iso_center(top):
    return (sum(p[0] for p in top) / 4.0, sum(p[1] for p in top) / 4.0)


def roof_cryo_quench(d, top, S):
    cx, cy = _iso_center(top)
    d.line([(cx, top[0][1]+ (top[2][1]-top[0][1])*0.15), (cx, top[2][1]-(top[2][1]-top[0][1])*0.15)],
           fill=FROST_WHITE, width=max(3, S//120))
    d.ellipse([cx-S*0.14, cy-S*0.08, cx-S*0.01, cy+S*0.08], fill=ORANGE)
    d.ellipse([cx+S*0.01, cy-S*0.08, cx+S*0.14, cy+S*0.08], fill=ICE)


def roof_mass_driver(d, top, S):
    d.line([top[3], top[1]], fill=VIOLET, width=max(5, S//60))
    d.line([top[3], top[1]], fill=VIOLET_LIT, width=max(2, S//150))
    cx, cy = _iso_center(top)
    d.ellipse([top[1][0]-S*0.05, top[1][1]-S*0.05, top[1][0]+S*0.05, top[1][1]+S*0.05], fill=HOT_YELLOW)


def roof_dissipator(d, top, S):
    cx, cy = _iso_center(top)
    for i in range(-2, 3):
        off = i * S*0.05
        d.line([(top[3][0]+ (top[1][0]-top[3][0])*0.15, cy+off),
                (top[1][0]-(top[1][0]-top[3][0])*0.15, cy+off)],
               fill=lerp(STEEL_EDGE, EMBER, 0.5), width=max(3, S//120))
    d.ellipse([cx-S*0.05, cy-S*0.05, cx+S*0.05, cy+S*0.05], fill=ORANGE)


def roof_solar(d, top, S):
    cx, cy = _iso_center(top)
    for i in range(-1, 2):
        for j in range(-1, 2):
            px = cx + i*S*0.12; py = cy + j*S*0.07
            d.polygon([(px, py-S*0.04), (px+S*0.05, py), (px, py+S*0.04), (px-S*0.05, py)], fill=CRYO)


def roof_capacitor(d, top, S):
    cx, cy = _iso_center(top)
    d.line([(cx-S*0.10, cy-S*0.05), (cx+S*0.02, cy), (cx-S*0.02, cy+S*0.01), (cx+S*0.10, cy+S*0.05)],
           fill=SPARK_WHITE, width=max(3, S//110))


def roof_battery(d, top, S):
    cx, cy = _iso_center(top)
    d.ellipse([cx-S*0.12, cy-S*0.07, cx+S*0.12, cy+S*0.07], fill=EMBER)
    d.ellipse([cx-S*0.07, cy-S*0.04, cx+S*0.07, cy+S*0.04], fill=HOT_YELLOW)


def make_shadow(sprite):
    """A soft ground shadow projected down-right from the sprite silhouette."""
    S = sprite.size[0]
    alpha = sprite.split()[3]
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    black = Image.new("RGBA", (S, S), (0, 0, 0, 150))
    sh.paste(black, (0, 0), alpha)
    sh = sh.transform((S, S), Image.AFFINE, (1, 0.5, -S*0.10, 0, 0.5, S*0.22), resample=Image.BILINEAR)
    sh = sh.filter(ImageFilter.GaussianBlur(S//48))
    return sh


# ── Drivers ──────────────────────────────────────────────────────────
ICONS = {
    "cryo-quench":         icon_cryo_quench,
    "lava-manufacturer":   icon_lava_manufacturer,
    "ice-crusher":         icon_ice_crusher,
    "electric-heater":     icon_electric_heater,
    "mass-driver":         icon_mass_driver,
    "mass-driver-catcher": icon_mass_driver_catcher,
    "capacitor":           icon_capacitor,
    "molten-salt-battery": icon_molten_salt_battery,
    "dissipator":          icon_dissipator,
    "cindra-solar-panel":  icon_solar_panel,
    "ice":                 icon_item_ice,
    "cindra-stone":        icon_item_stone,
    "cindra-volatiles":    icon_item_volatiles,
    "cryo-hardened-alloy": icon_item_alloy,
    "cindra-science-pack": icon_science_pack,
}

ENTITIES = {
    "cryo-quench":         roof_cryo_quench,
    "mass-driver":         roof_mass_driver,
    "dissipator":          roof_dissipator,
    "cindra-solar-panel":  roof_solar,
    "capacitor":           roof_capacitor,
    "molten-salt-battery": roof_battery,
}
ENTITY_PX = 256


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "mods/cindra/graphics"
    icons_dir = os.path.join(out, "icons")
    os.makedirs(icons_dir, exist_ok=True)
    for name, fn in ICONS.items():
        strip = finalize_icon(fn())
        strip.save(os.path.join(icons_dir, f"{name}.png"))
        print(f"icon  {name:22s} -> {icons_dir}/{name}.png  {strip.size}")

    for name, roof in ENTITIES.items():
        edir = os.path.join(out, "entity", name)
        os.makedirs(edir, exist_ok=True)
        spr = entity_sprite(ENTITY_PX, roof)
        spr.save(os.path.join(edir, f"{name}.png"))
        make_shadow(spr).save(os.path.join(edir, f"{name}-shadow.png"))
        print(f"sprite {name:22s} -> {edir}/  ({ENTITY_PX}px + shadow)")


if __name__ == "__main__":
    main()
