# SPBU: kanopi pompa + 2 pulau + 4 pompa dua sisi dengan selang melengkung dan nozel.
# Tengah = tengah kanopi, tanah di z=0. Pulau memanjang di Y, jarak pulau 28 (x = +-14).
# Dipakai: exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\spbu_pompa.py", encoding="utf8").read(), "p", "exec"))
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("SpbuPompa")


def tube(m, p0, p1, r, seg=8):
    """silinder antara dua titik."""
    a, b_ = Vector(p0), Vector(p1)
    d = b_ - a
    L = d.length
    if L < 1e-4:
        return
    bb = bm(m)
    res = bmesh.ops.create_cone(bb, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r, depth=L)
    q = d.to_track_quat("Z", "Y")
    bmesh.ops.rotate(bb, cent=(0, 0, 0), matrix=q.to_matrix(), verts=res["verts"])
    bmesh.ops.translate(bb, vec=(a + b_) / 2, verts=res["verts"])


def bezier(p0, p1, p2, p3, n=10):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append(u ** 3 * Vector(p0) + 3 * u * u * t * Vector(p1) + 3 * u * t * t * Vector(p2) + t ** 3 * Vector(p3))
    return pts


# ---------------------------------------------------------------- kanopi
CZ = 14.4       # bawah atap
RW, RD = 72.0, 42.0
rrect("PkRoof", 0, 0, CZ, RW, RD, 1.1, 5.0, 6)
rrect("PkRed", 0, 0, CZ + 0.2, RW + 0.7, RD + 0.7, 0.55, 5.3, 6)  # pita merah di sisi
rrect("PkRed", 0, 0, CZ - 0.5, RW + 0.4, RD + 0.4, 0.6, 5.2, 6)  # list merah di bawah tepi
rrect("PkUnder", 0, 0, CZ - 0.05, RW - 3, RD - 3, 0.2, 4.0, 6)   # panel bawah
for sx in (-1, 1):
    for sy in (-1, 1):
        tube("PkPillar", (sx * 28, sy * 14, 0.3), (sx * 28, sy * 14, CZ), 0.85, 16)
        cyl("PkRed", sx * 28, sy * 14, 0.3, 1.25, 1.6, 16)
        cyl("PkRed", sx * 28, sy * 14, CZ - 1.6, 1.15, 1.2, 16)
# lampu panjang di bawah atap
for x in (-24, -14, -4, 4, 14, 24):
    box("PkLamp", x, 0, CZ - 0.35, 1.2, 30.0, 0.2)

# ---------------------------------------------------------------- pulau + pompa
def pump(cx, cy):
    # alas
    box("PmDark", cx, cy, 0.8, 3.4, 3.4, 0.5)
    # badan
    box("PmBody", cx, cy, 1.3, 2.4, 3.0, 5.2)
    # kap atas putih + lampu atas
    box("PmWhite", cx, cy, 6.5, 2.9, 3.4, 0.7)
    box("PmRed", cx, cy, 7.2, 2.5, 3.0, 0.35)
    for sx in (-1, 1):
        # layar angka + panel + nomor
        box("PmDark", cx + sx * 1.22, cy, 4.6, 0.12, 2.5, 1.5)
        box("PmScreen", cx + sx * 1.3, cy, 4.8, 0.1, 2.0, 0.8)
        box("PmWhite", cx + sx * 1.22, cy, 3.3, 0.14, 2.5, 1.0)
        box("PmRed", cx + sx * 1.24, cy, 3.5, 0.14, 0.9, 0.6)
        # pita merah-putih di badan
        box("PmWhite", cx + sx * 1.21, cy, 1.5, 0.12, 2.8, 0.45)
        # sarung nozel (holster) di sisi
        box("PmDark", cx + sx * 1.45, cy + 0.9, 2.1, 0.7, 0.8, 1.7)
        # nozel: gagang kuning + moncong perak ke bawah
        tube("PmYellow", (cx + sx * 1.7, cy + 0.9, 3.9), (cx + sx * 2.35, cy + 0.9, 3.25), 0.2, 8)
        tube("PmMetal", (cx + sx * 1.45, cy + 0.9, 3.5), (cx + sx * 1.45, cy + 0.9, 2.6), 0.16, 8)
        # selang: dari atas badan melengkung keluar lalu turun ke nozel
        pts = bezier((cx + sx * 1.0, cy - 0.5, 6.3), (cx + sx * 4.2, cy - 0.5, 7.2),
                     (cx + sx * 4.6, cy + 0.6, 3.3), (cx + sx * 2.35, cy + 0.9, 3.25), 12)
        for i in range(len(pts) - 1):
            tube("PmHose", pts[i], pts[i + 1], 0.14, 6)


for ix in (-14, 14):
    # pulau: alas beton + bibir kuning + tiang kecil pelindung
    rrect("PiBase", ix, 0, 0, 5.0, 18.0, 0.9, 1.2, 4)
    box("PiYellow", ix, 0, 0.9, 5.2, 18.2, 0.12)
    for sy in (-1, 1):
        cyl("PiYellow", ix, sy * 8.4, 0.9, 0.35, 2.4, 8)
        cyl("PiRed", ix, sy * 8.4, 3.1, 0.38, 0.35, 8)
    for iy in (-4.2, 4.2):
        pump(ix, iy)

print(export(r"D:\ROBLOX STUDIO\assets\blender\spbu_pompa.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_spbu_pompa.blend"))
