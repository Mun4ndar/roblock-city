# ROBLOCK Resort: lantai kamar (koridor + 6 kamar dengan kamar mandi). Dibangun di y=2000 tepat di atas resor.
# Dijalankan lewat Blender MCP: exec(helpers.py) lalu exec(file ini). 1 unit = 1 stud, depan = +Y, atas = +Z.
# Koridor x -30..30, y -3..3. Kamar utara y 3.5..17.5 dan selatan -17.5..-3.5 (3 + 3, tiap 18 lebar). Lantai z = F.
# Kabin lift (kayu/baja) dibuat dari Part di Luau (map/BuildResortLantai.luau), bukan mesh.
# Menulis map/ResortLantaiData.luau (kotak tabrakan, tempat tidur, lampu, label kamar).
import math

new_scene("ResortLantai")
OUT = r"D:\ROBLOX STUDIO\assets\blender\resort_lantai.fbx"
BLEND = r"D:\ROBLOX STUDIO\assets\blender\roblock_resort_lantai.blend"
DATA = r"D:\ROBLOX STUDIO\map\ResortLantaiData.luau"
F = 0.2
CE = 8.4  # tinggi langit-langit (permukaan bawah)
SOLIDS, BEDS, LAMPS, LABELS = [], [], [], []


def solid(name, x0, x1, y0, y1, z0, z1):
    SOLIDS.append((name, round(x0, 2), round(x1, 2), round(y0, 2), round(y1, 2), round(z0, 2), round(z1, 2)))


def wall(x0, x1, y0, y1, name="Dinding"):
    box("RlWall", (x0 + x1) / 2, (y0 + y1) / 2, F, x1 - x0, y1 - y0, CE - F)
    solid(name, x0, x1, y0, y1, F, CE)


def rbox(m, cx, cy, z0, sx, sy, sz, yaw=0.0):
    b = bm(m)
    r = bmesh.ops.create_cube(b, size=1.0)
    bmesh.ops.scale(b, vec=(sx, sy, sz), verts=r["verts"])
    if yaw:
        bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(yaw), 3, "Z"), verts=r["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, z0 + sz / 2), verts=r["verts"])


class G:
    def __init__(s, x, y, yaw=0.0):
        s.x, s.y, s.yaw = x, y, yaw
        s.c, s.s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def pt(s, dx, dy):
        return (s.x + dx * s.c - dy * s.s, s.y + dx * s.s + dy * s.c)

    def box(s, m, dx, dy, z0, sx, sy, sz):
        px, py = s.pt(dx, dy)
        rbox(m, px, py, z0, sx, sy, sz, s.yaw)

    def cyl(s, m, dx, dy, z0, r, h, seg=16, r2=None):
        px, py = s.pt(dx, dy)
        cyl(m, px, py, z0, r, h, seg, r2)

    def ball(s, m, dx, dy, z, r, seg=8):
        px, py = s.pt(dx, dy)
        ball(m, px, py, z, r, seg)

    def solid(s, name, dx, dy, sx, sy, z1):  # yaw hanya 0 atau 180
        px, py = s.pt(dx, dy)
        solid(name, px - sx / 2, px + sx / 2, py - sy / 2, py + sy / 2, F, z1)


# ---------------- lantai, langit-langit, dinding luar ----------------
box("RlParq", 0, 0, -0.4, 60.4, 36.4, F + 0.4)
solid("Lantai", -31, 31, -19, 19, -1.0, F)
box("RlCeil", 0, 0, CE, 60.4, 36.4, 0.5)
solid("Langit", -31, 31, -19, 19, CE, CE + 1.0)
box("RlFloor", 0, 0, F, 59.5, 5.5, 0.03)  # karpet koridor
box("RlGoldT", 0, -2.85, F, 59.5, 0.12, 0.035)
box("RlGoldT", 0, 2.85, F, 59.5, 0.12, 0.035)

DOORX = (-18.0, 0.0, 18.0)
# dinding koridor (y = +-3..3.5) dengan bukaan pintu lebar 4 di tiap kamar
for side in (1, -1):
    y0, y1 = (3.0, 3.5) if side > 0 else (-3.5, -3.0)
    cuts = [-30.0]
    for dx in DOORX:
        cuts += [dx - 2.0, dx + 2.0]
    cuts += [30.0]
    for i in range(0, len(cuts), 2):
        wall(cuts[i], cuts[i + 1], y0, y1, "DindingKoridor")
    for dx in DOORX:  # kusen pintu + ambang atas
        box("RlGoldT", dx - 2.0, (y0 + y1) / 2, F, 0.2, 0.7, 6.3)
        box("RlGoldT", dx + 2.0, (y0 + y1) / 2, F, 0.2, 0.7, 6.3)
        box("RlGoldT", dx, (y0 + y1) / 2, F + 6.3, 4.4, 0.7, 0.2)
wall(30.0, 30.5, -3.0, 3.0, "UjungKoridor")
# dinding antar kamar dan dinding luar
for side in (1, -1):
    ya, yb = (3.5, 18.0) if side > 0 else (-18.0, -3.5)
    for x in (-27.0, -9.0, 9.0, 27.0):
        wall(x - 0.25, x + 0.25, ya, yb, "DindingKamar")
    wall(-27.0, 27.0, 17.5, 18.0, "DindingBelakang") if side > 0 else wall(-27.0, 27.0, -18.0, -17.5, "DindingBelakang")
# dinding barat/timur koridor di balik kamar luar sudah ditutup oleh dinding kamar x = +-27 (koridor sampai x=+-30)
# bukaan lift di x -30 (y -3..3) dibiarkan terbuka: kabin + pintu geser dibuat Luau
box("RlWall", -30.25, 0, F + 7.8, 0.5, 6.0, CE - F - 7.8)  # ambang atas bukaan
box("RlGoldT", -30.1, 0, F + 7.6, 0.3, 6.2, 0.2)

# hiasan koridor: lukisan, tanaman, lampu
arts = ["RlArtA", "RlArtB", "RlArtC", "RlArtD"]
for side in (1, -1):
    for k, x in enumerate((-25.0, -9.0, 9.0, 25.0)):
        box(arts[(k + (0 if side > 0 else 2)) % 4], x, side * 2.95, F + 3.6, 3.4, 0.08, 2.2)
        box("RlGoldT", x, side * 2.93, F + 3.5, 3.6, 0.05, 0.1)
        box("RlGoldT", x, side * 2.93, F + 5.9, 3.6, 0.05, 0.1)
box("RlArtE", 29.9, 0.0, F + 3.2, 0.08, 4.6, 2.6)
for k in range(15):  # lampu cove langit-langit koridor (strip) dan lampu bulat
    box("RlNeon", -28.0 + k * 4.0, 0.0, CE - 0.04, 1.4, 0.4, 0.04)
for x in (-24.0, -12.0, 0.0, 12.0, 24.0):
    LAMPS.append((x, 0.0, CE - 0.6, 0.32, 18))
for y in (1.8, -1.8):
    cyl("RlPot", 28.6, y, F, 0.6, 1.2, 12, 0.5)
    ball("RlLeaf", 28.6, y, F + 2.0, 0.9, 8)
    solid("Tanaman", 28.0, 29.2, y - 0.6, y + 0.6, F, 2.4)

# ---------------- kamar ----------------
n = 0
for side in (1, -1):
    for cx in DOORX:
        n += 1
        g = G(cx, 10.75 * side, 0.0 if side > 0 else 180.0)
        # lantai kayu kamar + karpet
        g.box("RlRug", -4.0, -2.6, F, 6.0, 4.0, 0.03)
        # tempat tidur (kepala ke dinding belakang, +y lokal)
        g.box("RlWoodD", -4.0, 3.3, F, 5.2, 6.8, 1.0)
        g.box("RlLinen", -4.0, 3.3, F + 1.0, 4.9, 6.5, 0.5)
        g.box("RlBlanket", -4.0, 1.9, F + 1.5, 4.9, 3.8, 0.14)
        g.box("RlWood", -4.0, 6.55, F, 5.4, 0.3, 2.8)
        for dx in (-1.1, 1.1):
            g.box("RlLinen", -4.0 + dx, 5.5, F + 1.5, 1.9, 1.0, 0.42)
        g.solid("Tempat tidur", -4.0, 3.3, 5.2, 6.8, F + 1.5)
        px, py = g.pt(-4.0, 3.0)
        BEDS.append((n, round(px, 2), round(py, 2), F + 1.55, g.yaw))
        # meja samping + lampu tidur
        for dx in (-8.0, -0.2):
            g.box("RlWood", dx, 6.0, F, 1.2, 1.2, 1.5)
            g.ball("RlNeon", dx, 6.0, F + 1.9, 0.35)
            g.solid("Meja samping", dx, 6.0, 1.2, 1.2, F + 1.5)
        LAMPS.append((*g.pt(-4.0, 0.0), CE - 0.8, 0.4, 16))
        # TV dan konsol
        g.box("RlWood", -4.0, -6.2, F, 4.6, 1.0, 1.2)
        g.box("RlDark", -4.0, -6.55, F + 3.2, 4.0, 0.2, 2.4)
        g.box("RlScreen", -4.0, -6.43, F + 3.35, 3.7, 0.05, 2.1)
        g.solid("Konsol TV", -4.0, -6.2, 4.6, 1.0, F + 1.2)
        # bangku kaki tempat tidur
        g.box("RlTealCush", -4.0, -0.9, F + 0.5, 4.6, 1.1, 0.6)
        g.box("RlWoodD", -6.0, -0.9, F, 0.2, 0.9, 0.5)
        g.box("RlWoodD", -2.0, -0.9, F, 0.2, 0.9, 0.5)
        g.solid("Bangku", -4.0, -0.9, 4.6, 1.1, F + 1.1)
        # lemari pakaian
        g.box("RlWood", 1.8, 6.25, F, 3.0, 1.0, 6.6)
        g.box("RlWoodD", 1.8, 5.73, F + 0.4, 0.06, 0.04, 5.8)
        g.solid("Lemari", 1.8, 6.25, 3.0, 1.0, F + 6.6)
        # lukisan di dinding sisi barat
        g.box(arts[n % 4], -8.7, -1.0, F + 3.4, 0.08, 3.0, 2.2)
        # kamar mandi (x 3.5..8.75, y 1..6.75): sekat dengan pintu 2 lebar
        wallx = 3.5
        px0, py0 = g.pt(wallx, 3.9)  # sekat x: panjang y 1.0..6.75
        # sekat dibuat sebagai dinding dunia (axis aligned, yaw 0/180)
        if g.yaw == 0.0:
            wall(g.x + wallx - 0.15, g.x + wallx + 0.15, g.y + 1.0, g.y + 6.75, "SekatMandi")
            wall(g.x + 3.5, g.x + 4.3, g.y + 0.85, g.y + 1.15, "SekatMandi")
            wall(g.x + 6.3, g.x + 8.75, g.y + 0.85, g.y + 1.15, "SekatMandi")
        else:
            wall(g.x - wallx - 0.15, g.x - wallx + 0.15, g.y - 6.75, g.y - 1.0, "SekatMandi")
            wall(g.x - 4.3, g.x - 3.5, g.y - 1.15, g.y - 0.85, "SekatMandi")
            wall(g.x - 8.75, g.x - 6.3, g.y - 1.15, g.y - 0.85, "SekatMandi")
        g.box("RlTile", 6.1, 3.9, F, 5.2, 5.7, 0.03)
        # toilet
        g.box("RlPorcelain", 5.2, 6.0, F, 0.8, 1.1, 0.9)
        g.box("RlPorcelain", 5.2, 6.45, F + 0.9, 0.8, 0.35, 0.9)
        g.solid("Toilet", 5.2, 6.1, 0.9, 1.3, F + 1.2)
        # wastafel dan cermin
        g.box("RlWood", 8.2, 2.6, F, 1.0, 2.0, 1.5)
        g.box("RlPorcelain", 8.15, 2.6, F + 1.5, 0.9, 1.2, 0.12)
        g.box("RlGlass", 8.72, 2.6, F + 3.0, 0.05, 1.8, 1.4)
        g.box("RlSteel", 8.4, 2.6, F + 1.62, 0.12, 0.12, 0.5)
        g.solid("Wastafel", 8.2, 2.6, 1.0, 2.0, F + 1.6)
        # kamar mandi: pancuran
        g.box("RlPorcelain", 7.6, 5.7, F, 2.3, 2.1, 0.15)
        g.box("RlGlass", 7.6, 4.62, F + 0.15, 2.3, 0.06, 5.6)
        g.box("RlGlass", 6.47, 5.7, F + 0.15, 0.06, 2.1, 5.6)
        g.box("RlSteel", 7.6, 6.65, F + 5.4, 0.1, 0.55, 0.1)
        g.cyl("RlSteel", 7.6, 6.35, F + 5.35, 0.3, 0.1, 12)
        g.box("RlSteel", 7.6, 6.7, F + 3.4, 0.1, 0.08, 2.0)
        g.solid("Kaca pancuran", 6.47, 5.7, 0.1, 2.1, F + 5.6)
        LAMPS.append((*g.pt(6.0, 4.0), CE - 0.8, 0.3, 10))
        # nomor kamar di dinding koridor
        LABELS.append((n, cx + 3.0, side * 2.93, -side))

# ---------------- tulis data Luau ----------------
def f(v):
    return ("%.2f" % float(v)).rstrip("0").rstrip(".")

L = ["--!strict", "-- DIBUAT OTOMATIS oleh tools/blender/resort_lantai.py (koordinat Blender; lantai z = %s)" % F, "return {", "\tFLOOR = %s," % F, "\tSOLIDS = {"]
for s in SOLIDS:
    L.append('\t\t{ "%s", %s },' % (s[0], ", ".join(f(v) for v in s[1:])))
L += ["\t},", "\tBEDS = {  -- { nomor, x, y, tinggi kasur, yaw (arah kepala = (-sin, cos)) }"]
for b in BEDS:
    L.append("\t\t{ %d, %s }," % (b[0], ", ".join(f(v) for v in b[1:])))
L += ["\t},", "\tLAMPS = {"]
for l in LAMPS:
    L.append("\t\t{ %s }," % ", ".join(f(v) for v in l))
L += ["\t},", "\tLABELS = {  -- { nomor kamar, x, y, arah hadap y }"]
for l in LABELS:
    L.append("\t\t{ %d, %s }," % (l[0], ", ".join(f(v) for v in l[1:])))
L += ["\t},", "}"]
with open(DATA, "w", encoding="utf8") as fh:
    fh.write("\n".join(L) + "\n")

print(export(OUT, BLEND))
