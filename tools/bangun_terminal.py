# Terminal bandara modern, garbarata, menara kontrol (tiga FBX). Depan terminal = +Y Blender (= -Z Roblox).
import math
exec(open(r"D:\ROBLOX STUDIO\tools\blender_lib.py").read())
OUT = r"D:\ROBLOX STUDIO\assets\blender"
report = {}

# ---------------------------------------------------------------- terminal
clear_scene()
M = Maker()
HW = 176.0  # setengah lebar bangunan kaca
GL_T = 22.0  # tinggi atas kaca
M.box("TmFloor", 0, 6, 0.6, 376, 112, 1.2)  # lantai + teras depan (y -50..62)

bays = 46
bw = 2 * HW / bays
for side in (1, -1):
    yy = side * 38.0
    for b in range(bays):
        cx = -HW + bw * (b + 0.5)
        M.box("TmGlass", cx, yy, 1.2 + (GL_T - 1.2) / 2, bw - 0.5, 0.3, GL_T - 1.2)
    for b in range(bays + 1):
        M.box("TmWhite", -HW + bw * b, yy, 1.2 + (GL_T - 1.2) / 2, 0.55, 1.0, GL_T - 1.2)
    # pita biru di bawah atap dan pelat bawah kaca
    M.box("TmFrame", 0, yy, 22.5, 2 * HW + 4, 1.4, 1.0)
    M.box("TmWhite", 0, yy, 1.5, 2 * HW, 1.1, 0.6)
# dinding ujung
for side in (1, -1):
    M.box("TmWhite", side * (HW + 1), 0, 11.5, 2.0, 76.6, 22.5)
# kolom dalam
for k in range(-8, 9):
    for side in (1, -1):
        M.cyl("TmWhite", (k * 21.5, side * 20.0, 12.1), 0.8, 21.8, "z", 10)
# meja check-in, bangku, lampu langit-langit
for cx in (-132, -80, -28, 28, 80, 132):
    M.box("TmCounter", cx, 2, 2.4, 30, 4.2, 2.4)
    M.box("TmDark", cx, 2, 3.8, 26, 3.4, 0.4)
    M.box("TmFrame", cx, 0.2, 7.5, 28, 0.6, 5.0)
    M.box("TmWhite", cx, 2, 12.5, 0.8, 0.8, 20)
for cx in range(-150, 151, 50):
    M.box("TmDark", cx, -26, 2.0, 22, 2.4, 1.6)
    M.box("TmDark", cx, -26, 3.0, 22, 0.6, 2.0)
for ry in (-24, -8, 8, 24):
    for cx in range(-165, 166, 55):
        M.box("TmLight", cx, ry, 22.6, 36, 1.2, 0.3)

# atap bergelombang: datar di bawah (z 23), gelombang di atas; menjorok ke depan (y 58) dan belakang (y -46)
xs = [(-190 + 5 * i) for i in range(77)]
tops = [25.0 + 3.0 * math.exp(-((x / 85.0) ** 2)) + 1.1 * math.sin(x / 11.0) for x in xs]
y0, y1 = -46.0, 58.0
v, f = [], []
for i, x in enumerate(xs):
    v += [(x, y0, 23.0), (x, y1, 23.0), (x, y0, tops[i]), (x, y1, tops[i])]
n = len(xs)
for i in range(n - 1):
    a, b = i * 4, (i + 1) * 4
    f += [(a + 2, b + 2, b + 3, a + 3), (a + 0, a + 1, b + 1, b + 0), (a + 1, a + 3, b + 3, b + 1), (a + 0, b + 0, b + 2, a + 2)]
f += [(0, 1, 3, 2), ((n - 1) * 4 + 0, (n - 1) * 4 + 2, (n - 1) * 4 + 3, (n - 1) * 4 + 1)]
M.solid("TmRoof", v, f)

# kanopi depan: tiang, papan nama, lampu tepi
for k in range(-8, 9):
    M.cyl("TmWhite", (k * 22.0, 55.0, 12.1), 0.7, 21.8, "z", 10)
M.box("TmFrame", 0, 58.6, 20.5, 214, 1.2, 5.0)
M.box("TmFrame", -150, 58.2, 21.0, 60, 1.0, 4.0)
M.box("TmFrame", 150, 58.2, 21.0, 60, 1.0, 4.0)
M.box("TmLight", 0, 56.0, 22.7, 360, 0.8, 0.3)
# pintu masuk tengah: bingkai tinggi
M.box("TmFrame", -16, 38.6, 12, 1.2, 1.4, 22)
M.box("TmFrame", 16, 38.6, 12, 1.2, 1.4, 22)
M.box("TmFrame", 0, 38.6, 18, 33, 1.4, 1.2)
# tangga/tepi teras
M.box("TmFloor", 0, 61.0, 0.35, 376, 2.0, 0.7)
objs = M.build()
report["terminal"] = export(objs, OUT + r"\terminal_bandara.fbx")
bpy.ops.wm.save_as_mainfile(filepath=OUT + r"\roblock_bandara_terminal.blend")

# ---------------------------------------------------------------- garbarata
clear_scene()
M = Maker()
L = 49.0
FZ = 5.4  # tinggi lantai
M.cyl("BrGray", (0, 0, 8.0), 5.4, 8.6, "z", 20)
M.cyl("BrYellow", (0, 0, 12.4), 5.6, 0.7, "z", 20)
M.box("BrWhite", 0, L / 2 - 1.5, FZ + 3.1, 5.6, L - 7, 6.4)
for side in (1, -1):
    M.box("BrGlass", side * 2.85, L / 2 - 1.5, FZ + 3.4, 0.25, L - 12, 2.4)
M.box("BrGray", 0, L / 2 - 1.5, FZ - 0.3, 5.9, L - 7, 0.7)
# lipatan akordeon dekat rotunda dan kabin
for yy in (4.2, 5.4, 6.6, 7.8):
    M.box("BrGray", 0, yy, FZ + 3.1, 6.1, 0.55, 6.7)
for yy in (L - 11.0, L - 9.8, L - 8.6):
    M.box("BrGray", 0, yy, FZ + 3.1, 6.1, 0.55, 6.7)
# kabin ujung
M.box("BrWhite", 0, L - 1.0, FZ + 3.2, 7.4, 6.0, 7.2)
M.box("BrYellow", 0, L + 2.3, FZ + 1.0, 7.6, 0.6, 1.4)
M.box("BrGlass", 0, L + 2.1, FZ + 4.7, 5.2, 0.3, 3.2)
M.box("BrGray", 0, L + 2.3, FZ + 6.4, 7.0, 0.7, 0.7)
M.box("BrYellow", 0, L - 1.0, FZ + 6.95, 7.6, 6.2, 0.5)
for side in (1, -1):
    M.box("BrGlass", side * 3.75, L - 1.0, FZ + 3.9, 0.25, 3.5, 2.6)
# tiang penyangga beroda
M.box("BrDark", 0, L - 6.0, 2.9, 1.6, 1.6, 5.4)
M.box("BrGray", 0, L - 6.0, 0.45, 5.2, 1.4, 0.9)
for sx in (-1, 1):
    M.cyl("BrDark", (sx * 2.4, L - 6.0, 0.9), 0.9, 0.7, "x", 12)
objs = M.build()
report["garbarata"] = export(objs, OUT + r"\garbarata.fbx")
bpy.ops.wm.save_as_mainfile(filepath=OUT + r"\roblock_bandara_garbarata.blend")

# ---------------------------------------------------------------- menara kontrol
clear_scene()
M = Maker()
SEG = 16


def circ(r, z, seg=SEG):
    return [(r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z) for k in range(seg)]


M.rings("TwWhite", [circ(8.2, 0), circ(6.2, 18), circ(5.4, 40), circ(5.0, 60)])
M.rings("TwRed", [circ(5.68, 40), circ(5.55, 44)])
M.rings("TwRed", [circ(5.45, 48), circ(5.32, 52)])
M.rings("TwWhite", [circ(5.0, 60), circ(5.0, 61.5), circ(10.5, 63.5)])
M.rings("TwGlass", [circ(10.6, 63.5), circ(12.2, 71.0)])
M.rings("TwDark", [circ(12.2, 71.0), circ(12.6, 71.8), circ(12.6, 72.6)])
M.rings("TwWhite", [circ(12.6, 72.6), circ(13.6, 73.2), circ(13.6, 74.0), circ(7.0, 76.5), circ(1.0, 77.5)])
M.cyl("TwRed", (0, 0, 83.0), 0.35, 11.0, "z", 8)
M.cyl("TwDark", (0, 0, 78.4), 1.4, 2.0, "z", 10)
for k in range(8):
    a = 2 * math.pi * k / 8
    M.box("TwDark", 12.45 * math.cos(a), 12.45 * math.sin(a), 67.2, 0.5, 0.5, 7.4)
objs = M.build()
report["menara"] = export(objs, OUT + r"\menara_bandara.fbx")
bpy.ops.wm.save_as_mainfile(filepath=OUT + r"\roblock_bandara_menara.blend")
print(report)
