# ROBLOCK Mall modern. Depan = +Y. Dipasang di Roblox dengan putaran 180 derajat (depan mall menghadap +Z).
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))

new_scene("Mall")
W, D, H = 190.0, 120.0, 26.0
HW, HD = W / 2, D / 2

# --- badan ---
box("MlWall", 0, 0, 0, W, D, H)
box("MlStone", 0, 0, 0, W + 2.0, D + 2.0, 1.2)  # lis dasar
box("MlRoof", 0, 0, H, W + 2.0, D + 2.0, 1.0)
for s in (-1, 1):  # pagar atap
    box("MlWhite", 0, s * (HD + 0.4), H + 1.0, W + 2.8, 0.8, 1.8)
    box("MlWhite", s * (HW + 0.4), 0, H + 1.0, 0.8, D + 2.0, 1.8)
box("MlStone", 0, 0, H - 0.8, W + 2.4, D + 2.4, 0.8)  # kornis

# --- fasad depan (y = +60) ---
GY = HD + 0.15
box("MlGlass", 0, GY, 1.4, W - 8, 0.3, 8.0)  # etalase lantai dasar
n = int((W - 8) / 6)
for i in range(n + 1):
    x = -(W - 8) / 2 + i * (W - 8) / n
    box("MlDark", x, GY + 0.1, 1.2, 0.7, 0.6, 8.4)
box("MlDark", 0, GY + 0.1, 9.4, W - 6, 0.7, 0.6)
box("MlDark", 0, GY + 0.1, 1.2, W - 6, 0.7, 0.4)
box("MlGlass", 0, GY, 11.0, W - 8, 0.3, 13.0)  # kaca lantai atas
box("MlWhite", 0, GY + 0.2, 10.0, W - 4, 1.0, 1.0)  # pita pemisah
box("MlWhite", 0, GY + 0.2, 24.2, W - 4, 1.0, 1.0)
cols = ("MlCoral", "MlTeal", "MlYellow")
k = 0
x = -HW + 6
while x <= HW - 6 + 1e-6:  # sirip berwarna
    if abs(x) > 26:
        box(cols[k % 3], x, GY + 0.8, 10.4, 1.4, 1.8, 14.0)
        k += 1
    x += 8.0
# bidang masuk tengah: pintu kaca besar (portal ada di y=60)
box("MlDark", 0, GY + 0.2, 0.0, 17, 0.6, 11.4)
box("MlGlass", 0, GY + 0.45, 0.4, 14.6, 0.4, 9.6)
box("MlDark", 0, GY + 0.6, 0.4, 0.5, 0.5, 9.6)
for dx in (-7.3, 7.3):
    box("MlDark", dx, GY + 0.6, 0.4, 0.6, 0.5, 9.6)

# kanopi pintu masuk (terbuka, portal tetap terjangkau)
CX0, CY1 = 24.0, 74.0
box("MlWhite", 0, (HD + CY1) / 2, 15.0, 2 * CX0, CY1 - HD, 1.4)
box("MlDark", 0, CY1 - 0.4, 16.4, 2 * CX0 + 1.0, 1.2, 5.0)  # papan nama (teks di Roblox)
box("MlYellow", 0, CY1 - 0.4, 15.3, 2 * CX0 + 1.0, 1.3, 0.35)
box("MlYellow", 0, CY1 - 0.4, 21.4, 2 * CX0 + 1.0, 1.3, 0.35)
for sx in (-1, 1):
    for yy in (CY1 - 2.0, HD + 4.0):
        cyl("MlWhite", sx * (CX0 - 2.5), yy, 0.0, 1.1, 15.0, 20)
        cyl("MlStone", sx * (CX0 - 2.5), yy, 0.0, 1.6, 0.6, 20)
# lantai teras depan
box("MlStone", 0, (HD + CY1) / 2 + 2, 0, 2 * CX0 + 8, CY1 - HD + 4, 0.35)

# --- menara kaca sudut depan ---
for sx in (-1, 1):
    tx, ty = sx * 92.0, 54.0
    cyl("MlGlass", tx, ty, 0.0, 9.0, 34.0, 28)
    for zz in (0.0, 8.0, 17.0, 26.0):
        cyl("MlWhite", tx, ty, zz, 9.5, 1.0, 28)
    cyl("MlRoof", tx, ty, 34.0, 9.6, 1.2, 28)
    cyl("MlYellow", tx, ty, 35.2, 9.2, 0.6, 28)
    dome("MlGlass", tx, ty, 35.8, 6.0, 5.0, 20)
    cyl("MlDark", tx, ty, 40.6, 0.25, 6.0, 8, 0.08)
    ball("MlYellow", tx, ty, 46.8, 0.5)

# --- sisi dan belakang: celah kaca vertikal ---
for sx in (-1, 1):
    for yy in range(-50, 51, 10):
        box("MlGlass", sx * (HW + 0.15), yy, 5.0, 0.3, 4.0, 17.0)
        box("MlStone", sx * (HW + 0.2), yy, 4.6, 0.4, 5.0, 0.5)
        box("MlStone", sx * (HW + 0.2), yy, 22.0, 0.4, 5.0, 0.5)
for xx in range(-80, 81, 20):
    box("MlGlass", xx, -HD - 0.15, 5.0, 8.0, 0.3, 17.0)
    box("MlStone", xx, -HD - 0.2, 4.6, 9.0, 0.4, 0.5)
    box("MlStone", xx, -HD - 0.2, 22.0, 9.0, 0.4, 0.5)
# pintu servis belakang
for xx in (-60, 60):
    box("MlDark", xx, -HD - 0.3, 0, 10, 0.6, 8)

# --- atap: lanskap tong kaca + unit AC (taman atap ada di y -41..19) ---
for xx in (-45, -15, 15, 45):
    vault("MlGlass", xx, 44.0, H + 1.0, 18.0, 18.0, 6.0)
    box("MlWhite", xx - 9.0, 44.0, H + 1.0, 0.5, 18.0, 0.8)
    box("MlWhite", xx + 9.0, 44.0, H + 1.0, 0.5, 18.0, 0.8)
for xx in (-75, -50, -25, 0, 25, 50, 75):
    box("MlStone", xx, -50.0, H + 1.0, 10.0, 7.0, 3.2)
    cyl("MlDark", xx, -50.0, H + 4.2, 2.6, 0.5, 14)

info = export(r"D:\ROBLOX STUDIO\assets\blender\mall_modern.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_mall.blend")
print(info)
