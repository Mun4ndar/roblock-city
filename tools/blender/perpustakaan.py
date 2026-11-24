# Perpustakaan modern: atrium kaca setengah silinder, sirip kayu, atap hijau. Depan = +Y.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Perpustakaan")
W, D, H = 120.0, 70.0, 18.0
HW, HD = W / 2, D / 2

box("PlWall", 0, 0, 0, W, D, H)
box("PlStone", 0, 0, 0, W + 1.6, D + 1.6, 1.2)
box("PlRoof", 0, 0, H, W + 2.4, D + 2.4, 1.0)
box("PlWhite", 0, 0, H - 0.9, W + 2.0, D + 2.0, 0.9)
# atap hijau (taman) dengan bingkai
box("PlGreen", 0, -6, H + 1.0, W - 14, D - 22, 0.5)
for s in (-1, 1):
    box("PlWhite", 0, s * (HD + 1.1), H + 1.0, W + 2.6, 0.6, 1.2)
    box("PlWhite", s * (HW + 1.1), 0, H + 1.0, 0.6, D + 2.2, 1.2)

GY = HD + 0.1
# sirip kayu vertikal di sayap kiri dan kanan
for sx in (-1, 1):
    for i in range(10):
        x = sx * (24.0 + i * 3.4)
        box("PlWood", x, GY + 0.55, 1.2, 1.1, 1.2, H - 1.8)
    box("PlGlass", sx * 41.0, GY - 0.1, 2.4, 34.0, 0.3, H - 4.4)
    box("PlDark", sx * 41.0, GY, 1.2, 36.0, 0.6, 1.2)
    box("PlDark", sx * 41.0, GY, H - 2.0, 36.0, 0.6, 0.8)
# atrium tengah: setengah silinder kaca menonjol ke depan
R = 15.0
cy0 = HD - 1.0
steps = 20
for i in range(steps):
    a0 = math.pi * i / steps
    a1 = math.pi * (i + 1) / steps
    x0, y0 = math.cos(a0) * R, cy0 + math.sin(a0) * R * 0.8
    x1, y1 = math.cos(a1) * R, cy0 + math.sin(a1) * R * 0.8
    seg = math.hypot(x1 - x0, y1 - y0)
    ang = math.atan2(y1 - y0, x1 - x0)
    for (mat, z0, hh, th) in (("PlGlass", 1.4, H - 2.6, 0.35),):
        b = bm(mat)
        r = bmesh.ops.create_cube(b, size=1.0)
        bmesh.ops.scale(b, vec=(seg + 0.05, th, hh), verts=r["verts"])
        bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(ang, 3, "Z"), verts=r["verts"])
        bmesh.ops.translate(b, vec=((x0 + x1) / 2, (y0 + y1) / 2, z0 + hh / 2), verts=r["verts"])
    if i % 2 == 0:  # tiang kaca
        cyl("PlWhite", x0, y0, 0.0, 0.45, H + 4.0, 8)
cyl("PlWhite", -R, cy0, 0.0, 0.45, H + 4.0, 8)
cyl("PlWhite", R, cy0, 0.0, 0.45, H + 4.0, 8)
# atap atrium: setengah cakram tebal + kubah kaca kecil
b = bm("PlWhite")
pts = []
for i in range(steps + 1):
    a = math.pi * i / steps
    pts.append((math.cos(a) * (R + 1.2), cy0 + math.sin(a) * (R * 0.8 + 1.2)))
pts += [(-R - 1.2, cy0 - 12), (R + 1.2, cy0 - 12)]
lo = [b.verts.new((x, y, H + 2.0)) for (x, y) in pts]
hi = [b.verts.new((x, y, H + 3.2)) for (x, y) in pts]
n = len(pts)
for i in range(n):
    j = (i + 1) % n
    b.faces.new([lo[i], lo[j], hi[j], hi[i]])
b.faces.new(hi)
b.faces.new(list(reversed(lo)))
dome("PlGlass", 0, cy0 - 8, H + 3.2, 9.0, 4.5, 20)
# pintu kaca di tengah atrium
box("PlDark", 0, cy0 + R * 0.8 - 0.1, 0.0, 9.0, 0.6, 8.6)
box("PlGlass", 0, cy0 + R * 0.8 + 0.2, 0.4, 7.8, 0.4, 7.4)
box("PlWood", 0, cy0 + R * 0.8 + 0.4, 0.4, 0.3, 0.4, 7.4)
# papan nama di atas atrium (teks di Roblox)
box("PlWood", 0, cy0 + R * 0.8 + 0.3, H + 3.2, 24.0, 1.0, 4.2)
# tangga masuk
for i in range(3):
    b2 = bm("PlStone")
    box("PlStone", 0, cy0 + R * 0.8 + 3.0 + i * 1.4, 0, 20.0 + i * 2.0, 1.4, 0.9 - i * 0.3)

# --- sisi dan belakang ---
for sx in (-1, 1):
    for yy in range(-24, 25, 12):
        box("PlGlass", sx * (HW + 0.1), yy, 4.0, 0.3, 6.0, 9.0)
        box("PlWhite", sx * (HW + 0.2), yy, 3.6, 0.4, 7.2, 0.5)
        box("PlWhite", sx * (HW + 0.2), yy, 13.0, 0.4, 7.2, 0.5)
for xx in range(-48, 49, 16):
    box("PlGlass", xx, -HD - 0.1, 4.0, 9.0, 0.3, 9.0)
    box("PlWhite", xx, -HD - 0.2, 3.6, 10.0, 0.4, 0.5)
    box("PlWhite", xx, -HD - 0.2, 13.0, 10.0, 0.4, 0.5)

# --- patung buku raksasa di kiri tangga (hiasan) ---
for sx in (-1, 1):
    bx, by = sx * 28.0, HD + 12.0
    for i, (c, w) in enumerate((("PlBook1", 7.0), ("PlBook2", 6.0), ("PlBook3", 5.0))):
        box(c, bx, by, 0.5 + i * 1.8, w, 4.5, 1.8)
        box("PlWhite", bx, by - 0.1, 0.5 + i * 1.8 + 0.5, w - 0.6, 4.6, 0.7)
    box("PlStone", bx, by, 0, 9.0, 6.0, 0.5)

print(export(r"D:\ROBLOX STUDIO\assets\blender\perpustakaan_modern.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_perpustakaan.blend"))
