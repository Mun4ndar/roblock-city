# Kapal C: kapal layar kecil (putih-biru-kayu).
import math

C = {
    "Bawah": (0.12, 0.2, 0.4),
    "Garis": (0.1, 0.35, 0.7),
    "Badan": (0.97, 0.97, 0.98),
    "Geladak": (0.74, 0.55, 0.34),
    "Kabin": (0.97, 0.97, 0.98),
    "Kaca": (0.45, 0.75, 0.92),
    "Kayu": (0.6, 0.4, 0.22),
    "Besi": (0.78, 0.8, 0.84),
    "Hitam": (0.1, 0.1, 0.12),
    "Layar": (0.98, 0.98, 0.96),
    "LayarBiru": (0.2, 0.5, 0.85),
    "Merah": (0.85, 0.15, 0.12),
    "Tali": (0.85, 0.78, 0.55),
    "Jok": (0.1, 0.3, 0.65),
}
b = Boat("Layar", C)
L, WID = 22.0, 6.6
b.hull(L, WID, 2.0, 1.4, 0.9, ("Bawah", "Garis", "Badan"), exp=1.9, bow_fine=0.55, stern_taper=0.18, split=(-0.5, 0.2), keel_rise=0.9)
b.deck("Geladak", inset=0.93, lift=0.03)


def dz(y):
    return b.deck_at(y)[1] + 0.03


def hw(y):
    return b.deck_at(y)[0] * 0.93


# --- kabin rendah
yc = 1.2
zb = dz(yc)
b.box("Kabin", (0, yc, zb + 0.7), (3.8, 6.0, 1.4))
b.box("Kayu", (0, yc, zb + 1.45), (3.6, 5.8, 0.12))
for s in (-1, 1):
    for k in range(3):
        y = yc - 1.8 + k * 1.8
        b.cyl("Kaca", (s * 1.93, y, zb + 0.8), 0.3, 0.1, axis="X", seg=10)
        b.cyl("Besi", (s * 1.96, y, zb + 0.8), 0.37, 0.06, axis="X", seg=12)
b.box("Kaca", (0, yc - 3.0, zb + 0.85), (2.4, 0.1, 0.5))
# pintu masuk (hatch) di belakang kabin
b.box("Kayu", (0, yc + 3.05, zb + 0.55), (1.3, 0.1, 1.1))
# tutup palka di atas kabin
b.box("Kaca", (0, yc - 0.6, zb + 1.55), (1.2, 1.2, 0.1))

# --- tiang utama, boom, layar
ym = -2.4
zm = dz(ym)
H = 15.0
b.tube("Besi", (0, ym, zm), (0, ym, zm + H), 0.17, seg=8)
b.tube("Besi", (0, ym, zm + 1.6), (0, ym + 7.8, zm + 1.9), 0.11, seg=8)  # boom
# layar utama (segitiga tipis)
b.prism("Layar", [(0, ym + 0.25, zm + 2.3), (0, ym + 0.25, zm + H - 0.3), (0, ym + 7.5, zm + 2.1)], 0.07)
# garis biru di layar
b.prism("LayarBiru", [(0, ym + 0.25, zm + H - 1.9), (0, ym + 0.25, zm + H - 0.3), (0, ym + 1.0, zm + H - 1.9)], 0.09)
# layar depan (jib) ke haluan
yb = -9.7
b.tube("Tali", (0, yb, dz(yb) + 0.3), (0, ym, zm + H - 0.5), 0.05)  # forestay
b.prism("Layar", [(0, ym - 0.4, zm + H - 1.6), (0, yb + 1.1, dz(yb) + 0.9), (0, ym - 0.4, zm + 2.2)], 0.06)
# bendera di puncak tiang
b.prism("Merah", [(0, ym, zm + H), (0, ym, zm + H - 0.6), (0, ym + 1.2, zm + H - 0.3)], 0.05)
# tali penyangga (shroud) kiri-kanan
for s in (-1, 1):
    b.tube("Tali", (0, ym, zm + H - 3.0), (s * (hw(ym) - 0.15), ym + 0.2, zm), 0.03)
    b.tube("Tali", (0, ym, zm + H - 3.0), (s * (hw(ym) - 0.15), ym + 1.8, zm), 0.03)
# backstay
b.tube("Tali", (0, ym, zm + H - 0.5), (0, L / 2 - 0.6, dz(L / 2 - 0.6) + 0.1), 0.03)

# --- pagar pengaman (stanchion + kawat)
for s in (-1, 1):
    pts = []
    for k in range(0, 10):
        y = -7.8 + k * 1.9
        x = s * (hw(y) - 0.12)
        b.tube("Besi", (x, y, dz(y)), (x, y, dz(y) + 0.75), 0.05)
        pts.append((x, y, dz(y) + 0.75))
    for p, q in zip(pts[:-1], pts[1:]):
        b.tube("Besi", p, q, 0.035)
# pulpit haluan
for s in (-1, 1):
    b.tube("Besi", (s * (hw(-8.4) - 0.1), -8.4, dz(-8.4)), (s * 0.5, -9.6, dz(-9.6) + 0.75), 0.05)
b.tube("Besi", (-0.5, -9.6, dz(-9.6) + 0.75), (0.5, -9.6, dz(-9.6) + 0.75), 0.05)

# --- kokpit: bangku, kemudi (tiller), winch
yk = 6.2
for s in (-1, 1):
    b.box("Kayu", (s * (hw(yk) - 0.7), yk, dz(yk) + 0.3), (1.0, 4.4, 0.6))
    b.box("Jok", (s * (hw(yk) - 0.7), yk, dz(yk) + 0.66), (0.95, 4.2, 0.14))
b.tube("Kayu", (0, L / 2 - 1.0, dz(L / 2) + 0.7), (0, 6.2, dz(6.2) + 0.9), 0.1)
b.sphere("Kayu", (0, 6.1, dz(6.2) + 0.92), 0.14, seg=6)
b.cyl("Besi", (1.2, 3.8, zb + 1.7), 0.22, 0.25, axis="Z", seg=10)
b.cyl("Besi", (-1.2, 3.8, zb + 1.7), 0.22, 0.25, axis="Z", seg=10)
# tangga/pelampung dan jangkar
b.torus("Merah", (hw(L / 2 - 1.4) - 0.2, L / 2 - 1.4, dz(L / 2 - 1.4) + 1.0), 0.45, 0.12, axis="X", seg=14, tube=6)
b.tube("Besi", (0, yb + 0.7, dz(yb + 0.7) + 0.15), (0, yb + 1.9, dz(yb + 1.9) + 0.15), 0.07)
# lampu navigasi
b.sphere("Merah", (-(hw(-8.8) - 0.15), -8.8, dz(-8.8) + 0.3), 0.18, seg=8)
b.sphere("Jok", ((hw(-8.8) - 0.15), -8.8, dz(-8.8) + 0.3), 0.18, seg=8)
# motor kecil tempel di cermin buritan
b.box("Hitam", (0, L / 2 + 0.55, 0.9), (0.6, 0.9, 1.0))
b.tube("Hitam", (0, L / 2 + 0.55, 0.5), (0, L / 2 + 0.55, -1.2), 0.15)

objs = b.build(hull_mats=("Bawah", "Garis", "Badan", "Geladak"))
print([(o.name, len(o.data.polygons)) for o in objs])
