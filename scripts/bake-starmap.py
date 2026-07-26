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
# dayside limb; the emission map carries the magma glow, and a dim cold blue fill
# keeps the frozen hemisphere from going pure black.
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
set_input(bsdf, "Emission Strength", 2.4)   # magma glow carries the dayside

tex_refl = nodes.new("ShaderNodeTexImage")
tex_refl.image = load("cindra-reflectivity.png", "Non-Color")
# Reflectivity high (ice) -> low roughness (glossy); low (basalt) -> rough matte.
# Remap into [0.30, 0.95]: icy nightside gets a cold sheen, molten dayside stays matte.
rough = nodes.new("ShaderNodeMapRange")
rough.inputs["To Min"].default_value = 0.30
rough.inputs["To Max"].default_value = 0.95
# MapRange inverts via To Min > To Max would flip; we want high refl -> low rough,
# so feed (1 - refl) by swapping the From range instead.
rough.inputs["From Min"].default_value = 1.0
rough.inputs["From Max"].default_value = 0.0
links.new(tex_refl.outputs["Color"], rough.inputs["Value"])
links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
set_input(bsdf, "Specular IOR Level", 0.4)

tex_n = nodes.new("ShaderNodeTexImage")
tex_n.image = load("cindra-normal.png", "Non-Color")
nmap = nodes.new("ShaderNodeNormalMap")
nmap.inputs["Strength"].default_value = 0.9
links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

sphere.data.materials.append(mat)

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

# Cold blue fill from the ice (right, +X) side so the frozen hemisphere reads
# blue rather than black; dim, so the dayside still dominates.
fill = bpy.data.lights.new("fill", "SUN")
fill.energy = 0.7
fill.color = (0.45, 0.62, 1.0)
fill.angle = radians(8)
fill_obj = bpy.data.objects.new("fill", fill)
scene.collection.objects.link(fill_obj)
fill_obj.rotation_euler = (radians(90), radians(8), radians(90))

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
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("baked star-map sprite ->", OUT)
