# Kapal A: speedboat putih-merah. Dipakai: exec(open(kapal_lib.py).read()); exec(open(kapal_a.py).read())
import math

W_ = (1, 1, 1)
C = {
    "Bawah": (0.62, 0.1, 0.1),
    "Garis": (0.08, 0.2, 0.5),
    "Badan": (0.96, 0.97, 0.98),
    "Geladak": (0.78, 0.66, 0.46),
    "Putih": (0.96, 0.97, 0.98),
    "Jok": (0.1, 0.32, 0.75),
    "Besi": (0.72, 0.74, 0.78),
    "Kaca": (0.55, 0.82, 0.95),
    "Hitam": (0.1, 0.1, 0.12),
    "Merah": (0.85, 0.12, 0.12),
    "LampuMerah": (1.0, 0.1, 0.1),
    "LampuHijau": (0.1, 0.9, 0.2),
}
b = Boat("SpeedBoat", C)
L, WID = 22.0, 7.4
b.hull(L, WID, 1.5, 1.9, 1.2, ("Bawah", "Garis", "Badan"), exp=1.8, bow_fine=0.5, stern_taper=0.06, split=(-0.2, 0.55))
b.deck("Geladak", inset=0.93, lift=0.03)


def dz(y):
    return b.deck_at(y)[1] + 0.03


def hw(y):
    return b.deck_at(y)[0] * 0.93


# --- konsol + kaca depan
yc = -2.6
b.box("Putih", (0, yc, dz(yc) + 0.75), (3.4, 2.0, 1.5))
b.box("Hitam", (0, yc - 0.2, dz(yc) + 1.52), (3.0, 1.3, 0.12))
b.torus("Hitam", (0, yc - 0.35, dz(yc) + 2.0), 0.42, 0.07, axis="Y", seg=16, tube=6)
b.tube("Hitam", (0, yc - 0.35, dz(yc) + 1.55), (0, yc - 0.35, dz(yc) + 1.95), 0.07)
yw = yc - 1.0
b.box("Kaca", (0, yw, dz(yc) + 2.25), (3.3, 0.1, 1.6), rot=(math.radians(-24), 0, 0))
for sx in (-1.7, 1.7):
    b.tube("Besi", (sx, yw + 0.25, dz(yc) + 1.45), (sx, yw - 0.2, dz(yc) + 3.0), 0.09)
b.tube("Besi", (-1.7, yw - 0.2, dz(yc) + 3.0), (1.7, yw - 0.2, dz(yc) + 3.0), 0.09)
# panel instrumen kecil
for i, cx in enumerate((-0.9, 0.0, 0.9)):
    b.cyl("Kaca", (cx, yc - 0.5, dz(yc) + 1.6), 0.18, 0.05, axis="Z", seg=10)

# --- jok (dua baris) + sandaran
for yb in (1.0, 5.2):
    b.box("Putih", (0, yb, dz(yb) + 0.35), (5.4, 2.0, 0.7))
    b.box("Jok", (0, yb, dz(yb) + 0.82), (5.3, 1.9, 0.32))
    b.box("Jok", (0, yb + 1.0, dz(yb) + 1.45), (5.3, 0.4, 1.3))
# bantalan berjemur di haluan
yp = -9.0
b.box("Jok", (0, yp, dz(yp) + 0.2), (3.2, 3.4, 0.4))

# --- pagar haluan
posts = [-7.5, -6.0, -4.5]
for s in (-1, 1):
    pts = []
    for y in posts:
        x = s * (hw(y) - 0.15)
        z = dz(y)
        b.tube("Besi", (x, y, z), (x, y, z + 0.95), 0.07)
        pts.append((x, y, z + 0.95))
    for p, q in zip(pts[:-1], pts[1:]):
        b.tube("Besi", p, q, 0.07)
b.tube("Besi", (-hw(-8.3) + 0.2, -8.3, dz(-8.3) + 0.9), (hw(-8.3) - 0.2, -8.3, dz(-8.3) + 0.9), 0.06)

# --- cleat + lampu haluan
for y in (-8.0, -1.5, 8.5):
    for s in (-1, 1):
        x = s * (hw(y) - 0.35)
        b.box("Besi", (x, y, dz(y) + 0.1), (0.9, 0.28, 0.2))
        b.box("Besi", (x, y, dz(y) + 0.28), (0.25, 0.28, 0.22))
b.sphere("LampuMerah", (-(hw(-8.6) - 0.25), -8.6, dz(-8.6) + 0.35), 0.25, seg=8)
b.sphere("LampuHijau", ((hw(-8.6) - 0.25), -8.6, dz(-8.6) + 0.35), 0.25, seg=8)

# --- motor tempel di buritan
ym = L / 2 + 0.9
zt = dz(L / 2 - 0.2)
b.box("Putih", (0, ym, zt + 1.0), (1.5, 2.2, 2.4))
b.box("Merah", (0, ym, zt + 2.15), (1.55, 2.25, 0.28))
b.box("Hitam", (0, ym + 1.15, zt + 1.0), (0.8, 0.3, 1.2))
b.tube("Besi", (0, ym, zt - 0.2), (0, ym, -2.1), 0.32)
b.box("Merah", (0, ym + 0.1, -2.3), (0.5, 1.5, 0.45))
b.cyl("Besi", (0, ym - 0.6, -2.3), 0.16, 0.3, axis="Y", seg=8)
for a in range(3):
    ang = a * math.tau / 3
    b.box("Besi", (0, ym - 0.78, -2.3), (0.08, 0.1, 1.5), rot=(0, 0, ang))

# --- lengkung penarik ski di buritan + bendera
yr = 8.8
for s in (-1, 1):
    b.tube("Besi", (s * (hw(yr) - 0.4), yr, dz(yr)), (s * 1.6, yr, dz(yr) + 2.6), 0.1)
b.tube("Besi", (-1.6, yr, dz(yr) + 2.6), (1.6, yr, dz(yr) + 2.6), 0.1)
b.tube("Besi", (0, 9.9, dz(9.9)), (0, 9.9, dz(9.9) + 3.2), 0.05)
b.prism("Merah", [(0, 9.9, dz(9.9) + 3.15), (0, 9.9, dz(9.9) + 2.55), (0, 11.0, dz(9.9) + 2.85)], 0.04)

# --- pelampung penyelamat dan kotak pendingin
b.torus("Merah", (hw(1.0) - 0.55, 1.0, dz(1.0) + 0.7), 0.5, 0.15, axis="X", seg=16, tube=6)
for a in range(4):
    ang = a * math.pi / 2
    b.box("Putih", (hw(1.0) - 0.55, 1.0 + 0.5 * math.cos(ang), dz(1.0) + 0.7 + 0.5 * math.sin(ang)), (0.34, 0.26, 0.26), rot=(ang, 0, 0))
b.box("Jok", (-2.8, 8.0, dz(8.0) + 0.45), (1.6, 1.2, 0.9))
b.box("Putih", (-2.8, 8.0, dz(8.0) + 0.95), (1.7, 1.3, 0.14))

objs = b.build(hull_mats=("Bawah", "Garis", "Badan", "Geladak"))
print([(o.name, len(o.data.polygons)) for o in objs])
