# Bendera Merah Putih berkibar: 16 bingkai gelombang, tepi tiang (x = 0) TIDAK bergerak. Dijalankan lewat Blender MCP.
# Bidang kain di XZ (lebar 5 sepanjang X, tinggi 3,33 sepanjang Z), gelombang menyimpang ke arah Y. x=0 = tepi tiang.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Bendera")
L, H = 5.0, 3.333
NX, NY = 24, 10
FRAMES = 16
THICK = 0.05
AMP = 0.5


def wave(x, z, t):
    u = x / L
    phase = 2 * math.pi * (1.4 * u - t)
    y = AMP * (u ** 1.2) * math.sin(phase)
    # kain sedikit menjuntai ke bawah di ujung bebas dan melengkung di sumbu z
    zz = z - 0.12 * (u ** 2) * (1.0 + 0.4 * math.sin(phase + 1.0))
    return y, zz


def build_half(name, z0, z1, t):
    b = bm(name)
    rows = max(2, int(round(NY * (z1 - z0) / H)))
    verts = []
    for j in range(rows + 1):
        row = []
        for i in range(NX + 1):
            x = L * i / NX
            z = z0 + (z1 - z0) * j / rows
            y, zz = wave(x, z, t)
            row.append(b.verts.new((x, y, zz)))
        verts.append(row)
    faces = []
    for j in range(rows):
        for i in range(NX):
            faces.append(b.faces.new([verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]]))
    bmesh.ops.solidify(b, geom=faces, thickness=THICK)


for k in range(FRAMES):
    t = k / FRAMES
    build_half("BdMerah%02d" % (k + 1), H / 2, H, t)
    build_half("BdPutih%02d" % (k + 1), 0.0, H / 2, t)

info = export(r"D:\ROBLOX STUDIO\assets\blender\bendera_berkibar.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_bendera.blend")
print(info["bbox_min"], info["bbox_max"], info["center"], sum(info["faces"].values()))
