import bpy
import os

# Script otomatis memasang 6 PBR Texture Maps ke Material 'M_KidsConcertStage' di Blender
tex_dir = os.path.dirname(bpy.data.filepath) if bpy.data.filepath else "."

mat = bpy.data.materials.get("M_KidsConcertStage") or bpy.data.materials.new(name="M_KidsConcertStage")
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links
nodes.clear()

bsdf = nodes.new("ShaderNodeBsdfPrincipled")
bsdf.location = (200, 0)
output = nodes.new("ShaderNodeOutputMaterial")
output.location = (550, 0)
links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

maps = [
    ("KidsConcertStage_Albedo.png", "sRGB", "Base Color", (-300, 300)),
    ("KidsConcertStage_Metallic.png", "Non-Color", "Metallic", (-300, 50)),
    ("KidsConcertStage_Roughness.png", "Non-Color", "Roughness", (-300, -200)),
    ("KidsConcertStage_Emissive.png", "sRGB", "Emission Color", (-300, -450)),
]

for filename, colorspace, socket_name, loc in maps:
    path = os.path.join(tex_dir, filename)
    if os.path.exists(path):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path)
        tex.image.colorspace_settings.name = colorspace
        tex.location = loc
        links.new(tex.outputs["Color"], bsdf.inputs[socket_name])

norm_path = os.path.join(tex_dir, "KidsConcertStage_Normal.png")
if os.path.exists(norm_path):
    tex_norm = nodes.new("ShaderNodeTexImage")
    tex_norm.image = bpy.data.images.load(norm_path)
    tex_norm.image.colorspace_settings.name = "Non-Color"
    tex_norm.location = (-600, -700)
    norm_node = nodes.new("ShaderNodeNormalMap")
    norm_node.location = (-250, -700)
    links.new(tex_norm.outputs["Color"], norm_node.inputs["Color"])
    links.new(norm_node.outputs["Normal"], bsdf.inputs["Normal"])

print("Material PBR M_KidsConcertStage berhasil dibuat!")
