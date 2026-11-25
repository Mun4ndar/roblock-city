# Perlengkapan lomba 17-an: tiang panjat pinang berhadiah dan karung goni.
# Dipakai: exec(open(helpers.py).read()); exec(open(lomba_17an.py).read())
# 1 unit = 1 stud, alas di z=0, pusat di x=y=0. Satu bahan = satu objek (satu MeshPart).
import math

# ---------------------------------------------------------------- panjat pinang
new_scene("Pinang")
box("Kayu", 0, 0, 0.0, 3.2, 3.2, 0.45)  # alas
cyl("Kayu", 0, 0, 0.45, 0.85, 23.6, seg=18, r2=0.68)  # batang pinang
for i in range(6):  # bekas olesan oli (cincin gelap tipis)
    cyl("Oli", 0, 0, 3.0 + i * 3.4, 0.9 - i * 0.03, 0.55, seg=18)
zt = 24.0
box("Besi", 0, 0, zt, 6.4, 0.3, 0.3)  # palang atas arah X
box("Besi", 0, 0, zt, 0.3, 6.4, 0.3)  # palang atas arah Y
for k, (mat, sx, sy) in enumerate([("HadiahMerah", 3.0, 0), ("HadiahBiru", -3.0, 0), ("HadiahKuning", 0, 3.0), ("HadiahHijau", 0, -3.0)]):
    box("Tali", sx, sy, zt - 1.3, 0.08, 0.08, 1.3)
    box(mat, sx, sy, zt - 2.6, 1.5, 1.5, 1.3)
    box("Pita", sx, sy, zt - 2.0, 1.56, 0.3, 0.3)
    box("Pita", sx, sy, zt - 2.6, 0.3, 1.56, 1.3)
cyl("Besi", 0, 0, zt + 0.3, 0.12, 2.2, seg=8)  # tiang kecil bendera
box("Merah", 0.85, 0, zt + 1.5, 1.5, 0.06, 0.5)
box("Putih", 0.85, 0, zt + 1.0, 1.5, 0.06, 0.5)
info1 = export(r"D:\ROBLOX STUDIO\assets\blender\panjat_pinang.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_lomba.blend")
print("pinang", info1)

# ---------------------------------------------------------------- karung goni
new_scene("Karung")
cyl("Goni", 0, 0, 0.0, 1.35, 3.0, seg=16, r2=1.15)
cyl("Goni", 0, 0, 2.9, 1.18, 0.45, seg=16, r2=1.3)  # bibir karung
cyl("Tali", 0, 0, 2.55, 1.2, 0.22, seg=16)
info2 = export(r"D:\ROBLOX STUDIO\assets\blender\karung_goni.fbx")
print("karung", info2)
