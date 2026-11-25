# ROBLOCK CITY: lukisan dinding Balai Kota, dirender di Blender (Workbench, datar) jadi PNG.
# Keluaran: assets/blender/lukisan/<nama>.png. Dijalankan lewat Blender MCP (exec).
import bpy, math, os
from mathutils import Vector

OUTDIR = r"D:\ROBLOX STUDIO\assets\blender\lukisan"
os.makedirs(OUTDIR, exist_ok=True)


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def col(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return (lin(r), lin(g), lin(b), 1.0)


class Canvas:
    def __init__(self, name, w, h, px_w, px_h, sky="#9fd8ff"):
        old = bpy.data.scenes.get(name)
        if old:
            for o in list(old.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.scenes.remove(old)
        self.sc = bpy.data.scenes.new(name)
        self.w, self.h, self.layer = w, h, 0
        self.mats = {}
        sc = self.sc
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.render.resolution_x, sc.render.resolution_y = px_w, px_h
        sc.render.image_settings.file_format = "PNG"
        sc.view_settings.view_transform = "Standard"
        sc.display.shading.light = "FLAT"
        sc.display.shading.color_type = "MATERIAL"
        sc.display.render_aa = "8"
        sc.display.shading.show_object_outline = False
        world = bpy.data.worlds.new(name + "W")
        world.use_nodes = False
        world.color = col(sky)[:3]
        sc.world = world
        cam = bpy.data.cameras.new(name + "C")
        cam.type = "ORTHO"
        cam.ortho_scale = max(w, h)
        co = bpy.data.objects.new(name + "C", cam)
        co.location = (w / 2, -20, h / 2)
        co.rotation_euler = (math.pi / 2, 0, 0)
        sc.collection.objects.link(co)
        sc.camera = co
        self.rect(0, 0, w, h, sky)

    def mat(self, color):
        if color not in self.mats:
            m = bpy.data.materials.new("m" + color)
            m.diffuse_color = col(color)
            self.mats[color] = m
        return self.mats[color]

    def poly(self, pts, color):
        self.layer += 1
        y = -self.layer * 0.002
        me = bpy.data.meshes.new("p")
        verts = [(x, y, z) for (x, z) in pts]
        me.from_pydata(verts, [], [list(range(len(verts)))])
        me.update()
        ob = bpy.data.objects.new("p", me)
        ob.data.materials.append(self.mat(color))
        self.sc.collection.objects.link(ob)

    def rect(self, x, z, w, h, color):
        self.poly([(x, z), (x + w, z), (x + w, z + h), (x, z + h)], color)

    def disc(self, cx, cz, r, color, sx=1.0, sz=1.0, n=40):
        self.poly([(cx + math.cos(a) * r * sx, cz + math.sin(a) * r * sz) for a in [i * 2 * math.pi / n for i in range(n)]], color)

    def tri(self, a, b, c, color):
        self.poly([a, b, c], color)

    def save(self, name):
        self.sc.render.filepath = os.path.join(OUTDIR, name + ".png")
        prev = bpy.context.window.scene
        try:
            bpy.context.window.scene = self.sc
            bpy.ops.render.render(write_still=True)
        finally:
            bpy.context.window.scene = prev
        return self.sc.render.filepath


def bands(c, colors, z0, z1):
    n = len(colors)
    for i, k in enumerate(colors):
        c.rect(0, z0 + (z1 - z0) * i / n, c.w, (z1 - z0) / n + 0.01, k)


def sun(c, x, z, r):
    c.disc(x, z, r * 1.35, "#fff2b8")
    c.disc(x, z, r, "#ffd94a")


def cloud(c, x, z, s=1.0):
    for dx, dz, r in [(0, 0, 0.55), (0.55, 0.15, 0.7), (1.2, 0, 0.55), (0.6, -0.1, 0.6)]:
        c.disc(x + dx * s, z + dz * s, r * s, "#ffffff", 1.0, 0.8)


def tree(c, x, z, s=1.0, leaf="#3f9b4a"):
    c.rect(x - 0.08 * s, z, 0.16 * s, 0.7 * s, "#7a4e2e")
    c.disc(x, z + 0.95 * s, 0.5 * s, leaf)
    c.disc(x - 0.3 * s, z + 0.75 * s, 0.35 * s, leaf)
    c.disc(x + 0.3 * s, z + 0.75 * s, 0.35 * s, leaf)


def house(c, x, z, w, h, wall, roof):
    c.rect(x, z, w, h, wall)
    c.tri((x - 0.15, z + h), (x + w + 0.15, z + h), (x + w / 2, z + h + w * 0.45), roof)
    c.rect(x + w * 0.4, z, w * 0.2, h * 0.5, "#6b4a35")
    c.rect(x + w * 0.1, z + h * 0.45, w * 0.2, h * 0.25, "#bfe6ff")
    c.rect(x + w * 0.7, z + h * 0.45, w * 0.2, h * 0.25, "#bfe6ff")


# ---------------- Pusat Kota ----------------
c = Canvas("L_Downtown", 6.44, 4.44, 1024, 706, "#9fd8ff")
bands(c, ["#a8dcff", "#bde6ff", "#d3efff", "#ffe9c4"][::-1], 0, 4.44)
sun(c, 5.4, 3.6, 0.35)
cloud(c, 0.7, 3.5, 0.5)
cloud(c, 3.6, 3.85, 0.4)
import random
r = random.Random(3)
x = 0.0
cols = ["#5b7fa6", "#7a96b8", "#4f6d93", "#8aa6c4", "#6a86ac"]
while x < 6.44:
    w = r.uniform(0.55, 0.9)
    h = r.uniform(1.2, 3.0)
    colr = r.choice(cols)
    c.rect(x, 0.5, w, h, colr)
    for wx in range(int(w / 0.22)):
        for wz in range(int(h / 0.3)):
            if r.random() < 0.7:
                c.rect(x + 0.08 + wx * 0.22, 0.65 + wz * 0.3, 0.1, 0.14, "#ffe9a0")
    x += w + 0.04
# balai kota di tengah
c.rect(2.35, 0.5, 1.75, 1.5, "#f0e6cd")
c.rect(2.2, 0.5, 2.05, 0.25, "#d8cdb2")
for i in range(6):
    c.rect(2.55 + i * 0.27, 0.75, 0.1, 1.1, "#ffffff")
c.tri((2.25, 2.0), (4.2, 2.0), (3.225, 2.55), "#f0e6cd")
c.rect(2.95, 2.0, 0.55, 0.3, "#e8dcc0")
c.poly([(3.225 + math.cos(a) * 0.45, 2.0 + math.sin(a) * 0.55) for a in [i * math.pi / 20 for i in range(21)]], "#46a596")
c.rect(3.2, 2.55, 0.05, 0.4, "#e2ac34")
c.rect(0, 0, 6.44, 0.55, "#4a4d55")
c.rect(0, 0.22, 6.44, 0.05, "#f5f5f5")
for i in range(8):
    c.rect(0.2 + i * 0.8, 0.23, 0.4, 0.03, "#ffd94a")
c.save("downtown")

# ---------------- Pulau Pantai ----------------
c = Canvas("L_Pantai", 6.44, 4.44, 1024, 706, "#8fd3ff")
bands(c, ["#8fd3ff", "#a9ddff", "#c7ecff", "#ffe6bd"][::-1], 1.7, 4.44)
sun(c, 1.3, 3.5, 0.45)
cloud(c, 4.2, 3.7, 0.5)
bands(c, ["#2a9bd6", "#2fa8de", "#43b7e8", "#69c9ee"], 0.9, 1.9)
for i in range(7):
    c.rect(0.4 + i * 0.9, 1.15 + (i % 3) * 0.2, 0.45, 0.04, "#ffffff")
c.poly([(0, 0), (6.44, 0), (6.44, 0.9), (4.5, 1.05), (2.2, 0.85), (0, 1.1)], "#f2dca0")
# pohon kelapa
c.poly([(4.9, 0.7), (5.05, 0.7), (5.3, 2.7), (5.18, 2.7)], "#8a5a34")
for ang in (160, 120, 80, 40, 10, 195):
    a = math.radians(ang)
    tx, tz = 5.25, 2.7
    c.tri((tx, tz), (tx + math.cos(a - 0.2) * 1.1, tz + math.sin(a - 0.2) * 0.9 - 0.15), (tx + math.cos(a + 0.2) * 1.1, tz + math.sin(a + 0.2) * 0.9 - 0.15), "#2f9a4a")
c.disc(5.18, 2.62, 0.09, "#6b4a2a")
c.disc(5.32, 2.6, 0.09, "#6b4a2a")
# payung + kursi pantai
c.rect(1.5, 0.35, 0.05, 0.9, "#ffffff")
c.tri((0.9, 1.2), (2.2, 1.2), (1.55, 1.7), "#ff6b6b")
c.tri((1.55, 1.2), (2.2, 1.2), (1.55, 1.7), "#ffffff")
c.rect(2.5, 0.3, 0.9, 0.18, "#4aa3df")
# perahu layar
c.poly([(3.4, 1.35), (4.3, 1.35), (4.05, 1.1), (3.65, 1.1)], "#ffffff")
c.rect(3.82, 1.35, 0.04, 0.9, "#8a5a34")
c.tri((3.88, 1.4), (3.88, 2.2), (4.4, 1.4), "#ffd94a")
c.tri((3.78, 1.4), (3.78, 2.0), (3.35, 1.4), "#ff6b6b")
# bianglala
c.disc(0.9, 2.6, 0.7, "#ffffff", 1.0, 1.0)
c.disc(0.9, 2.6, 0.62, "#8fd3ff", 1.0, 1.0)
for i in range(8):
    a = i * math.pi / 4
    c.disc(0.9 + math.cos(a) * 0.66, 2.6 + math.sin(a) * 0.66, 0.08, ["#ff6b6b", "#ffd94a", "#6bd96b", "#6bb8ff"][i % 4])
c.rect(0.88, 1.7, 0.04, 0.9, "#ffffff")
c.save("pantai")

# ---------------- Perumahan ----------------
c = Canvas("L_Rumah", 6.44, 4.44, 1024, 706, "#a8dcff")
bands(c, ["#a8dcff", "#bfe7ff", "#d9f1ff"][::-1], 1.4, 4.44)
sun(c, 5.6, 3.7, 0.38)
cloud(c, 1.2, 3.6, 0.55)
c.poly([(0, 0), (6.44, 0), (6.44, 1.6), (4.5, 1.9), (2.5, 1.5), (0, 1.9)], "#6cc06a")
c.poly([(0, 0), (6.44, 0), (6.44, 0.9), (0, 0.9)], "#7ccf74")
c.poly([(2.8, 0), (3.6, 0), (3.2, 1.0), (3.1, 1.0)], "#e8d9a8")
house(c, 0.5, 0.9, 1.3, 0.9, "#ffd6a0", "#c8553d")
house(c, 2.0, 1.1, 1.5, 1.0, "#bfe3ff", "#4a6fa5")
house(c, 3.9, 0.95, 1.4, 0.95, "#ffe6e6", "#7a4e8e")
tree(c, 0.25, 0.7, 1.0)
tree(c, 5.75, 0.8, 1.1, "#4aa95a")
tree(c, 3.65, 1.0, 0.8)
c.rect(0, 0.25, 6.44, 0.15, "#ffffff")
c.save("rumah")

# ---------------- Pedesaan ----------------
c = Canvas("L_Desa", 6.44, 4.44, 1024, 706, "#b6e3ff")
bands(c, ["#b6e3ff", "#cdeeff", "#e6f7ff"][::-1], 1.5, 4.44)
sun(c, 1.0, 3.7, 0.4)
cloud(c, 4.0, 3.7, 0.55)
c.poly([(0, 1.2), (1.8, 2.5), (3.4, 1.3), (5.0, 2.3), (6.44, 1.4), (6.44, 0), (0, 0)], "#86c77a")
c.poly([(0, 0), (6.44, 0), (6.44, 1.0), (3.0, 1.35), (0, 1.0)], "#6fb865")
for i in range(7):  # alur ladang
    c.poly([(0.2 + i * 0.35, 0), (0.45 + i * 0.35, 0), (1.9 + i * 0.1, 1.15), (1.75 + i * 0.1, 1.15)], "#d8c25a" if i % 2 else "#e8d46a")
# lumbung
c.rect(3.7, 0.9, 1.4, 0.95, "#c8402f")
c.poly([(3.55, 1.85), (5.25, 1.85), (4.9, 2.55), (3.9, 2.55)], "#8c2a20")
c.rect(4.15, 0.9, 0.5, 0.7, "#ffffff")
c.rect(4.35, 0.9, 0.1, 0.7, "#c8402f")
# kincir angin
c.poly([(5.6, 0.9), (5.8, 0.9), (5.75, 2.8), (5.65, 2.8)], "#f2f2f2")
for ang in (20, 110, 200, 290):
    a = math.radians(ang)
    px, pz = 5.7, 2.85
    c.tri((px, pz), (px + math.cos(a) * 1.0 - math.sin(a) * 0.12, pz + math.sin(a) * 1.0 + math.cos(a) * 0.12), (px + math.cos(a) * 1.0 + math.sin(a) * 0.12, pz + math.sin(a) * 1.0 - math.cos(a) * 0.12), "#ffffff")
c.disc(5.7, 2.85, 0.1, "#8a5a34")
tree(c, 3.3, 0.9, 1.0, "#4aa95a")
tree(c, 0.3, 1.1, 1.1)
c.save("desa")

# ---------------- Bandara ----------------
c = Canvas("L_Bandara", 6.44, 4.44, 1024, 706, "#8fd0ff")
bands(c, ["#79c4fb", "#92d1fd", "#acddff", "#c8e8ff"][::-1], 0.9, 4.44)
cloud(c, 1.0, 3.5, 0.6)
cloud(c, 4.6, 3.1, 0.5)
c.rect(0, 0, 6.44, 0.9, "#6b707a")
for i in range(8):
    c.rect(0.2 + i * 0.8, 0.43, 0.4, 0.05, "#ffffff")
# menara kontrol
c.rect(5.3, 0.9, 0.35, 1.5, "#e8e8f0")
c.poly([(5.1, 2.4), (5.85, 2.4), (5.7, 2.8), (5.25, 2.8)], "#4aa3df")
c.rect(5.05, 2.35, 0.8, 0.08, "#ffffff")
# terminal
c.rect(0.4, 0.9, 2.2, 0.7, "#eef2f8")
c.rect(0.4, 1.35, 2.2, 0.28, "#4aa3df")
for i in range(7):
    c.rect(0.55 + i * 0.3, 1.0, 0.2, 0.25, "#bfe6ff")
# pesawat
c.disc(3.3, 2.3, 1.15, "#ffffff", 1.0, 0.2)
c.tri((4.15, 2.3), (4.55, 3.1), (4.4, 2.3), "#ff6b6b")
c.poly([(3.0, 2.3), (3.7, 2.3), (3.0, 1.55), (2.7, 1.55)], "#e8edf5")
c.poly([(3.0, 2.35), (3.7, 2.35), (3.1, 3.05), (2.8, 3.05)], "#e8edf5")
for i in range(5):
    c.disc(2.6 + i * 0.25, 2.35, 0.06, "#4aa3df")
c.rect(2.1, 2.2, 0.9, 0.05, "#ff6b6b")
c.save("bandara")

# ---------------- Potret Walikota ----------------
c = Canvas("L_Potret", 3.64, 5.04, 580, 800, "#dfe9f5")
bands(c, ["#c9d9ee", "#d6e3f4", "#e4eefa"][::-1], 0, 5.04)
c.rect(0.3, 0.3, 3.04, 4.44, "#e8f0fa")
c.rect(0.55, 2.9, 0.12, 1.6, "#e2ac34")
c.tri((0.67, 4.5), (0.67, 3.8), (1.3, 4.5), "#1e6eb4")
# jas
c.poly([(0.7, 0), (2.94, 0), (2.9, 1.7), (2.3, 2.3), (1.34, 2.3), (0.74, 1.7)], "#24304f")
c.poly([(1.34, 2.3), (2.3, 2.3), (1.82, 1.2)], "#ffffff")
c.poly([(1.72, 1.9), (1.92, 1.9), (2.0, 0.6), (1.82, 0.4), (1.64, 0.6)], "#d23c3c")
c.poly([(1.34, 2.3), (1.7, 2.3), (1.3, 1.0), (0.95, 1.7)], "#1b2540")
c.poly([(2.3, 2.3), (1.94, 2.3), (2.34, 1.0), (2.69, 1.7)], "#1b2540")
c.disc(2.45, 1.4, 0.07, "#e2ac34")
# leher + kepala
c.rect(1.58, 2.2, 0.5, 0.45, "#f1c9a5")
c.disc(1.82, 3.3, 0.8, "#f6d5b5", 0.9, 1.05)
c.disc(1.82, 3.9, 0.82, "#3a2a22", 0.95, 0.5)
c.disc(1.5, 3.35, 0.09, "#2a2020")
c.disc(2.14, 3.35, 0.09, "#2a2020")
c.poly([(1.82 + math.cos(a) * 0.3, 3.08 - math.sin(a) * 0.2) for a in [i * math.pi / 16 for i in range(17)]], "#b83f3f")
c.save("potret")

# ---------------- Lambang ----------------
c = Canvas("L_Lambang", 6.44, 5.44, 1024, 865, "#1c3a6e")
c.disc(3.22, 2.72, 2.6, "#e2ac34")
c.disc(3.22, 2.72, 2.42, "#fff2b8")
c.disc(3.22, 2.72, 2.28, "#2563b0")
c.disc(3.22, 2.0, 1.55, "#ffd94a", 1.0, 1.0)
c.disc(3.22, 2.0, 1.3, "#ffe98a", 1.0, 1.0)
for sx, h in [(2.3, 1.0), (2.72, 1.55), (3.14, 1.15), (3.56, 1.7), (3.98, 1.2)]:
    c.rect(sx, 0.75, 0.36, h, "#17315c")
c.rect(2.15, 0.75, 2.4, 0.38, "#0f2347")
c.rect(2.95, 1.0, 0.55, 1.25, "#1e4580")
c.disc(3.22, 2.3, 0.3, "#e2ac34")
c.rect(3.2, 2.5, 0.05, 0.35, "#e2ac34")
c.poly([(3.22, 4.75), (3.4, 4.25), (3.95, 4.25), (3.5, 3.95), (3.67, 3.45), (3.22, 3.75), (2.77, 3.45), (2.94, 3.95), (2.49, 4.25), (3.04, 4.25)], "#ffd94a")
c.save("lambang")
print(os.listdir(OUTDIR))
