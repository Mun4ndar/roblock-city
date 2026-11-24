# ROBLOCK CITY: jembatan sungai (dijalankan lewat Blender MCP execute_blender_code).
# Skala 1 unit = 1 stud. X = sepanjang jalan, Y = melintang, Z = atas; z=0 adalah permukaan jalan.
# Variabel yang harus diset sebelum exec: JB_NAME ("raya" / "desa"), JB_L (panjang), JB_W (lebar jalan).
import bpy, bmesh, math
from mathutils import Vector, Matrix

NAME = "Jembatan_" + JB_NAME
L = float(JB_L)
W = float(JB_W)
E = 3.0  # lebar trotoar di tiap sisi
OUT = r"D:\ROBLOX STUDIO\assets\blender\jembatan_%s.fbx" % JB_NAME
BLEND = r"D:\ROBLOX STUDIO\assets\blender\roblock_jembatan.blend"

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


def cyl(m, cx, cy, z0, r, h, seg=12, r2=None):
    b = bm(m)
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
                                radius2=(r if r2 is None else r2), depth=h)
    bmesh.ops.translate(b, vec=(cx, cy, z0 + h / 2), verts=res["verts"])


def ball(m, cx, cy, cz, r, seg=10):
    b = bm(m)
    res = bmesh.ops.create_uvsphere(b, u_segments=seg, v_segments=8, radius=r)
    bmesh.ops.translate(b, vec=(cx, cy, cz), verts=res["verts"])


def pyramid(m, cx, cy, z0, w, h):
    b = bm(m)
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=4, radius1=w / math.sqrt(2), radius2=0.0, depth=h)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, z0 + h / 2), verts=res["verts"])


HALF = W / 2 + E  # setengah lebar total
BED = -2.4  # dasar sungai relatif permukaan jalan

# ---- dek ----
box("BjConcrete", 0, 0, -2.2, L, 2 * HALF, 1.8)  # bawah jalan (z -2.2..-0.4)
for s in (-1, 1):
    yc = s * (W / 2 + E / 2)
    box("BjWalk", 0, yc, -0.4, L, E, 0.4)  # trotoar rata dengan jalan (z -0.4..0)
    box("BjStone", 0, s * (W / 2 + 0.2), 0.0, L, 0.4, 0.28)  # bibir trotoar
    # kornis luar + dinding tepi
    box("BjStone", 0, s * (HALF + 0.2), -1.0, L + 0.4, 0.8, 1.0)
    box("BjWhite", 0, s * (HALF + 0.3), 0.0 - 0.12, L + 0.6, 0.9, 0.12)
    # kolom penopang (pilaster) sampai dasar sungai
    n = 7
    for i in range(n):
        x = -L / 2 + 2 + i * (L - 4) / (n - 1)
        box("BjConcrete", x, s * (HALF + 0.5), BED, 1.8, 0.8, -BED - 1.0)
        box("BjStone", x, s * (HALF + 0.55), -1.0, 2.3, 1.0, 0.3)
        # busur hias di antara pilaster
    for i in range(n - 1):
        x0 = -L / 2 + 2 + i * (L - 4) / (n - 1)
        x1 = -L / 2 + 2 + (i + 1) * (L - 4) / (n - 1)
        xm = (x0 + x1) / 2
        span = (x1 - x0) - 1.8
        b = bm("BjStone")
        # busur: segmen balok kecil mengikuti lengkung
        k = 7
        for j in range(k):
            t0 = math.pi * j / k
            t1 = math.pi * (j + 1) / k
            xa, za = xm + math.cos(t0) * span / 2, -1.0 + math.sin(t0) * 0.55
            xb, zb = xm + math.cos(t1) * span / 2, -1.0 + math.sin(t1) * 0.55
            seg = math.hypot(xb - xa, zb - za)
            ang = math.atan2(zb - za, xb - xa)
            r = bmesh.ops.create_cube(b, size=1.0)
            bmesh.ops.scale(b, vec=(seg + 0.05, 0.5, 0.22), verts=r["verts"])
            bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(-ang, 3, "Y"), verts=r["verts"])
            bmesh.ops.translate(b, vec=((xa + xb) / 2, s * (HALF + 0.5), (za + zb) / 2), verts=r["verts"])

# ---- pagar ----
py = HALF - 0.5  # sumbu pagar
for s in (-1, 1):
    box("BjStone", 0, s * py, 0.0, L, 0.9, 0.6)
    box("BjWhite", 0, s * py, 2.0, L, 0.7, 0.4)
    nb = int(L / 1.1)
    for i in range(nb):
        x = -L / 2 + 0.8 + i * (L - 1.6) / (nb - 1)
        cyl("BjWhite", x, s * py, 0.6, 0.2, 1.4, 8, 0.16)
    # tiang pagar + lampu
    npost = 7
    for i in range(npost):
        x = -L / 2 + 1.0 + i * (L - 2.0) / (npost - 1)
        end = i in (0, npost - 1)
        if end:  # tiang gerbang tinggi dengan lentera
            box("BjStone", x, s * py, -0.4, 2.6, 2.6, 7.4)
            box("BjWhite", x, s * py, 3.0, 3.0, 3.0, 0.35)
            box("BjGold", x, s * py, 5.6, 2.8, 2.8, 0.3)
            box("BjWhite", x, s * py, 7.0, 3.3, 3.3, 0.6)
            ball("BjLamp", x, s * py, 8.5, 0.85)
            box("BjStone", x, s * py, 7.6, 1.2, 1.2, 0.5)
            pyramid("BjWhite", x, s * py, 9.4, 3.0, 1.9)
            ball("BjGold", x, s * py, 11.5, 0.38)
            continue
        box("BjStone", x, s * py, 0.0, 1.4, 1.4, 3.1)
        box("BjWhite", x, s * py, 3.1, 1.8, 1.8, 0.3)
        if i % 2 == 1:
            cyl("BjDark", x, s * py, 3.4, 0.14, 4.6, 8, 0.1)
            box("BjDark", x, s * py, 8.0, 0.5, 0.5, 0.18)
            ball("BjLamp", x, s * py, 8.5, 0.5)
            cyl("BjDark", x, s * py, 9.0, 0.35, 0.3, 8, 0.05)

# ---- bangun objek ----
objs = []
for name, b in BM.items():
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    me = bpy.data.meshes.new(NAME + "_" + name)
    b.to_mesh(me)
    b.free()
    ob = bpy.data.objects.new(name, me)
    sc.collection.objects.link(ob)
    objs.append(ob)
mn = Vector((1e9, 1e9, 1e9))
mx = Vector((-1e9, -1e9, -1e9))
for ob in objs:
    for v in ob.data.vertices:
        mn = Vector(map(min, mn, v.co))
        mx = Vector(map(max, mx, v.co))
info = {"bbox_min": tuple(mn), "bbox_max": tuple(mx),
        "faces": {o.name: len(o.data.polygons) for o in objs}}
prev = bpy.context.window.scene
try:
    bpy.context.window.scene = sc
    bpy.ops.export_scene.fbx(filepath=OUT, use_selection=False, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL",
                             global_scale=1.0, bake_space_transform=False, add_leaf_bones=False)
finally:
    bpy.context.window.scene = prev
print(info)
