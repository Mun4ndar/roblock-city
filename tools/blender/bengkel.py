# Bengkel mobil modern: pintu rolling, roda gigi di atap, tumpukan ban. Depan = +Y.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Bengkel")
W, D, H = 22.0, 26.0, 12.0
HW, HD = W / 2, D / 2

box("BgWall", 0, 0, 0, W, D, H)
box("BgStone", 0, 0, 0, W + 0.8, D + 0.8, 1.0)
box("BgOrange", 0, 0, 8.6, W + 0.5, D + 0.5, 1.0)  # pita oranye
box("BgRoof", 0, 0, H, W + 1.4, D + 1.4, 1.0)
box("BgDark", 0, 0, H + 0.6, W + 1.8, D + 1.8, 0.5)
# atap gigi gergaji (skylight)
for i in range(3):
    y0 = -8 + i * 6.0
    b = bm("BgGlass")
    pts = [(-8, y0, H + 1.0), (8, y0, H + 1.0), (8, y0 + 5.0, H + 1.0), (-8, y0 + 5.0, H + 1.0),
           (-8, y0, H + 3.0), (8, y0, H + 3.0)]
    vs = [b.verts.new(p) for p in pts]
    for f in ([0, 1, 5, 4], [0, 4, 3], [1, 2, 5], [4, 5, 2, 3], [0, 3, 2, 1]):
        try:
            b.faces.new([vs[j] for j in f])
        except ValueError:
            pass
GY = HD + 0.1
# dua pintu rolling lebar
for dx in (-5.6, 1.4):
    box("BgDark", dx + 0.0 + 1.0, GY + 0.1, 0, 8.6, 0.5, 8.0)
    for k in range(10):
        box("BgDoor", dx + 1.0, GY + 0.35, 0.3 + k * 0.76, 7.8, 0.3, 0.6)
    box("BgOrange", dx + 1.0, GY + 0.4, 8.2, 8.6, 0.6, 0.35)
# kantor kecil di kanan: kaca besar
box("BgDark", 8.3, GY + 0.1, 0, 4.4, 0.5, 6.4)
box("BgGlass", 8.3, GY + 0.35, 0.6, 3.6, 0.3, 5.0)
box("BgDark", 8.3, GY + 0.45, 0.6, 0.25, 0.3, 5.0)
# papan roda gigi di depan atas
def gear(cx, cy, cz, r, teeth=10):
    b = bm("BgOrange")
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=24, radius1=r, radius2=r, depth=0.8)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, cz), verts=res["verts"])
    for t in range(teeth):
        a = t * 2 * math.pi / teeth
        b2 = bm("BgOrange")
        r2 = bmesh.ops.create_cube(b2, size=1.0)
        bmesh.ops.scale(b2, vec=(r * 0.42, 0.8, r * 0.5), verts=r2["verts"])
        bmesh.ops.rotate(b2, cent=(0, 0, 0), matrix=Matrix.Rotation(a, 3, "Y"), verts=r2["verts"])
        bmesh.ops.translate(b2, vec=(cx + math.sin(a) * (r + r * 0.12), cy, cz + math.cos(a) * (r + r * 0.12)), verts=r2["verts"])
    b3 = bm("BgDark")
    r3 = bmesh.ops.create_cone(b3, cap_ends=True, cap_tris=False, segments=16, radius1=r * 0.45, radius2=r * 0.45, depth=0.9)
    bmesh.ops.rotate(b3, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=r3["verts"])
    bmesh.ops.translate(b3, vec=(cx, cy, cz), verts=r3["verts"])
gear(0, GY + 1.6, H + 4.6, 2.8)
box("BgDark", 0, GY + 1.6, H + 1.0, 0.6, 0.6, 2.6)
# kanopi depan
box("BgOrange", 0, GY + 2.6, 9.6, W + 0.6, 5.0, 0.4)
for sx in (-1, 1):
    cyl("BgDark", sx * (HW - 0.2), GY + 4.8, 0.0, 0.3, 9.6, 8)
# tumpukan ban di dua sisi
def tire(cx, cy, z0):
    b = bm("BgTire")
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=16, radius1=1.4, radius2=1.4, depth=0.9)
    bmesh.ops.translate(b, vec=(cx, cy, z0 + 0.45), verts=res["verts"])
    b2 = bm("BgRim")
    r2 = bmesh.ops.create_cone(b2, cap_ends=True, cap_tris=False, segments=12, radius1=0.8, radius2=0.8, depth=0.95)
    bmesh.ops.translate(b2, vec=(cx, cy, z0 + 0.45), verts=r2["verts"])
for sx in (-1, 1):
    for i in range(4):
        tire(sx * 12.8, GY + 3.0, i * 0.9)
# lantai halaman
box("BgStone", 0, GY + 3.0, 0, W + 4, 6.0, 0.25)
# jendela samping
for sx in (-1, 1):
    for yy in (-6, 0, 6):
        box("BgGlass", sx * (HW + 0.1), yy, 4.5, 0.3, 3.4, 2.4)
print(export(r"D:\ROBLOX STUDIO\assets\blender\bengkel_modern.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_bengkel.blend"))
