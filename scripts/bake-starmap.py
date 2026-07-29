# Headless Blender bake of the Cindra star-map sprite.
#
# The engine renders the ORBITAL planet live from the equirectangular maps
# (platform_surface_render_parameters), but the STAR-MAP view wants a single
# baked sprite (starmap_icon). We bake it from the very same equirect maps so the
# two views read as the same planet: UV-sphere -> albedo + emission + normal
# material -> Cycles render on a transparent film.
#
# Cindra is TIDALLY LOCKED, so the bake presents ONE fixed face: the dramatic
# fire/ice split. gen-planet-maps.py lays the insolation gradient along LONGITUDE
# (sub-stellar/fire at lon=-90, terminator ribbon at lon=0, anti-stellar/ice at
# lon=+90). We rotate the sphere -90 deg about Z so lon=0 (the ribbon) faces the
# camera, putting the molten DAYSIDE on the left limb, the temperate RIBBON down
# the centre, and the frozen NIGHTSIDE on the right limb. Because the sprite is a
# static PNG it can never spin; the orbital backdrop is frozen separately (see
# prototypes/space-appearance.lua, rotation_seconds very large).
#
# The star sits perilously close, so lighting is a strong, hot KEY sun from the
# dayside limb; the emission map carries the magma glow. A soft warm WORLD ambient
# plus a gentle FRONT fill light the presented face directly, so the sandy ribbon
# down the centre reads as lit sand (not the black disc the grazing-only lighting
# used to produce); a dim cold blue fill keeps the frozen hemisphere blue, not
# pure black.
#
#   blender -b -P scripts/bake-starmap.py -- <space_maps_dir> <out_png>

import bpy
import sys
import os
from math import radians

argv = sys.argv[sys.argv.index("--") + 1:]
SPACE = argv[0]
OUT = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# --- Sphere ----------------------------------------------------------------
bpy.ops.mesh.primitive_uv_sphere_add(segments=192, ring_count=96, radius=1.0)
sphere = bpy.context.active_object
bpy.ops.object.shade_smooth()
# Rotate -90 about Z so the terminator (lon=0) faces the camera; a small tilt
# about X shows a touch of the northern pole for a 3D globe read. Fire ends up on
# the LEFT limb, ice on the RIGHT.
sphere.rotation_euler = (radians(8), 0.0, radians(-90))


def load(name, colorspace):
    img = bpy.data.images.load(os.path.join(SPACE, name))
    img.colorspace_settings.name = colorspace
    return img


def set_input(node, name, value):
    """Set a Principled BSDF input if the socket exists (Blender version-safe)."""
    if name in node.inputs:
        node.inputs[name].default_value = value


# --- Material --------------------------------------------------------------
mat = bpy.data.materials.new("cindra")
mat.use_nodes = True
nt = mat.node_tree
nodes, links = nt.nodes, nt.links
nodes.clear()

out = nodes.new("ShaderNodeOutputMaterial")
bsdf = nodes.new("ShaderNodeBsdfPrincipled")
links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

tex_albedo = nodes.new("ShaderNodeTexImage")
tex_albedo.image = load("cindra.png", "sRGB")
links.new(tex_albedo.outputs["Color"], bsdf.inputs["Base Color"])

tex_em = nodes.new("ShaderNodeTexImage")
tex_em.image = load("cindra-emission.png", "sRGB")
if "Emission Color" in bsdf.inputs:
    links.new(tex_em.outputs["Color"], bsdf.inputs["Emission Color"])
elif "Emission" in bsdf.inputs:
    links.new(tex_em.outputs["Color"], bsdf.inputs["Emission"])
# Emission carries the molten dayside, the sandy-seam self-glow, and the icy
# nightside shimmer -- strong enough to dominate the lit albedo. Tuned against the
# STANDARD view transform (see render settings, ci-fg6): Standard keeps the magma
# emission a SATURATED glowing orange/red instead of AgX's washed-out pale peach,
# so a modest strength already reads as a bright, radiant glow that the compositor
# Glare (below) blooms into a halo.
set_input(bsdf, "Emission Strength", 1.6)

tex_refl = nodes.new("ShaderNodeTexImage")
tex_refl.image = load("cindra-reflectivity.png", "Non-Color")
# Reflectivity high (ice) -> low roughness (glossy); low (basalt) -> rough matte.
# Remap into [0.14, 0.95]: icy nightside gets a bright cold SHEEN (glossier floor
# than before, ci-fg6, so the frost ridges glint), molten dayside stays matte.
rough = nodes.new("ShaderNodeMapRange")
rough.inputs["To Min"].default_value = 0.14
rough.inputs["To Max"].default_value = 0.95
# MapRange inverts via To Min > To Max would flip; we want high refl -> low rough,
# so feed (1 - refl) by swapping the From range instead.
rough.inputs["From Min"].default_value = 1.0
rough.inputs["From Max"].default_value = 0.0
links.new(tex_refl.outputs["Color"], rough.inputs["Value"])
links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
# Lift the specular so the icy nightside sheen catches the cold fill light more
# strongly (a brighter blue glint on the frost ridges). ci-fg6.
set_input(bsdf, "Specular IOR Level", 0.55)

tex_n = nodes.new("ShaderNodeTexImage")
tex_n.image = load("cindra-normal.png", "Non-Color")
nmap = nodes.new("ShaderNodeNormalMap")
nmap.inputs["Strength"].default_value = 0.9
links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

sphere.data.materials.append(mat)

# --- World ambient: a soft warm base so the lit albedo (esp. the sandy ribbon
# down the centre) never falls to pure black where no key light grazes. -----
world = bpy.data.worlds.new("cindra_world")
scene.world = world
world.use_nodes = True
wbg = world.node_tree.nodes.get("Background")
if wbg is not None:
    wbg.inputs["Color"].default_value = (0.12, 0.10, 0.09, 1.0)   # warm dim ambient
    wbg.inputs["Strength"].default_value = 0.35

# --- Lights: hot key from the dayside limb + dim cold blue fill ------------
# The star is perilously close: a bright, hot, white key from the fire (left,
# world -X) side, grazing the dayside limb.
key = bpy.data.lights.new("key", "SUN")
key.energy = 3.5
key.color = (1.0, 0.90, 0.74)
key.angle = radians(3)
key_obj = bpy.data.objects.new("key", key)
scene.collection.objects.link(key_obj)
# Point the sun toward +X (rays travel +X), so it comes FROM -X (the fire limb).
key_obj.rotation_euler = (radians(90), radians(-8), radians(-90))

# Cold blue fill from the ice (right, +X) side so the frozen hemisphere reads as
# a SHIMMERY blue, not flat navy (ci-fg6): brighter and bluer than before so the
# glossy frost ridges glint. Still below the hot key so the dayside dominates.
fill = bpy.data.lights.new("fill", "SUN")
fill.energy = 1.4
fill.color = (0.40, 0.60, 1.0)
fill.angle = radians(8)
fill_obj = bpy.data.objects.new("fill", fill)
scene.collection.objects.link(fill_obj)
fill_obj.rotation_euler = (radians(90), radians(8), radians(90))

# Gentle FRONT fill from the camera side (rays travel +Y, toward the sphere's
# front face) so the presented disc -- and the sandy ribbon crossing its centre,
# whose normal faces the camera -- is lit head-on instead of only grazed by the
# two limb suns. Warm-neutral and modest so the molten emission still dominates.
front = bpy.data.lights.new("front", "SUN")
front.energy = 0.8
front.color = (1.0, 0.94, 0.82)
front.angle = radians(12)
front_obj = bpy.data.objects.new("front", front)
scene.collection.objects.link(front_obj)
front_obj.rotation_euler = (radians(90), 0.0, 0.0)

# --- Camera: orthographic, framing the unit sphere -------------------------
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
cam.ortho_scale = 2.15
cam_obj = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(cam_obj)
cam_obj.location = (0.0, -3.0, 0.0)
cam_obj.rotation_euler = (radians(90), 0.0, 0.0)
scene.camera = cam_obj

# --- Render settings -------------------------------------------------------
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 128
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
# View transform: STANDARD, not the default AgX (ci-fg6). AgX aggressively
# desaturates bright pixels toward white, which turned the molten emission into a
# dull pale peach ("too dull"). Standard preserves the hot orange/red saturation
# so the lava limb reads as GLOWING magma and the icy sheen stays a clean blue.
scene.view_settings.view_transform = "Standard"
scene.render.filepath = OUT

# --- Compositor: bloom the molten limb (ci-fg6) ----------------------------
# The bare emission read too flat ("dull"). A Glare (Fog Glow) node bleeds the
# hot, white-blown lava emission into a radiant halo, so the fire limb GLOWS
# instead of sitting as matte peach. Threshold ~0.7 so only the genuinely hot
# (near-white) magma blooms; the sandy seam and dim ice do not wash out.
#
# The compositor API moved between Blender releases (4.x: scene.node_tree with a
# Composite node + glare_type attr / FOG_GLOW enum; 5.x: scene.compositing_node_
# group with a Group Output + socket-driven "Type" / "Fog Glow" enum). We build
# for both and swallow failures: if a future Blender changes the API again, the
# bake still succeeds on the strong raw emission alone -- just without the halo.
def set_glare(glare):
    """Configure a Glare node as a Fog-Glow bloom across Blender 4.x/5.x."""
    # 5.x: menu SOCKETS with display-name enums.
    for sock, val in (("Type", "Fog Glow"), ("Quality", "High"),
                      ("Threshold", 0.7), ("Size", 0.6)):
        if sock in glare.inputs:
            try:
                glare.inputs[sock].default_value = val
            except Exception:
                pass
    # 4.x: node ATTRIBUTES with UPPER_CASE enums.
    if hasattr(glare, "glare_type"):
        glare.glare_type = "FOG_GLOW"
    if hasattr(glare, "quality"):
        glare.quality = "HIGH"
    if hasattr(glare, "threshold"):
        glare.threshold = 0.7
    if hasattr(glare, "mix"):
        glare.mix = 0.15
    if hasattr(glare, "size"):
        try:
            glare.size = 8   # 4.x FOG_GLOW size is an int 6..9
        except Exception:
            pass


def add_bloom():
    if hasattr(scene, "compositing_node_group"):
        # Blender 5.x: the scene compositor is a node group (RLayers -> Glare ->
        # Group Output), assigned to scene.compositing_node_group.
        ng = bpy.data.node_groups.new("cindra_comp", "CompositorNodeTree")
        ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = ng.nodes.new("CompositorNodeRLayers")
        glare = ng.nodes.new("CompositorNodeGlare")
        set_glare(glare)
        gout = ng.nodes.new("NodeGroupOutput")
        ng.links.new(rl.outputs["Image"], glare.inputs["Image"])
        ng.links.new(glare.outputs["Image"], gout.inputs["Image"])
        scene.compositing_node_group = ng
    else:
        # Blender 4.x: RLayers -> Glare -> Composite on scene.node_tree.
        scene.use_nodes = True
        ct = scene.node_tree
        for n in list(ct.nodes):
            ct.nodes.remove(n)
        rl = ct.nodes.new("CompositorNodeRLayers")
        glare = ct.nodes.new("CompositorNodeGlare")
        set_glare(glare)
        comp = ct.nodes.new("CompositorNodeComposite")
        ct.links.new(rl.outputs["Image"], glare.inputs["Image"])
        ct.links.new(glare.outputs["Image"], comp.inputs["Image"])
        if "Alpha" in rl.outputs and "Alpha" in comp.inputs:
            ct.links.new(rl.outputs["Alpha"], comp.inputs["Alpha"])


try:
    add_bloom()
    print("compositor bloom (Glare/Fog Glow) enabled")
except Exception as e:
    print("WARNING: compositor bloom unavailable, baking raw emission:", e)

bpy.ops.render.render(write_still=True)
print("baked star-map sprite ->", OUT)
