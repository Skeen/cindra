#!/usr/bin/env python3
# Regenerate the bootstrap-rock stone-tint before/after (ci-jvc).
#
#   nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
#     --run "python3 scripts/render-rock-tint.py"
#
# Writes docs/verification/ci-jvc-rock-stone-tint.png: three representative
# vanilla huge-rock variations, stock on the left and warm-tinted on the right,
# both composited over the dark Cindra terminator soil colour.
#
# WHY THIS IS FAITHFUL. The engine renders a Sprite's `tint` as a per-pixel
# multiply into the source texture, so multiplying the exact vanilla source PNGs
# here reproduces what the game draws (an FBSR render does NOT honour sprite tint,
# so it would under-show the shift). The tint value is the single source of truth
# in mods/cindra/scripts/rock_tint.lua -- keep STONE_TINT below in sync with it.

import glob
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

# Mirror of rock_tint.lua STONE_TINT (the wired value). 0..1 multiply.
STONE_TINT = {"r": 1.0, "g": 0.93, "b": 0.62}
# Approx colour of the terminator ground (volcanic-soil-light clone): dark warm grey.
TERMINATOR_BG = (52, 46, 41)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HUGE_ROCK_GLOB = os.path.join(
    ROOT, "factorio/data/base/graphics/decorative/huge-rock/*.png"
)
OUT = os.path.join(ROOT, "docs/verification/ci-jvc-rock-stone-tint.png")


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64)


def multiply_tint(im, tint):
    out = im.copy()
    for i, c in enumerate((tint["r"], tint["g"], tint["b"])):
        out[..., i] = np.clip(im[..., i] * c, 0, 255)
    return out


def over(fg, bg_rgb):
    a = fg[..., 3:4] / 255.0
    bg = np.zeros_like(fg[..., :3])
    bg[...] = bg_rgb
    rgb = fg[..., :3] * a + bg * (1 - a)
    return np.dstack([rgb, np.full(fg.shape[:2], 255.0)]).astype(np.uint8)


def font(size):
    try:
        return ImageFont.truetype("DejaVuSans-Bold.ttf", size)
    except OSError:
        return ImageFont.load_default()


def main():
    rocks = sorted(glob.glob(HUGE_ROCK_GLOB))
    if not rocks:
        raise SystemExit("no huge-rock source PNGs found (is factorio/ linked?)")
    # A stable, representative spread across the variation set (deterministic).
    picks = [rocks[0], rocks[len(rocks) // 2], rocks[-1]]

    cell, pad, cols = 190, 34, 2
    rows = len(picks)
    sheet = Image.new("RGB", (cols * cell, pad + rows * cell), (26, 26, 28))
    draw = ImageDraw.Draw(sheet)
    label_font = font(20)
    draw.text((12, 8), "BEFORE  (stock huge-rock)", fill=(230, 225, 215), font=label_font)
    draw.text(
        (cell + 12, 8),
        "AFTER  (warm stone tint %.2f/%.2f/%.2f)"
        % (STONE_TINT["r"], STONE_TINT["g"], STONE_TINT["b"]),
        fill=(230, 225, 215),
        font=label_font,
    )

    for r, path in enumerate(picks):
        src = load(path)
        for ci in range(2):
            img = over(src if ci == 0 else multiply_tint(src, STONE_TINT), TERMINATOR_BG)
            im = Image.fromarray(img, "RGBA").convert("RGB")
            im.thumbnail((cell - 20, cell - 20))
            sheet.paste(
                im,
                (ci * cell + (cell - im.width) // 2, pad + r * cell + (cell - im.height) // 2),
            )
    draw.line([(cell, pad), (cell, sheet.height)], fill=(70, 70, 74), width=2)
    sheet.save(OUT)
    print("wrote", os.path.relpath(OUT, ROOT), sheet.size)


if __name__ == "__main__":
    main()
