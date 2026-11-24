# ROBLOCK Resort: hotel pantai bertingkat mundur dengan balkon, menara layar di tengah. Depan = +Y (menuju kolam).
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Resort")
W, D = 140.0, 40.0
HW, HD = W / 2, D / 2

# ---- lobi dasar ----
rrect("RsWall", 0, 0, 0, W - 2, D - 2, 10.0, 4.0, 5)
box("RsSand", 0, 0, 0, W + 1.0, D + 1.0, 0.9)
box("RsWhite", 0, 0, 10.0, W + 1.0, D + 1.0, 0.8)  # atap lobi = lantai teras
GY = HD
# etalase kaca lobi (kiri dan kanan tengah)
for sx in (-1, 1):
    box("RsGlass", sx * 44.0, GY, 1.2, 56.0, 0.3, 7.6)
    for i in range(10):
        box("RsDark", sx * 44.0 - 28.0 + i * 56.0 / 9, GY + 0.1, 1.0, 0.5, 0.6, 8.0)
    box("RsDark", sx * 44.0, GY + 0.1, 8.6, 57.0, 0.6, 0.5)

# ---- sayap bertingkat (ziggurat) ----
tiers = [(10.8, 12.0, 40.0), (22.8, 10.5, 34.0), (33.3, 10.5, 28.0)]  # (z0, tinggi, kedalaman)
for sx in (-1, 1):
    for (z0, h, d) in tiers:
        cx = sx * 42.0
        wing_w = 56.0
        yc = -(D - d) / 2  # mundur ke belakang, depan tetap bertingkat
        box("RsWall", cx, yc, z0, wing_w, d, h)
        fy = yc + d / 2  # muka depan tingkat
        box("RsWhite", cx, yc, z0 + h, wing_w + 1.0, d + 1.0, 0.7)  # atap/teras
        # pita jendela + balkon
        for k in range(2):
            zb = z0 + 1.2 + k * (h / 2)
            hh = h / 2 - 1.8
            box("RsGlass", cx, fy + 0.1, zb, wing_w - 4, 0.3, hh)
            n = 14
            for i in range(n + 1):
                box("RsWhite", cx - (wing_w - 4) / 2 + i * (wing_w - 4) / n, fy + 0.15, zb, 0.35, 0.5, hh)
            box("RsWhite", cx, fy + 1.2, zb - 0.6, wing_w - 1, 2.4, 0.5)  # lantai balkon
            box("RsGlass", cx, fy + 2.35, zb - 0.1, wing_w - 1, 0.2, 1.5)  # pagar kaca
        # teras taman di atap tingkat bawah (depan tingkat berikutnya)
        box("RsWood", cx, fy - 2.5, z0 + h + 0.7, wing_w - 6, 3.0, 0.15)
        for i in range(8):
            px = cx - wing_w / 2 + 4 + i * (wing_w - 8) / 7
            box("RsPlanter", px, fy - 1.0, z0 + h + 0.7, 3.0, 1.4, 0.9)
            ball("RsLeaf", px, fy - 1.0, z0 + h + 2.0, 1.1, 8)
    # sirip pembatas di ujung sayap
    box("RsWhite", sx * 70.5, 0, 0, 1.0, D, 44.0)
    box("RsTeal", sx * 71.1, 0, 14.0, 0.3, D - 6, 2.0)

# ---- menara layar di tengah ----
TW, TD = 30.0, 26.0
box("RsWhite", 0, -4, 10.8, TW, TD, 33.5)
R = TW / 2
for i in range(16):  # muka depan melengkung kaca
    a0 = math.pi * i / 16
    a1 = math.pi * (i + 1) / 16
    x0, y0 = math.cos(a0) * R, 9.0 + math.sin(a0) * 9.0
    x1, y1 = math.cos(a1) * R, 9.0 + math.sin(a1) * 9.0
    seg = math.hypot(x1 - x0, y1 - y0)
    ang = math.atan2(y1 - y0, x1 - x0)
    b = bm("RsGlass")
    r = bmesh.ops.create_cube(b, size=1.0)
    bmesh.ops.scale(b, vec=(seg + 0.05, 0.4, 32.0), verts=r["verts"])
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(ang, 3, "Z"), verts=r["verts"])
    bmesh.ops.translate(b, vec=((x0 + x1) / 2, (y0 + y1) / 2, 11.5 + 16.0), verts=r["verts"])
    if i % 2 == 0:
        cyl("RsWhite", x0, y0, 10.8, 0.4, 33.0, 8)
# lengkung layar (dua sirip miring)
for sx in (-1, 1):
    for t in range(14):
        a = t / 13.0
        zz = 44.0 + a * 9.0
        xx = sx * (14.5 - a * 11.0)
        box("RsWhite", xx, -4 + 8.0 * (1 - a), zz, 1.6, 1.2 + 2.0 * (1 - a), 1.0)
box("RsTeal", 0, 4.0, 52.0, 8.0, 1.2, 1.0)
cyl("RsGold", 0, -4, 44.0, 0.3, 11.0, 8, 0.1)
# kanopi pintu masuk + kolom kayu
box("RsWood", 0, GY + 6.0, 9.2, 34.0, 12.0, 0.6)
for i in range(12):
    box("RsWhite", -16.5 + i * 3.0, GY + 6.0, 9.8, 0.4, 12.0, 0.5)
for sx in (-1, 1):
    for sy in (GY + 11.0,):
        cyl("RsWhite", sx * 15.0, sy, 0.9, 0.8, 8.4, 14)
box("RsDark", 0, GY + 0.1, 0.8, 9.0, 0.6, 8.4)
box("RsGlass", 0, GY + 0.4, 1.2, 8.0, 0.3, 7.4)
box("RsTeal", 0, GY + 11.9, 9.2, 34.4, 0.3, 0.8)
box("RsDark", 0, 18.6, 11.6, 24.0, 0.8, 3.6)  # papan nama (teks di Roblox, y muka = 19.0)
box("RsTeal", 0, 18.7, 11.3, 24.6, 0.9, 0.3)
box("RsTeal", 0, 18.7, 15.2, 24.6, 0.9, 0.3)
# ---- palem pot di sisi pintu ----
for sx in (-1, 1):
    cyl("RsPlanter", sx * 22.0, GY + 3.0, 0.9, 1.6, 1.4, 14)
    cyl("RsDark", sx * 22.0, GY + 3.0, 2.3, 0.3, 4.5, 8)
    for k in range(6):
        a = k * math.pi / 3
        box("RsLeaf", sx * 22.0 + math.cos(a) * 1.6, GY + 3.0 + math.sin(a) * 1.6, 6.5, 3.2, 0.5, 0.25)

print(export(r"D:\ROBLOX STUDIO\assets\blender\resort_modern.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_resort.blend"))
