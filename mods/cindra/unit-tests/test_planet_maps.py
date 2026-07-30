#!/usr/bin/env python3
# Pixel test for the procedural planet maps (scripts/gen-planet-maps.py).
#
# The map generator is pure and deterministic, so its output is testable off-game
# without Blender or Factorio. This guards the ci-i9m REDESIGN of the from-space
# look, which SUPERSEDES the ci-fg6 painted-sandy-seam contract per the mayor,
# and the ci-6i1 recolour of the terminator belt (dark volcanic mountains, NOT a
# gray/tan sandy blur):
#
#   • NO PAINTED SEAM. The terminator is a SMOOTH hot->cold albedo ramp (mirroring
#     the in-game terrain ramp), not a bright self-lit stripe down the middle.
#     The old bug was a hard vertical line; here the terminator carries almost
#     no self-glow, so the day/night falloff comes from the parallel KEY LIGHT.
#   • DARK VOLCANIC MOUNTAINS AT THE TERMINATOR (ci-6i1). The middle third between
#     fire and ice is a BROAD band of dark reddish-brown / near-black basalt: LOW
#     luminance and WARM (R>G>B, R clearly above B), NOT the old gray/tan sandy
#     ribbon (which read as an ugly gray stripe from space) and NOT a neutral gray
#     (R != B). The gray/tan neutrals are gone from the ramp entirely.
#   • ICE READS AS ICE. The frozen hemisphere is PALE cyan-white frost (our terrain),
#     NOT a near-black vault laced with saturated electric-blue cracks (which read
#     as Fulgora lightning). It goes dark via the LIGHT falloff, not a black albedo.
#   • LAVA STILL GLOWS. The fiery hemisphere is a strongly glowing molten emission;
#     the terminator and ice do not self-light a bright band.
#
# Run (numpy only, ~1s at test resolution):
#   nix-shell -p "python3.withPackages(ps: with ps; [numpy])" \
#     --run "python3 mods/cindra/unit-tests/test_planet_maps.py"

import importlib.util
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.normpath(os.path.join(HERE, "..", "..", "..", "scripts", "gen-planet-maps.py"))

spec = importlib.util.spec_from_file_location("gen_planet_maps", GEN)
gpm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpm)

# Small, fast resolution: the zones are analytic (from longitude), so the split
# holds at any resolution; noise detail just gets coarser.
layers = gpm.generate_maps(W=256, H=128, seed=gpm.SEED)
masks = layers["_masks"]

albedo = layers["cindra.png"][0][..., :3]          # (H,W,3) float 0..255
emission = layers["cindra-emission.png"][0][..., :3]
emax = emission.max(axis=-1)                        # per-pixel emissive strength

# Select pixels that belong firmly to each region (avoid the blend borders).
fire = masks["day"] > 0.85
ice = masks["night"] > 0.85
seam = masks["ribbon"] > 0.85

passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print("ok - " + name)
    else:
        failed += 1
        print("not ok - " + name + ("  [" + detail + "]" if detail else ""))


def rgb_mean(arr, mask):
    return arr[mask].mean(axis=0)


def bright(arr, mask):
    return arr[mask].mean(axis=-1)


# All three regions must actually exist on the presented face.
check("each region is present (fire / terminator / ice)",
      fire.sum() > 50 and seam.sum() > 50 and ice.sum() > 50,
      f"fire={int(fire.sum())} seam={int(seam.sum())} ice={int(ice.sum())}")

fire_bright = float(np.median(bright(albedo, fire)))
seam_bright = float(np.median(bright(albedo, seam)))
ice_bright = float(np.median(bright(albedo, ice)))

# --- NO PAINTED SEAM (ci-i9m supersedes ci-fg6) -----------------------------
# The terminator must NOT be a bright self-lit stripe: its emission is near-zero,
# so it falls dark where the key light does not reach it (the natural terminator).
seam_emax = float(np.median(emax[seam]))
fire_emax = float(np.median(emax[fire]))
ice_emax = float(np.median(emax[ice]))
check("terminator carries NO bright self-glow band (median emax < 20)",
      seam_emax < 20.0,
      f"seam median emax={seam_emax:.1f}")
# The terminator is a DARK belt, not a bright albedo spike: the mountain band is
# dimmer than the pale ice and no brighter than the fiery limb.
check("terminator is a dark belt, not a bright albedo spike",
      seam_bright < ice_bright and seam_bright <= fire_bright + 20.0,
      f"seam={seam_bright:.1f} fire={fire_bright:.1f} ice={ice_bright:.1f}")

# --- DARK VOLCANIC MOUNTAINS AT THE TERMINATOR (ci-6i1) ---------------------
# The middle third is a broad band of dark reddish-brown / near-black basalt.
seam_alb = rgb_mean(albedo, seam)
# LOW luminance: the belt is dark rock, well below the pale ice and not a bright
# neutral. (The old sandy/grey stops sat around ~150; dark mountains are far below.)
check("terminator is DARK volcanic rock (mean brightness < 90, << ice)",
      seam_bright < 90.0 and seam_bright < 0.5 * ice_bright,
      f"seam={seam_bright:.1f} ice={ice_bright:.1f}")
# WARM, not gray/tan: red clearly dominates blue (basalt reddish-brown), the
# opposite of the old cool-grey-dust neutral (R ~= G ~= B).
check("terminator albedo is WARM basalt (R>G>B, R clearly above B: R-B > 12)",
      seam_alb[0] > seam_alb[1] > seam_alb[2] and (seam_alb[0] - seam_alb[2]) > 12.0,
      f"albedo={seam_alb.round(1)}  R-B={(seam_alb[0] - seam_alb[2]):.1f}")
# NOT a neutral gray: reject the cool-grey-dust look (R within ~15% of B).
check("terminator is NOT neutral gray (R > 1.3*B)",
      seam_alb[0] > 1.3 * seam_alb[2],
      f"albedo={seam_alb.round(1)}  R/B={seam_alb[0] / max(seam_alb[2], 1e-6):.2f}")

# --- FIRE HEMISPHERE: lava / volcanic, strongly glowing ---------------------
fire_alb = rgb_mean(albedo, fire)
check("fire albedo is lava orange-red (R>G>B, R>150)",
      fire_alb[0] > fire_alb[1] > fire_alb[2] and fire_alb[0] > 150,
      f"albedo={fire_alb.round(1)}")
fire_em = rgb_mean(emission, fire)
check("dayside is a STRONGLY GLOWING emission (median emax > 150)",
      fire_emax > 150,
      f"median emax={fire_emax:.1f}")
check("dayside emission is warm (R dominant, R>B)",
      fire_em[0] > fire_em[2],
      f"emission={fire_em.round(1)}")
check("dayside glows hotter than the terminator AND the ice",
      fire_emax > seam_emax and fire_emax > ice_emax,
      f"fire={fire_emax:.1f} seam={seam_emax:.1f} ice={ice_emax:.1f}")

# --- ICE HEMISPHERE: PALE ICE, not a Fulgora-electric vault -----------------
ice_alb = rgb_mean(albedo, ice)
# PALE: bright frost, NOT a near-black base. Darkness on the ice limb is supplied
# by the light falloff in the bake / orbit, not by a black albedo.
check("ice albedo is PALE frost, not near-black (mean brightness > 140)",
      ice_bright > 140,
      f"ice brightness={ice_bright:.1f}")
# COOL, but NOT the saturated electric-blue-on-black that reads as lightning: the
# channels are close (pale cyan-white), blue leads but only modestly.
check("ice albedo is cool pale cyan-white (B>R and G>R)",
      ice_alb[2] > ice_alb[0] and ice_alb[1] > ice_alb[0],
      f"albedo={ice_alb.round(1)}")
check("ice is NOT electric-blue-on-black (B < 1.7*R -- pale, not saturated)",
      ice_alb[2] < 1.7 * ice_alb[0],
      f"albedo={ice_alb.round(1)}  B/R={ice_alb[2] / max(ice_alb[0], 1e-6):.2f}")
# A faint icy-blue shimmer is still present, kept DIM so the frozen hemisphere
# stays dark overall and well below the fiery glow.
check("ice shimmer is faint but present (3 < median emax < 80)",
      3 < ice_emax < 80,
      f"ice emax={ice_emax:.1f}")
ice_em = rgb_mean(emission, ice)
check("ice shimmer is icy-blue (B dominant, B>R)",
      ice_em[2] > ice_em[0],
      f"emission={ice_em.round(1)}")

# --- Determinism ------------------------------------------------------------
again = gpm.generate_maps(W=256, H=128, seed=gpm.SEED)["cindra.png"][0]
check("deterministic: same seed -> identical albedo",
      np.array_equal(again, layers["cindra.png"][0]))

print(f"\n{passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
