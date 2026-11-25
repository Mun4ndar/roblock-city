# Kantor Pos klasik: bata merah, menara jam, beranda berpilar, kotak pos besar. Depan = +Y.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("KantorPos")
W, D, H = 70.0, 50.0, 16.0
HW, HD = W / 2, D / 2

box("PsBrick", 0, 0, 0, W, D, H)
box("PsStone", 0, 0, 0, W + 1.4, D + 1.4, 1.6)  # lis dasar
box("PsCream", 0, 0, 7.6, W + 0.8, D + 0.8, 0.7)  # pita tengah
box("PsCream", 0, 0, H - 1.2, W + 2.0, D + 2.0, 1.2)  # kornis
box("PsRoof", 0, 0, H, W + 2.2, D + 2.2, 1.0)  # atap datar gelap
box("PsCream", 0, 0, H + 1.0, W + 2.6, D + 2.6, 0.6)
# pagar atap (balustrade rendah)
for s in (-1, 1):
    box("PsCream", 0, s * (HD + 1.1), H + 1.6, W + 2.4, 0.6, 1.4)
    box("PsCream", s * (HW + 1.1), 0, H + 1.6, 0.6, D + 2.2, 1.4)

# --- jendela berbingkai di depan, sisi, belakang ---
def win(cx, y, z0, w, h, face):
    d = 0.4
    if face in ("f", "b"):
        s = 1 if face == "f" else -1
        box("PsCream", cx, y + s * 0.1, z0 - 0.5, w + 1.4, d, h + 1.0)
        box("PsGlass", cx, y + s * 0.3, z0, w, d, h)
        box("PsCream", cx, y + s * 0.45, z0, 0.25, d, h)
        box("PsCream", cx, y + s * 0.45, z0 + h / 2, w, d, 0.25)
        # kepala lengkung
        cyl("PsCream", cx, y + s * 0.15, z0 + h, w / 2 + 0.7, d, 16)
    else:
        s = 1 if face == "r" else -1
        box("PsCream", cx + s * 0.1, y, z0 - 0.5, d, w + 1.4, h + 1.0)
        box("PsGlass", cx + s * 0.3, y, z0, d, w, h)
        box("PsCream", cx + s * 0.45, y, z0, d, 0.25, h)
        box("PsCream", cx + s * 0.45, y, z0 + h / 2, d, w, 0.25)

for x in (-28, -20, 20, 28):
    win(x, HD, 2.6, 4.0, 8.0, "f")
for x in (-28, -14, 0, 14, 28):
    win(x, -HD, 2.6, 4.0, 8.0, "b")
for yy in (-15, -5, 5, 15):
    win(HW, yy, 2.6, 4.0, 8.0, "r")
    win(-HW, yy, 2.6, 4.0, 8.0, "l")
for x in (-28, -14, 0, 14, 28):  # jendela atas bundar kecil (oculus)
    cyl("PsCream", x, -HD - 0.15, 11.0, 1.9, 0.4, 14)
    cyl("PsGlass", x, -HD - 0.35, 11.0, 1.4, 0.4, 14)

# --- beranda berpilar + pintu ---
for dx in (-8.0, -2.7, 2.7, 8.0):
    cyl("PsCream", dx, HD + 3.2, 1.0, 0.95, 11.0, 18)
    cyl("PsCream", dx, HD + 3.2, 1.0, 1.25, 0.6, 18)
    box("PsStone", dx, HD + 3.2, 12.0, 2.5, 2.5, 0.5)
box("PsCream", 0, HD + 2.0, 12.5, 21.0, 6.0, 1.2)
box("PsGold", 0, HD + 2.0, 13.7, 21.4, 6.2, 0.3)
box("PsBrick", 0, HD + 0.9, 14.0, 17.0, 4.0, 1.2)  # papan teks
# lantai beranda
box("PsStone", 0, HD + 2.8, 0, 22.0, 6.5, 0.45)
for i in range(3):
    box("PsStone", 0, HD + 6.2 + i * 1.2, 0, 14.0, 1.2, 0.45 - i * 0.15)
# pintu
box("PsDark", 0, HD + 0.2, 0, 7.4, 0.6, 8.2)
box("PsGlass", 0, HD + 0.5, 0.4, 6.4, 0.4, 7.0)
box("PsGold", 0, HD + 0.7, 0.4, 0.25, 0.4, 7.0)

# --- menara jam di tengah atap depan ---
TY = HD - 6.0
box("PsBrick", 0, TY, H + 1.6, 11.0, 11.0, 12.0)
box("PsCream", 0, TY, H + 1.6, 12.0, 12.0, 1.0)
box("PsCream", 0, TY, H + 12.6, 12.6, 12.6, 1.2)
pyramid("PsRoof", 0, TY, H + 13.8, 13.4, 7.5)
ball("PsGold", 0, TY, H + 22.0, 0.7)
cyl("PsGold", 0, TY, H + 21.0, 0.15, 1.6, 6)
for sy in (-1, 1):  # muka jam di depan dan belakang
    yy = TY + sy * 5.65
    b = bm("PsCream")
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=24, radius1=4.2, radius2=4.2, depth=0.5)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(0, yy, H + 8.2), verts=res["verts"])
    b = bm("PsClock")
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=24, radius1=3.7, radius2=3.7, depth=0.6)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(0, yy + sy * 0.05, H + 8.2), verts=res["verts"])
    box("PsDark", 0, yy + sy * 0.45, H + 8.2 - 0.2, 0.35, 0.3, 3.0)  # jarum panjang
    box("PsDark", 1.0, yy + sy * 0.45, H + 8.0, 2.2, 0.3, 0.35)  # jarum pendek
    for a in range(12):  # penanda jam
        an = a * math.pi / 6
        box("PsDark", math.sin(an) * 3.2, yy + sy * 0.45, H + 8.2 + math.cos(an) * 3.2 - 0.18, 0.35, 0.3, 0.35)
for sx in (-1, 1):  # lengkung jendela menara
    box("PsGlass", sx * 5.55, TY, H + 4.0, 0.3, 3.0, 5.0)
    box("PsCream", sx * 5.6, TY, H + 3.6, 0.3, 4.2, 5.8)

# --- kotak pos besar di kiri-kanan pintu ---
for sx in (-1, 1):
    px, py = sx * 17.0, HD + 4.5
    cyl("PsRed", px, py, 0, 1.8, 3.6, 20)
    dome("PsRed", px, py, 3.6, 1.8, 1.4, 20)
    box("PsDark", px, py - 1.85, 2.2, 2.4, 0.2, 0.4)
    cyl("PsGold", px, py, 0, 1.95, 0.4, 20)

print(export(r"D:\ROBLOX STUDIO\assets\blender\kantor_pos_klasik.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_kantor_pos.blend"))
