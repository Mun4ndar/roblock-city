# Gedung sekolah ceria: atap pelana merah, menara jam, jendela dengan daun jendela warna-warni. Depan = +Y.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Sekolah")
W, D, H = 140.0, 34.0, 18.0
HW, HD = W / 2, D / 2


def gable(m, cx, y0, y1, z0, x0, x1, rise, over=1.6):
    """atap pelana dengan bubungan sepanjang X: dari y0 ke y1 (lebar), naik 'rise' di tengah."""
    b = bm(m)
    ym = (y0 + y1) / 2
    pts = [(x0, y0 - over, z0), (x0, y1 + over, z0), (x0, ym, z0 + rise),
           (x1, y0 - over, z0), (x1, y1 + over, z0), (x1, ym, z0 + rise)]
    vs = [b.verts.new(p) for p in pts]
    for f in ([0, 2, 1], [3, 4, 5], [0, 3, 5, 2], [1, 2, 5, 4], [0, 1, 4, 3]):
        b.faces.new([vs[i] for i in f])


box("ScWall", 0, 0, 0, W, D, H)
box("ScStone", 0, 0, 0, W + 1.2, D + 1.2, 1.4)
for sy in (-1, 1):  # lis tengah dengan garis pelangi
    cols = ["ScRed", "ScOrange", "ScYellow", "ScGreen", "ScBlue", "ScPurple"]
    for i, c in enumerate(cols):
        box(c, 0, sy * (HD + 0.05), 8.8 + i * 0.35, W + 0.2, 0.3, 0.34)
gable("ScRoof", 0, -HD, HD, H, -HW - 1.6, HW + 1.6, 8.0)
box("ScWhite", 0, 0, H - 0.8, W + 2.0, D + 2.0, 0.8)  # kornis

# ---- jendela dengan daun jendela ----
GY = HD + 0.1
shut = ["ScBlue", "ScGreen", "ScOrange", "ScPurple"]
k = 0
for x in range(-62, 63, 8):
    if abs(x) < 12:
        continue
    for (z0, hh) in ((2.6, 4.4), (11.2, 4.4)):
        box("ScWhite", x, GY + 0.1, z0 - 0.4, 4.6, 0.4, hh + 0.8)
        box("ScGlass", x, GY + 0.3, z0, 3.6, 0.3, hh)
        box("ScWhite", x, GY + 0.45, z0, 0.25, 0.3, hh)
        box("ScWhite", x, GY + 0.45, z0 + hh / 2, 3.6, 0.3, 0.25)
        c = shut[k % 4]
        box(c, x - 2.7, GY + 0.35, z0, 1.1, 0.3, hh)
        box(c, x + 2.7, GY + 0.35, z0, 1.1, 0.3, hh)
    k += 1
for x in range(-62, 63, 10):  # belakang
    for z0 in (3.0, 11.0):
        box("ScGlass", x, -HD - 0.1, z0, 4.0, 0.3, 4.4)
        box("ScWhite", x, -HD - 0.15, z0 - 0.4, 5.0, 0.3, 0.4)
for sx in (-1, 1):
    for yy in (-8, 0, 8):
        for z0 in (3.0, 11.0):
            box("ScGlass", sx * (HW + 0.1), yy, z0, 0.3, 4.0, 4.4)

# ---- bagian tengah: serambi, pintu, menara jam ----
PY = HD + 4.0
box("ScWall", 0, HD + 2.0, 0, 28.0, 4.0, 19.0)
box("ScWhite", 0, HD + 2.0, 0, 29.0, 5.0, 1.2)
box("ScStone", 0, PY + 0.8, 0, 22.0, 3.0, 0.7)
for i in range(3):
    box("ScStone", 0, PY + 2.8 + i * 1.3, 0, 18.0 - i, 1.3, 0.7 - i * 0.2)
# pintu lengkung
box("ScDark", 0, PY + 0.2, 0.7, 9.0, 0.5, 8.0)
cyl("ScDark", 0, PY + 0.2, 8.7, 4.5, 0.5, 20)
b = bm("ScGlass")
box("ScGlass", -2.1, PY + 0.55, 1.2, 3.6, 0.3, 7.0)
box("ScGlass", 2.1, PY + 0.55, 1.2, 3.6, 0.3, 7.0)
cyl("ScGlass", 0, PY + 0.5, 8.2, 3.8, 0.3, 20)
box("ScWhite", 0, PY + 0.7, 1.2, 0.25, 0.3, 11.0)
# frontispis di atas serambi
b = bm("ScWhite")
prism_pts = [(-15, HD - 0.5, 19.0), (15, HD - 0.5, 19.0), (0, HD - 0.5, 25.0), (-15, PY + 0.8, 19.0), (15, PY + 0.8, 19.0), (0, PY + 0.8, 25.0)]
vs = [b.verts.new(p) for p in prism_pts]
for f in ([0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]):
    b.faces.new([vs[i] for i in f])
b = bm("ScRoof")
prism_pts = [(-16.5, HD - 0.5, 19.0), (16.5, HD - 0.5, 19.0), (0, HD - 0.5, 26.0), (-16.5, PY + 1.5, 19.0), (16.5, PY + 1.5, 19.0), (0, PY + 1.5, 26.0)]
# (garis atap frontispis, sedikit lebih besar)
box("ScRoof", 0, HD + 2.0, 18.8, 31.0, 6.2, 0.5)
cyl("ScYellow", 0, PY + 0.9, 21.2, 1.6, 0.4, 20)
# tiang serambi
for sx in (-1, 1):
    cyl("ScWhite", sx * 10.5, PY + 0.2, 1.4, 0.7, 17.4, 14)
# menara jam
TY = -2.0
box("ScWall", 0, TY, H, 14.0, 14.0, 14.0)
box("ScWhite", 0, TY, H + 14.0, 15.4, 15.4, 1.0)
pyramid("ScRoof", 0, TY, H + 15.0, 17.0, 9.0)
cyl("ScGold", 0, TY, H + 23.9, 0.18, 4.0, 6, 0.06)
ball("ScGold", 0, TY, H + 28.0, 0.5)
for sy in (-1, 1):
    yy = TY + sy * 7.1
    b = bm("ScWhite")
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=24, radius1=4.8, radius2=4.8, depth=0.5)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(0, yy, H + 7.0), verts=res["verts"])
    b = bm("ScClock")
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=24, radius1=4.2, radius2=4.2, depth=0.6)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(0, yy + sy * 0.05, H + 7.0), verts=res["verts"])
    box("ScDark", 0, yy + sy * 0.45, H + 7.0 - 0.2, 0.4, 0.3, 3.4)
    box("ScDark", -1.2, yy + sy * 0.45, H + 6.8, 2.6, 0.3, 0.4)
    for a in range(12):
        an = a * math.pi / 6
        box("ScDark", math.sin(an) * 3.6, yy + sy * 0.45, H + 7.0 + math.cos(an) * 3.6 - 0.2, 0.4, 0.3, 0.4)
for sx in (-1, 1):
    box("ScGlass", sx * 7.1, TY, H + 2.5, 0.3, 4.0, 6.0)

# ---- tiang bendera + bangku ----
cyl("ScWhite", 36.0, HD + 10.0, 0, 0.3, 17.0, 8)
box("ScRed", 38.0, HD + 10.0, 14.0, 4.0, 0.15, 2.6)
box("ScWhiteFlag", 38.0, HD + 10.0, 11.4, 4.0, 0.15, 2.6)
cyl("ScStone", 36.0, HD + 10.0, 0, 1.2, 0.6, 12)
for sx in (-1, 1):
    box("ScWood", sx * 24.0, HD + 4.0, 1.0, 6.0, 1.6, 0.4)
    box("ScWood", sx * 24.0, HD + 4.8, 1.4, 6.0, 0.3, 1.6)
    box("ScStone", sx * 22.0, HD + 4.0, 0.0, 0.5, 1.2, 1.0)
    box("ScStone", sx * 26.0, HD + 4.0, 0.0, 0.5, 1.2, 1.0)

print(export(r"D:\ROBLOX STUDIO\assets\blender\sekolah_ceria.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_sekolah.blend"))
