# Pembantu bersama untuk generator bangunan (exec dari skrip lain lewat Blender MCP).
# Skala 1 unit = 1 stud. Konvensi: depan = +Y, atas = +Z, tiap bahan = satu objek (jadi satu MeshPart).
import bpy, bmesh, math
from mathutils import Vector, Matrix

BM = {}
SC = None


def new_scene(name):
    global SC, BM
    old = bpy.data.scenes.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    SC = bpy.data.scenes.new(name)
    BM = {}
    return SC


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


def ball(m, cx, cy, cz, r, seg=12):
    b = bm(m)
    res = bmesh.ops.create_uvsphere(b, u_segments=seg, v_segments=8, radius=r)
    bmesh.ops.translate(b, vec=(cx, cy, cz), verts=res["verts"])


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


def vault(m, cx, cy, z0, w, d, h, seg=16):
    """tong setengah silinder (sumbu sepanjang Y): lebar w (X), panjang d (Y), tinggi h."""
    b = bm(m)
    pts = []
    for i in range(seg + 1):
        a = math.pi * i / seg
        pts.append((cx + math.cos(a) * w / 2, z0 + math.sin(a) * h))
    f, bk = [], []
    for (x, z) in pts:
        f.append(b.verts.new((x, cy + d / 2, z)))
        bk.append(b.verts.new((x, cy - d / 2, z)))
    for i in range(seg):
        b.faces.new([bk[i], bk[i + 1], f[i + 1], f[i]])
    b.faces.new([f[i] for i in range(seg + 1)])
    b.faces.new([bk[i] for i in reversed(range(seg + 1))])


def pyramid(m, cx, cy, z0, w, h):
    b = bm(m)
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=4, radius1=w / math.sqrt(2), radius2=0.0, depth=h)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, z0 + h / 2), verts=res["verts"])


def rrect(m, cx, cy, z0, w, d, h, r=6.0, seg=6):
    """prisma dengan alas persegi panjang bersudut bulat."""
    b = bm(m)
    pts = []
    cs = [(w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)]
    for (ox, oy, a0) in cs:
        for i in range(seg + 1):
            a = math.radians(a0 + 90.0 * i / seg)
            pts.append((cx + ox + math.cos(a) * r, cy + oy + math.sin(a) * r))
    lo = [b.verts.new((x, y, z0)) for (x, y) in pts]
    hi = [b.verts.new((x, y, z0 + h)) for (x, y) in pts]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        b.faces.new([lo[i], lo[j], hi[j], hi[i]])
    b.faces.new(list(reversed(lo)))
    b.faces.new(hi)


def export(out, blend=None):
    objs = []
    for name, b in BM.items():
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        me = bpy.data.meshes.new(SC.name + "_" + name)
        b.to_mesh(me)
        b.free()
        ob = bpy.data.objects.new(name, me)
        SC.collection.objects.link(ob)
        objs.append(ob)
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        for v in ob.data.vertices:
            mn = Vector(map(min, mn, v.co))
            mx = Vector(map(max, mx, v.co))
    info = {"bbox_min": tuple(round(c, 3) for c in mn), "bbox_max": tuple(round(c, 3) for c in mx),
            "center": tuple(round((a + b_) / 2, 3) for a, b_ in zip(mn, mx)),
            "faces": {o.name: len(o.data.polygons) for o in objs}}
    prev = bpy.context.window.scene
    try:
        bpy.context.window.scene = SC
        bpy.ops.export_scene.fbx(filepath=out, use_selection=False, object_types={"MESH"},
                                 axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL",
                                 global_scale=1.0, bake_space_transform=False, add_leaf_bones=False)
    finally:
        bpy.context.window.scene = prev
    if blend:
        try:
            bpy.data.libraries.write(blend, {SC}, fake_user=True)
        except Exception as e:
            info["blend_err"] = str(e)
    return info
