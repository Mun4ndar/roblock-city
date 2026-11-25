# Minimarket SPBU yang bisa dimasuki: dinding berongga, pintu terbuka di depan, rak oli/snack/minuman,
# lemari pendingin, meja kasir, keranjang. Tengah = tengah denah, lantai z=0, depan = +Y (pintu).
# Denah dalam: x -19.2..19.2, y -11.2..11.2. Dipakai:
#   exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\spbu_minimarket.py", encoding="utf8").read(), "m", "exec"))
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Minimarket")
W, D, H = 40.0, 24.0, 11.0
HX, HY = W / 2, D / 2        # 20, 12
T = 0.8                      # tebal dinding
IX, IY = HX - T, HY - T      # sisi dalam 19.2 / 11.2
DOOR = 3.6                   # setengah lebar pintu

# ---------------------------------------------------------------- lantai
box("MtFloor", 0, 0, 0, W + 0.8, D + 0.8, 0.3)
nx, ny = 10, 6
tw, td = 2 * IX / nx, 2 * IY / ny
for i in range(nx):
    for j in range(ny):
        if (i + j) % 2 == 0:
            box("MtFloorB", -IX + (i + 0.5) * tw, -IY + (j + 0.5) * td, 0.3, tw, td, 0.03)
box("MtRed", 0, IY + 0.2, 0.3, 2 * DOOR - 0.6, 1.6, 0.06)  # keset pintu

# ---------------------------------------------------------------- dinding
# belakang
box("MtWall", 0, -HY + T / 2, 0, W, T, H)
box("MtRed", 0, -HY + T / 2 - 0.05, 7.8, W + 0.2, T + 0.1, 1.4)
# depan: kaki dinding, kaca, tiang, balok atas
for sx in (-1, 1):
    x0, x1 = DOOR, HX
    cx, w = sx * (x0 + x1) / 2, x1 - x0
    box("MtWall", cx, HY - T / 2, 0, w, T, 1.2)
    # kaca (antara kaki dinding dan balok atas)
    box("MtGlass", cx - sx * 0.1, HY - T / 2, 1.2, w - 0.8, 0.25, 6.2)
    n = 5
    for k in range(n + 1):
        px = sx * (x0 + 0.2 + k * (w - 0.6) / n)
        box("MtDark", px, HY - T / 2, 1.2, 0.35, 0.5, 6.4)
box("MtWall", 0, HY - T / 2, 7.4, W, T, H - 7.4)
box("MtRed", 0, HY - T / 2 + 0.05, 7.8, W + 0.2, T + 0.1, 1.4)
box("MtDark", 0, HY - T / 2, 7.2, W, 0.6, 0.3)
for sx in (-1, 1):
    box("MtDark", sx * DOOR, HY - T / 2, 0, 0.45, 0.9, 7.5)  # kusen pintu
# samping kiri/kanan: tiga jendela
wins = (-6.0, 0.0, 6.0)
hw = 1.8
for sx in (-1, 1):
    wx = sx * (HX - T / 2)
    edges = [-HY + T, -hw + wins[0] + 0 - 0]
    # potongan dinding antara jendela
    segs = [(-HY, wins[0] - hw), (wins[0] + hw, wins[1] - hw), (wins[1] + hw, wins[2] - hw), (wins[2] + hw, HY)]
    for (a, b_) in segs:
        box("MtWall", wx, (a + b_) / 2, 0, T, b_ - a, H)
    for yy in wins:
        box("MtWall", wx, yy, 0, T, 2 * hw, 3.0)
        box("MtWall", wx, yy, 6.6, T, 2 * hw, H - 6.6)
        box("MtGlass", wx, yy, 3.0, 0.2, 2 * hw, 3.6)
        for e in (-hw, hw):
            box("MtDark", wx, yy + e, 3.0, 0.45, 0.3, 3.6)
        box("MtDark", wx, yy, 3.0, 0.45, 2 * hw, 0.25)
        box("MtDark", wx, yy, 6.35, 0.45, 2 * hw, 0.25)
    box("MtRed", wx + sx * 0.05, 0, 7.8, T + 0.1, D, 1.4)
# pojok luar
for sx in (-1, 1):
    for sy in (-1, 1):
        box("MtDark", sx * (HX - 0.2), sy * (HY - 0.2), 0, 0.7, 0.7, H)

# ---------------------------------------------------------------- atap + langit-langit
rrect("MtRoofW", 0, 0, H, W + 3.0, D + 3.0, 0.9, 3.5, 5)
rrect("MtRed", 0, 0, H - 0.35, W + 3.2, D + 3.2, 0.5, 3.6, 5)
box("MtCeil", 0, 0, H - 1.0, 2 * IX, 2 * IY, 1.0)
for x in (-14.0, -5.0, 5.0, 14.0):
    box("MtLamp", x, 0, H - 1.05, 1.2, 15.0, 0.12)
# papan nama di atap (teks dipasang di Studio)
box("MtDark", 0, HY - 0.8, H + 0.9, 20.0, 1.0, 4.6)
box("MtRed", 0, HY - 0.8, H + 5.5, 20.4, 1.2, 0.35)
# kanopi pintu
box("MtRed", 0, HY + 2.4, 8.2, 11.0, 4.8, 0.45)
box("MtWhite", 0, HY + 2.4, 8.65, 11.0, 4.8, 0.12)
for sx in (-1, 1):
    tube_ = None
    box("MtDark", sx * 5.0, HY + 4.4, 0.3, 0.35, 0.35, 7.9)

# ---------------------------------------------------------------- isi toko
PRODUCT_SNACK = ("MtSnackR", "MtSnackY", "MtSnackB", "MtSnackG")
PRODUCT_DRINK = ("MtBottleB", "MtBottleG", "MtBottleO", "MtBottleR")


def shelf_row(x0, x1, cy, depth, levels, kinds, two_sided=True, back_panel=True):
    """rak gondola memanjang di X: x0..x1, tengah y=cy, produk di dua sisi."""
    L = x1 - x0
    cx = (x0 + x1) / 2
    box("MtShelfDark", cx, cy, 0.3, L, depth, 0.3)
    if back_panel and two_sided:
        box("MtShelfDark", cx, cy, 0.3, L, 0.12, levels[-1] + 1.0)
    for px in (x0, x1, cx):
        box("MtShelfDark", px, cy, 0.3, 0.25, depth, levels[-1] + 1.0)
    box("MtRed", cx, cy, levels[-1] + 1.3, L, depth, 0.2)  # lis atas
    for li, z in enumerate(levels):
        box("MtShelf", cx, cy, z, L, depth, 0.12)
        kind = kinds[li % len(kinds)]
        for side in ((-1, 1) if two_sided else (1,)):
            n = int(L / 0.95)
            for k in range(n):
                x = x0 + 0.6 + k * (L - 1.2) / max(n - 1, 1)
                oy = cy + side * (depth / 4 + 0.05)
                if kind == "oil":
                    nm = "MtOilY" if (k + li) % 2 == 0 else "MtOilK"
                    cyl(nm, x, oy, z + 0.12, 0.38, 0.95, 10)
                    cyl("MtDark", x, oy, z + 1.07, 0.18, 0.18, 8)
                elif kind == "drink":
                    nm = PRODUCT_DRINK[(k + li) % 4]
                    cyl(nm, x, oy, z + 0.12, 0.28, 0.95, 8)
                else:
                    nm = PRODUCT_SNACK[(k * 3 + li) % 4]
                    box(nm, x, oy, z + 0.12, 0.62, 0.3, 0.8 + 0.12 * ((k + li) % 3))


# dua baris rak di tengah-kiri
shelf_row(-17.0, -3.0, -1.0, 2.2, (0.65, 1.75, 2.85, 3.95), ("snack", "oil", "snack", "drink"))
shelf_row(-17.0, -3.0, -6.2, 2.2, (0.65, 1.75, 2.85, 3.95), ("oil", "drink", "snack", "snack"))

# rak dinding belakang bagian kiri (satu sisi) - oli dan snack
shelf_row(-18.6, 1.0, -IY + 1.0, 1.7, (0.65, 1.95, 3.25, 4.55, 5.85), ("oil", "snack", "drink", "snack", "oil"), two_sided=False, back_panel=False)
box("MtShelfDark", -8.8, -IY + 0.15, 0.3, 19.6, 0.2, 6.6)  # papan belakang rak dinding

# lemari pendingin minuman di dinding belakang kanan (4 pintu kaca)
FX0, FX1 = 4.0, 19.0
fcy = -IY + 1.2
box("MtFridge", (FX0 + FX1) / 2, fcy, 0.3, FX1 - FX0, 2.4, 7.2)
box("MtDark", (FX0 + FX1) / 2, fcy + 1.25, 0.3, FX1 - FX0, 0.15, 0.5)
fw = (FX1 - FX0) / 4
for i in range(4):
    cx = FX0 + (i + 0.5) * fw
    box("MtFridgeLit", cx, fcy + 1.22, 0.9, fw - 0.5, 0.1, 5.5)
    box("MtFridgeGlass", cx, fcy + 1.3, 0.9, fw - 0.3, 0.1, 5.7)
    box("MtDark", cx - fw / 2, fcy + 1.28, 0.8, 0.25, 0.25, 6.0)
    box("MtWhite", cx, fcy + 1.34, 4.3, 0.9, 0.05, 0.5)  # gagang
    for lv in range(4):
        z = 1.0 + lv * 1.35
        box("MtFridgeShelf", cx, fcy + 1.05, z, fw - 0.6, 0.6, 0.08)
        for k in range(4):
            nm = PRODUCT_DRINK[(i + k + lv) % 4]
            cyl(nm, cx - fw / 2 + 0.8 + k * (fw - 1.6) / 3, fcy + 1.05, z + 0.08, 0.26, 0.95, 8)
box("MtRed", (FX0 + FX1) / 2, fcy, 7.5, FX1 - FX0 + 0.2, 2.4, 0.3)

# tumpukan kaleng oli di sudut depan kiri (piramida)
for lv, n in enumerate((5, 4, 3, 2)):
    for k in range(n):
        x = -16.8 + (k - (n - 1) / 2) * 1.2 + 2.6
        nm = "MtOilY" if (k + lv) % 2 == 0 else "MtOilK"
        cyl(nm, x, 7.6, 0.3 + lv * 1.1, 0.5, 1.05, 12)
box("MtShelfDark", -14.2, 7.6, 0.3, 7.0, 2.0, 0.25)
# tumpukan keranjang merah dekat pintu kiri
for lv in range(5):
    box("MtRed", -6.0, 9.2, 0.3 + lv * 0.45, 1.8, 1.3, 0.55)
    box("MtDark", -6.0, 9.2, 0.65 + lv * 0.45, 1.5, 1.0, 0.12)

# meja kasir (L): memanjang di X dari x=5 sampai dinding kanan
CX0, CX1 = 5.0, IX
ccy = 6.0
box("MtCounter", (CX0 + CX1) / 2, ccy, 0.3, CX1 - CX0, 2.2, 3.1)
box("MtWhite", (CX0 + CX1) / 2, ccy, 3.4, CX1 - CX0 + 0.5, 2.8, 0.3)
box("MtRed", (CX0 + CX1) / 2, ccy + 1.12, 0.6, CX1 - CX0, 0.12, 0.35)
box("MtDark", 12.0, ccy - 0.4, 3.7, 1.8, 1.4, 0.8)
box("MtScreen", 12.0, ccy - 0.95, 4.5, 1.3, 0.1, 0.8)
box("MtDark", 12.0, ccy - 0.55, 4.4, 1.5, 0.2, 0.15)
box("MtDark", 9.0, ccy + 0.2, 3.7, 0.8, 0.9, 0.5)  # mesin kartu
# permen/cokelat di depan kasir
for k in range(6):
    box(PRODUCT_SNACK[k % 4], 6.0 + k * 0.8, ccy + 0.5, 3.7, 0.6, 0.3, 0.7)
# rak belakang kasir: dua papan dengan botol minyak kecil + kardus
box("MtShelfDark", 1.8, 1.8, 0.3, 0.3, 2.0, 5.0)

print(export(r"D:\ROBLOX STUDIO\assets\blender\spbu_minimarket.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_spbu_minimarket.blend"))
