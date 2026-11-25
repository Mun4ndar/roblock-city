"""Generator mobil modern untuk ROBLOCK CITY (Blender 3.6, jalankan lewat execute_blender_code:
exec(open(r'D:\\ROBLOX STUDIO\\tools\\blender\\mobil_modern.py').read()); build('serasi')).

Satuan 1 unit = 1 stud. Depan mobil = -Y, atas = +Z, roda menyentuh tanah di z=0.
Hasil per mobil: ShellBody (cat, termasuk atap), ShellGlass, ShellTrim (plastik hitam), ShellLamp (lampu depan),
ShellTail (lampu belakang), Tire + Rim (satu roda kiri di posisi FL) dan Roda lain tidak diekspor
(VehicleBuilder menyalin templat roda ke empat posisi).
Ekspor FBX: axis_forward='-Z', axis_up='Y' => depan jadi +Z di Roblox, tambahkan atribut Yaw=180 pada templat.
Anggaran segitiga: body+glass sekitar 6-9 ribu, roda 700, lampu/trim 400.
"""
import bpy, bmesh, math

SPECS = {
    # L panjang, W lebar, wb jarak sumbu roda, r jari-jari roda, ww lebar roda, track jarak tengah roda ke sumbu
    # zb jarak bodi ke tanah, nose/cowl/tail tinggi garis bahu, roof tinggi atap
    # ta awal kaca depan, tra awal atap, trb akhir atap, tb akhir kaca belakang (0..1 dari depan)
    "serasi": dict(L=15.5, W=7.0, wb=9.4, r=1.3, ww=1.1, track=3.0, zb=0.9, nose=3.0, cowl=3.7, tail=3.5,
                   roof=6.4, ta=0.30, tra=0.44, trb=0.68, tb=0.80),
    "jelajah": dict(L=15.0, W=7.4, wb=9.0, r=1.75, ww=1.4, track=3.1, zb=1.5, nose=3.9, cowl=4.5, tail=4.6,
                    roof=7.3, ta=0.26, tra=0.36, trb=0.9, tb=0.97),
    "kilat": dict(L=15.5, W=7.4, wb=9.6, r=1.35, ww=1.5, track=3.1, zb=0.7, nose=2.4, cowl=3.2, tail=3.2,
                  roof=5.6, ta=0.34, tra=0.5, trb=0.66, tb=0.8),
}


def smooth(a):
    return a * a * (3 - 2 * a)


def interp(points, t):
    """Interpolasi mulus antar titik (t, nilai)."""
    if t <= points[0][0]:
        return points[0][1]
    for i in range(len(points) - 1):
        t0, v0 = points[i]
        t1, v1 = points[i + 1]
        if t <= t1:
            k = smooth((t - t0) / (t1 - t0))
            return v0 + (v1 - v0) * k
    return points[-1][1]


def make_mesh(name, verts, faces, flat=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if not flat:
        for p in me.polygons:
            p.use_smooth = True
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.radians(50)
    return ob


def ring_section(a, zb, zt, p=3.2, n=28):
    """Penampang superelips: lebar setengah a, dari zb sampai zt, mulai dari tengah bawah."""
    pts = []
    zc, b = (zb + zt) / 2, (zt - zb) / 2
    for k in range(n):
        th = 2 * math.pi * k / n
        s, c = math.sin(th), -math.cos(th)
        x = a * math.copysign(abs(s) ** (2 / p), s)
        z = zc + b * math.copysign(abs(c) ** (2 / p), c)
        pts.append((x, z))
    return pts


def loft(rings, cap=True):
    """rings = daftar ring [(x,y,z)...]; kembalikan verts, faces."""
    verts, faces = [], []
    n = len(rings[0])
    for ring in rings:
        verts.extend(ring)
    for i in range(len(rings) - 1):
        for k in range(n):
            a = i * n + k
            b = i * n + (k + 1) % n
            faces.append((a, b, b + n, a + n))
    if cap:
        faces.append(tuple(reversed(range(n))))
        faces.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
    return verts, faces


def build_body(s):
    L, W = s["L"], s["W"]
    half = W / 2
    ts = [i / 30 for i in range(31)]
    deck = [(0, s["nose"]), (s["ta"], s["cowl"]), (s["tb"], s["cowl"] - 0.1), (1, s["tail"])]
    rings = []
    for t in ts:
        y = -L / 2 + t * L
        tn = 0.10
        if t < tn:
            k = math.sqrt(max(0.0, 1 - ((tn - t) / tn) ** 2))
            sc = 0.62 + 0.38 * k
        elif t > 1 - tn:
            k = math.sqrt(max(0.0, 1 - ((t - (1 - tn)) / tn) ** 2))
            sc = 0.6 + 0.4 * k
        else:
            sc = 1.0
        zb = s["zb"] + 0.7 * max(0.0, (0.14 - t) / 0.14) ** 2 + 0.5 * max(0.0, (t - 0.86) / 0.14) ** 2
        zt = interp(deck, t)
        a = half * sc
        sect = ring_section(a, zb, zt)
        rings.append([(x, y, z) for x, z in sect])
    return loft(rings)


def build_greenhouse(s):
    """Kembalikan (verts, faces_body, faces_glass): atap + tiang B menjadi bodi, sisanya kaca."""
    L, W = s["L"], s["W"]
    half = W / 2
    ta, tra, trb, tb = s["ta"], s["tra"], s["trb"], s["tb"]
    ts = [ta + (tb - ta) * i / 18 for i in range(19)]
    deck = [(0, s["nose"]), (s["ta"], s["cowl"]), (s["tb"], s["cowl"] - 0.1), (1, s["tail"])]
    verts, ring_ids = [], []
    for t in ts:
        y = -L / 2 + t * L
        zb = interp(deck, t) - 0.25
        if t < tra:
            h = interp([(ta, 0.02), (tra, s["roof"] - zb)], t)
        elif t > trb:
            h = interp([(trb, s["roof"] - zb), (tb, 0.02)], t)
        else:
            h = s["roof"] - zb
        wb_ = half * 0.9
        wt = wb_ * (0.74 if h > 1 else 0.9)
        zt = zb + h
        zm = zb + h * 0.62
        wm = wb_ * 0.9
        ids = []
        for x, z in ((-wb_, zb), (wb_, zb), (wm, zm), (wt, zt), (-wt, zt), (-wm, zm)):
            ids.append(len(verts))
            verts.append((x, y, z))
        ring_ids.append((t, ids))
    faces_body, faces_glass = [], []
    yb = -L / 2 + (tra + trb) / 2 * L  # tiang B di tengah atap
    for i in range(len(ring_ids) - 1):
        t0, a = ring_ids[i]
        t1, b = ring_ids[i + 1]
        tm = (t0 + t1) / 2
        for k in range(6):
            quad = (a[k], a[(k + 1) % 6], b[(k + 1) % 6], b[k])
            top = k == 3  # permukaan atas (antara kanan-atas dan kiri-atas)
            if top and tra <= tm <= trb:
                faces_body.append(quad)
            elif k in (1, 5) and False:
                faces_body.append(quad)
            else:
                nearB = abs(tm - (tra + trb) / 2) < 0.012
                (faces_body if nearB and k in (0, 1, 2, 4, 5) else faces_glass).append(quad)
    # tutup ujung
    for idx in (0, len(ring_ids) - 1):
        faces_glass.append(tuple(ring_ids[idx][1]))
    return verts, faces_body, faces_glass


def box(name, center, size, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    md = ob.modifiers.new("b", "BEVEL")
    md.width = bevel
    md.segments = 2
    bpy.ops.object.modifier_apply(modifier="b")
    return ob


def cylinder_x(name, center, radius, depth, verts=22, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center,
                                        rotation=(0, math.pi / 2, 0))
    ob = bpy.context.active_object
    ob.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel:
        md = ob.modifiers.new("b", "BEVEL")
        md.width = bevel
        md.segments = 2
        bpy.ops.object.modifier_apply(modifier="b")
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob


def build(key, prefix="Car_"):
    s = SPECS[key]
    L, W = s["L"], s["W"]
    objs = {}
    v, f = build_body(s)
    body = make_mesh(prefix + "Body", v, f)
    gv, fb, fg = build_greenhouse(s)

    def sub(name, faces):
        used = sorted({i for fc in faces for i in fc})
        remap = {o: n for n, o in enumerate(used)}
        return make_mesh(name, [gv[i] for i in used], [tuple(remap[i] for i in fc) for fc in faces])

    roof = sub(prefix + "Roof", fb)
    glass = sub(prefix + "Glass", fg)
    # lengkung roda dipotong dari bodi
    wx, wy = s["track"], s["wb"] / 2
    arch = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            arch.append(cylinder_x(prefix + "Arch", (sx * wx, sy * wy, s["r"]), s["r"] + 0.3, s["ww"] + 1.2, 24))
    for a in arch:
        md = body.modifiers.new("cut", "BOOLEAN")
        md.operation = "DIFFERENCE"
        md.object = a
        md.solver = "FAST"
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.modifier_apply(modifier="cut")
    for a in arch:
        bpy.data.objects.remove(a)
    body = join([body, roof], prefix + "ShellBody")
    glass.name = prefix + "ShellGlass"
    # trim: gril, bumper bawah, difuser, kaca spion, ambang pintu
    nose_z = s["nose"]
    half = W / 2
    trim = [
        box("t1", (0, -L / 2 + 0.05, s["zb"] + 0.9), (W * 0.42, 0.5, 0.9)),
        box("t2", (0, -L / 2 + 0.2, s["zb"] + 0.3), (W * 0.62, 0.7, 0.55)),
        box("t3", (0, L / 2 - 0.2, s["zb"] + 0.3), (W * 0.6, 0.7, 0.55)),
        box("t4", (-half * 0.94, 0, s["zb"] + 0.25), (0.35, L * 0.5, 0.45)),
        box("t5", (half * 0.94, 0, s["zb"] + 0.25), (0.35, L * 0.5, 0.45)),
        box("t6", (-half * 0.97, -L / 2 + s["ta"] * L + 0.3, s["cowl"] + 0.35), (0.9, 0.7, 0.55), 0.18),
        box("t7", (half * 0.97, -L / 2 + s["ta"] * L + 0.3, s["cowl"] + 0.35), (0.9, 0.7, 0.55), 0.18),
    ]
    trimo = join(trim, prefix + "ShellTrim")
    lamp = join([
        box("l1", (-half * 0.62, -L / 2 + 0.18, nose_z - 0.75), (1.6, 0.5, 0.6), 0.12),
        box("l2", (half * 0.62, -L / 2 + 0.18, nose_z - 0.75), (1.6, 0.5, 0.6), 0.12),
    ], prefix + "ShellLamp")
    tail = join([
        box("k1", (-half * 0.62, L / 2 - 0.16, s["tail"] - 0.7), (1.7, 0.45, 0.55), 0.12),
        box("k2", (half * 0.62, L / 2 - 0.16, s["tail"] - 0.7), (1.7, 0.45, 0.55), 0.12),
    ], prefix + "ShellTail")
    # satu roda (kiri depan) sebagai templat
    cx, cy, cz = -s["track"], -s["wb"] / 2, s["r"]
    tire = cylinder_x(prefix + "Tire", (cx, cy, cz), s["r"], s["ww"], 24, bevel=0.22)
    rim = cylinder_x(prefix + "Rim", (cx - 0.12, cy, cz), s["r"] * 0.62, s["ww"] + 0.1, 20, bevel=0.06)
    hub = cylinder_x(prefix + "Hub", (cx - 0.22, cy, cz), s["r"] * 0.22, s["ww"] + 0.2, 12)
    rim = join([rim, hub], prefix + "Rim")
    tris = {}
    for o in (body, glass, trimo, lamp, tail, tire, rim):
        me = o.data
        tris[o.name] = sum(len(p.vertices) - 2 for p in me.polygons)
    return dict(body=body, glass=glass, trim=trimo, lamp=lamp, tail=tail, tire=tire, rim=rim, tris=tris)


def export(parts, path):
    bpy.ops.object.select_all(action="DESELECT")
    for k in ("body", "glass", "trim", "lamp", "tail", "tire", "rim"):
        parts[k].select_set(True)
    bpy.context.view_layer.objects.active = parts["body"]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             mesh_smooth_type="OFF", path_mode="COPY", embed_textures=False)
