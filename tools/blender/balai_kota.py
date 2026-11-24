# ROBLOCK CITY: Balai Kota mewah (dijalankan lewat Blender MCP execute_blender_code).
# Skala 1 unit = 1 stud. Depan bangunan = +Y Blender (jadi -Z di Roblox). Simetris terhadap sumbu X.
import bpy, bmesh, math
from mathutils import Vector, Matrix

NAME = "BalaiKota"
OUT = r"D:\ROBLOX STUDIO\assets\blender\balai_kota.fbx"
BLEND = r"D:\ROBLOX STUDIO\assets\blender\roblock_balai_kota.blend"

old = bpy.data.scenes.get(NAME)
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
sc = bpy.data.scenes.new(NAME)

BM = {}


def bm(name):
    if name not in BM:
        BM[name] = bmesh.new()
    return BM[name]


def box(m, cx, cy, z0, sx, sy, sz):
    b = bm(m)
    r = bmesh.ops.create_cube(b, size=1.0)
    bmesh.ops.scale(b, vec=(sx, sy, sz), verts=r["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, z0 + sz / 2), verts=r["verts"])


def cyl(m, cx, cy, z0, r, h, seg=24, r2=None):
    b = bm(m)
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
                                radius2=(r if r2 is None else r2), depth=h)
    bmesh.ops.translate(b, vec=(cx, cy, z0 + h / 2), verts=res["verts"])


def dome(m, cx, cy, z0, r, hz=None, seg=28):
    b = bm(m)
    res = bmesh.ops.create_uvsphere(b, u_segments=seg, v_segments=14, radius=r)
    verts = res["verts"]
    kill = [v for v in verts if v.co.z < -1e-4]
    bmesh.ops.delete(b, geom=kill, context="VERTS")
    keep = [v for v in verts if v.is_valid]
    k = (hz / r) if hz else 1.0
    for v in keep:
        v.co.z *= k
    bmesh.ops.translate(b, vec=(cx, cy, z0), verts=keep)


def prism_tri(m, cx, cy0, cy1, z0, w, h):
    # frontispis segitiga: alas lebar w di z0, puncak z0+h, kedalaman y0..y1
    b = bm(m)
    pts = [(-w / 2, cy0, z0), (w / 2, cy0, z0), (0, cy0, z0 + h),
           (-w / 2, cy1, z0), (w / 2, cy1, z0), (0, cy1, z0 + h)]
    vs = [b.verts.new((cx + p[0], p[1], p[2])) for p in pts]
    for f in ([0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]):
        b.faces.new([vs[i] for i in f])


def window(cx, y, z0, w, h, face="front", frame=True):
    """jendela: bingkai batu + kaca + sekat. face: front (+Y), back (-Y), left (-X), right (+X)"""
    d = 0.35
    if face in ("front", "back"):
        s = 1 if face == "front" else -1
        if frame:
            box("BkStone", cx, y + s * 0.08, z0 - 0.4, w + 1.0, d, h + 0.8)
        box("BkGlass", cx, y + s * 0.2, z0, w, d, h)
        box("BkWhite", cx, y + s * 0.3, z0, 0.22, d, h)
        box("BkWhite", cx, y + s * 0.3, z0 + h / 2, w, d, 0.22)
    else:
        s = 1 if face == "right" else -1
        if frame:
            box("BkStone", cx + s * 0.08, y, z0 - 0.4, d, w + 1.0, h + 0.8)
        box("BkGlass", cx + s * 0.2, y, z0, d, w, h)
        box("BkWhite", cx + s * 0.3, y, z0, d, 0.22, h)
        box("BkWhite", cx + s * 0.3, y, z0 + h / 2, d, w, 0.22)


# ---------------- alas, tangga ----------------
box("BkStone", 0, -0.5, 0, 78, 29, 1.0)  # alas utama x +-39, y -15..14
for i in range(4):  # tangga lebar (tinggi 1.0 total, empat anak tangga)
    box("BkStone", 0, 14.4 + i * 2.0, 0, 34, 2.0, 1.0 - i * 0.25)
box("BkStone", 0, 11.8, 1.0, 42, 5, 0.3)  # lantai beranda

# ---------------- badan utama ----------------
box("BkWall", 0, -2, 1.2, 44, 24, 22.8)  # y -14..10, z 1.2..24
box("BkStone", 0, -2, 1.2, 45, 25, 2.2)
box("BkStone", 0, -2, 11.5, 44.6, 24.6, 0.5)
box("BkStone", 0, -2, 23.0, 46.6, 26.6, 1.0)
box("BkGold", 0, -2, 24.0, 47.0, 27.0, 0.35)
box("BkRoof", 0, -2, 24.35, 40, 22, 0.6)

for s in (-1, 1):  # sayap
    cx = s * 30
    box("BkWall", cx, -2, 1.2, 16, 20, 14.8)  # y -12..8, z 1.2..16
    box("BkStone", cx, -2, 1.2, 16.6, 20.6, 2.0)
    box("BkStone", cx, -2, 8.5, 16.4, 20.4, 0.4)
    box("BkStone", cx, -2, 15.2, 17.6, 21.6, 1.0)
    box("BkGold", cx, -2, 16.2, 18.0, 22.0, 0.3)
    box("BkRoof", cx, -2, 16.5, 14.5, 18.5, 0.5)
    tx = s * 38.5  # menara sudut berkubah
    cyl("BkWall", tx, 6, 1.2, 3.4, 18.5, 20)
    cyl("BkStone", tx, 6, 1.2, 3.8, 1.8, 20)
    cyl("BkStone", tx, 6, 17.0, 3.9, 1.0, 20)
    cyl("BkGold", tx, 6, 18.0, 4.0, 0.3, 20)
    dome("BkDome", tx, 6, 18.3, 3.6, 4.5, 20)
    cyl("BkGold", tx, 6, 22.7, 0.25, 3.0, 8, 0.05)
    box("BkGold", tx, 6, 25.6, 0.7, 0.7, 0.7)
    for zz in (6, 11.5):
        window(tx, 6 + 3.35, zz, 2.2, 3.4, "front", False)
    for zz in (3.4, 10.0):
        hh = 4.2 if zz < 6 else 3.6
        for dx in (-5, 0, 5):
            window(cx + dx, 8.0, zz, 2.8, hh, "front")
            window(cx + dx, -12.0, zz, 2.8, hh, "back")
        for dy in (-8, -2, 4):
            window(s * 38.0 - s * 0.0, dy, zz, 2.8, hh, "right" if s > 0 else "left")
    for dx in (-8.2, -2.5, 2.5, 8.2):
        box("BkWhite", cx + dx, 8.2, 1.2, 1.0, 0.6, 14.0)

# ---------------- beranda berpilar + frontispis ----------------
xs = [(-17.5 + i * 5.0) for i in range(8)]
for x in xs:
    cyl("BkColumn", x, 12.5, 1.3, 1.25, 1.0, 20)
    cyl("BkColumn", x, 12.5, 2.3, 1.05, 17.5, 20)
    cyl("BkColumn", x, 12.5, 19.8, 1.35, 0.8, 20)
    box("BkStone", x, 12.5, 20.6, 2.9, 2.9, 0.5)
box("BkStone", 0, 12.0, 21.1, 44, 6.4, 1.4)
box("BkWhite", 0, 12.0, 22.5, 45, 6.8, 1.0)
box("BkGold", 0, 12.0, 23.5, 45.4, 7.0, 0.3)
prism_tri("BkWall", 0, 8.6, 15.4, 23.8, 45.4, 8.5)
prism_tri("BkGold", 0, 15.4, 15.7, 25.0, 20.0, 3.5)
b = bm("BkGold")  # lambang: cakram emas di muka frontispis
res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=28, radius1=2.3, radius2=2.3, depth=0.4)
bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
bmesh.ops.translate(b, vec=(0, 16.0, 27.0), verts=res["verts"])
box("BkStone", 0, 10.15, 1.2, 8.4, 0.5, 11.2)  # pintu utama
box("BkDark", 0, 10.4, 1.2, 7.0, 0.4, 9.6)
box("BkGold", 0, 10.6, 1.2, 0.25, 0.3, 9.6)
box("BkGlass", -1.75, 10.6, 2.0, 2.9, 0.3, 7.6)
box("BkGlass", 1.75, 10.6, 2.0, 2.9, 0.3, 7.6)
box("BkGold", 0, 10.5, 11.3, 7.0, 0.4, 0.6)
for dx in (-12.5, -7.5, 7.5, 12.5):
    window(dx, 10.0, 3.5, 3.0, 8.0, "front")
for dx in (-12.5, -7.5, -4.5, 4.5, 7.5, 12.5):
    window(dx, 10.0, 14.5, 3.0, 5.5, "front")
for dx in (-12, -6, 0, 6, 12):
    window(dx, -14.0, 3.5, 3.0, 8.0, "back")
    window(dx, -14.0, 14.5, 3.0, 5.5, "back")
for dy in (-8, -2, 4):
    window(22.0, dy, 14.5, 2.8, 5.5, "right")
    window(-22.0, dy, 14.5, 2.8, 5.5, "left")

# ---------------- kubah tengah ----------------
cyl("BkWall", 0, -2, 24.35, 10.5, 6.5, 32)
cyl("BkStone", 0, -2, 24.35, 11.4, 1.0, 32)
cyl("BkStone", 0, -2, 30.0, 11.2, 0.9, 32)
cyl("BkGold", 0, -2, 30.9, 11.4, 0.3, 32)
for i in range(12):
    a = i * math.pi * 2 / 12
    cyl("BkColumn", math.cos(a) * 10.6, -2 + math.sin(a) * 10.6, 25.3, 0.5, 4.8, 8)
    a2 = a + math.pi / 12
    c = bm("BkGlass")
    res = bmesh.ops.create_cube(c, size=1.0)
    bmesh.ops.scale(c, vec=(0.6, 2.2, 3.4), verts=res["verts"])
    bmesh.ops.rotate(c, cent=(0, 0, 0), matrix=Matrix.Rotation(a2, 3, "Z"), verts=res["verts"])
    bmesh.ops.translate(c, vec=(math.cos(a2) * 10.52, -2 + math.sin(a2) * 10.52, 27.4), verts=res["verts"])
dome("BkDome", 0, -2, 31.2, 10.3, 9.5, 32)
for i in range(8):  # rusuk emas kubah
    a = i * math.pi * 2 / 8
    for j in range(9):
        t = (j + 0.5) / 9 * (math.pi / 2) * 0.96
        rr = 10.3 * math.cos(t) + 0.12
        zz = 31.2 + 9.5 * math.sin(t)
        box("BkGold", math.cos(a) * rr, -2 + math.sin(a) * rr, zz, 0.45, 0.45, 0.9)
cyl("BkGold", 0, -2, 40.5, 2.3, 0.6, 24)
cyl("BkWall", 0, -2, 41.1, 1.9, 2.8, 16)
for k in range(6):
    a = k * math.pi * 2 / 6
    box("BkGlass", math.cos(a) * 1.85, -2 + math.sin(a) * 1.85, 41.6, 0.4, 0.4, 1.9)
dome("BkGold", 0, -2, 43.9, 2.0, 2.6, 16)
cyl("BkGold", 0, -2, 46.4, 0.35, 5.0, 8, 0.05)
box("BkGold", 0, -2, 51.0, 0.5, 0.5, 0.5)

# ---------------- tiang bendera + taman ----------------
for fx in (-24, 24):
    cyl("BkColumn", fx, 20.5, 0.0, 0.35, 16.0, 10)
    cyl("BkGold", fx, 20.5, 16.0, 0.5, 0.5, 10)
    box("BkFlag1" if fx < 0 else "BkFlag2", fx + 2.0, 20.5, 11.8, 3.6, 0.15, 2.4)
    cyl("BkStone", fx, 20.5, 0.0, 1.0, 0.6, 12)
for hx in (-30, 30):  # pagar tanaman depan sayap
    box("BkStone", hx, 12.0, 1.0, 14.0, 2.0, 0.7)
    for k in range(7):
        r = bm("BkHedge")
        res = bmesh.ops.create_uvsphere(r, u_segments=12, v_segments=8, radius=1.0)
        bmesh.ops.scale(r, vec=(1.0, 0.9, 0.85), verts=res["verts"])
        bmesh.ops.translate(r, vec=(hx - 6 + k * 2.0, 12.0, 1.8), verts=res["verts"])
for lx in (-18.5, 18.5):  # lampu taman emas di samping tangga
    cyl("BkGold", lx, 23.0, 0.0, 0.2, 6.0, 8)
    dome("BkGlass", lx, 23.0, 6.0, 0.75, 0.9, 10)

# ---------------- bangun objek ----------------
objs = []
for name, b in BM.items():
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    me = bpy.data.meshes.new(name)
    b.to_mesh(me)
    b.free()
    ob = bpy.data.objects.new(name, me)
    sc.collection.objects.link(ob)
    objs.append(ob)
mn = Vector((1e9, 1e9, 1e9))
mx = Vector((-1e9, -1e9, -1e9))
faces = 0
for ob in objs:
    faces += len(ob.data.polygons)
    for v in ob.data.vertices:
        mn = Vector(map(min, mn, v.co))
        mx = Vector(map(max, mx, v.co))
info = {"bbox_min": tuple(mn), "bbox_max": tuple(mx), "faces": faces,
        "per": {o.name: len(o.data.polygons) for o in objs}}

prev = bpy.context.window.scene
try:
    bpy.context.window.scene = sc
    bpy.ops.export_scene.fbx(filepath=OUT, use_selection=False, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL",
                             global_scale=1.0, bake_space_transform=False, add_leaf_bones=False)
finally:
    bpy.context.window.scene = prev
try:
    bpy.data.libraries.write(BLEND, {sc}, fake_user=True)
except Exception as e:
    info["blend_err"] = str(e)
print(info)
