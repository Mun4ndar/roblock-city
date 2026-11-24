# Apartemen berbalkon (parametrik). Dijalankan lewat Blender MCP; membuat satu FBX per gedung.
# Depan = +Y. Lobi z 0..10, badan z 10..10+H, mahkota atap di atasnya.
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

APT = {  # nama: (W lebar x, D kedalaman y, H tinggi badan)
    "ApartemenMint": (56, 70, 75),
    "ApartemenSelatan": (56, 80, 60),
    "ApartemenKrem": (50, 60, 45),
    "ApartemenKuning": (60, 70, 65),
    "ApartemenPink": (50, 70, 45),
    "ApartemenTaman": (50, 60, 55),
    "ApartemenHijau": (60, 60, 70),
    "ApartemenLaut": (44, 44, 86),
    "ApartemenUjung": (50, 56, 60),
    "ApartemenBata": (60, 60, 50),
}


def balcony_face(face_y, sy, W, z0, H, floor_h=4.0):
    """balkon bertumpuk di muka y = face_y; sy = +1 (depan) atau -1 (belakang)"""
    bays = max(3, int(W / 9))
    bw = (W - 6) / bays
    floors = int((H - 2) / floor_h)
    for f in range(floors):
        zf = z0 + 1.0 + f * floor_h
        for i in range(bays):
            x = -(W - 6) / 2 + bw * (i + 0.5)
            # jendela kaca di balik balkon
            box("AtGlass", x, face_y + sy * 0.1, zf + 0.6, bw - 1.4, 0.3, floor_h - 1.4)
            box("AtTrim", x, face_y + sy * 0.15, zf + 0.5, bw - 1.1, 0.3, 0.2)
            # lantai balkon + pagar kaca
            box("AtSlab", x, face_y + sy * 1.4, zf - 0.55, bw - 0.6, 2.8, 0.5)
            box("AtGlass", x, face_y + sy * 2.7, zf - 0.05, bw - 0.6, 0.2, 1.4)
            box("AtTrim", x, face_y + sy * 2.7, zf + 1.35, bw - 0.6, 0.3, 0.2)
        # sirip pembagi
    for i in range(bays + 1):
        x = -(W - 6) / 2 + bw * i
        box("AtAccent", x, face_y + sy * 1.1, z0 + 0.4, 0.7, 2.4, floors * floor_h + 0.6)


def build(name, W, D, H):
    new_scene("Apt_" + name)
    HW, HD = W / 2, D / 2
    # lobi kaca
    box("AtDark", 0, 0, 0, W - 1, D - 1, 10.0)
    box("AtStone", 0, 0, 0, W + 1.2, D + 1.2, 1.0)
    GY = HD
    box("AtGlass", 0, GY + 0.05, 1.4, W - 8, 0.3, 6.6)
    n = max(5, int((W - 8) / 5))
    for i in range(n + 1):
        box("AtDark", -(W - 8) / 2 + i * (W - 8) / n, GY + 0.15, 1.2, 0.5, 0.6, 7.0)
    box("AtDark", 0, GY + 0.15, 8.0, W - 7, 0.6, 0.5)
    # pintu + kanopi
    box("AtDark", 0, GY + 0.1, 0.0, 8.6, 0.6, 7.6)
    box("AtGlass", 0, GY + 0.4, 0.4, 7.6, 0.3, 6.8)
    box("AtAccent", 0, GY + 3.2, 8.2, 18.0, 6.4, 0.6)
    for sx in (-1, 1):
        cyl("AtWhite", sx * 8.5, GY + 5.8, 0, 0.5, 8.2, 10)
    box("AtStone", 0, GY + 3.2, 0, 19.0, 6.6, 0.25)
    # badan
    z0 = 10.0
    box("AtWall", 0, 0, z0, W, D, H)
    box("AtWhite", 0, 0, z0, W + 1.0, D + 1.0, 0.8)
    # balkon depan dan belakang
    balcony_face(HD, 1, W, z0, H)
    balcony_face(-HD, -1, W, z0, H)
    # sisi: kolom jendela
    floors = int((H - 2) / 4.0)
    for sx in (-1, 1):
        for f in range(floors):
            zf = z0 + 1.6 + f * 4.0
            for yy in range(-int(HD) + 8, int(HD) - 6, 9):
                box("AtGlass", sx * (HW + 0.1), yy, zf, 0.3, 4.0, 2.2)
                box("AtTrim", sx * (HW + 0.15), yy, zf - 0.2, 0.3, 4.6, 0.2)
        box("AtAccent", sx * (HW + 0.2), 0, z0, 0.5, 1.4, H)
    # mahkota atap
    zt = z0 + H
    box("AtWhite", 0, 0, zt, W + 2.0, D + 2.0, 1.2)
    box("AtAccent", 0, 0, zt + 1.2, W + 2.2, D + 2.2, 0.5)
    box("AtRoof", 0, 0, zt + 1.7, W - 2, D - 2, 0.4)
    for s in (-1, 1):  # pagar atap
        box("AtWhite", 0, s * (HD + 0.8), zt + 1.2, W + 2.4, 0.5, 1.6)
        box("AtWhite", s * (HW + 0.8), 0, zt + 1.2, 0.5, D + 2.4, 1.6)
    # penthouse bertingkat + tangki air
    box("AtWall", 0, -HD * 0.2, zt + 2.0, W * 0.5, D * 0.4, 6.0)
    box("AtGlass", 0, -HD * 0.2 + D * 0.2 + 0.1, zt + 3.0, W * 0.4, 0.3, 3.4)
    box("AtAccent", 0, -HD * 0.2, zt + 8.0, W * 0.5 + 1.0, D * 0.4 + 1.0, 0.7)
    cyl("AtWhite", -W * 0.3, -HD * 0.55, zt + 2.0, 2.6, 5.0, 16)
    cyl("AtAccent", -W * 0.3, -HD * 0.55, zt + 7.0, 2.8, 0.6, 16)
    cyl("AtWhite", W * 0.3, -HD * 0.55, zt + 2.0, 2.6, 5.0, 16)
    cyl("AtAccent", W * 0.3, -HD * 0.55, zt + 7.0, 2.8, 0.6, 16)
    cyl("AtDark", 0, -HD * 0.2, zt + 8.7, 0.2, 8.0, 6, 0.06)
    return export(r"D:\ROBLOX STUDIO\assets\blender\apt_%s.fbx" % name)


res = {}
for nm, (w, d, h) in APT.items():
    info = build(nm, w, d, h)
    res[nm] = {"center": info["center"], "faces": sum(info["faces"].values())}
print(res)
