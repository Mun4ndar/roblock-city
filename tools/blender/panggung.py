# Panggung Konser Taman Kota: dek, atap lengkung bergaris pelangi, rangka truss, layar LED (hanya bingkai),
# menara speaker, tangga, spanduk, bendera segitiga, balon, lantai dansa, gerbang balon. Dijalankan lewat Blender MCP.
# Depan = +Y (menghadap penonton), atas = +Z, sumbu panggung di x = 0. Satu objek per bahan; nama = warna dipasang di Studio.
# Menulis juga map/PanggungData.luau (posisi lampu, layar, pad joget) supaya pemasang Luau memakai angka yang sama.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math, json, random

new_scene("Panggung")
random.seed(17)

# ----------------------------------------------------------------- alat bantu
def _rot_to(d):
    d = Vector(d).normalized()
    up = "Y" if abs(d.y) < 0.9 else "X"
    return d.to_track_quat("Z", up).to_matrix()


def tube(m, p0, p1, r, n=6):
    b = bm(m)
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    if d.length < 1e-4:
        return
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=n, radius1=r, radius2=r, depth=d.length)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=_rot_to(d), verts=res["verts"])
    bmesh.ops.translate(b, vec=(p0 + p1) / 2, verts=res["verts"])


def cyl_y(m, cx, cy, cz, r, depth, seg=16):
    """silinder dengan sumbu sepanjang Y (pusat di cy)."""
    tube(m, (cx, cy - depth / 2, cz), (cx, cy + depth / 2, cz), r, seg)


def ellipsoid(m, c, rx, ry, rz, su=10, sv=6):
    b = bm(m)
    res = bmesh.ops.create_uvsphere(b, u_segments=su, v_segments=sv, radius=1.0)
    bmesh.ops.scale(b, vec=(rx, ry, rz), verts=res["verts"])
    bmesh.ops.translate(b, vec=c, verts=res["verts"])


def prism_xz(m, pts, y0, y1):
    """poligon cembung di bidang XZ diekstrusi dari y0 ke y1."""
    b = bm(m)
    a = [b.verts.new((x, y0, z)) for (x, z) in pts]
    c = [b.verts.new((x, y1, z)) for (x, z) in pts]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        b.faces.new([a[i], a[j], c[j], c[i]])
    b.faces.new(list(reversed(a)))
    b.faces.new(c)


# ----------------------------------------------------------------- ukuran
HALF = 22.0           # setengah lebar dek
DY0, DY1 = -11.0, 13.0  # dek dari belakang ke depan
DECK = 3.0
R = 44.64             # jari-jari busur atap
ZMID, ZEDGE = 29.0, 22.0  # permukaan atas atap di tengah dan di x = +-24
RY0, RY1, RT = -12.0, 14.5, 0.7


def ztop(x):
    return ZMID - (R - math.sqrt(R * R - x * x))


def ztruss_top(x):
    return ztop(x) - RT - 0.12


def ztruss_bot(x):
    return ztruss_top(x) - 2.4


data = {"fixtures": [], "balloons": 0}

# ----------------------------------------------------------------- dek
box("Dek", 0, (DY0 + DY1) / 2, 0.0, HALF * 2, DY1 - DY0, DECK)
# tepi kuning menonjol di sekeliling dek
box("DekTepi", 0, DY1 - 0.4, DECK, HALF * 2, 0.8, 0.14)
box("DekTepi", 0, DY0 + 0.4, DECK, HALF * 2, 0.8, 0.14)
box("DekTepi", -HALF + 0.4, (DY0 + DY1) / 2, DECK, 0.8, DY1 - DY0 - 1.6, 0.14)
box("DekTepi", HALF - 0.4, (DY0 + DY1) / 2, DECK, 0.8, DY1 - DY0 - 1.6, 0.14)
cyl("DekTengah", 0, 4.0, DECK, 6.5, 0.04, seg=32)
cyl("DekTengah", -12, 3.0, DECK, 3.2, 0.04, seg=24)
cyl("DekTengah", 12, 3.0, DECK, 3.2, 0.04, seg=24)
# rok depan merah muda + pita biru
box("Rok", 0, DY1 + 0.15, 0.0, HALF * 2, 0.3, DECK)
box("RokPita", 0, DY1 + 0.32, 0.9, HALF * 2, 0.12, 0.55)
# podium drum
box("Podium", 0, -6.2, DECK, 9.0, 5.6, 0.7)
# drum
cyl_y("DrumPutih", 0, -4.1, DECK + 0.7 + 1.55, 1.5, 1.4, 20)
cyl_y("DrumMerah", 0, -3.35, DECK + 0.7 + 1.55, 1.52, 0.1, 20)
cyl("DrumMerah", -1.7, -6.9, DECK + 0.7 + 1.8, 0.85, 0.7, 16)
cyl("DrumMerah", 1.1, -6.9, DECK + 0.7 + 1.8, 0.85, 0.7, 16)
cyl("DrumPutih", 2.7, -5.2, DECK + 0.7 + 1.2, 1.0, 0.55, 16)
tube("Rangka", (2.7, -5.2, DECK + 0.7), (2.7, -5.2, DECK + 0.7 + 1.2), 0.07)
cyl("Simbal", -3.2, -7.6, DECK + 0.7 + 4.0, 1.3, 0.07, 18)
cyl("Simbal", 3.4, -7.4, DECK + 0.7 + 3.6, 1.2, 0.07, 18)
cyl("Simbal", 0.0, -8.0, DECK + 0.7 + 4.6, 1.4, 0.07, 18)
for (cx, cy, h) in [(-3.2, -7.6, 4.0), (3.4, -7.4, 3.6), (0.0, -8.0, 4.6)]:
    tube("Rangka", (cx, cy, DECK + 0.7), (cx, cy, DECK + 0.7 + h), 0.07)
# stool
cyl("DrumMerah", 0, -6.0, DECK + 0.7 + 0.6, 0.7, 0.25, 12)

# ----------------------------------------------------------------- atap lengkung 8 pita warna
BANDS = ["AtapMerah", "AtapKuning", "AtapHijau", "AtapBiru", "AtapBiru", "AtapHijau", "AtapKuning", "AtapMerah"]
edges = [-24 + 6 * i for i in range(9)]
SUB = 3
for bi, name in enumerate(BANDS):
    b = bm(name)
    xs = [edges[bi] + (edges[bi + 1] - edges[bi]) * k / SUB for k in range(SUB + 1)]
    top_f = [b.verts.new((x, RY1, ztop(x))) for x in xs]
    top_b = [b.verts.new((x, RY0, ztop(x))) for x in xs]
    bot_f = [b.verts.new((x, RY1, ztop(x) - RT)) for x in xs]
    bot_b = [b.verts.new((x, RY0, ztop(x) - RT)) for x in xs]
    for k in range(SUB):
        b.faces.new([top_b[k], top_b[k + 1], top_f[k + 1], top_f[k]])        # atas
        b.faces.new([bot_f[k], bot_f[k + 1], bot_b[k + 1], bot_b[k]])        # bawah
        b.faces.new([top_f[k], top_f[k + 1], bot_f[k + 1], bot_f[k]])        # depan
        b.faces.new([bot_b[k], bot_b[k + 1], top_b[k + 1], top_b[k]])        # belakang
    b.faces.new([bot_b[0], top_b[0], top_f[0], bot_f[0]])
    b.faces.new([bot_f[SUB], top_f[SUB], top_b[SUB], bot_b[SUB]])
# bintang emas di puncak atap (menghadap penonton)
sp = []
for i in range(10):
    a = math.pi / 2 + i * math.pi / 5
    rr = 3.4 if i % 2 == 0 else 1.45
    sp.append((rr * math.cos(a), 33.2 + rr * math.sin(a)))
# bintang cembung per segitiga: pecah jadi 5 ujung + pusat agar tiap prisma cembung
cx_star = 0.0
for i in range(5):
    p_out = sp[2 * i]
    p_l = sp[(2 * i - 1) % 10]
    p_r = sp[2 * i + 1]
    prism_xz("Bintang", [(0, 33.2), p_l, p_out, p_r], 0.6, 1.4)
# tiang bintang
tube("Rangka", (0, 1.0, ztop(0) - 0.3), (0, 1.0, 31.0), 0.3)

# ----------------------------------------------------------------- truss lengkung (3 bidang)
NODES = [-22 + 44 * i / 16 for i in range(17)]
TRUSS_Y = [11.5, 0.0, -9.5]
for ty in TRUSS_Y:
    pts_t = [(x, ty, ztruss_top(x)) for x in NODES]
    pts_b = [(x, ty, ztruss_bot(x)) for x in NODES]
    for i in range(16):
        tube("Rangka", pts_t[i], pts_t[i + 1], 0.24)
        tube("Rangka", pts_b[i], pts_b[i + 1], 0.24)
        if i % 2 == 0:
            tube("Rangka", pts_t[i], pts_b[i + 1], 0.13)
        else:
            tube("Rangka", pts_b[i], pts_t[i + 1], 0.13)
    for i in range(17):
        tube("Rangka", pts_t[i], pts_b[i], 0.13)
# pengikat memanjang antar truss
for x in [-22, -11, 0, 11, 22]:
    for (ya, yb) in [(TRUSS_Y[0], TRUSS_Y[1]), (TRUSS_Y[1], TRUSS_Y[2])]:
        tube("Rangka", (x, ya, ztruss_bot(x)), (x, yb, ztruss_bot(x)), 0.2)

# ----------------------------------------------------------------- kolom penopang (4)
for sx in (-1, 1):
    for cy in (11.5, -9.5):
        x = sx * 21.8
        top = ztruss_bot(21.8) + 0.2
        box("RangkaHitam", x, cy, DECK, 2.3, 2.3, 0.35)
        for dx in (-0.55, 0.55):
            tube("Rangka", (x + dx, cy, DECK + 0.35), (x + dx, cy, top), 0.2)
        z = DECK + 0.35
        k = 0
        while z + 2.4 < top:
            z1 = z + 2.4
            if k % 2 == 0:
                tube("Rangka", (x - 0.55, cy, z), (x + 0.55, cy, z1), 0.1)
            else:
                tube("Rangka", (x + 0.55, cy, z), (x - 0.55, cy, z1), 0.1)
            tube("Rangka", (x - 0.55, cy, z1), (x + 0.55, cy, z1), 0.1)
            z = z1
            k += 1

# ----------------------------------------------------------------- batang lampu sorot + lampu
BAR_Y = [7.0, -4.0]
BAR_Z = 16.8
LAMP_X = [-20 + 4 * i for i in range(11)]
for by in BAR_Y:
    tube("Rangka", (-21.5, by, BAR_Z), (21.5, by, BAR_Z), 0.2)
    for hx in (-20, -10, 0, 10, 20):
        tube("Rangka", (hx, by, BAR_Z), (hx, by, ztruss_bot(hx)), 0.1)
    # sambung batang ke truss depan/tengah dengan penahan miring
    for lx in LAMP_X:
        tube("RangkaHitam", (lx, by, BAR_Z - 0.2), (lx, by, BAR_Z - 0.55), 0.09)
        cyl("LampuBadan", lx, by, BAR_Z - 1.55, 0.55, 1.0, seg=12)
        cyl("LampuLensa", lx, by, BAR_Z - 1.62, 0.43, 0.07, seg=12)
        data["fixtures"].append([lx, by, BAR_Z - 1.6])

# ----------------------------------------------------------------- dinding layar LED (bingkai saja; layar dibuat di Luau)
box("LayarBingkai", 0, -10.5, DECK, 44.0, 0.4, 16.8)
SCREENS = [
    {"name": "Utama", "cx": 0.0, "cz": 11.5, "w": 30.0, "h": 12.4},
    {"name": "Kiri", "cx": -18.3, "cz": 10.6, "w": 3.5, "h": 10.6},
    {"name": "Kanan", "cx": 18.3, "cz": 10.6, "w": 3.5, "h": 10.6},
]
for s in SCREENS:
    w, h, cx, cz = s["w"], s["h"], s["cx"], s["cz"]
    t = 0.55
    box("LayarTepi", cx, -10.2, cz - h / 2 - t, w + 2 * t, 0.5, t)
    box("LayarTepi", cx, -10.2, cz + h / 2, w + 2 * t, 0.5, t)
    box("LayarTepi", cx - w / 2 - t, -10.2, cz - h / 2 - t, t, 0.5, h + 2 * t)
    box("LayarTepi", cx + w / 2, -10.2, cz - h / 2 - t, t, 0.5, h + 2 * t)
    s["y"] = -10.18

# ----------------------------------------------------------------- menara speaker (2 sisi)
SPK = []
for sx in (-1, 1):
    x = sx * 28.0
    y = 4.0
    for i in range(4):
        z0 = i * 3.4
        box("SpeakerKotak", x, y, z0, 4.4, 3.4, 3.4)
        box("SpeakerKotak", x, y, z0, 4.6, 3.6, 0.2)
        fy = y + 1.7
        cyl_y("SpeakerRing", x, fy + 0.03, z0 + 1.7, 1.45, 0.08, 18)
        cyl_y("SpeakerKerucut", x, fy + 0.12, z0 + 1.7, 1.2, 0.3, 18)
        cyl_y("SpeakerRing", x, fy + 0.3, z0 + 1.7, 0.4, 0.12, 12)
    box("RangkaHitam", x, y, 13.6, 4.8, 3.8, 0.35)
    SPK.append((x, y))

# ----------------------------------------------------------------- tangga (dua sisi depan) + pegangan
for sx in (-1, 1):
    xc = sx * 16.0
    for j in (3, 2, 1):
        y0 = DY1 + 1.8 * (3 - j)
        box("Tangga", xc, y0 + 0.9, 0.0, 8.0, 1.8, float(j))
    for edge in (-4.0, 4.0):
        rx = xc + edge
        ya, yb = DY1 + 0.5, DY1 + 5.0
        za, zb = DECK + 1.2, 1.0 + 1.2
        tube("Rangka", (rx, ya, za), (rx, yb, zb), 0.1)
        tube("Rangka", (rx, ya, DECK), (rx, ya, za), 0.1)
        tube("Rangka", (rx, yb, 1.0), (rx, yb, zb), 0.1)

# ----------------------------------------------------------------- spanduk besar (4) dan bendera segitiga
BAN = [(-18.6, "SpandukPink"), (-14.6, "SpandukKuning"), (14.6, "SpandukBiru"), (18.6, "SpandukPink")]
for (bx, nm) in BAN:
    box(nm, bx, 11.9, 9.2, 3.2, 0.14, 9.0)
    box("SpandukTiang", bx, 11.9, 18.3, 3.5, 0.2, 0.2)
    box("SpandukTiang", bx, 11.9, 9.0, 3.5, 0.2, 0.2)
BUNT = ["BuntingMerah", "BuntingKuning", "BuntingHijau", "BuntingBiru"]
for i in range(29):
    x = -21 + 1.5 * i
    zt = ztruss_bot(x) - 0.2
    nm = BUNT[i % 4]
    prism_xz(nm, [(x - 0.55, zt), (x + 0.55, zt), (x, zt - 1.35)], 12.35, 12.45)
for i in range(29):
    x = -21 + 1.5 * i
    zt = ztruss_bot(x) - 0.2
    nm = BUNT[(i + 2) % 4]
    prism_xz(nm, [(x - 0.55, zt), (x + 0.55, zt), (x, zt - 1.35)], -10.1, -10.0)

# ----------------------------------------------------------------- balon
BAL = ["BalonMerah", "BalonKuning", "BalonBiru", "BalonHijau", "BalonUngu", "BalonPink"]


def balloon(c, color):
    ellipsoid(color, c, 0.95, 0.95, 1.15, 10, 6)
    tube("Tali", (c[0], c[1], c[2] - 1.15), (c[0] + 0.0, c[1], c[2] - 1.15), 0.01, 3)
    data["balloons"] += 1


def cluster(bx, by, bz, n):
    for i in range(n):
        ang = random.uniform(0, 2 * math.pi)
        rad = random.uniform(0.6, 1.9)
        h = random.uniform(6.0, 11.0)
        top = (bx + math.cos(ang) * rad, by + math.sin(ang) * rad, bz + h)
        color = BAL[(i + int(bx)) % 6]
        ellipsoid(color, top, 0.95, 0.95, 1.15, 10, 6)
        tube("Tali", (bx, by, bz + 0.2), (top[0], top[1], top[2] - 1.1), 0.025, 3)
        data["balloons"] += 1
    cyl("Tali", bx, by, bz, 0.35, 0.3, seg=8)


for sx in (-1, 1):
    cluster(sx * 24.6, 12.5, 0.0, 8)
    cluster(sx * 24.6, -11.5, 0.0, 8)
    cluster(sx * 19.5, 18.6, 0.0, 6)

# gerbang balon di pintu masuk area penonton (y = 46)
GY = 46.0
n_arch = 22
for i in range(n_arch + 1):
    a = math.pi * i / n_arch
    x = math.cos(a) * 10.0
    z = 1.3 + math.sin(a) * 10.5
    for layer in (-0.9, 0.9):
        c = (x, GY + layer * 0.5, z)
        ellipsoid(BAL[(i + (0 if layer < 0 else 3)) % 6], c, 1.05, 1.05, 1.05, 10, 6)
        data["balloons"] += 1
for sx in (-10.0, 10.0):
    box("RangkaHitam", sx, GY, 0.0, 1.2, 1.2, 0.5)

# ----------------------------------------------------------------- lantai dansa berpetak (di depan panggung)
FLOOR_Y0 = 19.0
TW = 4.0
for ix in range(10):
    for iy in range(6):
        nm = ["UbinA", "UbinB", "UbinC"][(ix + iy) % 3]
        box(nm, -18 + TW * ix, FLOOR_Y0 + TW * iy + TW / 2 - TW / 2 + TW / 2, 0.04, TW - 0.15, TW - 0.15, 0.36)
data["floor"] = {"y0": FLOOR_Y0, "y1": FLOOR_Y0 + TW * 6, "x0": -20.0, "x1": 20.0}

# ----------------------------------------------------------------- data untuk pemasang Luau
data["screens"] = SCREENS
data["speakers"] = SPK
data["deckZ"] = DECK
data["pads"] = [[-10.0, 31.0], [0.0, 31.0], [10.0, 31.0]]
data["marquee"] = {"cx": 0.0, "y": 14.7, "cz": 27.0, "w": 30.0, "h": 5.0}
# ----------------------------------------------------------------- UV ke atlas PBR 4x4 (KidsConcertStage_*.png, 1024 px)
# Titik datar = satu warna dari atlas; TEXCELL = proyeksi kotak diregangkan ke satu sel (kolom, baris dari atas).
def px(x, y):
    return (x / 1024.0, 1.0 - y / 1024.0)


FLAT = {
    "DekTengah": px(640, 900), "DekTepi": px(900, 900), "RokPita": px(800, 80), "Podium": px(140, 600),
    "DrumPutih": px(640, 900), "DrumMerah": px(60, 540), "Simbal": px(900, 900), "Rangka": px(380, 100),
    "AtapMerah": px(60, 540), "AtapKuning": px(190, 540), "AtapHijau": px(60, 700), "AtapBiru": px(800, 100),
    "Bintang": px(900, 900), "RangkaHitam": px(100, 800), "LampuBadan": px(100, 800), "LampuLensa": px(100, 800),
    "LayarBingkai": px(100, 800), "LayarTepi": px(300, 900), "SpeakerKotak": px(100, 800), "SpeakerRing": px(380, 100),
    "SpeakerKerucut": px(580, 70), "Tangga": px(384, 640), "SpandukTiang": px(380, 100),
    "BuntingMerah": px(60, 540), "BuntingKuning": px(190, 540), "BuntingHijau": px(60, 700), "BuntingBiru": px(190, 700),
    "BalonMerah": px(60, 540), "BalonKuning": px(190, 540), "BalonBiru": px(800, 100), "BalonHijau": px(770, 645),
    "BalonUngu": px(190, 700), "BalonPink": px(60, 700), "Tali": px(640, 900),
    "UbinA": px(60, 540), "UbinB": px(60, 700), "UbinC": px(190, 540),
}
TEXCELL = {"Dek": (0, 0), "Rok": (3, 1), "SpandukPink": (2, 1), "SpandukKuning": (2, 1), "SpandukBiru": (2, 1)}


def export_uv(out, blend=None):
    objs = []
    for name, b in BM.items():
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        uvl = b.loops.layers.uv.new("UVMap")
        if name in TEXCELL:
            c, r = TEXCELL[name]
            mn = Vector((1e9, 1e9, 1e9))
            mx = Vector((-1e9, -1e9, -1e9))
            for v in b.verts:
                mn = Vector(map(min, mn, v.co))
                mx = Vector(map(max, mx, v.co))
            for f in b.faces:
                n = f.normal
                ax = max(range(3), key=lambda i: abs(n[i]))
                ia, ib = [(1, 2), (0, 2), (0, 1)][ax]
                for lp in f.loops:
                    co = lp.vert.co
                    u = (co[ia] - mn[ia]) / max(mx[ia] - mn[ia], 1e-4)
                    v = (co[ib] - mn[ib]) / max(mx[ib] - mn[ib], 1e-4)
                    lp[uvl].uv = ((c + 0.02 + 0.96 * u) / 4.0, 1.0 - (r + 1 - 0.02 - 0.96 * v) / 4.0)
        else:
            uv = FLAT.get(name, px(100, 800))
            for f in b.faces:
                for lp in f.loops:
                    lp[uvl].uv = uv
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
            "center": tuple(round((a + b_) / 2, 3) for a, b_ in zip(mn, mx))}
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


info = export_uv(r"D:\ROBLOX STUDIO\assets\blender\panggung.fbx", r"D:\ROBLOX STUDIO\assets\blender\panggung.blend")
data["bboxCenter"] = info["center"]
data["bboxMin"] = info["bbox_min"]
data["bboxMax"] = info["bbox_max"]
open(r"D:\ROBLOX STUDIO\assets\blender\panggung_data.json", "w").write(json.dumps(data))
print(json.dumps({"info": info, "balloons": data["balloons"], "fixtures": len(data["fixtures"])}))
