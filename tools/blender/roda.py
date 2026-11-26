# Roda bulat untuk semua kendaraan ROBLOCK CITY (jalankan lewat Blender MCP: exec(open(path).read())).
# Dua objek per roda: RodaBan (karet gelap + cakram dalam) dan RodaVelg (lip + 5 jari + tutup tengah).
# Sumbu putar = sumbu X Blender (tetap X di Roblox), diameter 2 unit, simetris kiri-kanan, pusat di asal.
# Di Studio ukuran MeshPart diatur per kendaraan (lebar, 2r, 2r) dan velg memakai faktor skala yang sama.
import bpy, bmesh, math
from mathutils import Vector

SEG = 40  # sisi keliling; cukup bulat tapi tetap ringan untuk HP


def lathe(bm, prof, seg=SEG, uv=False, uvname="UVMap"):
    """Putar profil [(x, r)] mengelilingi sumbu X. Titik r=0 jadi satu titik."""
    rings = []
    for (x, r) in prof:
        if r < 1e-6:
            rings.append([bm.verts.new((x, 0, 0))])
        else:
            rings.append([bm.verts.new((x, r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg))) for k in range(seg)])
    faces = []
    for i in range(len(prof) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(seg):
            k2 = (k + 1) % seg
            if len(a) == 1 and len(b) == 1:
                continue
            elif len(a) == 1:
                f = [a[0], b[k], b[k2]]
            elif len(b) == 1:
                f = [a[k], a[k2], b[0]]
            else:
                f = [a[k], a[k2], b[k2], b[k]]
            try:
                faces.append((bm.faces.new(f), i, k))
            except ValueError:
                pass
    if uv:
        layer = bm.loops.layers.uv.verify()
        n = max(1, len(prof) - 1)
        for f, i, k in faces:
            for l in f.loops:
                vi = l.vert
                # u dari sudut, v dari urutan profil
                ang = math.atan2(vi.co.z, vi.co.y)
                u = (ang / (2 * math.pi)) % 1.0
                if abs(u) < 1e-6 and k == seg - 1:
                    u = 1.0
                # tentukan indeks cincin dari x/r titik ini
                idx = i
                for j, (x, r) in enumerate(prof):
                    if abs(vi.co.x - x) < 1e-6 and abs(math.hypot(vi.co.y, vi.co.z) - r) < 1e-6:
                        idx = j
                        break
                l[layer].uv = (u, idx / n)
    return faces


def mirror_prof(half):
    """half = profil sisi kiri (x<0) dari tengah sumbu keluar; kembalikan profil penuh kiri->kanan."""
    right = [(-x, r) for (x, r) in reversed(half)]
    return half + right


def spoke(bm, theta, x0, x1, r0, r1, w0, w1):
    """Jari berbentuk balok meruncing dari radius r0 ke r1 pada sudut theta, tebal x0..x1."""
    c, s = math.cos(theta), math.sin(theta)
    # arah radial (c,s) di bidang YZ, arah lebar tegak lurus (-s,c)
    def pt(x, r, w):
        return bm.verts.new((x, r * c - w * s, r * s + w * c))
    v = []
    for x in (x0, x1):
        v.append([pt(x, r0, -w0), pt(x, r0, w0), pt(x, r1, w1), pt(x, r1, -w1)])
    a, b = v
    bm.faces.new([a[0], a[1], a[2], a[3]])
    bm.faces.new([b[3], b[2], b[1], b[0]])
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([a[i], b[i], b[j], a[j]])


def build(name, kind):
    """kind = 'mobil' atau 'motor'."""
    if kind == "mobil":
        h = 0.45
        # sisi kiri (x<0): dari titik tengah cakram dalam keluar ke tapak, lalu tutup ke tengah (x=0)
        half = [
            (-0.22, 0.0), (-0.22, 0.56), (-0.33, 0.61), (-0.39, 0.655), (-0.445, 0.76), (-0.445, 0.88),
            (-0.405, 0.955), (-0.33, 0.995), (-0.30, 1.0), (-0.16, 1.0), (-0.145, 0.965), (-0.105, 0.965),
            (-0.09, 1.0), (0.0, 1.0),
        ]
        spokes, lip_r, lip_x = 5, 0.665, 0.435
    else:
        h = 0.30
        half = [
            (-0.12, 0.0), (-0.12, 0.60), (-0.20, 0.63), (-0.255, 0.68), (-0.30, 0.78), (-0.30, 0.86),
            (-0.265, 0.935), (-0.19, 0.985), (-0.12, 1.0), (0.0, 1.0),
        ]
        spokes, lip_r, lip_x = 6, 0.64, 0.285
    # buang titik tengah (x=0) dari half agar tidak terduplikasi saat dicerminkan
    half_l = half[:-1]
    full = half_l + [(0.0, half[-1][1])] + [(-x, r) for (x, r) in reversed(half_l)]

    # ---- ban
    bmt = bmesh.new()
    lathe(bmt, full, uv=True)
    bmesh.ops.remove_doubles(bmt, verts=bmt.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bmt, faces=bmt.faces[:])
    mt = bpy.data.meshes.new(name + "Ban")
    bmt.to_mesh(mt)
    bmt.free()
    ob_t = bpy.data.objects.new(name + "Ban", mt)

    # ---- velg
    bmr = bmesh.new()
    sgn = (-1, 1)
    for sx in sgn:
        # lip velg (cincin) + bagian mangkuk dangkal; dilathe satu sisi lalu dicerminkan dengan tanda x
        lip = [(sx * (lip_x + 0.015), 0.50), (sx * (lip_x + 0.015), lip_r + 0.02), (sx * (lip_x - 0.04), lip_r + 0.035),
               (sx * (lip_x - 0.10), lip_r - 0.01), (sx * (lip_x - 0.10), 0.50), (sx * (lip_x + 0.015), 0.50)]
        # profil tertutup: titik terakhir = pertama
        fs = lathe(bmr, lip[:-1] + [lip[0]])
        # jari
        x_out = sx * (lip_x - 0.085)
        x_in = sx * (lip_x - 0.175 if kind == "mobil" else lip_x - 0.14)
        for i in range(spokes):
            th = 2 * math.pi * i / spokes + math.pi / 2
            xa, xb = (x_in, x_out) if sx < 0 else (x_out, x_in)
            xa, xb = min(xa, xb), max(xa, xb)
            spoke(bmr, th, xa, xb, 0.10, lip_r - 0.10, 0.075, 0.055)
        # tutup tengah
        cap = [(sx * (lip_x - 0.255), 0.0), (sx * (lip_x - 0.255), 0.115), (sx * (lip_x - 0.215), 0.15), (sx * (lip_x - 0.105), 0.15),
               (sx * (lip_x - 0.075), 0.115), (sx * (lip_x - 0.075), 0.0)]
        if sx > 0:
            cap = cap
        lathe(bmr, cap)
    bmesh.ops.remove_doubles(bmr, verts=bmr.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bmr, faces=bmr.faces[:])
    mr = bpy.data.meshes.new(name + "Velg")
    bmr.to_mesh(mr)
    bmr.free()
    ob_r = bpy.data.objects.new(name + "Velg", mr)
    return ob_t, ob_r


def make_all():
    # bersihkan
    for o in list(bpy.data.objects):
        if o.name.startswith(("RodaMobil", "RodaMotor")):
            bpy.data.objects.remove(o, do_unlink=True)
    coll = bpy.data.collections.get("ROBLOCK_Roda")
    if coll is None:
        coll = bpy.data.collections.new("ROBLOCK_Roda")
        bpy.context.scene.collection.children.link(coll)
    out = []
    for name, kind, ox in (("RodaMobil", "mobil", 0.0), ("RodaMotor", "motor", 0.0)):
        t, r = build(name, kind)
        for o in (t, r):
            coll.objects.link(o)
            o.location = (0, 0, 0)
        out += [t, r]
    # bahan: ban gelap, velg perak
    def mat(nm, col, rough, metal):
        m = bpy.data.materials.get(nm) or bpy.data.materials.new(nm)
        m.use_nodes = True
        p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        p.inputs["Base Color"].default_value = col
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metal
        return m
    mban = mat("KaretBan", (0.035, 0.035, 0.04, 1), 0.88, 0.0)
    mvelg = mat("VelgPerak", (0.78, 0.8, 0.84, 1), 0.3, 0.9)
    for o in out:
        o.data.materials.clear()
        o.data.materials.append(mban if o.name.endswith("Ban") else mvelg)
        for p in o.data.polygons:
            p.use_smooth = True
        # tepi tajam: pecah normal di sudut > 40 derajat
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        md = o.modifiers.new("Tajam", "EDGE_SPLIT")
        md.split_angle = math.radians(40)
        bpy.ops.object.modifier_apply(modifier="Tajam")
        o.select_set(False)
    return out


objs = make_all()
for o in objs:
    print(o.name, len(o.data.vertices), "verts", len(o.data.polygons), "faces", tuple(round(d, 3) for d in o.dimensions))
