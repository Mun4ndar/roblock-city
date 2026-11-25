# Aula sekolah: atap tong merah, serambi berpilar, jendela lengkung. Depan = +Y.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Aula")
W, D, H = 50.0, 40.0, 9.0
HW, HD = W / 2, D / 2

box("AuWall", 0, 0, 0, W, D, H)
box("AuStone", 0, 0, 0, W + 1.0, D + 1.0, 1.2)
box("AuWhite", 0, 0, H - 0.8, W + 1.6, D + 1.6, 0.8)
# atap tong (sumbu sepanjang Y)
vault("AuRoof", 0, 0, H, W + 2.4, D + 2.4, 7.5, 24)
box("AuGold", 0, 0, H, W + 2.6, D + 2.6, 0.25)
# rusuk atap
for i in range(1, 8):
    y = -HD - 1.0 + i * (D + 2.0) / 8
    vault("AuWhite", 0, y, H + 0.1, W + 2.8, 0.5, 7.7, 24)

GY = HD + 0.1
# fasad depan: jendela besar berkepala lengkung
for x in (-16, 16):
    box("AuWhite", x, GY + 0.1, 1.8, 6.4, 0.4, 7.6)
    box("AuGlass", x, GY + 0.3, 2.2, 5.2, 0.3, 6.0)
    cyl("AuWhite", x, GY + 0.1, 8.2, 3.2, 0.4, 20)
    box("AuWhite", x, GY + 0.45, 2.2, 0.3, 0.3, 6.0)
# pintu utama lengkung
box("AuWhite", 0, GY + 0.1, 0.5, 11.0, 0.5, 9.0)
cyl("AuWhite", 0, GY + 0.1, 8.5, 5.5, 0.5, 24)
box("AuDark", 0, GY + 0.4, 0.8, 8.4, 0.5, 7.4)
cyl("AuDark", 0, GY + 0.4, 8.2, 4.2, 0.5, 24)
box("AuGlass", -2.1, GY + 0.7, 1.0, 3.6, 0.3, 6.6)
box("AuGlass", 2.1, GY + 0.7, 1.0, 3.6, 0.3, 6.6)
cyl("AuGlass", 0, GY + 0.7, 7.6, 3.9, 0.3, 24)
box("AuWhite", 0, GY + 0.9, 1.0, 0.3, 0.3, 10.6)
# serambi berpilar
for dx in (-9.0, -3.0, 3.0, 9.0):
    cyl("AuWhite", dx, GY + 3.6, 1.2, 0.8, 8.4, 14)
box("AuWhite", 0, GY + 2.4, 9.6, 23.0, 6.4, 1.0)
box("AuGold", 0, GY + 2.4, 10.6, 23.4, 6.6, 0.3)
b = bm("AuRoof")
pts = [(-11.5, GY - 0.6, 10.9), (11.5, GY - 0.6, 10.9), (0, GY - 0.6, 14.6), (-11.5, GY + 5.6, 10.9), (11.5, GY + 5.6, 10.9), (0, GY + 5.6, 14.6)]
vs = [b.verts.new(p) for p in pts]
for f in ([0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]):
    b.faces.new([vs[i] for i in f])
box("AuStone", 0, GY + 4.6, 0, 20.0, 3.4, 0.5)
for i in range(2):
    box("AuStone", 0, GY + 6.6 + i * 1.2, 0, 16.0, 1.2, 0.5 - i * 0.2)
# sisi: jendela lengkung
for sx in (-1, 1):
    for yy in range(-14, 15, 7):
        x = sx * (HW + 0.1)
        box("AuWhite", x + sx * 0.05, yy, 1.8, 0.4, 3.8, 6.0)
        box("AuGlass", x + sx * 0.2, yy, 2.2, 0.3, 3.0, 4.6)
        b = bm("AuWhite")
        res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=14, radius1=1.9, radius2=1.9, depth=0.4)
        bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"), verts=res["verts"])
        bmesh.ops.translate(b, vec=(x + sx * 0.05, yy, 7.8), verts=res["verts"])
for xx in range(-18, 19, 9):
    box("AuGlass", xx, -HD - 0.1, 2.2, 3.6, 0.3, 4.6)
# papan nama di atas serambi (teks di Roblox)
box("AuDark", 0, GY + 5.7, 11.2, 12.0, 0.4, 2.4)
print(export(r"D:\ROBLOX STUDIO\assets\blender\aula_sekolah.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_aula.blend"))
