#!/usr/bin/env python3
# Pixel test for the procedural planet maps (scripts/gen-planet-maps.py, ci-hmc).
#
# The map generator is pure and deterministic, so its output is testable off-game
# without Blender or Factorio. This guards the REDESIGN contract -- the presented
# face must read FIERY -> SANDY -> ICY -- and in particular the regression that
# started ci-hmc: the MIDDLE of the globe rendered BLACK because the ribbon had a
# dark slate albedo and ZERO emission, so any point the key light did not graze
# went black. We assert the sandy seam now carries a bright albedo AND its own
# warm emission, the dayside is a strong warm glow, and the nightside is the
# darkest, blue-biased zone.
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

# Select pixels that belong firmly to each zone (avoid the blend borders).
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


# All three zones must actually exist on the presented face.
check("each zone is present (fire / sandy seam / ice)",
      fire.sum() > 50 and seam.sum() > 50 and ice.sum() > 50,
      f"fire={int(fire.sum())} seam={int(seam.sum())} ice={int(ice.sum())}")

# --- THIN SANDY TERMINATOR (ci-fg6 space-view refinement) -------------------
# The mayor slimmed the sandy middle band ~10x: the disc must read as mostly
# FIERY hemisphere + ICY hemisphere with only a THIN sand seam between them. The
# old band was the middle ~third of the disc (screen width ~0.30R); the new one
# is a sliver (~0.03R, ~10x thinner). Guard both the total coverage and the
# on-disc equatorial width so a later tweak cannot quietly widen it back.
day_m, night_m, ribbon_m = masks["day"], masks["night"], masks["ribbon"]
seam_frac = float(ribbon_m.sum() / (day_m.sum() + night_m.sum()))
check("sandy seam is THIN vs the hemispheres (soft-mask sum < 0.20 of fire+ice)",
      seam_frac < 0.20,
      f"seam/(fire+ice)={seam_frac:.3f}")
# Equatorial screen width: along the equator (lat=0 row) sol ~ -sin(lon) ~ screen-x
# near the centre, so the fraction of the row that is sandy tracks the on-disc
# band width. Old band ~0.15 of the equirect row; the slimmed seam is well under.
eq_row = ribbon_m[ribbon_m.shape[0] // 2]
eq_seam_frac = float((eq_row > 0.5).mean())
check("sandy terminator is a thin sliver on the disc (equator width < 0.06)",
      eq_seam_frac < 0.06,
      f"equator seam width frac={eq_seam_frac:.3f}")

# --- SANDY SEAM: bright, warm, and self-lit (THE black-centre fix) ----------
seam_alb = rgb_mean(albedo, seam)
check("ribbon albedo is SANDY YELLOW (R>G>B, warm)",
      seam_alb[0] > seam_alb[1] > seam_alb[2],
      f"albedo={seam_alb.round(1)}")
check("ribbon albedo is bright, not dark slate (R>140, mean>110)",
      seam_alb[0] > 140 and seam_alb.mean() > 110,
      f"albedo={seam_alb.round(1)}")

seam_em = rgb_mean(emission, seam)
seam_emax = float(np.median(emax[seam]))
check("ribbon carries its OWN warm emission -> never black (median emax > 30)",
      seam_emax > 30,
      f"median emax={seam_emax:.1f}")
check("ribbon emission is warm sandy (R>=G>=B)",
      seam_em[0] >= seam_em[1] >= seam_em[2],
      f"emission={seam_em.round(1)}")

# --- FIRE HEMISPHERE: radiant molten glow -----------------------------------
fire_em = rgb_mean(emission, fire)
fire_emax = float(np.median(emax[fire]))
# ci-fg6: the fire limb must GLOW STRONGLY, not read as dull peach. Most of the
# dayside now blows out toward white-hot (median emax near saturation), which the
# bake's Glare node blooms into a radiant halo.
check("dayside is a STRONGLY GLOWING emission (median emax > 200)",
      fire_emax > 200,
      f"median emax={fire_emax:.1f}")
check("dayside emission is warm (R dominant, R>B)",
      fire_em[0] > fire_em[2],
      f"emission={fire_em.round(1)}")
check("dayside glows hotter than the sandy seam",
      fire_emax > seam_emax,
      f"fire={fire_emax:.1f} seam={seam_emax:.1f}")

# --- ICE HEMISPHERE: the DARKEST zone, icy-blue biased ----------------------
ice_bright = float(np.median(bright(albedo, ice)))
seam_bright = float(np.median(bright(albedo, seam)))
fire_bright = float(np.median(bright(albedo, fire)))
check("nightside is the DARKEST albedo (darker than seam AND fire)",
      ice_bright < seam_bright and ice_bright < fire_bright,
      f"ice={ice_bright:.1f} seam={seam_bright:.1f} fire={fire_bright:.1f}")

ice_alb = rgb_mean(albedo, ice)
# ci-fg6: not just B>R, but STRONGLY blue -- a shimmery icy sheen, not flat navy.
check("nightside albedo is STRONGLY icy-blue biased (B > 1.5*R)",
      ice_alb[2] > 1.5 * ice_alb[0],
      f"albedo={ice_alb.round(1)}  B/R={ice_alb[2] / max(ice_alb[0], 1e-6):.2f}")
ice_emax = float(np.median(emax[ice]))
# The nightside now carries a VISIBLE icy-blue shimmer self-glow (lifted from the
# old barely-there 0.11 factor, ci-fg6) -- but still dimmer than the sandy seam,
# so the frozen vault stays the darkest, dimmest-lit zone.
check("nightside shimmer is VISIBLE (median emax > 24)",
      ice_emax > 24,
      f"ice emax={ice_emax:.1f}")
ice_em = rgb_mean(emission, ice)
check("nightside shimmer is icy-blue (B dominant, B>R)",
      ice_em[2] > ice_em[0],
      f"emission={ice_em.round(1)}")
check("nightside stays dark: dimmer self-glow than the sandy seam",
      ice_emax < seam_emax,
      f"ice={ice_emax:.1f} seam={seam_emax:.1f}")

# --- Determinism ------------------------------------------------------------
again = gpm.generate_maps(W=256, H=128, seed=gpm.SEED)["cindra.png"][0]
check("deterministic: same seed -> identical albedo",
      np.array_equal(again, layers["cindra.png"][0]))

print(f"\n{passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
