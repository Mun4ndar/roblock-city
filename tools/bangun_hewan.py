# Hewan berkerangka untuk ROBLOCK CITY. Dijalankan tanpa antarmuka:
#   blender -b -P tools/bangun_hewan.py -- <keluaran_dir> [id ...]
# Tiap hewan = beberapa objek bernama "<Sendi>__<Bahan>" (mis. LegFL__Body, LegFL__White).
# Titik asal objek = titik sendi, jadi di Roblox tiap sendi jadi Motor6D yang bisa digerakkan.
# 1 unit Blender = 1 stud. Hewan menghadap +Y (di Roblox jadi menghadap -Z).
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

PALET = {
    "kucing": dict(Body=(240, 150, 60), Light=(255, 243, 225), Pink=(250, 150, 170), Dark=(45, 38, 40), White=(255, 255, 255), Stripe=(205, 110, 35)),
    "anjing": dict(Body=(176, 124, 80), Light=(245, 225, 195), Pink=(240, 120, 140), Dark=(40, 32, 32), White=(255, 255, 255), Stripe=(110, 70, 42)),
    "kelinci": dict(Body=(248, 246, 242), Light=(240, 232, 225), Pink=(255, 170, 190), Dark=(45, 38, 45), White=(255, 255, 255), Stripe=(225, 215, 205)),
    "rubah": dict(Body=(228, 100, 45), Light=(252, 246, 236), Pink=(245, 150, 150), Dark=(50, 38, 36), White=(255, 255, 255), Stripe=(150, 60, 30)),
    "panda": dict(Body=(248, 248, 246), Light=(225, 225, 222), Pink=(255, 175, 190), Dark=(38, 38, 44), White=(255, 255, 255), Stripe=(60, 60, 66)),
}


def V(x, y, z):
    return Vector((x, y, z))


def loft(profile, seg=12):
    """profile: daftar (z, rx, ry) dari bawah ke atas; radius 0 = ujung runcing/bulat."""
    verts = []
    rings = []
    for z, rx, ry in profile:
        if rx < 1e-5 and ry < 1e-5:
            rings.append([len(verts)])
            verts.append(V(0, 0, z))
        else:
            ring = []
            for j in range(seg):
                a = 2 * math.pi * j / seg
                ring.append(len(verts))
                verts.append(V(rx * math.cos(a), ry * math.sin(a), z))
            rings.append(ring)
    faces = []
    for a_ring, b_ring in zip(rings, rings[1:]):
        if len(a_ring) == 1 and len(b_ring) == 1:
            continue
        for j in range(seg):
            k = (j + 1) % seg
            if len(a_ring) == 1:
                faces.append((a_ring[0], b_ring[k], b_ring[j]))
            elif len(b_ring) == 1:
                faces.append((a_ring[j], a_ring[k], b_ring[0]))
            else:
                faces.append((a_ring[j], a_ring[k], b_ring[k], b_ring[j]))
    return verts, faces


def ell_profile(rx, ry, rz, rings=8):
    out = []
    for i in range(rings + 1):
        a = -math.pi / 2 + math.pi * i / rings
        out.append((math.sin(a) * rz, math.cos(a) * rx, math.cos(a) * ry))
    return out


class Rig:
    def __init__(self, scale):
        self.scale = scale
        self.joints = {}  # nama -> pivot
        self.mats = {}  # (sendi, bahan) -> (verts, faces)

    def joint(self, name, pivot):
        self.joints[name] = Vector(pivot)

    def _add(self, joint, mat, verts, faces, center, rot):
        eul = Euler(rot, "XYZ")
        vs, fs = self.mats.setdefault((joint, mat), ([], []))
        base = len(vs)
        for v in verts:
            w = v.copy()
            w.rotate(eul)
            vs.append(w + Vector(center))
        for f in faces:
            fs.append(tuple(base + i for i in f))

    def ell(self, joint, mat, center, radii, rot=(0, 0, 0), seg=12, rings=8):
        v, f = loft(ell_profile(radii[0], radii[1], radii[2], rings), seg)
        self._add(joint, mat, v, f, center, rot)

    def tube(self, joint, mat, p0, p1, r0, r1, seg=10, flat=1.0):
        """Tabung meruncing dari p0 ke p1 dengan ujung membulat."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        length = d.length
        prof = []
        for a in (-90, -60, -30):
            r = math.radians(a)
            prof.append((r0 * math.sin(r), r0 * math.cos(r), r0 * math.cos(r) * flat))
        prof.append((0.0, r0, r0 * flat))
        prof.append((length * 0.5, (r0 + r1) / 2, (r0 + r1) / 2 * flat))
        prof.append((length, r1, r1 * flat))
        for a in (30, 60, 90):
            r = math.radians(a)
            prof.append((length + r1 * math.sin(r), r1 * math.cos(r), r1 * math.cos(r) * flat))
        v, f = loft(prof, seg)
        q = V(0, 0, 1).rotation_difference(d.normalized())
        vs = []
        for x in v:
            x = x.copy()
            x.rotate(q)
            vs.append(x)
        self._add(joint, mat, vs, f, p0, (0, 0, 0))

    def build(self, prefix, collection):
        objs = []
        for (joint, mat), (verts, faces) in self.mats.items():
            pivot = self.joints[joint]
            mesh = bpy.data.meshes.new(f"{prefix}_{joint}__{mat}")
            s = self.scale
            mesh.from_pydata([((v - pivot) * s)[:] for v in verts], [], faces)
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(mesh)
            bm.free()
            for poly in mesh.polygons:
                poly.use_smooth = True
            obj = bpy.data.objects.new(f"{joint}__{mat}", mesh)
            obj.location = pivot * s
            obj["bahan"] = mat
            collection.objects.link(obj)
            objs.append(obj)
        return objs


def face_point(c, r, az, el, push=0.0):
    p = V(
        r[0] * math.cos(el) * math.sin(az),
        r[1] * math.cos(el) * math.cos(az),
        r[2] * math.sin(el),
    )
    n = Vector((p.x / r[0] ** 2, p.y / r[1] ** 2, p.z / r[2] ** 2)).normalized()
    return Vector(c) + p + n * push


def eyes(rig, head, c, r, az=0.55, el=0.2, size=(0.14, 0.09, 0.19), shine=True):
    for sx in (-1, 1):
        p = face_point(c, r, az * sx, el, 0.0)
        rig.ell(head, "Dark", p, size, rot=(0, 0, -sx * 0.5))
        if shine:
            q = p + V(sx * -0.03, 0.07, 0.07)
            rig.ell(head, "White", q, (size[0] * 0.36, size[1] * 0.6, size[2] * 0.36))


def body_top(c, r, y):
    t = max(0.0, 1 - (y / r[1]) ** 2)
    return c[2] + r[2] * math.sqrt(t)


# ------------------------------------------------------------------ spesies


def kucing():
    rig = Rig(0.95)
    bc, br = (0, 0, 1.6), (0.85, 1.25, 0.8)
    rig.joint("Body", bc)
    rig.ell("Body", "Body", bc, br)
    rig.ell("Body", "Light", (0, 0.95, 1.55), (0.45, 0.5, 0.58))
    for y in (-0.7, -0.15, 0.4):
        rig.ell("Body", "Stripe", (0, y, body_top(bc, br, y) - 0.03), (0.32, 0.09, 0.1))
    hc, hr = (0, 1.5, 2.3), (0.88, 0.74, 0.72)
    rig.joint("Head", (0, 1.0, 2.0))
    rig.ell("Head", "Body", hc, hr)
    rig.ell("Head", "Stripe", (0, 1.55, 3.0), (0.07, 0.22, 0.05))
    rig.ell("Head", "Light", (0, 2.06, 2.12), (0.4, 0.3, 0.28))
    rig.ell("Head", "Pink", (0, 2.34, 2.2), (0.13, 0.09, 0.1))
    eyes(rig, "Head", hc, hr)
    for sx in (-1, 1):
        n = "EarL" if sx < 0 else "EarR"
        base = V(sx * 0.5, 1.35, 2.8)
        rig.joint(n, base)
        d = V(sx * 0.3, -0.05, 1).normalized()
        rig.tube(n, "Body", base, base + d * 0.6, 0.3, 0.05)
        rig.tube(n, "Pink", base + V(0, 0.16, 0.05), base + d * 0.5 + V(0, 0.1, 0), 0.17, 0.03)
    legs = [("LegFL", -1, 0.75), ("LegFR", 1, 0.75), ("LegBL", -1, -0.8), ("LegBR", 1, -0.8)]
    for name, sx, y in legs:
        hip = V(sx * 0.5, y, 1.15)
        rig.joint(name, hip)
        rig.ell(name, "Body", hip + V(0, 0, -0.5), (0.28, 0.3, 0.58))
        rig.ell(name, "White", hip + V(0, 0.05, -0.95), (0.3, 0.38, 0.21))
    rig.joint("Tail", (0, -1.1, 1.95))
    rig.tube("Tail", "Body", V(0, -1.1, 1.95), V(0, -1.62, 2.45), 0.21, 0.18)
    rig.joint("TailB", (0, -1.62, 2.45))
    rig.tube("TailB", "Body", V(0, -1.62, 2.45), V(0, -1.85, 3.05), 0.18, 0.15)
    rig.ell("TailB", "Light", (0, -1.87, 3.15), (0.17, 0.17, 0.2))
    return rig


def anjing():
    rig = Rig(1.0)
    bc, br = (0, 0, 1.7), (0.95, 1.35, 0.85)
    rig.joint("Body", bc)
    rig.ell("Body", "Body", bc, br)
    rig.ell("Body", "Light", (0, 1.0, 1.6), (0.5, 0.55, 0.62))
    rig.ell("Body", "Stripe", (0, -0.15, body_top(bc, br, -0.15) - 0.34), (0.82, 0.95, 0.5))
    hc, hr = (0, 1.65, 2.45), (0.85, 0.7, 0.7)
    rig.joint("Head", (0, 1.1, 2.15))
    rig.ell("Head", "Body", hc, hr)
    rig.ell("Head", "Light", (0, 2.2, 2.25), (0.42, 0.5, 0.34))
    rig.ell("Head", "Dark", (0, 2.66, 2.38), (0.21, 0.13, 0.15))
    rig.ell("Head", "Pink", (0, 2.5, 1.98), (0.15, 0.2, 0.06))
    eyes(rig, "Head", hc, hr, az=0.5, el=0.25, size=(0.13, 0.09, 0.17))
    for sx in (-1, 1):
        n = "EarL" if sx < 0 else "EarR"
        base = V(sx * 0.72, 1.55, 2.95)
        rig.joint(n, base)
        rig.ell(n, "Stripe", base + V(sx * 0.12, -0.05, -0.42), (0.17, 0.34, 0.52), rot=(0, sx * 0.25, 0))
    for name, sx, y in [("LegFL", -1, 0.85), ("LegFR", 1, 0.85), ("LegBL", -1, -0.85), ("LegBR", 1, -0.85)]:
        hip = V(sx * 0.58, y, 1.25)
        rig.joint(name, hip)
        rig.ell(name, "Body", hip + V(0, 0, -0.55), (0.3, 0.33, 0.62))
        rig.ell(name, "Light", hip + V(0, 0.06, -1.03), (0.34, 0.42, 0.22))
    rig.joint("Tail", (0, -1.3, 2.1))
    rig.tube("Tail", "Body", V(0, -1.3, 2.1), V(0, -1.85, 2.85), 0.2, 0.13)
    rig.ell("Tail", "Stripe", (0, -1.87, 2.92), (0.15, 0.15, 0.18))
    return rig


def kelinci():
    rig = Rig(1.0)
    bc, br = (0, 0, 1.4), (0.8, 1.0, 0.8)
    rig.joint("Body", bc)
    rig.ell("Body", "Body", bc, br)
    rig.ell("Body", "Light", (0, 0.65, 1.2), (0.5, 0.5, 0.6))
    hc, hr = (0, 1.15, 2.25), (0.75, 0.65, 0.65)
    rig.joint("Head", (0, 0.75, 1.95))
    rig.ell("Head", "Body", hc, hr)
    for sx in (-1, 1):
        rig.ell("Head", "Light", (sx * 0.32, 1.6, 2.02), (0.3, 0.26, 0.26))
        rig.ell("Head", "Pink", (sx * 0.5, 1.5, 2.0), (0.1, 0.05, 0.08))
    rig.ell("Head", "Pink", (0, 1.8, 2.18), (0.11, 0.08, 0.09))
    eyes(rig, "Head", hc, hr, az=0.6, el=0.25, size=(0.13, 0.09, 0.18))
    for sx in (-1, 1):
        n = "EarL" if sx < 0 else "EarR"
        base = V(sx * 0.32, 1.0, 2.75)
        rig.joint(n, base)
        d = V(sx * 0.12, -0.22, 1).normalized()
        rig.tube(n, "Body", base, base + d * 1.15, 0.22, 0.2)
        rig.tube(n, "Pink", base + V(0, 0.14, 0.05), base + d * 1.0 + V(0, 0.11, 0), 0.12, 0.1)
    for name, sx in [("LegFL", -1), ("LegFR", 1)]:
        hip = V(sx * 0.4, 0.5, 0.95)
        rig.joint(name, hip)
        rig.ell(name, "Body", hip + V(0, 0, -0.4), (0.21, 0.23, 0.46))
        rig.ell(name, "Light", hip + V(0, 0.06, -0.78), (0.23, 0.3, 0.17))
    for name, sx in [("LegBL", -1), ("LegBR", 1)]:
        hip = V(sx * 0.62, -0.5, 1.15)
        rig.joint(name, hip)
        rig.ell(name, "Body", hip + V(0, 0, -0.15), (0.38, 0.62, 0.52))
        rig.ell(name, "Light", hip + V(0, 0.28, -0.93), (0.25, 0.58, 0.18))
    rig.joint("Tail", (0, -0.95, 1.45))
    rig.ell("Tail", "Light", (0, -1.2, 1.5), (0.32, 0.32, 0.32))
    return rig


def rubah():
    rig = Rig(1.0)
    bc, br = (0, 0, 1.6), (0.72, 1.35, 0.7)
    rig.joint("Body", bc)
    rig.ell("Body", "Body", bc, br)
    rig.ell("Body", "Light", (0, 1.0, 1.5), (0.5, 0.5, 0.55))
    hc, hr = (0, 1.5, 2.3), (0.8, 0.6, 0.62)
    rig.joint("Head", (0, 1.1, 2.1))
    rig.ell("Head", "Body", hc, hr)
    for sx in (-1, 1):
        rig.ell("Head", "Light", (sx * 0.42, 1.68, 2.1), (0.4, 0.4, 0.3), rot=(0, 0, sx * 0.3))
    rig.tube("Head", "Body", V(0, 1.75, 2.22), V(0, 2.4, 2.15), 0.3, 0.13)
    rig.ell("Head", "Dark", (0, 2.58, 2.15), (0.13, 0.1, 0.1))
    eyes(rig, "Head", hc, hr, az=0.55, el=0.3, size=(0.12, 0.08, 0.16))
    for sx in (-1, 1):
        n = "EarL" if sx < 0 else "EarR"
        base = V(sx * 0.5, 1.4, 2.78)
        rig.joint(n, base)
        d = V(sx * 0.25, -0.1, 1).normalized()
        rig.tube(n, "Stripe", base, base + d * 0.85, 0.32, 0.05)
        rig.tube(n, "Light", base + V(0, 0.15, 0.05), base + d * 0.7 + V(0, 0.1, 0), 0.18, 0.03)
    for name, sx, y in [("LegFL", -1, 0.8), ("LegFR", 1, 0.8), ("LegBL", -1, -0.85), ("LegBR", 1, -0.85)]:
        hip = V(sx * 0.46, y, 1.2)
        rig.joint(name, hip)
        rig.ell(name, "Body", hip + V(0, 0, -0.5), (0.23, 0.26, 0.58))
        rig.ell(name, "Dark", hip + V(0, 0.03, -0.9), (0.24, 0.3, 0.32))
        rig.ell(name, "Dark", hip + V(0, 0.07, -1.05), (0.26, 0.34, 0.18))
    rig.joint("Tail", (0, -1.2, 1.8))
    rig.ell("Tail", "Body", (0, -2.0, 1.95), (0.45, 0.95, 0.42), rot=(-0.25, 0, 0))
    rig.ell("Tail", "Light", (0, -2.8, 2.18), (0.36, 0.5, 0.34), rot=(-0.25, 0, 0))
    return rig


def panda():
    rig = Rig(0.92)
    bc, br = (0, 0, 1.75), (1.15, 1.15, 1.05)
    rig.joint("Body", bc)
    rig.ell("Body", "Body", bc, br)
    rig.ell("Body", "Dark", (0, 0.55, 1.6), (1.18, 0.34, 0.7))
    hc, hr = (0, 1.1, 2.95), (1.0, 0.88, 0.85)
    rig.joint("Head", (0, 0.85, 2.55))
    rig.ell("Head", "Body", hc, hr)
    rig.ell("Head", "Light", (0, 1.75, 2.75), (0.42, 0.3, 0.32))
    rig.ell("Head", "Dark", (0, 2.0, 2.9), (0.17, 0.1, 0.12))
    for sx in (-1, 1):
        p = face_point(hc, hr, sx * 0.5, 0.12, 0.0)
        rig.ell("Head", "Dark", p, (0.3, 0.14, 0.38), rot=(0, 0, -sx * 0.45))
        rig.ell("Head", "White", p + V(sx * -0.02, 0.1, 0.05), (0.07, 0.04, 0.09))
        rig.ell("Head", "Pink", (sx * 0.78, 1.6, 2.68), (0.15, 0.06, 0.1))
    for sx in (-1, 1):
        n = "EarL" if sx < 0 else "EarR"
        base = V(sx * 0.75, 1.0, 3.62)
        rig.joint(n, base)
        rig.ell(n, "Dark", base + V(0, 0, 0.1), (0.36, 0.28, 0.36))
    for name, sx, y in [("LegFL", -1, 0.7), ("LegFR", 1, 0.7), ("LegBL", -1, -0.7), ("LegBR", 1, -0.7)]:
        hip = V(sx * 0.82, y, 1.3)
        rig.joint(name, hip)
        rig.ell(name, "Dark", hip + V(0, 0, -0.6), (0.4, 0.42, 0.72))
        rig.ell(name, "Dark", hip + V(0, 0.05, -1.08), (0.43, 0.5, 0.24))
    rig.joint("Tail", (0, -1.05, 1.6))
    rig.ell("Tail", "Body", (0, -1.3, 1.65), (0.3, 0.3, 0.3))
    return rig


SPESIES = {"kucing": kucing, "anjing": anjing, "kelinci": kelinci, "rubah": rubah, "panda": panda}


def material(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    c = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            n.inputs["Base Color"].default_value = c
    m.diffuse_color = c
    return m


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else os.getcwd()
    ids = argv[1:] or list(SPESIES.keys())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    col = bpy.data.collections.new("Hewan")
    scene.collection.children.link(col)
    for idx, sid in enumerate(ids):
        rig = SPESIES[sid]()
        objs = rig.build(sid, col)
        pal = PALET[sid]
        mats = {k: material(f"{sid}_{k}", v) for k, v in pal.items()}
        for o in objs:
            o.data.materials.append(mats[o["bahan"]])
        for o in objs:
            o.select_set(False)
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        fbx = os.path.join(out, f"hewan2_{sid}.fbx")
        bpy.ops.export_scene.fbx(
            filepath=fbx,
            use_selection=True,
            axis_forward="-Z",
            axis_up="Y",
            apply_scale_options="FBX_SCALE_ALL",
            object_types={"MESH"},
            mesh_smooth_type="FACE",
            add_leaf_bones=False,
            bake_anim=False,
        )
        print("FBX", fbx, len(objs), "objek")
        # tampilkan hewan berikutnya di sebelahnya untuk pratinjau
        for o in objs:
            o.location.x += idx * 7
            o.name = f"{sid}_{o.name}"
    # pratinjau
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    n = len(ids)
    cam.location = (n * 3.5 - 3.5 + 6, 22, 9)
    direction = Vector((n * 3.5 - 3.5, 0, 1.6)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 45 if n == 1 else 30
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x = 1600 if n > 1 else 900
    scene.render.resolution_y = 700
    scene.render.filepath = os.path.join(out, "pratinjau_hewan.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "roblock_hewan2.blend"))


main()
