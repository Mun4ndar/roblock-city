# Pameran Alat Pemadam Kebakaran: 9 model alat dalam satu FBX. Dijalankan lewat Blender MCP.
# Tiap alat dibangun di (ox, 0, 0) dengan dasar z = 0 (ox = indeks * 10). Nama objek = "<alat>_<bahan>".
# Depan = +Y, atas = +Z (konvensi helpers.py). Warna dipasang di Studio menurut akhiran nama bahan.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math, json

new_scene("PameranDamkar")
SP = 10.0


def _rot_to(d, ref_up=None):
    d = Vector(d).normalized()
    up = "Y" if abs(d.y) < 0.9 else "X"
    return d.to_track_quat("Z", up).to_matrix()


def seg(m, p0, p1, r, r2=None, n=12):
    """silinder dari titik p0 ke p1."""
    b = bm(m)
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=n, radius1=r, radius2=(r if r2 is None else r2), depth=d.length)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=_rot_to(d), verts=res["verts"])
    bmesh.ops.translate(b, vec=(p0 + p1) / 2, verts=res["verts"])


def ell(m, c, rx, ry, rz, seg_u=14, seg_v=8, keep_top=False):
    b = bm(m)
    res = bmesh.ops.create_uvsphere(b, u_segments=seg_u, v_segments=seg_v, radius=1.0)
    v = res["verts"]
    bmesh.ops.scale(b, vec=(rx, ry, rz), verts=v)
    bmesh.ops.translate(b, vec=c, verts=v)


def torus(m, c, R, r, axis="y", nu=28, nv=8):
    """cincin tabung: sumbu cincin sepanjang axis."""
    b = bm(m)
    rows = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        row = []
        for j in range(nv):
            t = 2 * math.pi * j / nv
            rr = R + r * math.cos(t)
            x, y, z = rr * math.cos(a), rr * math.sin(a), r * math.sin(t)
            if axis == "y":      # cincin di bidang XZ
                x, y, z = rr * math.cos(a), z, rr * math.sin(a)
            elif axis == "x":
                x, y, z = z, rr * math.cos(a), rr * math.sin(a)
            row.append(b.verts.new((c[0] + x, c[1] + y, c[2] + z)))
        rows.append(row)
    for i in range(nu):
        for j in range(nv):
            b.faces.new([rows[i][j], rows[(i + 1) % nu][j], rows[(i + 1) % nu][(j + 1) % nv], rows[i][(j + 1) % nv]])


def prism_y(m, pts, y0, y1):
    """poligon di bidang XZ (daftar (x, z)) diekstrusi dari y0 ke y1."""
    b = bm(m)
    a = [b.verts.new((x, y0, z)) for (x, z) in pts]
    c = [b.verts.new((x, y1, z)) for (x, z) in pts]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        b.faces.new([a[i], a[j], c[j], c[i]])
    b.faces.new(list(reversed(a)))
    b.faces.new(c)


ITEMS = []


def item(name):
    ITEMS.append(name)
    return (len(ITEMS) - 1) * SP


# 1. APAR --------------------------------------------------------------------------------------------
ox = item("apar")
cyl("apar_merah", ox, 0, 0.3, 0.7, 2.2, seg=24)
cyl("apar_merah", ox, 0, 2.5, 0.7, 0.55, seg=24, r2=0.34)
cyl("apar_hitam", ox, 0, 0, 0.8, 0.35, seg=24)
cyl("apar_perak", ox, 0, 3.05, 0.3, 0.32, seg=16)
box("apar_hitam", ox, 0, 3.3, 0.9, 0.5, 0.45)
box("apar_hitam", ox - 0.1, 0, 3.72, 1.3, 0.3, 0.13)
box("apar_hitam", ox + 0.05, 0, 3.5, 1.15, 0.28, 0.12)
box("apar_putih", ox, 0.665, 0.9, 0.9, 0.1, 1.2)
cyl("apar_perak", ox - 0.32, 0.3, 3.3, 0.2, 0.2, seg=16)
for p0, p1 in [((ox + 0.45, 0, 3.4), (ox + 0.95, 0, 3.15)), ((ox + 0.95, 0, 3.15), (ox + 1.1, 0, 2.2)),
               ((ox + 1.1, 0, 2.2), (ox + 0.95, 0.45, 1.5)), ((ox + 0.95, 0.45, 1.5), (ox + 0.7, 0.72, 1.15))]:
    seg("apar_hitam", p0, p1, 0.13)
seg("apar_perak", (ox + 0.7, 0.72, 1.15), (ox + 0.55, 0.9, 0.85), 0.2, 0.12)

# 2. Hidran ------------------------------------------------------------------------------------------
ox = item("hidran")
cyl("hidran_merah", ox, 0, 0, 1.05, 0.3, seg=24)
cyl("hidran_merah", ox, 0, 0.3, 0.8, 2.0, seg=24)
dome("hidran_merah", ox, 0, 2.3, 0.8, hz=0.65, seg=24)
cyl("hidran_merah", ox, 0, 2.9, 0.34, 0.3, seg=16)
cyl("hidran_kuning", ox, 0, 0.55, 0.85, 0.25, seg=24)
cyl("hidran_kuning", ox, 0, 1.95, 0.85, 0.25, seg=24)
seg("hidran_perak", (ox - 0.7, 0, 1.4), (ox - 1.2, 0, 1.4), 0.4)
seg("hidran_perak", (ox + 0.7, 0, 1.4), (ox + 1.2, 0, 1.4), 0.4)
seg("hidran_perak", (ox, 0.7, 1.3), (ox, 1.35, 1.3), 0.5)
seg("hidran_kuning", (ox - 1.2, 0, 1.4), (ox - 1.3, 0, 1.4), 0.48)
seg("hidran_kuning", (ox + 1.2, 0, 1.4), (ox + 1.3, 0, 1.4), 0.48)
seg("hidran_kuning", (ox, 1.3, 1.3), (ox, 1.42, 1.3), 0.58)
cyl("hidran_hitam", ox, 0, 3.2, 0.3, 0.35, seg=6)

# 3. Selang ------------------------------------------------------------------------------------------
ox = item("selang")
box("selang_hitam", ox + 0.5, 0, 0, 3.6, 1.6, 0.25)
for y in (-0.62, 0.62):
    seg("selang_kuning", (ox, y, 1.9), (ox, y + (0.12 if y > 0 else -0.12), 1.9), 1.75, n=28)
seg("selang_perak", (ox, -0.8, 1.9), (ox, 0.8, 1.9), 0.22)
for R in (0.65, 0.95, 1.25):
    for y in (-0.3, 0.3):
        torus("selang_merah", (ox, y, 1.9), R, 0.24, axis="y")
seg("selang_merah", (ox + 1.1, 0, 0.55), (ox + 1.8, 0, 0.5), 0.22)
seg("selang_merah", (ox + 0.2, 0, 0.9), (ox + 1.1, 0, 0.55), 0.22)
seg("selang_perak", (ox + 1.8, 0, 0.5), (ox + 2.1, 0, 0.5), 0.28)
seg("selang_perak", (ox + 2.1, 0, 0.5), (ox + 2.6, 0, 0.5), 0.3, 0.16)

# 4. Helm --------------------------------------------------------------------------------------------
ox = item("helm")
cyl("helm_hitam", ox, 0, 0, 1.0, 0.35, seg=24, r2=0.8)
dome("helm_kuning", ox, 0, 0.35, 1.35, hz=1.2, seg=28)
cyl("helm_kuning", ox, 0, 0.3, 1.75, 0.2, seg=28)
b = bm("helm_kuning")
res = bmesh.ops.create_cube(b, size=1.0)
bmesh.ops.scale(b, vec=(2.7, 1.3, 0.18), verts=res["verts"])
bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-18), 3, "X"), verts=res["verts"])
bmesh.ops.translate(b, vec=(ox, -1.65, 0.55), verts=res["verts"])
box("helm_kuning", ox, 0, 1.3, 0.4, 2.4, 0.3)
box("helm_merah", ox, 1.25, 0.8, 1.0, 0.15, 0.8)
box("helm_perak", ox, 1.31, 0.95, 0.5, 0.1, 0.5)
box("helm_hitam", ox, 1.1, 0.4, 1.9, 0.5, 0.18)

# 5. Baju tahan api -------------------------------------------------------------------------------------
ox = item("baju")
cyl("baju_hitam", ox, 0, 0, 1.0, 0.2, seg=24)
cyl("baju_hitam", ox, 0, 0.2, 0.12, 1.3, seg=12)
rrect("baju_kuning", ox, 0, 1.3, 2.3, 1.2, 2.3, r=0.45, seg=5)
rrect("baju_perak", ox, 0, 1.95, 2.36, 1.26, 0.22, r=0.46, seg=5)
rrect("baju_perak", ox, 0, 2.7, 2.36, 1.26, 0.22, r=0.46, seg=5)
cyl("baju_hitam", ox, 0, 3.55, 0.55, 0.3, seg=16)
ell("baju_hitam", (ox, 0, 3.95), 0.4, 0.4, 0.4)
box("baju_hitam", ox, 0.62, 1.35, 0.1, 0.06, 2.2)
for s in (-1, 1):
    seg("baju_kuning", (ox + s * 1.05, 0, 3.35), (ox + s * 1.85, 0.15, 2.0), 0.4)
    seg("baju_perak", (ox + s * 1.62, 0.1, 2.5), (ox + s * 1.7, 0.12, 2.37), 0.44)
    seg("baju_hitam", (ox + s * 1.83, 0.15, 2.05), (ox + s * 1.87, 0.16, 1.9), 0.43)
    ell("baju_kuning", (ox + s * 1.05, 0, 3.3), 0.42, 0.42, 0.42)

# 6. Kapak ---------------------------------------------------------------------------------------------
ox = item("kapak")
seg("kapak_kayu", (ox, 0, 0.05), (ox, 0, 3.7), 0.15)
seg("kapak_hitam", (ox, 0, 0.05), (ox, 0, 1.25), 0.2)
box("kapak_merah", ox, 0, 2.75, 0.75, 0.55, 1.2)
prism_y("kapak_perak", [(ox + 0.35, 2.7), (ox + 0.35, 3.95), (ox + 1.3, 4.25), (ox + 1.7, 3.3), (ox + 1.3, 2.4)], -0.12, 0.12)
prism_y("kapak_merah", [(ox - 0.35, 3.0), (ox - 1.5, 3.35), (ox - 0.35, 3.6)], -0.16, 0.16)
cyl("kapak_perak", ox, 0, 3.95, 0.2, 0.15, seg=12)

# 7. Alarm kebakaran ---------------------------------------------------------------------------------
ox = item("alarm")
cyl("alarm_hitam", ox, 0, 0, 0.7, 0.22, seg=24)
cyl("alarm_hitam", ox, 0, 0.2, 0.2, 1.3, seg=16)
rrect("alarm_merah", ox, 0, 1.45, 2.0, 0.9, 2.1, r=0.25, seg=4)
for s in (-1, 1):
    seg("alarm_perak", (ox + s * 0.55, 0.45, 2.85), (ox + s * 0.55, 0.78, 2.85), 0.5, 0.36)
    ell("alarm_hitam", (ox + s * 0.55, 0.8, 2.85), 0.14, 0.14, 0.14)
box("alarm_putih", ox, 0.46, 1.65, 1.2, 0.1, 0.65)
box("alarm_hitam", ox, 0.55, 1.8, 0.2, 0.3, 0.4)
dome("alarm_kuning", ox, 0, 3.55, 0.4, hz=0.4, seg=16)
cyl("alarm_kuning", ox, 0, 3.5, 0.42, 0.1, seg=16)

# 8. Masker oksigen ------------------------------------------------------------------------------------
ox = item("masker")
cyl("masker_perak", ox - 1.0, 0, 0, 0.7, 0.2, seg=20)
cyl("masker_biru", ox - 1.0, 0, 0.2, 0.55, 2.4, seg=20)
dome("masker_biru", ox - 1.0, 0, 2.6, 0.55, hz=0.42, seg=20)
cyl("masker_perak", ox - 1.0, 0, 3.0, 0.2, 0.3, seg=12)
box("masker_hitam", ox - 1.0, 0, 3.25, 0.6, 0.3, 0.3)
cyl("masker_perak", ox + 1.2, 0, 0, 0.55, 0.2, seg=16)
cyl("masker_perak", ox + 1.2, 0, 0.2, 0.18, 1.1, seg=12)
ell("masker_hitam", (ox + 1.2, 0, 2.25), 0.95, 0.7, 1.0)
ell("masker_kaca", (ox + 1.2, 0.28, 2.32), 0.72, 0.5, 0.72)
seg("masker_perak", (ox + 1.2, 0.5, 1.95), (ox + 1.2, 1.1, 1.95), 0.27)
torus("masker_hitam", (ox + 1.2, -0.05, 2.25), 1.0, 0.07, axis="y")
for p0, p1 in [((ox - 1.0, 0, 3.4), (ox - 1.0, 0, 3.9)), ((ox - 1.0, 0, 3.9), (ox - 0.2, 0, 4.0)),
               ((ox - 0.2, 0, 4.0), (ox + 0.5, 0, 3.7)), ((ox + 0.5, 0, 3.7), (ox + 0.85, 0.1, 3.15))]:
    seg("masker_hitam", p0, p1, 0.12)

# 9. Tangga ----------------------------------------------------------------------------------------------
ox = item("tangga")
for s in (-1, 1):
    box("tangga_perak", ox + s * 0.75, 0, 0.18, 0.22, 0.6, 4.3)
    box("tangga_merah", ox + s * 0.75, 0, 0, 0.3, 0.75, 0.2)
    box("tangga_merah", ox + s * 0.75, 0, 4.4, 0.3, 0.7, 0.18)
for i in range(9):
    seg("tangga_perak", (ox - 0.75, 0, 0.55 + i * 0.45), (ox + 0.75, 0, 0.55 + i * 0.45), 0.1)

info = export(r"D:\ROBLOX STUDIO\assets\blender\pameran_damkar.fbx", r"D:\ROBLOX STUDIO\assets\blender\pameran_damkar.blend")
out = {}
for ob in SC.objects:
    mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
    for v in ob.data.vertices:
        mn = Vector(map(min, mn, v.co)); mx = Vector(map(max, mx, v.co))
    out[ob.name] = [round(c, 3) for c in ((mn + mx) / 2)] + [round(c, 3) for c in (mx - mn)]
print(json.dumps({"items": ITEMS, "sp": SP, "objs": out}))
