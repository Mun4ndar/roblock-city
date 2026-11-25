# ROBLOCK Resort: interior lobi hotel (lobi + resepsionis, restoran kiri, lounge + bar kanan).
# Dijalankan lewat Blender MCP: exec(helpers.py) lalu exec(file ini). 1 unit = 1 stud, depan = +Y, atas = +Z.
# Ruang dalam: x -67.5..67.5, y -17.5..17.5, lantai z 1.0, langit-langit z 10.0.
# Menulis juga map/ResortDalamData.luau (kotak tabrakan, kursi, titik lampu) supaya Luau tidak menyalin angka.
import math
import random

new_scene("ResortDalam")
OUT = r"D:\ROBLOX STUDIO\assets\blender\resort_dalam.fbx"
BLEND = r"D:\ROBLOX STUDIO\assets\blender\roblock_resort_dalam.blend"
DATA = r"D:\ROBLOX STUDIO\map\ResortDalamData.luau"
F = 1.0
CE = 10.0
IX, IY = 67.5, 17.5
rnd = random.Random(11)

SOLIDS = []  # (nama, x0, x1, y0, y1, z0, z1)
SEATS = []  # (nama, x, y, tinggi permukaan, yaw derajat arah hadap)
LAMPS = []  # (x, y, z, kecerahan, jangkauan)


def solid(name, cx, cy, sx, sy, z0, z1, yaw=0.0):
    if yaw % 180 == 90:
        sx, sy = sy, sx
    SOLIDS.append((name, round(cx - sx / 2, 2), round(cx + sx / 2, 2), round(cy - sy / 2, 2), round(cy + sy / 2, 2), z0, z1))


def rbox(m, cx, cy, z0, sx, sy, sz, yaw=0.0):
    b = bm(m)
    r = bmesh.ops.create_cube(b, size=1.0)
    bmesh.ops.scale(b, vec=(sx, sy, sz), verts=r["verts"])
    if yaw:
        bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(yaw), 3, "Z"), verts=r["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, z0 + sz / 2), verts=r["verts"])


class G:
    """kelompok perabot: titik (x, y), diputar yaw derajat (0 = menghadap +Y, positif = berlawanan jarum jam)."""

    def __init__(s, x, y, yaw=0.0):
        s.x, s.y, s.yaw = x, y, yaw
        s.c, s.s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def pt(s, dx, dy):
        return (s.x + dx * s.c - dy * s.s, s.y + dx * s.s + dy * s.c)

    def box(s, m, dx, dy, z0, sx, sy, sz):
        px, py = s.pt(dx, dy)
        rbox(m, px, py, z0, sx, sy, sz, s.yaw)

    def cyl(s, m, dx, dy, z0, r, h, seg=20, r2=None):
        px, py = s.pt(dx, dy)
        cyl(m, px, py, z0, r, h, seg, r2)

    def ball(s, m, dx, dy, z, r, seg=10):
        px, py = s.pt(dx, dy)
        ball(m, px, py, z, r, seg)


# ============================================================ lantai
# lobi tengah: marmer krem + kotak gelap bergantian
box("RdFloorA", 0, 0, 0.9, 44.4, 35.0, 0.1)
NX, NY = 16, 12
tx, ty = 44.0 / NX, 34.6 / NY
for i in range(NX):
    for j in range(NY):
        if (i + j) % 2:
            box("RdFloorB", -22 + (i + 0.5) * tx, -17.3 + (j + 0.5) * ty, 1.0, tx, ty, 0.02)
# restoran kiri: parket kayu, lounge kanan: karpet biru toska
box("RdWood", -44.95, 0, 0.9, 45.1, 35.0, 0.1)
for i in range(11):
    box("RdWoodD", -66.0 + i * 4.1, 0, 1.0, 0.08, 35.0, 0.01)
box("RdCarpet", 44.95, 0, 0.9, 45.1, 35.0, 0.1)
box("RdCarpetB", 44.95, 0, 1.0, 40.0, 30.0, 0.02)
# karpet bundar di tengah lobi
cyl("RdGoldT", 0, 4.0, 1.0, 7.3, 0.03, 48)
cyl("RdRug", 0, 4.0, 1.0, 7.0, 0.05, 48)
cyl("RdRugB", 0, 4.0, 1.0, 5.6, 0.06, 48)
cyl("RdRug", 0, 4.0, 1.0, 4.4, 0.07, 48)
# jalur masuk
box("RdRug", 0, 13.5, 1.0, 5.0, 8.0, 0.05)
box("RdGoldT", -2.6, 13.5, 1.0, 0.15, 8.0, 0.06)
box("RdGoldT", 2.6, 13.5, 1.0, 0.15, 8.0, 0.06)

# ============================================================ dinding dalam: panel kayu, kornis
H = 4.2
def panel(x, y, sx, sy):
    box("RdPanel", x, y, F, sx, sy, H)
    box("RdGoldT", x, y, F + H, sx + (0.1 if sx > sy else 0), sy + (0.1 if sy > sx else 0), 0.15)
panel(0, -IY + 0.075, 2 * IX, 0.15)
panel(-IX + 0.075, 0, 0.15, 2 * IY)
panel(IX - 0.075, 0, 0.15, 2 * IY)
for sx in (-1, 1):
    panel(sx * 10.75, IY - 0.075, 12.5, 0.15)
    panel(sx * 66.75, IY - 0.075, 1.5, 0.15)
# kornis hijau toska di bawah langit-langit
box("RdTeal", 0, -IY + 0.2, CE - 0.5, 2 * IX, 0.4, 0.5)
box("RdTeal", -IX + 0.2, 0, CE - 0.5, 0.4, 2 * IY, 0.5)
box("RdTeal", IX - 0.2, 0, CE - 0.5, 0.4, 2 * IY, 0.5)
for sx in (-1, 1):
    box("RdTeal", sx * 42.0, IY - 0.2, CE - 0.5, 50, 0.4, 0.5)

# ============================================================ sekat antar ruang (x = +-22.4), bukaan lebar y -6..6
PX = 22.4
for sx in (-1, 1):
    for (y0, y1) in ((6.0, IY), (-IY, -6.0)):
        cy, sy = (y0 + y1) / 2, y1 - y0
        box("RdWall", sx * PX, cy, 0.9, 0.8, sy, CE - 0.9)
        box("RdPanel", sx * (PX - 0.45), cy, F, 0.1, sy, H)
        box("RdPanel", sx * (PX + 0.45), cy, F, 0.1, sy, H)
        box("RdGoldT", sx * (PX - 0.5), cy, F + H, 0.12, sy, 0.12)
        box("RdGoldT", sx * (PX + 0.5), cy, F + H, 0.12, sy, 0.12)
        solid("Sekat", sx * PX, cy, 0.8, sy, F, CE)
    box("RdWall", sx * PX, 0, 8.4, 0.8, 12.0, CE - 8.4)  # ambang bukaan
    box("RdTeal", sx * PX, 0, 8.2, 0.9, 12.2, 0.25)
    for sy_ in (-6.0, 6.0):  # tiang kolom emas di tepi bukaan
        cyl("RdGoldT", sx * PX, sy_, F, 0.45, CE - F, 14)
        solid("Kolom", sx * PX, sy_, 0.9, 0.9, F, CE)

# ============================================================ perabot
def sofa(g, name, wide=4.6, seats=2):
    g.box("RdSofa", 0, 0, F + 0.35, wide, 2.0, 0.55)  # dudukan
    g.box("RdSofaB", 0, -0.82, F + 0.9, wide, 0.5, 1.45)  # sandaran
    for sx in (-1, 1):
        g.box("RdSofa", sx * (wide / 2 - 0.25), -0.05, F + 0.35, 0.5, 2.0, 1.15)
    for k in range(seats):
        cx = (k + 0.5) * (wide - 1.0) / seats - (wide - 1.0) / 2
        g.box("RdSofaB", cx, 0.18, F + 0.9, (wide - 1.2) / seats, 1.5, 0.3)
    g.box("RdWoodD", -wide / 2 + 0.3, 0.7, F, 0.25, 0.25, 0.35)
    g.box("RdWoodD", wide / 2 - 0.3, 0.7, F, 0.25, 0.25, 0.35)
    g.box("RdWoodD", -wide / 2 + 0.3, -0.8, F, 0.25, 0.25, 0.35)
    g.box("RdWoodD", wide / 2 - 0.3, -0.8, F, 0.25, 0.25, 0.35)
    px, py = g.pt(0, 0)
    solid(name, px, py, wide, 2.0, F, F + 2.4, g.yaw)
    for k in range(seats):
        cx = (k + 0.5) * (wide - 1.0) / seats - (wide - 1.0) / 2
        sx_, sy_ = g.pt(cx, 0.15)
        SEATS.append((name, round(sx_, 2), round(sy_, 2), F + 1.2, g.yaw))


def armchair(g, name):
    sofa(g, name, wide=2.6, seats=1)


def coffee_table(x, y):
    g = G(x, y)
    g.cyl("RdWoodD", 0, 0, F + 0.1, 0.18, 1.05, 10)
    g.cyl("RdWoodD", 0, 0, F, 0.7, 0.12, 16)
    g.cyl("RdGoldT", 0, 0, F + 1.1, 1.35, 0.1, 24)
    g.cyl("RdGlassT", 0, 0, F + 1.2, 1.25, 0.08, 24)
    g.cyl("RdPaper", 0.3, 0.2, F + 1.28, 0.35, 0.03, 12)
    g.ball("RdFlower", -0.3, -0.2, F + 1.65, 0.28)
    g.cyl("RdGlassT", -0.3, -0.2, F + 1.28, 0.14, 0.25, 8)
    solid("MejaKopi", x, y, 2.7, 2.7, F, F + 1.35)


def plant(x, y, h=4.5, big=True):
    g = G(x, y)
    g.cyl("RdPot", 0, 0, F, 1.1, 1.6, 16, 0.9)
    g.cyl("RdSoil", 0, 0, F + 1.5, 0.9, 0.1, 12)
    g.cyl("RdWoodD", 0, 0, F + 1.5, 0.2, h - 1.5, 8)
    for k in range(6):
        a = k * math.pi / 3
        g.ball("RdLeaf", math.cos(a) * 0.9, math.sin(a) * 0.9, F + h - 0.6 + (k % 2) * 0.5, 0.95, 8)
    g.ball("RdLeaf", 0, 0, F + h + 0.5, 1.2, 8)
    solid("Tanaman", x, y, 2.2, 2.2, F, F + 2.0)


def chair(g, name):
    for dx in (-0.45, 0.45):
        for dy in (-0.45, 0.45):
            g.box("RdWoodL", dx, dy, F, 0.12, 0.12, 1.4)
    g.box("RdWoodL", 0, 0, F + 1.4, 1.1, 1.1, 0.14)
    g.box("RdTealCush", 0, 0.02, F + 1.54, 0.95, 0.95, 0.12)
    g.box("RdWoodL", 0, -0.5, F + 1.54, 1.1, 0.12, 1.3)
    sx_, sy_ = g.pt(0, 0.05)
    SEATS.append((name, round(sx_, 2), round(sy_, 2), F + 1.66, g.yaw))


def dining_table(x, y, i):
    g = G(x, y)
    g.cyl("RdLinen", 0, 0, F, 1.05, 2.35, 24, 1.55)  # taplak menjuntai
    g.cyl("RdLinen", 0, 0, F + 2.3, 1.6, 0.12, 24)
    g.cyl("RdTeal", 0, 0, F + 2.42, 0.5, 0.03, 16)  # alas tengah
    g.cyl("RdGlassT", 0, 0, F + 2.42, 0.1, 0.55, 8)
    g.ball("RdFlower", 0, 0, F + 3.05, 0.3)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        g.cyl("RdPlate", math.cos(a) * 1.1, math.sin(a) * 1.1, F + 2.42, 0.38, 0.05, 12)
    solid("MejaMakan", x, y, 3.3, 3.3, F, F + 2.5)
    for k in range(4):
        th = k * math.pi / 2 + math.pi / 4
        cx, cy = x + math.cos(th) * 2.4, y + math.sin(th) * 2.4
        chair(G(cx, cy, math.degrees(th) + 90), "KursiMakan")


def stool(x, y):
    g = G(x, y)
    g.cyl("RdMetalD", 0, 0, F, 0.5, 0.1, 12)
    g.cyl("RdMetalD", 0, 0, F, 0.1, 2.8, 8)
    g.cyl("RdTealCush", 0, 0, F + 2.8, 0.6, 0.35, 14)
    SEATS.append(("KursiBar", x, y, F + 3.15, 180.0))  # menghadap bar (-Y)
    solid("KursiBar", x, y, 1.2, 1.2, F, F + 3.15)


# ---------------- lobi tengah ----------------
# meja resepsionis (belakang tengah)
RY = -9.0
box("RdWood", 0, RY, F, 18.0, 2.0, 3.5)
box("RdMarble", 0, RY, F + 3.5, 18.8, 2.7, 0.22)
box("RdNeon", 0, RY + 1.03, F + 0.2, 16.5, 0.08, 0.25)
box("RdPanelL", 0, RY + 1.0, F + 0.7, 17.0, 0.06, 2.4)
box("RdMarble", 0, RY - 1.2, F + 2.6, 18.0, 0.5, 0.15)  # rak belakang
for k in range(5):
    box("RdSteelD", -6.0 + k * 3.0, RY - 0.2, F + 3.72, 0.7, 0.5, 0.45)  # komputer
    box("RdScreen", -6.0 + k * 3.0 + 0.0, RY - 0.4, F + 3.9, 1.2, 0.08, 0.8) if k in (0, 2, 4) else None
solid("MejaResepsionis", 0, RY, 18.8, 2.7, F, F + 3.8)
# lonceng meja dan alat tulis
cyl("RdGoldT", 3.0, RY + 0.7, F + 3.72, 0.35, 0.08, 12)
ball("RdGoldT", 3.0, RY + 0.7, F + 3.8, 0.28, 8)
# rak kunci kamar di dinding belakang
box("RdWoodD", 0, -IY + 0.35, F + 3.6, 11.0, 0.5, 4.4)
for r in range(3):
    for c in range(10):
        box("RdWall", -4.5 + c * 1.0, -IY + 0.62, F + 3.8 + r * 1.3, 0.8, 0.05, 1.0)
        ball("RdGoldT", -4.5 + c * 1.0, -IY + 0.68, F + 4.3 + r * 1.3, 0.12, 6)
# lengkung emas penanda lobi di atas rak
box("RdGoldT", 0, -IY + 0.25, F + 8.2, 14.0, 0.2, 0.2)

# meja concierge (kiri depan meja resepsionis)
CY = -3.6
box("RdWood", -15.0, CY, F, 5.4, 1.6, 3.2)
box("RdMarble", -15.0, CY, F + 3.2, 5.8, 2.0, 0.2)
box("RdNeon", -15.0, CY + 0.82, F + 0.2, 4.8, 0.08, 0.22)
box("RdSteelD", -15.0, CY - 0.3, F + 3.4, 0.7, 0.5, 0.45)
solid("MejaConcierge", -15.0, CY, 5.8, 2.0, F, F + 3.4)
# dudukan koper dan tiang pembatas dekat pintu (kanan)
for k in range(2):
    cyl("RdGoldT", 11.0 + k * 3.0, 11.5, F, 0.12, 2.2, 8)
    cyl("RdGoldT", 11.0 + k * 3.0, 11.5, F, 0.4, 0.08, 10)
box("RdRopeR", 12.5, 11.5, F + 1.9, 3.0, 0.08, 0.1)
box("RdMetalD", 14.0, 13.5, F, 3.0, 0.1, 0.06)  # tempat parkir kereta koper

# meja bunga besar di tengah karpet
c0 = G(0, 4.0)
c0.cyl("RdMarble", 0, 0, F, 0.9, 0.12, 20)
c0.cyl("RdMarble", 0, 0, F + 0.1, 0.35, 3.2, 14)
c0.cyl("RdMarble", 0, 0, F + 3.2, 1.9, 0.22, 28)
c0.cyl("RdGoldT", 0, 0, F + 3.4, 1.95, 0.08, 28)
c0.cyl("RdPot", 0, 0, F + 3.45, 0.55, 0.9, 12)
for k in range(9):
    a = k * 2 * math.pi / 9
    c0.ball("RdFlower" if k % 2 else "RdFlowerB", math.cos(a) * 0.55, math.sin(a) * 0.55, F + 4.9, 0.4, 8)
c0.ball("RdLeaf", 0, 0, F + 4.9, 0.75, 8)
solid("MejaBunga", 0, 4.0, 3.8, 3.8, F, F + 3.7)

# kelompok sofa lobi
sofa(G(-18.4, 5.0, -90), "SofaLobiKiri", 5.0, 2)
armchair(G(-13.0, 0.4, 0), "KursiLobiKiri1")
armchair(G(-13.0, 9.6, 180), "KursiLobiKiri2")
coffee_table(-13.0, 5.0)
sofa(G(18.4, 5.0, 90), "SofaLobiKanan", 5.0, 2)
armchair(G(13.0, 0.4, 0), "KursiLobiKanan1")
armchair(G(13.0, 9.6, 180), "KursiLobiKanan2")
coffee_table(13.0, 5.0)
for (px, py) in [(-20.5, 15.8), (20.5, 15.8), (-20.5, -15.5), (20.5, -15.5), (-6.5, 15.8), (6.5, 15.8)]:
    plant(px, py)

# lift (dinding belakang kiri dan kanan)
for sx in (-1, 1):
    for k in range(2):
        cx = sx * (13.0 + 1.9 + k * 3.8)
        box("RdSteelD", cx, -IY + 0.15, F, 3.4, 0.3, 7.2)
        box("RdSteel", cx, -IY + 0.32, F + 0.2, 1.55, 0.06, 6.8)
        box("RdSteel", cx + 0.0, -IY + 0.32, F + 0.2, 0.05, 0.07, 6.8)
        box("RdSteel", cx + 0.8, -IY + 0.32, F + 0.2, 1.55, 0.06, 6.8) if False else None
    box("RdGoldT", sx * 18.8, -IY + 0.35, F + 7.6, 8.6, 0.12, 0.2)
    box("RdNeon", sx * 22.0 - sx * 0.6, -IY + 0.35, F + 3.0, 0.15, 0.06, 0.4)  # tombol panggil
    box("RdWoodD", sx * 18.8, -IY + 0.1, F + 7.2, 8.0, 0.15, 0.2)

# ---------------- restoran (kiri) ----------------
tbl = 0
for yy in (8.5, -1.0):
    for xx in (-60.0, -50.0, -40.0, -30.0):
        dining_table(xx, yy, tbl)
        tbl += 1
# meja prasmanan di depan dapur terbuka
BY = -11.6
box("RdWood", -49.0, BY, F, 30.0, 1.8, 3.2)
box("RdMarble", -49.0, BY, F + 3.2, 30.8, 2.4, 0.2)
box("RdNeon", -49.0, BY + 0.92, F + 0.2, 28.0, 0.08, 0.22)
box("RdGlassT", -49.0, BY + 0.7, F + 3.4, 29.0, 0.06, 1.1)  # pelindung batuk kaca
solid("Prasmanan", -49.0, BY, 30.8, 2.4, F, F + 3.4)
for k in range(8):
    bx = -62.0 + k * 3.55
    box("RdSteel", bx, BY, F + 3.4, 2.8, 1.5, 0.12)
    cyl(["RdFood", "RdFoodB", "RdFoodC", "RdFoodD"][k % 4], bx, BY, F + 3.5, 1.0, 0.35, 14)
    dome("RdSteel", bx, BY, F + 3.5, 1.15, 0.8) if k % 2 == 0 else None
# dapur: kabinet belakang + kompor + kap
box("RdSteelD", -49.0, -IY + 1.0, F, 30.0, 2.0, 3.2)
box("RdMarble", -49.0, -IY + 1.0, F + 3.2, 30.0, 2.2, 0.18)
for k in range(5):
    cyl("RdDark", -60.0 + k * 3.0, -IY + 1.0, F + 3.38, 0.6, 0.06, 12)
    cyl("RdDark", -60.0 + k * 3.0 + 1.2, -IY + 1.0, F + 3.38, 0.4, 0.06, 12)
box("RdSteel", -57.0, -IY + 0.8, F + 7.0, 11.0, 1.4, 1.2)  # kap asap
box("RdSteel", -57.0, -IY + 0.35, F + 4.2, 0.9, 0.5, 4.0)
box("RdWoodD", -39.0, -IY + 0.45, F + 3.6, 12.0, 0.7, 0.18)  # rak piring
for k in range(14):
    cyl("RdPlate", -44.5 + k * 0.9, -IY + 0.5, F + 3.78, 0.35, 0.05, 10)
solid("DapurKabinet", -49.0, -IY + 1.0, 30.0, 2.0, F, F + 3.4)
# papan menu gantung di atas prasmanan: dibuat di Luau (SurfaceGui)

# ---------------- lounge & bar (kanan) ----------------
BR = -11.6
box("RdWoodD", 46.0, BR, F, 32.0, 1.9, 3.3)
box("RdMarble", 46.0, BR, F + 3.3, 33.0, 2.7, 0.22)
box("RdNeonB", 46.0, BR + 0.98, F + 0.2, 30.0, 0.08, 0.22)
box("RdPanelL", 46.0, BR + 0.96, F + 0.7, 30.5, 0.05, 2.3)
solid("MejaBar", 46.0, BR, 33.0, 2.7, F, F + 3.5)
for k in range(7):
    stool(32.0 + k * 4.3, -9.4)
# rak botol dan cermin di dinding belakang
box("RdWoodD", 46.0, -IY + 0.45, F + 3.4, 32.0, 0.8, 0.18)
box("RdWoodD", 46.0, -IY + 0.45, F + 5.2, 32.0, 0.8, 0.18)
box("RdWoodD", 46.0, -IY + 0.45, F + 7.0, 32.0, 0.8, 0.18)
box("RdMirror", 46.0, -IY + 0.08, F + 3.4, 32.0, 0.05, 5.6)
for row in range(3):
    for k in range(28):
        bx = 31.0 + k * 1.12
        col = ["RdBottleA", "RdBottleB", "RdBottleC", "RdBottleD"][rnd.randint(0, 3)]
        cyl(col, bx, -IY + 0.5, F + 3.55 + row * 1.8, 0.2, 0.9 + rnd.random() * 0.3, 8)
solid("RakBar", 46.0, -IY + 0.6, 32.0, 1.0, F, F + 3.4)
# lemari es + dispenser di ujung bar
box("RdSteel", 63.2, -14.5, F, 2.2, 2.2, 5.2)
box("RdSteelD", 63.2, -13.35, F + 0.4, 1.8, 0.05, 4.4)
solid("LemariEs", 63.2, -14.5, 2.2, 2.2, F, F + 5.2)

# kelompok sofa lounge
for (gx, gy) in ((32.5, 3.0), (47.0, 3.0)):
    sofa(G(gx, gy + 3.9, 180), f"SofaLounge{int(gx)}A", 5.0, 2)
    sofa(G(gx, gy - 3.9, 0), f"SofaLounge{int(gx)}B", 5.0, 2)
    armchair(G(gx - 3.6, gy, -90), f"KursiLounge{int(gx)}A")
    armchair(G(gx + 3.6, gy, 90), f"KursiLounge{int(gx)}B")
    coffee_table(gx, gy)
    cyl("RdRugB", gx, gy, 1.0, 5.4, 0.04, 40)
    cyl("RdGoldT", gx, gy, 1.0, 5.6, 0.03, 40)
# rak buku di dinding kanan
for k in range(3):
    yy = -4.5 + k * 4.2
    box("RdWoodD", IX - 0.7, yy, F, 1.3, 3.8, 7.6)
    for r in range(5):
        box("RdWall", IX - 1.0, yy, F + 0.3 + r * 1.5, 0.9, 3.5, 0.08)
        for b in range(11):
            col = ["RdBook1", "RdBook2", "RdBook3", "RdBook4"][(b + r + k) % 4]
            hh = 0.9 + ((b * 7 + r) % 3) * 0.15
            box(col, IX - 1.05, yy - 1.6 + b * 0.31, F + 0.38 + r * 1.5, 0.55, 0.24, hh)
    solid("RakBuku", IX - 0.7, yy, 1.3, 3.8, F, F + 7.6)
# pojok anak (depan kanan)
box("RdKidsMat", 59.5, 11.0, 1.0, 12.0, 10.0, 0.05)
for (kx, ky, col) in [(55.0, 8.0, "RdKid1"), (57.5, 8.0, "RdKid2"), (60.0, 8.0, "RdKid3"), (62.5, 8.0, "RdKid4")]:
    box(col, kx, ky, 1.05, 2.0, 2.0, 1.6)
cyl("RdKid2", 57.0, 13.5, 1.05, 1.1, 1.4, 14)
cyl("RdKid3", 60.5, 13.5, 1.05, 1.0, 1.0, 14)
pyramid("RdKid1", 63.0, 13.5, 1.05, 2.8, 3.2)
for k in range(6):
    ball(["RdKid1", "RdKid2", "RdKid3", "RdKid4"][k % 4], 55.5 + k * 1.3, 12.0 + (k % 2) * 0.6, 1.5, 0.45, 8)
box("RdWoodL", 59.5, 6.1, 1.05, 12.0, 0.12, 0.8)
box("RdWoodL", 53.5, 11.0, 1.05, 0.12, 10.0, 0.8)
solid("PojokAnak", 59.5, 11.0, 12.0, 10.0, F, F + 0.2)
for (px, py) in [(26.0, 15.8), (26.0, -9.0), (66.0, 4.0)]:
    plant(px, py)
for (px, py) in [(-26.0, 15.8), (-64.5, 15.5), (-64.5, -9.5)]:
    plant(px, py)

# ============================================================ lampu
LAMPS_POS = []
def chandelier(x, y, r=2.2, z=8.3):
    cyl("RdGoldT", x, y, z + 0.9, 0.07, CE - z - 0.9, 6)
    cyl("RdGoldT", x, y, z, r, 0.16, 28)
    cyl("RdGoldT", x, y, z + 0.5, r * 0.55, 0.12, 24)
    cyl("RdGoldT", x, y, z + 0.1, 0.2, 0.8, 8)
    for k in range(10):
        a = k * 2 * math.pi / 10
        ball("RdBulb", x + math.cos(a) * r, y + math.sin(a) * r, z + 0.35, 0.22, 6)
        box("RdCrystal", x + math.cos(a) * r, y + math.sin(a) * r, z - 0.5, 0.1, 0.1, 0.55)
    ball("RdBulb", x, y, z - 0.1, 0.4, 8)
    LAMPS.append((x, y, z - 0.2, 0.55, 30))
chandelier(0, 4.0, 3.0)
chandelier(0, -2.0, 1.8)
chandelier(-13, 5, 2.0)
chandelier(13, 5, 2.0)
for (x, y) in [(-60, 4), (-45, 4), (-32, 4), (33, 4), (47, 4)]:
    chandelier(x, y, 1.6, 8.5)
for (x, y) in [(-48, -8), (46, -8)]:
    chandelier(x, y, 1.3, 8.6)
# lampu langit-langit bundar kecil (hiasan)
for xi in range(-60, 61, 10):
    for yy in (-12.0, 12.0):
        cyl("RdNeon", xi, yy, CE - 0.06, 0.55, 0.06, 14)

# ============================================================ simpan data Luau
def fmt(v):
    return ("%.2f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)

lines = ["--!strict", "-- DIBUAT OTOMATIS oleh tools/blender/resort_dalam.py (koordinat Blender: x, y, z; lantai z = 1.0)", "return {", "\tSOLIDS = {"]
for s in SOLIDS:
    lines.append('\t\t{ "%s", %s },' % (s[0], ", ".join(fmt(float(v)) for v in s[1:])))
lines.append("\t},")
lines.append("\tSEATS = {")
for s in SEATS:
    lines.append('\t\t{ "%s", %s, %s, %s, %s },' % (s[0], fmt(float(s[1])), fmt(float(s[2])), fmt(float(s[3])), fmt(float(s[4]))))
lines.append("\t},")
lines.append("\tLAMPS = {")
for s in LAMPS:
    lines.append("\t\t{ %s },", ) if False else lines.append("\t\t{ %s }," % ", ".join(fmt(float(v)) for v in s))
lines.append("\t},")
lines.append("}")
with open(DATA, "w", encoding="utf8") as f:
    f.write("\n".join(lines) + "\n")

print(export(OUT, BLEND))
