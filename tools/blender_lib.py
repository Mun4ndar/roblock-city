# Pustaka kecil untuk membuat model bandara di Blender (dipakai lewat exec dari execute_blender_code).
# Satu objek per bahan; nama objek = nama bahan (jadi nama MeshPart di Roblox). 1 unit Blender = 1 stud.
import math
import bpy
import bmesh


class Maker:
    def __init__(self):
        self.mats = {}  # nama -> (verts, faces)

    def _m(self, name):
        return self.mats.setdefault(name, ([], []))

    def solid(self, name, verts, faces, fix=True):
        v, f = self._m(name)
        base = len(v)
        v.extend(verts)
        for face in faces:
            f.append(tuple(base + i for i in face))
        if fix:
            self._fix = True

    def surface2(self, name, verts, faces):
        """Permukaan terbuka dua sisi (tambahkan sisi sebaliknya)."""
        both = list(faces) + [tuple(reversed(f)) for f in faces]
        self.solid(name, verts, both, fix=False)

    def box(self, name, cx, cy, cz, sx, sy, sz):
        x0, x1 = cx - sx / 2, cx + sx / 2
        y0, y1 = cy - sy / 2, cy + sy / 2
        z0, z1 = cz - sz / 2, cz + sz / 2
        v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.solid(name, v, f)

    def cyl(self, name, c, r, length, axis="z", segs=16, r2=None):
        """Silinder (atau kerucut terpancung bila r2) dengan pusat c sepanjang sumbu axis."""
        r2 = r if r2 is None else r2
        v = []
        for end, rad in ((-0.5, r), (0.5, r2)):
            for k in range(segs):
                a = 2 * math.pi * k / segs
                p = (rad * math.cos(a), rad * math.sin(a), end * length)
                if axis == "z":
                    q = p
                elif axis == "y":
                    q = (p[0], p[2], p[1])
                else:
                    q = (p[2], p[0], p[1])
                v.append((c[0] + q[0], c[1] + q[1], c[2] + q[2]))
        f = []
        for k in range(segs):
            k2 = (k + 1) % segs
            f.append((k, k2, segs + k2, segs + k))
        f.append(tuple(reversed(range(segs))))
        f.append(tuple(range(segs, 2 * segs)))
        self.solid(name, v, f)

    def rings(self, name, rings, cap_first=True, cap_last=True):
        """Permukaan dari deretan cincin titik (jumlah titik sama)."""
        n = len(rings[0])
        v = [p for ring in rings for p in ring]
        f = []
        for i in range(len(rings) - 1):
            for k in range(n):
                k2 = (k + 1) % n
                f.append((i * n + k, i * n + k2, (i + 1) * n + k2, (i + 1) * n + k))
        if cap_first:
            f.append(tuple(reversed(range(n))))
        if cap_last:
            o = (len(rings) - 1) * n
            f.append(tuple(range(o, o + n)))
        self.solid(name, v, f)

    def prism(self, name, pts, axis, a0, a1):
        """Poligon cembung pts (2D) diekstrusi sepanjang axis dari a0 ke a1.
        axis 'x': pts=(y,z); axis 'z': pts=(x,y)."""
        n = len(pts)

        def to3(p, a):
            if axis == "x":
                return (a, p[0], p[1])
            if axis == "z":
                return (p[0], p[1], a)
            return (p[0], a, p[1])

        v = [to3(p, a0) for p in pts] + [to3(p, a1) for p in pts]
        f = [tuple(range(n)), tuple(range(n, 2 * n))]
        for k in range(n):
            k2 = (k + 1) % n
            f.append((k, k2, n + k2, n + k))
        self.solid(name, v, f)

    def hexa(self, name, quad, z, thk):
        """Sayap: 4 titik (x,y) dengan tinggi dasar z[i] dan tebal thk[i]."""
        v = [(p[0], p[1], z[i]) for i, p in enumerate(quad)] + [
            (p[0], p[1], z[i] + thk[i]) for i, p in enumerate(quad)
        ]
        f = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.solid(name, v, f)

    def build(self, prefix=""):
        objs = []
        for name, (v, f) in self.mats.items():
            me = bpy.data.meshes.new(prefix + name)
            bm = bmesh.new()
            bv = [bm.verts.new(p) for p in v]
            for face in f:
                try:
                    bm.faces.new([bv[i] for i in face])
                except ValueError:
                    pass
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
            bm.normal_update()
            # sisi luar: solid tertutup dibuat ulang arahnya (permukaan dua sisi aman)
            if not name.endswith("2S"):
                bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new(prefix + name, me)
            mat = bpy.data.materials.get(prefix + name) or bpy.data.materials.new(prefix + name)
            ob.data.materials.append(mat)
            bpy.context.collection.objects.link(ob)
            objs.append(ob)
        return objs


def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        bake_space_transform=False,
    )
    tris = {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in objs}
    return tris
