#!/usr/bin/env python3
# Pixel test for the BAKED star-map sprite lighting (scripts/bake-starmap.py).
#
# The bake needs Blender, so it cannot regenerate inside the fast test loop the
# way gen-planet-maps.py does. Instead this guards the committed sprite
# (graphics/icons/starmap-planet-cindra.png) against the ci-2f7 lighting CONTRACT:
# a single very strong PARALLEL sun from the LEFT, aimed PERPENDICULAR to the
# vertical lava line, cranked so the sun-side limb blows out to near-WHITE with a
# dramatic light->dark falloff into the frozen (ice) hemisphere. The terminator
# itself is the ci-6i1 DARK VOLCANIC-MOUNTAIN band (molten -> dark mountains ->
# ice, no gray/tan blur), which supersedes the earlier ci-nyj soft-bleed reading.
# If a future re-bake dims the sun, flips/rotates the light off the horizontal (so
# the blow-out no longer sits on the left limb), flattens the gradient into a wash,
# or washes/greys the dark-mountain terminator, this test fails.
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

# --- DARK VOLCANIC-MOUNTAIN TERMINATOR (ci-6i1, supersedes the ci-nyj bleed) --
# Original ci-nyj contract: an ambient bleed softened the terminator so the mid
# third lifted ABOVE the ice and ~55% of the disc read as lit. ci-6i1 (P1,
# human-flagged: "the planet should read molten -> dark mountains -> ice, with NO
# gray/tan blur") deliberately re-baked this sprite, replacing the sandy/gray
# terminator neutrals with a broad band of DARK VOLCANIC MOUNTAINS (reddish-brown
# basalt) down the middle third. That makes the terminator the DARKEST band on the
# disc -- darker than the pale-ice limb -- which is the exact opposite of the
# ci-nyj "mid lifted above ice" reading. ci-6i1 is the later, human-approved
# contract (verification: docs/verification/ci-6i1-terminator-orbital.png), so the
# terminator guard now encodes the dark-mountain look. We assert it two ways so a
# future re-bake cannot silently wash the mid band bright OR re-introduce the
# gray/tan blur ci-6i1 killed:
#
# 1. The mid third is the dark volcanic-mountain band: clearly DARKER than the
#    pale-ice limb (mid well below the right third), and warm basalt-toned
#    (R > G > B, R clearly above B) -- NOT the old neutral gray/tan terminator and
#    NOT a bright ambient-bleed wash. (This FAILS on both the pre-ci-6i1 bright/soft
#    bake and any revert to the gray/tan band.)
mid_rgb = rgb[mid].mean(axis=0)             # mean colour of the terminator band
mid_r, mid_g, mid_b = float(mid_rgb[0]), float(mid_rgb[1]), float(mid_rgb[2])
check("terminator is the DARK volcanic-mountain band, darker than the pale ice "
      "(mid third <= right third - 8, and mid luminance < 50)",
      mid_lum <= right_lum - 8.0 and mid_lum < 50.0,
      f"mid={mid_lum:.1f} right={right_lum:.1f} (delta={mid_lum - right_lum:.1f})")
check("terminator band is warm basalt, NOT neutral gray/tan "
      "(mid mean R > G > B and R - B >= 10)",
      mid_r > mid_g > mid_b and (mid_r - mid_b) >= 10.0,
      f"mid mean rgb=({mid_r:.1f},{mid_g:.1f},{mid_b:.1f}) R-B={mid_r - mid_b:.1f}")

# 2. With the dark terminator the disc reads as a clear lit/dark globe: the molten
#    sun side is lit, the dark mountains + ice hemisphere are not. "Lit" means
#    clearly above the SHADOW FLOOR -- the luminance the cool ambient leaves on the
#    unlit ice limb -- so the threshold is measured from the sprite (1.5x the
#    ice-side median), not hard-coded.
#
#    It used to be a hard-coded `lum > 60`, calibrated when the frozen limb's
#    albedo happened to sit just under it. ci-4qyj repainted the globe with the
#    REAL terrain colours, which made the ice ocean properly pale, and the constant
#    then measured the ice's ALBEDO instead of whether the star was lighting it --
#    reporting 0.59 for a globe whose light/dark read had not changed at all.
#    Deriving the threshold from the shadow floor restores the original meaning and
#    is strictly harder to game: darkening the ice albedo no longer moves it.
#    (Sanity: the pre-ci-4qyj sprite scores 0.38 on this metric, the current one
#    0.34 -- both a clean sunlit crescent over a dark hemisphere.)
shadow_floor = float(np.median(lum[right]))
lit_frac = float((disc & (lum > 1.5 * shadow_floor)).sum()) / float(disc.sum())
check("dark-terminator globe reads as a clear lit/dark split "
      "(0.30 <= lit fraction <= 0.52 above the shadow floor)",
      0.30 <= lit_frac <= 0.52,
      f"lit fraction (lum > 1.5x shadow floor {shadow_floor:.1f}) = {lit_frac:.3f}")

# --- THE THREE-PART PLANET ON THE STAR MAP (ci-4qyj) ------------------------
# The star-map icon is the FIRST thing a player ever sees of Cindra, so the
# three-part planet the ci-wly/ci-oe83 heightmap generates has to be legible in
# it: a broad molten OCEAN, the rock we build on, and a broad frozen OCEAN, in
# that order across the disc. (unit-tests/test_planet_maps.py proves the
# equirectangular maps carry those regions at the terrain's real widths; this
# proves the BAKE still shows all three rather than losing one to the lighting.)
molten = disc & (rgb[..., 0] > 150) & ((rgb[..., 0] - rgb[..., 2]) > 60)
icy = disc & ((rgb[..., 2] - rgb[..., 0]) > 10)
rock = disc & ~molten & ~icy & (lum < 70)
disc_cols = np.nonzero(disc.any(axis=0))[0]
xfrac = (xs - disc_cols.min()) / float(disc_cols.max() - disc_cols.min())
n_disc = float(disc.sum())

check("the molten OCEAN is a broad sheet on the star map (>= 15% of the disc)",
      molten.sum() / n_disc >= 0.15, f"molten fraction={molten.sum() / n_disc:.3f}")
check("the frozen OCEAN is a broad sheet on the star map (>= 15% of the disc)",
      icy.sum() / n_disc >= 0.15, f"icy fraction={icy.sum() / n_disc:.3f}")
check("the habitable rock band is visible between them (>= 10% of the disc)",
      rock.sum() / n_disc >= 0.10, f"rock fraction={rock.sum() / n_disc:.3f}")
check("they read molten -> habitable rock -> ice across the disc",
      float(xfrac[molten].mean()) < float(xfrac[rock].mean()) < float(xfrac[icy].mean()),
      f"molten x={xfrac[molten].mean():.2f} rock x={xfrac[rock].mean():.2f} "
      f"ice x={xfrac[icy].mean():.2f}")
check("the frozen limb reads as ICE, not merely shadow (right third B - R >= 15)",
      float((rgb[..., 2] - rgb[..., 0])[right].mean()) >= 15.0,
      f"right-third B-R={float((rgb[..., 2] - rgb[..., 0])[right].mean()):.1f}")

print(f"\n{passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
