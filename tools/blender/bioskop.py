# Bioskop modern: kanopi lampu, poster film, gulungan film di atap. Depan = +Y.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Bioskop")
W, D, H = 90.0, 60.0, 22.0
HW, HD = W / 2, D / 2

rrect("BsWall", 0, 0, 0, W, D, H, 5.0, 6)
box("BsStone", 0, 0, 0, W + 1.4, D + 1.4, 1.0)
rrect("BsRoof", 0, 0, H, W + 1.6, D + 1.6, 1.0, 5.5, 6)
box("BsGold", 0, 0, H - 0.5, W + 2.0, D + 2.0, 0.4)  # garis emas atap

# --- fasad depan ---
GY = HD + 0.1
box("BsGlass", 0, GY, 1.4, W - 12, 0.3, 8.2)
n = 14
for i in range(n + 1):
    x = -(W - 12) / 2 + i * (W - 12) / n
    box("BsDark", x, GY + 0.1, 1.2, 0.5, 0.6, 8.6)
box("BsDark", 0, GY + 0.1, 9.4, W - 10, 0.6, 0.6)
# pintu kembar
for dx in (-12, 12):
    box("BsDark", dx, GY + 0.2, 0, 8.6, 0.6, 8.4)
    box("BsGlass", dx, GY + 0.45, 0.4, 7.4, 0.4, 7.4)
    box("BsGold", dx, GY + 0.6, 0.4, 0.3, 0.4, 7.4)
# poster film
pc = ["BsPoster1", "BsPoster2", "BsPoster3"]
k = 0
for x in (-38, -28, -18, 18, 28, 38):
    box("BsDark", x, GY + 0.3, 11.0, 7.4, 0.5, 9.6)
    box(pc[k % 3], x, GY + 0.65, 11.5, 6.2, 0.4, 8.6)
    k += 1
# bintang kecil di tengah atas
box("BsGold", 0, GY + 0.3, 15.6, 20.0, 0.4, 0.5)
box("BsGold", 0, GY + 0.3, 11.6, 20.0, 0.4, 0.5)
box("BsDark", 0, GY + 0.3, 11.6, 20.0, 0.3, 4.5)

# --- kanopi lampu depan ---
MY = HD + 8.5
box("BsGold", 0, (HD + MY) / 2, 12.0, 46.0, MY - HD, 1.2)
box("BsDark", 0, MY - 0.2, 13.2, 46.0, 1.0, 5.6)  # papan teks "BIOSKOP" dipasang di Roblox
box("BsGold", 0, MY - 0.2, 18.8, 46.4, 1.2, 0.5)
box("BsGold", 0, MY - 0.2, 11.8, 46.4, 1.2, 0.5)
for i in range(24):  # lampu pijar
    x = -22.0 + i * 44.0 / 23
    ball("BsBulb", x, MY + 0.55, 12.6, 0.28, 8)
    ball("BsBulb", x, MY + 0.55, 18.4, 0.28, 8)
for sx in (-1, 1):
    cyl("BsGold", sx * 21.0, MY - 1.0, 0, 0.7, 12.0, 12)
    cyl("BsStone", sx * 21.0, MY - 1.0, 0, 1.1, 0.5, 12)
# lantai teras
box("BsStone", 0, (HD + MY) / 2 + 1, 0, 50.0, MY - HD + 2, 0.3)
# permadani merah
box("BsRed", 0, (HD + MY) / 2 + 1, 0.3, 14.0, MY - HD + 2, 0.12)

# --- sisi: pita bergaris + tiang lampu sorot ---
for sx in (-1, 1):
    for yy in range(-24, 25, 12):
        box("BsGlass", sx * (HW + 0.1), yy, 5.0, 0.3, 5.0, 10.0)
        box("BsStone", sx * (HW + 0.2), yy, 4.5, 0.4, 6.4, 0.5)
        box("BsStone", sx * (HW + 0.2), yy, 15.0, 0.4, 6.4, 0.5)
for xx in (-32, -16, 0, 16, 32):
    box("BsGlass", xx, -HD - 0.1, 5.0, 8.0, 0.3, 10.0)

# --- atap: gulungan film dan papan bintang ---
for sx in (-1, 1):
    for sy in (-18, 18):
        b = bm("BsDark")
        res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=24, radius1=5.0, radius2=5.0, depth=1.6)
        bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
        bmesh.ops.translate(b, vec=(sx * 34.0, sy, H + 6.2), verts=res["verts"])
        cyl("BsStone", sx * 34.0, sy, H + 1.0, 0.6, 4.4, 8)
        b2 = bm("BsGold")
        res = bmesh.ops.create_cone(b2, cap_ends=True, cap_tris=False, segments=16, radius1=1.4, radius2=1.4, depth=1.9)
        bmesh.ops.rotate(b2, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
        bmesh.ops.translate(b2, vec=(sx * 34.0, sy, H + 6.2), verts=res["verts"])
        for a in range(6):  # lubang gulungan
            an = a * math.pi / 3
            b3 = bm("BsGold")
            r3 = bmesh.ops.create_cone(b3, cap_ends=True, cap_tris=False, segments=10, radius1=0.9, radius2=0.9, depth=1.7)
            bmesh.ops.rotate(b3, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=r3["verts"])
            bmesh.ops.translate(b3, vec=(sx * 34.0 + math.cos(an) * 3.1, sy, H + 6.2 + math.sin(an) * 3.1), verts=r3["verts"])
# menara papan reklame di tengah atap
box("BsDark", 0, 24.0, H + 1.0, 18.0, 1.0, 10.0)
box("BsGold", 0, 24.0, H + 11.0, 18.4, 1.3, 0.5)
box("BsGold", 0, 24.0, H + 0.8, 18.4, 1.3, 0.5)
for xx in (-8, 8):
    box("BsStone", xx, 24.0, H + 1.0, 0.8, 0.8, 10.0)

print(export(r"D:\ROBLOX STUDIO\assets\blender\bioskop_modern.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_bioskop.blend"))
