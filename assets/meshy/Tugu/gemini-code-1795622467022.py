import os
import zipfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter

out_dir = "Downtown_City_Tugu_Keris_FBX"
os.makedirs(out_dir, exist_ok=True)

W, H = 1024, 1024

# Palette matching Tugu Keris Siginjai night scene + DOWNTOWN CITY neon sign
C_GOLD = (245, 192, 36)
C_GOLD_DARK = (185, 132, 18)
C_STONE_LIGHT = (210, 215, 224)
C_STONE_DARK = (92, 98, 112)
C_POOL_BLUE = (24, 62, 118)
C_POOL_RIM = (175, 185, 200)
C_NEON_RED = (255, 45, 75)
C_NEON_CYAN = (35, 235, 255)
C_NEON_GREEN = (55, 255, 115)
C_NEON_PINK = (255, 70, 195)
C_NEON_YELLOW = (255, 230, 55)
C_WHITE_GLOW = (255, 252, 240)

albedo = Image.new("RGB", (W, H), C_STONE_LIGHT)
roughness = Image.new("L", (W, H), 120)
metallic = Image.new("L", (W, H), 40)
normal = Image.new("RGB", (W, H), (128, 128, 255))
emissive = Image.new("RGB", (W, H), (0, 0, 0))

d_alb = ImageDraw.Draw(albedo)
d_rgh = ImageDraw.Draw(roughness)
d_met = ImageDraw.Draw(metallic)
d_nrm = ImageDraw.Draw(normal)
d_ems = ImageDraw.Draw(emissive)

def get_font(size):
    for p in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

# --- 4x4 PBR TEXTURE ATLAS (1024x1024) ---
# Tile (0,0) [0..256, 0..256]: Gold Monument Tower & Keris Blade
d_alb.rectangle([0, 0, 256, 256], fill=C_GOLD)
for y in range(16, 248, 24):
    d_alb.line([12, y, 244, y], fill=C_GOLD_DARK, width=3)
    d_nrm.line([12, y, 244, y], fill=(128, 95, 255), width=3)
d_rgh.rectangle([0, 0, 256, 256], fill=75)
d_met.rectangle([0, 0, 256, 256], fill=215)

# Tile (1,0) [256..512, 0..256]: Crown Ring Ornamental Band + Red/Cyan Trim
d_alb.rectangle([256, 0, 512, 180], fill=C_GOLD)
d_alb.rectangle([256, 180, 512, 220], fill=C_NEON_RED)
d_alb.rectangle([256, 220, 512, 256], fill=C_NEON_CYAN)
d_ems.rectangle([256, 180, 512, 220], fill=C_NEON_RED)
d_ems.rectangle([256, 220, 512, 256], fill=C_NEON_CYAN)
for x in range(268, 504, 24):
    d_alb.ellipse([x-7, 70, x+7, 110], fill=C_STONE_DARK)
    d_nrm.ellipse([x-7, 70, x+7, 110], outline=(100, 155, 255), width=3)
d_rgh.rectangle([256, 0, 512, 256], fill=65)
d_met.rectangle([256, 0, 512, 180], fill=210)

# Tile (2,0) [512..768, 0..256]: Fountain Water & Pool Base
d_alb.rectangle([512, 0, 768, 256], fill=C_POOL_BLUE)
for py in range(16, 248, 32):
    d_alb.line([512, py, 768, py], fill=(45, 115, 195), width=3)
    d_nrm.line([512, py, 768, py], fill=(128, 105, 255), width=3)
d_rgh.rectangle([512, 0, 768, 256], fill=30)
d_met.rectangle([512, 0, 768, 256], fill=15)

# Tile (3,0) [768..1024, 0..256]: Plaza Stone & Pedestal Trim
d_alb.rectangle([768, 0, 1024, 256], fill=C_STONE_LIGHT)
for gx in range(768, 1024, 64):
    d_alb.line([gx, 0, gx, 256], fill=C_STONE_DARK, width=2)
for gy in range(0, 256, 64):
    d_alb.line([768, gy, 1024, gy], fill=C_STONE_DARK, width=2)
d_rgh.rectangle([768, 0, 1024, 256], fill=165)
d_met.rectangle([768, 0, 1024, 256], fill=10)

# Row 1 [0..1024, 256..512]: Rainbow Light Strands (Red, Yellow, Green, Cyan, Pink)
rainbow_cols = [C_NEON_RED, C_NEON_YELLOW, C_NEON_GREEN, C_NEON_CYAN, C_NEON_PINK]
for idx, rcol in enumerate(rainbow_cols):
    x0 = idx * 204
    x1 = (idx + 1) * 204
    d_alb.rectangle([x0, 256, x1, 512], fill=rcol)
    d_ems.rectangle([x0, 256, x1, 512], fill=rcol)
    # Bright inner core glow
    d_alb.rectangle([x0 + 55, 256, x1 - 55, 512], fill=C_WHITE_GLOW)
    d_ems.rectangle([x0 + 55, 256, x1 - 55, 512], fill=C_WHITE_GLOW)
d_rgh.rectangle([0, 256, 1024, 512], fill=35)

# Row 2 [0..1024, 512..768]: Glowing "DOWNTOWN CITY" Sign Texture
d_alb.rectangle([0, 512, 1024, 768], fill=(26, 30, 42))
d_alb.text((48, 575), "DOWNTOWN CITY", fill=C_WHITE_GLOW, font=get_font(108))
d_ems.text((48, 575), "DOWNTOWN CITY", fill=C_WHITE_GLOW, font=get_font(108))
# Warm golden rim underline under sign
d_alb.rectangle([0, 725, 1024, 768], fill=C_GOLD)
d_ems.rectangle([0, 725, 1024, 768], fill=C_NEON_YELLOW)
d_rgh.rectangle([0, 512, 1024, 768], fill=40)

# Row 3 [0..1024, 768..1024]: Dark Structural Base & Gold Accents
d_alb.rectangle([0, 768, 512, 1024], fill=C_STONE_DARK)
d_alb.rectangle([512, 768, 1024, 1024], fill=C_GOLD)
d_rgh.rectangle([0, 768, 512, 1024], fill=150)
d_rgh.rectangle([512, 768, 1024, 1024], fill=70)
d_met.rectangle([512, 768, 1024, 1024], fill=215)

normal = normal.filter(ImageFilter.GaussianBlur(radius=0.6))

albedo.save(os.path.join(out_dir, "DowntownMonument_Albedo.png"), "PNG")
normal.save(os.path.join(out_dir, "DowntownMonument_Normal.png"), "PNG")
roughness.save(os.path.join(out_dir, "DowntownMonument_Roughness.png"), "PNG")
metallic.save(os.path.join(out_dir, "DowntownMonument_Metallic.png"), "PNG")
emissive.save(os.path.join(out_dir, "DowntownMonument_Emissive.png"), "PNG")

# Create Blender 3.6 Python script that builds the Tugu Keris Siginjai landmark with "DOWNTOWN CITY"
# matching the reference screenshot and exports Downtown_City_Tugu_Keris.fbx
blender_script = '''import os
import math
import bpy
import bmesh
from mathutils import Vector, Matrix


def get_script_dir():
    try:
        return os.path.dirname(os.path.abspath(__file__))
    except NameError:
        if bpy.data.filepath:
            return os.path.dirname(bpy.data.filepath)
        return os.getcwd()


def load_img(tex_dir, fname, colorspace):
    p = os.path.join(tex_dir, fname)
    if os.path.exists(p):
        img = bpy.data.images.load(p, check_existing=True)
        img.colorspace_settings.name = colorspace
        return img
    return None


def create_pbr_material(tex_dir, mat_name="M_DowntownMonument"):
    mat = bpy.data.materials.get(mat_name)
    if mat is None:
        mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (240, 0)
    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (560, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    img_alb = load_img(tex_dir, "DowntownMonument_Albedo.png", "sRGB")
    if img_alb:
        t_alb = nodes.new("ShaderNodeTexImage")
        t_alb.image = img_alb
        t_alb.location = (-320, 320)
        links.new(t_alb.outputs["Color"], bsdf.inputs["Base Color"])

    img_met = load_img(tex_dir, "DowntownMonument_Metallic.png", "Non-Color")
    if img_met:
        t_met = nodes.new("ShaderNodeTexImage")
        t_met.image = img_met
        t_met.location = (-320, 60)
        links.new(t_met.outputs["Color"], bsdf.inputs["Metallic"])

    img_rgh = load_img(tex_dir, "DowntownMonument_Roughness.png", "Non-Color")
    if img_rgh:
        t_rgh = nodes.new("ShaderNodeTexImage")
        t_rgh.image = img_rgh
        t_rgh.location = (-320, -200)
        links.new(t_rgh.outputs["Color"], bsdf.inputs["Roughness"])

    img_ems = load_img(tex_dir, "DowntownMonument_Emissive.png", "sRGB")
    if img_ems:
        t_ems = nodes.new("ShaderNodeTexImage")
        t_ems.image = img_ems
        t_ems.location = (-320, -460)
        links.new(t_ems.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 3.5

    img_nrm = load_img(tex_dir, "DowntownMonument_Normal.png", "Non-Color")
    if img_nrm:
        t_nrm = nodes.new("ShaderNodeTexImage")
        t_nrm.image = img_nrm
        t_nrm.location = (-600, -700)
        nrm_map = nodes.new("ShaderNodeNormalMap")
        nrm_map.location = (-250, -700)
        links.new(t_nrm.outputs["Color"], nrm_map.inputs["Color"])
        links.new(nrm_map.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def assign_uv_rect(bm, uv_layer, faces, u0, v0, u1, v1):
    for f in faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        if ay >= ax and ay >= az:
            coords = [(l.vert.co.x, l.vert.co.y) for l in f.loops]
        elif ax >= ay and ax >= az:
            coords = [(l.vert.co.y, l.vert.co.z) for l in f.loops]
        else:
            coords = [(l.vert.co.x, l.vert.co.z) for l in f.loops]

        min_u = min(c[0] for c in coords)
        max_u = max(c[0] for c in coords)
        min_v = min(c[1] for c in coords)
        max_v = max(c[1] for c in coords)
        du = max(max_u - min_u, 1e-5)
        dv = max(max_v - min_v, 1e-5)
        for loop, (cu, cv) in zip(f.loops, coords):
            nu = u0 + ((cu - min_u) / du) * (u1 - u0)
            nv = v0 + ((cv - min_v) / dv) * (v1 - v0)
            loop[uv_layer].uv = (nu, nv)


def add_cyl_segment(bm, uv_layer, z0, z1, r0, r1, segs, uv_rect, smooth=True):
    rings = []
    for z_h, rad in [(z0, r0), (z1, r1)]:
        ring = []
        for s in range(segs):
            a = (2.0 * math.pi * s) / segs
            ring.append(bm.verts.new((math.cos(a) * rad, math.sin(a) * rad, z_h)))
        rings.append(ring)
    faces = []
    for s in range(segs):
        ns = (s + 1) % segs
        f = bm.faces.new((rings[0][s], rings[0][ns], rings[1][ns], rings[1][s]))
        f.smooth = smooth
        faces.append(f)
    assign_uv_rect(bm, uv_layer, faces, *uv_rect)
    return faces


def add_curved_light_strand(bm, uv_layer, p_top, p_bot, mid_pull, radius, uv_rect):
    # Kabel cahaya pelangi melengkung dari mahkota atas ke kolam bawah
    steps = 12
    tube_segs = 6
    prev_ring = None
    faces = []
    for i in range(steps + 1):
        t = i / steps
        # Bezier kuadratik melengkung ke luar (mid_pull)
        p_ctrl = p_top.lerp(p_bot, 0.55)
        p_ctrl.x *= mid_pull
        p_ctrl.y *= mid_pull
        u = 1.0 - t
        pos = (u * u) * p_top + (2.0 * u * t) * p_ctrl + (t * t) * p_bot

        tangent = (p_bot - p_top).normalized()
        up_ref = Vector((0.0, 0.0, 1.0)) if abs(tangent.z) < 0.9 else Vector((1.0, 0.0, 0.0))
        binorm = tangent.cross(up_ref).normalized()
        norm_v = binorm.cross(tangent).normalized()

        ring = []
        for ts in range(tube_segs):
            ang = (2.0 * math.pi * ts) / tube_segs
            offset = (binorm * math.cos(ang) + norm_v * math.sin(ang)) * radius
            ring.append(bm.verts.new(pos + offset))
        if prev_ring is not None:
            for ts in range(tube_segs):
                nts = (ts + 1) % tube_segs
                f = bm.faces.new((prev_ring[ts], prev_ring[nts], ring[nts], ring[ts]))
                f.smooth = True
                faces.append(f)
        prev_ring = ring

    assign_uv_rect(bm, uv_layer, faces, *uv_rect)


def add_keris_blade(bm, uv_layer, z_start, height, base_width, waves=7):
    # Keris Siginjai berlekuk (luk) meruncing ke atas
    z_steps = waves * 4
    pts_left = []
    pts_right = []
    for i in range(z_steps + 1):
        t = i / z_steps
        z_h = z_start + t * height
        taper = (1.0 - t) ** 0.78
        w = max(0.015, base_width * taper)
        luk_offset = math.sin(t * waves * math.pi) * (base_width * 0.28 * (1.0 - t * 0.6))
        pts_left.append(bm.verts.new((luk_offset - w, 0.0, z_h)))
        pts_right.append(bm.verts.new((luk_offset + w, 0.0, z_h)))

    faces = []
    for i in range(z_steps):
        f1 = bm.faces.new((pts_left[i], pts_right[i], pts_right[i + 1], pts_left[i + 1]))
        f2 = bm.faces.new((pts_right[i], pts_left[i], pts_left[i + 1], pts_right[i + 1]))
        f1.smooth = True
        f2.smooth = True
        faces.extend([f1, f2])
    assign_uv_rect(bm, uv_layer, faces, 0.01, 0.76, 0.24, 0.99)


def build_tugu_keris():
    asset_name = "Downtown_City_Tugu_Keris"
    col_name = "downtown_city_tugu_keris"
    tex_dir = get_script_dir()

    col = bpy.data.collections.get(col_name)
    if col is None:
        col = bpy.data.collections.new(col_name)
        bpy.context.scene.collection.children.link(col)
    else:
        for old in list(col.objects):
            bpy.data.objects.remove(old, do_unlink=True)

    mat = create_pbr_material(tex_dir)

    mesh = bpy.data.meshes.new("TuguKeris_Mesh")
    obj = bpy.data.objects.new("Tugu_Keris_Downtown_City", mesh)
    col.objects.link(obj)
    obj.data.materials.append(mat)

    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    # 1. Kolam bundar & air mancur (Z: 0.0 to 1.4)
    add_cyl_segment(bm, uv_layer, 0.0, 0.85, 11.5, 11.5, 32, (0.76, 0.76, 0.99, 0.99), smooth=False)
    add_cyl_segment(bm, uv_layer, 0.85, 1.15, 11.7, 11.2, 32, (0.51, 0.76, 0.74, 0.99), smooth=False)
    add_cyl_segment(bm, uv_layer, 0.0, 0.75, 10.9, 10.9, 32, (0.51, 0.76, 0.74, 0.99), smooth=True)

    # Jet air mancur di sekeliling kolam
    for j_i in range(12):
        ang = (2.0 * math.pi * j_i) / 12.0
        jx = math.cos(ang) * 8.6
        jy = math.sin(ang) * 8.6
        # Buat kolom air mancur menyebar ke atas
        for s_i in range(6):
            a = (2.0 * math.pi * s_i) / 6
            v0 = bm.verts.new((jx + math.cos(a) * 0.12, jy + math.sin(a) * 0.12, 0.70))
            v1 = bm.verts.new((jx + math.cos(a) * 0.35, jy + math.sin(a) * 0.35, 5.20))
            v2 = bm.verts.new((jx + math.cos(a + 1.05) * 0.35, jy + math.sin(a + 1.05) * 0.35, 5.20))
            v3 = bm.verts.new((jx + math.cos(a + 1.05) * 0.12, jy + math.sin(a + 1.05) * 0.12, 0.70))
            f = bm.faces.new((v0, v1, v2, v3))
            f.smooth = True
            assign_uv_rect(bm, uv_layer, [f], 0.51, 0.76, 0.74, 0.99)

    # 2. Podium segi delapan & pilar tengah Tugu Keris Siginjai (Z: 0.75 to 14.5)
    add_cyl_segment(bm, uv_layer, 0.75, 2.20, 4.6, 3.8, 8, (0.76, 0.76, 0.99, 0.99), smooth=False)
    add_cyl_segment(bm, uv_layer, 2.20, 4.80, 3.2, 2.6, 8, (0.01, 0.76, 0.24, 0.99), smooth=False)
    add_cyl_segment(bm, uv_layer, 4.80, 14.20, 1.55, 1.35, 24, (0.01, 0.76, 0.24, 0.99), smooth=True)

    # 3. Mahkota / Kanopi Bundar Atas berhias motif & lampu neon (Z: 14.20 to 16.40)
    add_cyl_segment(bm, uv_layer, 14.20, 14.55, 1.35, 3.95, 28, (0.26, 0.76, 0.49, 0.99), smooth=True)
    add_cyl_segment(bm, uv_layer, 14.55, 16.10, 4.05, 4.05, 28, (0.26, 0.76, 0.49, 0.99), smooth=True)
    add_cyl_segment(bm, uv_layer, 16.10, 16.45, 3.95, 1.25, 28, (0.26, 0.76, 0.49, 0.99), smooth=True)

    # 4. Pedestal Emas & Keris Siginjai di puncak (Z: 16.45 to 22.8)
    add_cyl_segment(bm, uv_layer, 16.45, 17.85, 1.25, 1.45, 20, (0.01, 0.76, 0.24, 0.99), smooth=True)
    add_cyl_segment(bm, uv_layer, 17.85, 18.55, 0.85, 1.15, 16, (0.01, 0.76, 0.24, 0.99), smooth=True)
    add_keris_blade(bm, uv_layer, z_start=18.55, height=4.25, base_width=0.62, waves=7)

    # 5. untaian garis cahaya warna-warni (rainbow light strands) dari mahkota ke kolam
    rainbow_uvs = [
        (0.01, 0.51, 0.19, 0.74),
        (0.21, 0.51, 0.39, 0.74),
        (0.41, 0.51, 0.59, 0.74),
        (0.61, 0.51, 0.79, 0.74),
        (0.81, 0.51, 0.99, 0.74),
    ]
    n_strands = 20
    for idx in range(n_strands):
        a_top = (2.0 * math.pi * idx) / n_strands
        a_bot = a_top + (0.45 if idx % 2 == 0 else -0.45)
        p_top = Vector((math.cos(a_top) * 3.75, math.sin(a_top) * 3.75, 14.25))
        p_bot = Vector((math.cos(a_bot) * 10.6, math.sin(a_bot) * 10.6, 0.90))
        add_curved_light_strand(
            bm, uv_layer,
            p_top=p_top,
            p_bot=p_bot,
            mid_pull=1.18,
            radius=0.075,
            uv_rect=rainbow_uvs[idx % len(rainbow_uvs)],
        )

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    # 6. Tulisan 3D menyala "DOWNTOWN CITY" di bagian depan kolam (-Y di Blender -> -Z di Roblox)
    bpy.ops.object.text_add(location=(0.0, -11.85, 1.55), rotation=(math.radians(90.0), 0.0, 0.0))
    txt_obj = bpy.context.active_object
    txt_obj.data.body = "DOWNTOWN CITY"
    txt_obj.data.size = 1.65
    txt_obj.data.extrude = 0.22
    txt_obj.data.align_x = 'CENTER'
    txt_obj.data.align_y = 'CENTER'
    bpy.ops.object.convert(target='MESH')
    txt_mesh = bpy.context.active_object
    txt_mesh.name = "Sign_DOWNTOWN_CITY"
    for c in list(txt_mesh.users_collection):
        c.objects.unlink(txt_mesh)
    col.objects.link(txt_mesh)
    txt_mesh.data.materials.append(mat)

    # Map UVs of text mesh to Tile Row 2 [0..1, 0.25..0.50 in UV]
    tm = txt_mesh.data
    if not tm.uv_layers:
        tm.uv_layers.new(name="UVMap")
    tuv = tm.uv_layers.active.data
    xs = [v.co.x for v in tm.vertices]
    zs = [v.co.z for v in tm.vertices]
    min_x, max_x = min(xs), max(xs)
    min_z, max_z = min(zs), max(zs)
    dx = max(max_x - min_x, 1e-5)
    dz = max(max_z - min_z, 1e-5)
    for poly in tm.polygons:
        for li in poly.loop_indices:
            vco = tm.vertices[tm.loops[li].vertex_index].co
            u = 0.06 + ((vco.x - min_x) / dx) * 0.88
            v = 0.28 + ((vco.z - min_z) / dz) * 0.18
            tuv[li].uv = (u, v)

    # Join Tugu & Sign into single mesh for clean FBX export
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    txt_mesh.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    final_obj = bpy.context.active_object
    final_obj.name = asset_name

    fbx_out = os.path.join(tex_dir, f"{asset_name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_out,
        use_selection=True,
        object_types={'MESH'},
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        use_space_transform=True,
        bake_space_transform=True,
        axis_forward='-Z',
        axis_up='Y',
        mesh_smooth_type='FACE',
        path_mode='COPY',
        embed_textures=True,
    )
    print("Berhasil membuat & mengekspor FBX:", fbx_out)


if __name__ == "__main__":
    build_tugu_keris()
'''

with open(os.path.join(out_dir, "buat_tugu_keris_downtown_city.py"), "w", encoding="utf-8") as f:
    f.write(blender_script)

zip_name = "Downtown_City_Tugu_Keris_FBX_Pack.zip"
with zipfile.ZipFile(zip_name, "w", zipfile.ZIP_DEFLATED) as zf:
    for fname in sorted(os.listdir(out_dir)):
        zf.write(os.path.join(out_dir, fname), arcname=fname)

print("Generated ZIP:", zip_name, os.path.getsize(zip_name))