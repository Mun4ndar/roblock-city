# SPBU modern: toko kecil + kanopi lengkung + pompa. Asal = pusat toko, depan = +Y (menuju kanopi di y=76).
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("SPBU")
# ---- toko ----
W, D, H = 40.0, 24.0, 11.0
rrect("BpWall", 0, 0, 0, W, D, H, 3.0, 5)
box("BpStone", 0, 0, 0, W + 0.8, D + 0.8, 1.0)
box("BpRed", 0, 0, 7.8, W + 0.4, D + 0.4, 1.4)
rrect("BpWhite", 0, 0, H, W + 3.0, D + 3.0, 0.9, 3.5, 5)
box("BpRed", 0, 0, H + 0.9, W + 3.2, D + 3.2, 0.35)
GY = D / 2 + 0.1
box("BpGlass", 0, GY, 1.2, W - 6, 0.3, 6.2)
for i in range(11):
    x = -(W - 6) / 2 + i * (W - 6) / 10
    box("BpDark", x, GY + 0.1, 1.0, 0.4, 0.5, 6.6)
box("BpDark", 0, GY + 0.1, 7.4, W - 5, 0.5, 0.4)
box("BpGlass", 0, GY + 0.05, 8.6, W - 8, 0.3, 1.8)
# pintu geser
box("BpDark", 0, GY + 0.3, 0, 7.0, 0.5, 6.6)
box("BpGlass", 0, GY + 0.55, 0.3, 6.0, 0.3, 5.8)
# kanopi pintu
box("BpRed", 0, GY + 2.2, 7.0, 10.0, 4.4, 0.4)
# lengkungan jendela samping
for sx in (-1, 1):
    for yy in (-6, 0, 6):
        box("BpGlass", sx * (W / 2 + 0.1), yy, 3.0, 0.3, 3.4, 4.0)
# papan logo di atap (teks di Roblox)
box("BpDark", 0, 2.0, H + 1.3, 18.0, 1.0, 4.4)
box("BpRed", 0, 2.0, H + 5.7, 18.4, 1.2, 0.4)

# ---- kanopi ----
CYN = 76.0
CW, CD = 70.0, 40.0
rrect("BpWhite", 0, CYN, 14.2, CW, CD, 1.8, 6.0, 5)
rrect("BpRed", 0, CYN, 13.5, CW + 0.6, CD + 0.6, 0.8, 6.2, 5)
rrect("BpGlass", 0, CYN, 16.0, CW - 6, CD - 6, 0.2, 4.0, 4)  # panel lampu/surya
for sx in (-1, 1):
    for sy in (-1, 1):
        cyl("BpWhite", sx * 28, CYN + sy * 14, 1.0, 0.9, 12.6, 16)
        cyl("BpRed", sx * 28, CYN + sy * 14, 1.0, 1.2, 1.2, 16)
# pulau + pompa
for sx in (-1, 1):
    px = sx * 14
    box("BpStone", px, CYN, 0.2, 4.0, 16.0, 0.9)
    for sy in (-1, 1):
        py = CYN + sy * 4.5
        box("BpWhite", px, py, 1.1, 2.4, 3.0, 4.2)
        box("BpRed", px, py, 5.3, 2.6, 3.2, 0.5)
        box("BpDark", px + 1.25, py, 3.0, 0.1, 2.2, 1.6)
        cyl("BpDark", px - 1.35, py, 1.4, 0.18, 2.6, 8)
        box("BpGlass", px + 1.28, py, 3.2, 0.1, 1.6, 1.0)
# ---- pilon harga di pojok ----
PX, PY = -80.0, 146.0
box("BpDark", PX, PY, 0, 2.0, 1.6, 9.0)
box("BpWhite", PX, PY, 9.0, 8.0, 1.6, 10.0)
box("BpRed", PX, PY, 18.6, 8.2, 1.8, 1.4)
box("BpRed", PX, PY, 8.6, 8.2, 1.8, 0.8)
for k in range(3):
    box("BpDark", PX, PY + 0.85, 10.4 + k * 2.6, 6.4, 0.2, 1.8)
    box("BpGold", PX - 2.0, PY + 1.0, 10.8 + k * 2.6, 2.4, 0.2, 1.0)
print(export(r"D:\ROBLOX STUDIO\assets\blender\spbu_modern.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_spbu.blend"))
