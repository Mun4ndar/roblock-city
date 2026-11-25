"""Pustaka kecil untuk membuat kapal low-poly di Blender (1 unit = 1 stud).
Satu objek per bahan (nama bahan = nama objek, warnanya dipasang di Studio).
Haluan di -Y (menjadi -Z di Roblox), atas = +Z, garis air = z 0."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

COL = None


def collection():
    global COL
    COL = bpy.data.collections.get("ROBLOCK_Kapal") or bpy.data.collections.new("ROBLOCK_Kapal")
    if COL.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(COL)
    return COL


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    return m


class Boat:
    def __init__(self, name, colors):
        self.name = name
        self.colors = colors  # bahan -> rgb 0..1
        self.m = {}

    def bm(self, mat_name):
        return self.m.setdefault(mat_name, bmesh.new())

    # ---------- primitif
    def box(self, mat_name, loc, size, rot=(0, 0, 0)):
        bm = self.bm(mat_name)
        r = bmesh.ops.create_cube(bm, size=1.0)
        M = (
            Matrix.Translation(loc)
            @ Euler(rot).to_matrix().to_4x4()
            @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        )
        bmesh.ops.transform(bm, matrix=M, verts=r["verts"])

    def cyl(self, mat_name, loc, radius, length, axis="Z", seg=12, radius2=None, rot=None):
        """Silinder/kerucut; sumbu = axis ('X','Y','Z'); loc = tengah."""
        bm = self.bm(mat_name)
        r = bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            cap_tris=False,
            segments=seg,
            radius1=radius,
            radius2=radius if radius2 is None else radius2,
            depth=length,
        )
        if axis == "X":
            R = Matrix.Rotation(math.radians(90), 4, "Y")
        elif axis == "Y":
            R = Matrix.Rotation(math.radians(90), 4, "X")
        else:
            R = Matrix.Identity(4)
        if rot is not None:
            R = Euler(rot).to_matrix().to_4x4() @ R
        bmesh.ops.transform(bm, matrix=Matrix.Translation(loc) @ R, verts=r["verts"])

    def sphere(self, mat_name, loc, radius, scale=(1, 1, 1), seg=10):
        bm = self.bm(mat_name)
        r = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2), radius=radius)
        M = Matrix.Translation(loc) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        bmesh.ops.transform(bm, matrix=M, verts=r["verts"])

    def torus(self, mat_name, loc, major, minor, axis="Z", seg=18, tube=8):
        bm = self.bm(mat_name)
        rows = []
        for i in range(seg):
            a = i / seg * math.tau
            ring = []
            for j in range(tube):
                b = j / tube * math.tau
                x = (major + minor * math.cos(b)) * math.cos(a)
                y = (major + minor * math.cos(b)) * math.sin(a)
                z = minor * math.sin(b)
                if axis == "X":
                    p = Vector((z, x, y))
                elif axis == "Y":
                    p = Vector((x, z, y))
                else:
                    p = Vector((x, y, z))
                ring.append(bm.verts.new(p + Vector(loc)))
            rows.append(ring)
        for i in range(seg):
            for j in range(tube):
                a, b = rows[i], rows[(i + 1) % seg]
                bm.faces.new((a[j], a[(j + 1) % tube], b[(j + 1) % tube], b[j]))

    def tube(self, mat_name, p0, p1, radius, seg=8):
        """Silinder dari titik p0 ke p1."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        mid = (p0 + p1) / 2
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        bm = self.bm(mat_name)
        r = bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=seg, radius1=radius, radius2=radius, depth=d.length
        )
        bmesh.ops.transform(bm, matrix=Matrix.Translation(mid) @ q.to_matrix().to_4x4(), verts=r["verts"])

    def prism(self, mat_name, pts, thick):
        """Panel tipis dari poligon pts (3D) yang ditebalkan sepanjang +/- thick/2 pada sumbu X."""
        bm = self.bm(mat_name)
        a = [bm.verts.new((p[0] - thick / 2, p[1], p[2])) for p in pts]
        b = [bm.verts.new((p[0] + thick / 2, p[1], p[2])) for p in pts]
        bm.faces.new(a[::-1])
        bm.faces.new(b)
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))

    # ---------- lambung
    def hull(
        self,
        length,
        width,
        draft,
        sheer,
        bow_rise,
        mats,
        exp=1.7,
        stations=36,
        prof=13,
        bow_fine=0.5,
        stern_taper=0.08,
        keel_rise=0.8,
        split=(-0.3, 0.5),
    ):
        """Lambung loft. mats = (bawah, garis, atas). Mengembalikan fungsi tepi geladak (y -> (x, z))."""
        bm_lo, bm_mid, bm_hi = (self.bm(m) for m in mats)
        rows = []
        info = []

        def sec(t):
            wf = math.sin(min(t / bow_fine, 1.0) * math.pi / 2) ** 0.75
            wf *= 1 - stern_taper * max(0.0, (t - 0.85) / 0.15)
            kz = -draft * (1 - keel_rise * (max(0.0, bow_fine - t) / bow_fine) ** 2)
            sz = sheer + bow_rise * (1 - t) ** 3
            return wf * width / 2, kz, sz

        for k in range(stations + 1):
            t = k / stations
            y = -length / 2 + t * length
            hw, kz, sz = sec(t)
            row = []
            for i in range(prof):
                u = -1 + 2 * i / (prof - 1)
                x = hw * u
                z = kz + (sz - kz) * abs(u) ** exp
                row.append((x, y, z))
            rows.append(row)
            info.append((hw, sz))
        vr = []
        for row in rows:
            vr.append([(row[i]) for i in range(prof)])
        # satu set vertex per bmesh agar tidak berbagi lintas bahan: bangun per bahan lewat koordinat
        for k in range(stations):
            for i in range(prof - 1):
                pts = [rows[k][i], rows[k][i + 1], rows[k + 1][i + 1], rows[k + 1][i]]
                zc = sum(p[2] for p in pts) / 4
                # tinggi relatif terhadap garis air
                if zc < split[0]:
                    bm = bm_lo
                elif zc < split[1]:
                    bm = bm_mid
                else:
                    bm = bm_hi
                try:
                    vs = [bm.verts.new(p) for p in pts]
                    bm.faces.new(vs[::-1])
                except ValueError:
                    pass
        # cermin transom (buritan)
        last = rows[-1]
        try:
            vs = [bm_hi.verts.new(p) for p in last]
            bm_hi.faces.new(vs)
        except ValueError:
            pass
        self._hull_rows = rows
        self._hull_info = info
        # tutup atas (geladak) dibuat terpisah oleh deck()
        return rows

    def deck(self, mat_name, inset=0.9, lift=0.0, skip_front=0):
        rows = self._hull_rows
        port = []
        stbd = []
        for k, row in enumerate(rows):
            if k < skip_front:
                continue
            x, y, z = row[0]
            port.append((x * inset, y, z + lift))
            x2, y2, z2 = row[-1]
            stbd.append((x2 * inset, y2, z2 + lift))
        # poligon: sisi kiri depan->belakang, lalu sisi kanan belakang->depan
        outline = port + stbd[::-1]
        bm = self.bm(mat_name)
        vs = [bm.verts.new(p) for p in outline]
        # buang titik berimpit (haluan runcing)
        f = None
        try:
            f = bm.faces.new(vs)
        except ValueError:
            dedup = []
            for v in vs:
                if not dedup or (dedup[-1].co - v.co).length > 1e-4:
                    dedup.append(v)
            if len(dedup) > 2 and (dedup[0].co - dedup[-1].co).length < 1e-4:
                dedup.pop()
            f = bm.faces.new(dedup)
        # ukuran geladak pada y tertentu (untuk menaruh benda): lebar dan tinggi
        return f

    def deck_at(self, y):
        """(setengah lebar geladak, tinggi) di posisi y dari tabel baris lambung."""
        rows = self._hull_rows
        L = rows[-1][0][1] - rows[0][0][1]
        t = (y - rows[0][0][1]) / L
        k = min(max(int(round(t * (len(rows) - 1))), 0), len(rows) - 1)
        x, yy, z = rows[k][-1]
        return abs(x), z

    # ---------- keluaran
    def build(self, bevel_mats=(), bevel=0.06, smooth=True, hull_mats=()):
        collection()
        objs = []
        for mname, bm in self.m.items():
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.002)
            try:
                bmesh.ops.dissolve_degenerate(bm, dist=0.002, edges=bm.edges[:])
            except Exception:
                pass
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            me =bpy.data.meshes.new(f"{self.name}_{mname}")
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new(mname, me)
            COL.objects.link(ob)
            me.materials.append(mat(mname, self.colors.get(mname, (0.7, 0.7, 0.7))))
            bpy.context.view_layer.objects.active = ob
            for o in bpy.context.selected_objects:
                o.select_set(False)
            ob.select_set(True)
            if mname not in hull_mats and bevel:
                md = ob.modifiers.new("b", "BEVEL")
                md.width = bevel
                md.segments = 1
                md.limit_method = "ANGLE"
                md.angle_limit = math.radians(35)
                bpy.ops.object.modifier_apply(modifier=md.name)
            if smooth:
                bpy.ops.object.shade_smooth()
                ob.data.use_auto_smooth = True
                ob.data.auto_smooth_angle = math.radians(40)
            objs.append(ob)
        self.m = {}
        return objs


def clear_collection():
    col = bpy.data.collections.get("ROBLOCK_Kapal")
    if col:
        for o in list(col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
