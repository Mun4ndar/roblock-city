# Kapal B: kapal nelayan kayu berkabin (biru-putih-kayu).
import math

C = {
    "Bawah": (0.45, 0.12, 0.1),
    "Garis": (0.96, 0.96, 0.94),
    "Badan": (0.13, 0.38, 0.62),
    "Geladak": (0.72, 0.52, 0.32),
    "Kabin": (0.96, 0.96, 0.94),
    "Atap": (0.8, 0.22, 0.18),
    "Kaca": (0.55, 0.82, 0.95),
    "Kayu": (0.55, 0.36, 0.2),
    "Besi": (0.55, 0.57, 0.6),
    "Hitam": (0.1, 0.1, 0.12),
    "Kuning": (0.98, 0.78, 0.15),
    "Merah": (0.85, 0.15, 0.12),
    "Tali": (0.85, 0.75, 0.5),
    "Jaring": (0.3, 0.6, 0.45),
    "Lampu": (1.0, 0.85, 0.4),
}
b = Boat("Nelayan", C)
L, WID = 24.0, 8.4
b.hull(L, WID, 1.7, 2.1, 1.7, ("Bawah", "Garis", "Badan"), exp=1.5, bow_fine=0.42, stern_taper=0.04, split=(-0.2, 0.55), keel_rise=0.7)
b.deck("Geladak", inset=0.94, lift=0.03)


def dz(y):
    return b.deck_at(y)[1] + 0.03


def hw(y):
    return b.deck_at(y)[0] * 0.94


# --- pagar rendah di sisi lambung (kayu)
for s in (-1, 1):
    pts = []
    for k in range(0, 11):
        y = -9.5 + k * 1.9
        x = s * (hw(y) - 0.12)
        b.tube("Kayu", (x, y, dz(y)), (x, y, dz(y) + 0.8), 0.09)
        pts.append((x, y, dz(y) + 0.8))
    for p, q in zip(pts[:-1], pts[1:]):
        b.tube("Kayu", p, q, 0.1)

# --- kabin di buritan
yc = 5.2
zb = dz(yc)
b.box("Kabin", (0, yc, zb + 2.0), (5.4, 5.6, 4.0))
b.box("Atap", (0, yc, zb + 4.2), (6.2, 6.4, 0.45))
b.box("Kabin", (0, yc - 3.1, zb + 4.55), (6.0, 0.3, 0.3))
# jendela depan + samping (kaca menempel keluar sedikit)
b.box("Kaca", (0, yc - 2.84, zb + 2.5), (3.6, 0.12, 1.4))
for s in (-1, 1):
    b.box("Kaca", (s * 2.74, yc - 0.6, zb + 2.5), (0.12, 1.7, 1.3))
    b.box("Kaca", (s * 2.74, yc + 1.5, zb + 2.5), (0.12, 1.3, 1.3))
    b.box("Besi", (s * 2.76, yc - 0.6, zb + 1.7), (0.1, 1.9, 0.12))
# pintu belakang
b.box("Kayu", (0, yc + 2.84, zb + 1.5), (1.3, 0.12, 2.8))
b.sphere("Kuning", (0.4, yc + 2.92, zb + 1.5), 0.1, seg=6)
# lampu kabin + antena + radar
b.sphere("Lampu", (0, yc - 3.2, zb + 3.9), 0.28, seg=8)
b.tube("Besi", (1.9, yc + 1.6, zb + 4.4), (1.9, yc + 1.6, zb + 7.2), 0.07)
b.tube("Besi", (-1.9, yc + 1.6, zb + 4.4), (-1.9, yc + 1.6, zb + 6.4), 0.06)
b.box("Hitam", (0, yc, zb + 4.75), (1.4, 0.5, 0.2))
b.cyl("Hitam", (0, yc, zb + 5.05), 0.6, 0.16, axis="Z", seg=10)
# cerobong kecil
b.cyl("Hitam", (-1.8, yc + 2.2, zb + 5.0), 0.3, 1.5, axis="Z", seg=8)
b.cyl("Merah", (-1.8, yc + 2.2, zb + 5.75), 0.33, 0.2, axis="Z", seg=8)

# --- tiang derek dan boom di depan kabin
ym = -1.2
b.tube("Kayu", (0, ym, dz(ym)), (0, ym, dz(ym) + 7.0), 0.22)
b.tube("Kayu", (0, ym, dz(ym) + 6.2), (0, ym - 4.0, dz(ym) + 3.4), 0.12)
b.tube("Tali", (0, ym - 4.0, dz(ym) + 3.4), (0, ym - 4.0, dz(ym) + 1.8), 0.04)
b.sphere("Merah", (0, ym - 4.0, dz(ym) + 1.65), 0.2, seg=8)
b.tube("Tali", (0, ym, dz(ym) + 6.6), (hw(ym - 1) - 0.4, ym + 1.2, dz(ym)), 0.03)
b.tube("Tali", (0, ym, dz(ym) + 6.6), (-hw(ym - 1) + 0.4, ym + 1.2, dz(ym)), 0.03)
b.prism("Merah", [(0, ym, dz(ym) + 7.0), (0, ym, dz(ym) + 6.3), (0, ym + 1.6, dz(ym) + 6.65)], 0.04)

# --- peti ikan, tong, jaring, tali
for i, (x, y) in enumerate(((-2.0, -4.8), (-0.9, -4.8), (-1.45, -4.8))):
    pass
for k, (x, y, h) in enumerate(((-2.4, -5.4, 0.7), (-1.2, -5.4, 0.7), (-1.8, -5.4, 1.4), (2.3, -4.6, 0.7))):
    b.box("Kuning", (x, y, dz(y) + h / 2 + (0.7 if h > 1 else 0) * 0.5), (1.0, 1.0, 0.7))
for x, y in ((2.3, -3.2), (2.5, -1.9)):
    b.cyl("Badan", (x, y, dz(y) + 0.65), 0.55, 1.3, axis="Z", seg=12)
    b.cyl("Besi", (x, y, dz(y) + 0.85), 0.57, 0.09, axis="Z", seg=12)
    b.cyl("Besi", (x, y, dz(y) + 0.4), 0.57, 0.09, axis="Z", seg=12)
# tumpukan jaring
b.sphere("Jaring", (-2.5, 9.4, dz(9.4) + 0.5), 1.0, scale=(1.2, 1.0, 0.55), seg=10)
b.torus("Tali", (2.5, 9.0, dz(9.0) + 0.2), 0.7, 0.18, axis="Z", seg=16, tube=6)
b.torus("Tali", (2.5, 9.0, dz(9.0) + 0.5), 0.6, 0.18, axis="Z", seg=16, tube=6)
# ban pelindung di sisi lambung
for s in (-1, 1):
    for y in (-3.0, 1.0, 5.0):
        b.torus("Hitam", (s * (hw(y) + 0.1), y, 1.2), 0.38, 0.14, axis="X", seg=12, tube=6)
# jangkar di haluan
ya = -9.3
b.tube("Besi", (0.0, ya, dz(ya) + 0.2), (0.0, ya + 1.0, dz(ya) + 0.2), 0.08)
b.box("Besi", (0.0, ya + 1.0, dz(ya) + 0.35), (0.9, 0.1, 0.1))
b.sphere("Besi", (0, ya, dz(ya) + 0.3), 0.12, seg=6)
# kemudi dan penyangga di buritan
b.box("Kayu", (0, L / 2 + 0.5, 0.6), (0.2, 1.2, 1.6))
# kunci/engsel (detail kecil) dan lampu navigasi
b.sphere("Merah", (-(hw(-9.5) - 0.2), -9.5, dz(-9.5) + 0.55), 0.2, seg=8)
b.sphere("Jaring", ((hw(-9.5) - 0.2), -9.5, dz(-9.5) + 0.55), 0.2, seg=8)
# bendera di tiang kabin
b.tube("Besi", (-2.4, yc - 0.5, zb + 4.4), (-2.4, yc - 0.5, zb + 6.0), 0.05)
b.prism("Kuning", [(-2.4, yc - 0.5, zb + 5.95), (-2.4, yc - 0.5, zb + 5.4), (-2.4, yc - 1.6, zb + 5.7)], 0.04)

objs = b.build(hull_mats=("Bawah", "Garis", "Badan", "Geladak"))
print([(o.name, len(o.data.polygons)) for o in objs])
