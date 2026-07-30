#!/usr/bin/env python3
# Pixel test for the BAKED star-map sprite lighting (scripts/bake-starmap.py).
#
# The bake needs Blender, so it cannot regenerate inside the fast test loop the
# way gen-planet-maps.py does. Instead this guards the committed sprite
# (graphics/icons/starmap-planet-cindra.png) against the ci-2f7 lighting CONTRACT:
# a single very strong PARALLEL sun from the LEFT, aimed PERPENDICULAR to the
# vertical lava line, cranked so the sun-side limb blows out to near-WHITE with a
# dramatic light->dark falloff into the frozen (ice) hemisphere. If a future
# re-bake dims the sun, flips/rotates the light off the horizontal (so the
# blow-out no longer sits on the left limb), or flattens the gradient into a wash,
# this test fails.
#
# This is deliberately the same off-game verification pattern as
# test_planet_maps.py (which guards the equirectangular albedo/emission maps this
# sprite is baked from). Run (numpy + pillow):
#   nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
#     --run "python3 mods/cindra/unit-tests/test_starmap_lighting.py"

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITE = os.path.normpath(os.path.join(
    HERE, "..", "graphics", "icons", "starmap-planet-cindra.png"))

im = np.asarray(Image.open(SPRITE).convert("RGBA")).astype(float)
H, W, _ = im.shape
rgb = im[..., :3]
alpha = im[..., 3]
disc = alpha > 128                                  # the lit globe (film is transparent)

lum = rgb.mean(axis=-1)                              # per-pixel luminance 0..255
minc = rgb.min(axis=-1)                              # min channel: high only when near-WHITE
xs = np.arange(W)[None, :].repeat(H, axis=0)         # x index per pixel

passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print("ok - " + name)
    else:
        failed += 1
        print("not ok - " + name + ("  [" + detail + "]" if detail else ""))


# Sanity: the sprite is a round disc on a transparent film.
disc_frac = disc.sum() / (H * W)
check("sprite is a disc on transparent film (0.4 < disc fraction < 0.85)",
      0.40 < disc_frac < 0.85,
      f"disc fraction={disc_frac:.2f}")

# --- SUN-SIDE BLOWS OUT TO NEAR-WHITE ---------------------------------------
# The brightest point must approach white: measured on the MIN channel so a hot
# but saturated orange (low blue) does NOT count -- only a genuine white clip.
brightest_min = float(np.sort(minc[disc])[-200:].mean())
check("sun-side brightest point blows out to near-WHITE (top-200 min-channel > 245)",
      brightest_min > 245.0,
      f"top-200 min-channel mean={brightest_min:.1f}")

# There is a BROAD patch of near-white highlight -- the ci-2f7 crank widened the
# blown-out limb well beyond the earlier subtle hot corner (old bake ~1.7k px).
near_white = disc & (rgb[..., 0] > 235) & (rgb[..., 1] > 235) & (rgb[..., 2] > 225)
nw = int(near_white.sum())
check("near-white blow-out is a BROAD patch (>= 2200 px)",
      nw >= 2200,
      f"near-white px={nw}")

# --- LIGHT COMES FROM THE LEFT, PERPENDICULAR TO THE VERTICAL LAVA LINE ------
# The lava line is the vertical lon=0 terminator down the centre; a horizontal
# sun from the left puts the blow-out on the LEFT limb. So the near-white patch
# must sit in the left quarter, NOT the centre or the dark right side.
if nw > 0:
    nw_x = float(xs[near_white].mean()) / W
    check("blow-out sits on the LEFT/sun limb (mean x-fraction < 0.30)",
          nw_x < 0.30,
          f"near-white mean x-fraction={nw_x:.2f}")
else:
    check("blow-out sits on the LEFT/sun limb (mean x-fraction < 0.30)", False,
          "no near-white pixels to locate")

# --- STRONG, READABLE LIGHT->DARK GRADIENT (not a flat wash) ----------------
left = disc & (xs < W * 0.30)
mid = disc & (xs > W * 0.40) & (xs < W * 0.60)
right = disc & (xs > W * 0.70)
left_lum = float(lum[left].mean())
mid_lum = float(lum[mid].mean())
right_lum = float(lum[right].mean())

# The crank drives the sun-side much brighter than the earlier subtle bake
# (old left-third ~178); require it clearly above that.
check("sun side is dramatically bright (left-third luminance > 195)",
      left_lum > 195.0,
      f"left-third lum={left_lum:.1f}")
# And the light->dark contrast is stronger than the old wash (old ratio ~2.85):
# a dramatic, readable gradient, not a subtle one.
check("strong left->dark falloff (left-third >= 3.3x right-third)",
      left_lum >= 3.3 * right_lum,
      f"left={left_lum:.1f} right={right_lum:.1f} ratio={left_lum / max(right_lum, 1e-6):.2f}")
check("falloff is well underway by the terminator (mid < 0.55x left)",
      mid_lum < 0.55 * left_lum,
      f"mid={mid_lum:.1f} left={left_lum:.1f}")

# --- SAND/LAVA BELT IS PERPENDICULAR TO THE LIGHT: NO WEDGE (ci-pde) ---------
# The sun runs exactly horizontal (from the left), so the lava/sand belt -- the
# lon=0 terminator meridian the magma sits on -- must run VERTICAL down the disc,
# square to those rays. Any tilt of the sphere about the horizontal light axis
# slides that meridian off vertical while the light terminator stays vertical, so
# the belt and the lit/dark boundary cross at an angle: the pie-slice WEDGE the
# overseer flagged on ci-2f7. We measure the belt's lean directly from the
# saturated magma band: per row (away from the polar caps) take the mean x of the
# hot orange lava pixels, fit x vs y, and require the band's horizontal drift
# across the disc to be a tiny fraction of the diameter (a vertical band drifts
# ~0; the ci-2f7 wedge drifted ~0.066 of the diameter).
r_ch, g_ch, b_ch = rgb[..., 0], rgb[..., 1], rgb[..., 2]
lava = disc & (r_ch > 170) & ((r_ch - b_ch) > 90) & ((r_ch - g_ch) > 40)
ys_all = np.nonzero(disc.any(axis=1))[0]
cy = float(np.nonzero(disc)[0].mean())
rad = float(np.sqrt(disc.sum() / np.pi))
band_rows, band_cx = [], []
for y in range(H):
    if abs(y - cy) > 0.55 * rad:            # skip the narrow polar caps
        continue
    m = lava[y]
    if int(m.sum()) < 8:
        continue
    band_rows.append(y)
    band_cx.append(float(np.nonzero(m)[0].mean()))
if len(band_rows) >= 20:
    br = np.array(band_rows, float)
    bx = np.array(band_cx, float)
    slope = float(np.polyfit(br, bx, 1)[0])
    ndrift = abs(slope * (br.max() - br.min()) / (2.0 * rad))
    check("lava/sand belt runs vertical, square to the light -- NO wedge "
          "(band drift < 0.025 of diameter)",
          ndrift < 0.025,
          f"belt drift/diameter={ndrift:.4f}")
else:
    check("lava/sand belt runs vertical, square to the light -- NO wedge",
          False, f"too few lava-band rows to fit ({len(band_rows)})")

# --- DARK ICE SIDE IS DARK BUT NOT A PURE-BLACK VOID ------------------------
# The frozen hemisphere reads as the DARK side (strong falloff) yet still shows
# the pale-ice shimmer under the cool ambient -- not crushed to black.
check("ice side is clearly the dark side (right-third luminance < 110)",
      right_lum < 110.0,
      f"right-third lum={right_lum:.1f}")
check("ice side is not a pure-black void (right-third luminance > 15)",
      right_lum > 15.0,
      f"right-third lum={right_lum:.1f}")

# --- SOFT TERMINATOR: a slight ambient bleed past 90deg -> ~55% lit (ci-nyj) ---
# The bare Lambert key gives a HARD terminator exactly at the disc centre (a clean
# 50% half). ci-nyj adds a subtle wrap-around ambient/reflected-ground bleed in the
# bake so a little light spills just PAST the terminator onto the near-dark side:
# the terminator softens and ~55% of the disc reads as lit, WITHOUT washing out the
# deep dark ice limb (which the right-third guards above still hold dark). We assert
# the effect two ways so a future re-bake cannot silently revert to the hard 50%:
#
# 1. The near-terminator centre band (mid third) is clearly LIFTED above the deep
#    dark ice (right third) by the bleed. Before the softening the mid third fell to
#    -- or below -- the ambient ice floor (mid ~= right); the bleed now lifts it a
#    clear margin above. (This FAILS on the pre-ci-nyj hard-terminator bake.)
check("soft terminator: bleed lifts the mid band above the deep-dark ice "
      "(mid third >= right third + 4)",
      mid_lum >= right_lum + 4.0,
      f"mid={mid_lum:.1f} right={right_lum:.1f} (delta={mid_lum - right_lum:.1f})")

# 2. The lit fraction of the disc sits around ~55% (not a hard 50%, not a wash).
#    "Lit" = clearly above the cool ice ambient floor (luminance > 60). Before the
#    softening this was ~0.48 (under half); the bleed pushes it to ~0.54-0.55. Kept
#    below 0.62 so the planet still reads as a clear lit/dark globe, not over-lit.
lit_frac = float((disc & (lum > 60.0)).sum()) / float(disc.sum())
check("terminator softened to ~55% of the disc lit (0.50 <= lit fraction <= 0.62)",
      0.50 <= lit_frac <= 0.62,
      f"lit fraction (lum>60) = {lit_frac:.3f}")

print(f"\n{passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
