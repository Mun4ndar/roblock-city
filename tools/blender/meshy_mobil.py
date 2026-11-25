"""Memproses mobil buatan Meshy (satu mesh dengan roda menyatu) menjadi FBX ringan untuk Roblox.

Jalankan lewat execute_blender_code (Blender 3.6):
    exec(open(r'D:\\ROBLOX STUDIO\\tools\\blender\\meshy_mobil.py').read())
    proses('kancil', r'D:\\ROBLOX STUDIO\\assets\\meshy\\serasi.glb', panjang=15.5, depan='-X')
Hasil: assets/blender/mobil_<id>.fbx (ShellBody ~9,5 ribu segitiga, WheelPiece ~1,3 ribu) +
mobil_<id>_warna.png (warna dasar 1024px). Nilai yang dicetak (jari-jari roda, jarak sumbu, jarak roda
ke tengah, tinggi) dipakai untuk mengisi VehicleConfig (wheelRadius, wheelbase, wheelTrack, width).
Pasang di Studio: lihat catatan "Kancil" di memori proyek (templat CarShells.<id>, atribut Preserve,
Yaw=180, Wheel model atribut OuterPlusX, SurfaceAppearance.ColorMap = gambar yang diunggah).
"""
import bpy, bmesh, math, os
import numpy as np

OUT = r"D:\ROBLOX STUDIO\assets\blender"


def _mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def _dec(o, tris):
    md = o.modifiers.new("d", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = min(1.0, tris / max(1, len(o.data.polygons)))
    md.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="d")


def _coords(o):
    n = len(o.data.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    o.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _contact(co, front, H, xmask, win=0.6):
    """Tengah roda (y) dari titik tapak ban: titik terendah di sisi depan/belakang, diambil dari
    kelompok paling padat (standar tengah, knalpot dan penahan tidak ikut)."""
    low = co[xmask(co[:, 0]) & (co[:, 2] < 0.05 * H)]
    low = low[low[:, 1] > 0] if front else low[low[:, 1] < 0]
    h, e = np.histogram(low[:, 1], bins=max(8, int((low[:, 1].max() - low[:, 1].min()) / 0.25)))
    c = (e[np.argmax(h)] + e[np.argmax(h) + 1]) / 2
    return float(low[np.abs(low[:, 1] - c) < win, 1].mean())


def proses(id, path, panjang, depan="-X", tris_bodi=9500, tris_roda=1300, r_roda=None, y_depan=None, y_belakang=None):
    """depan = sumbu Blender yang dihadapi moncong mobil setelah impor ('-X','+X','-Y','+Y').
    Mobil diputar agar depan = +Y, diskalakan ke `panjang` stud, dan alasnya di z=0."""
    before = set(bpy.data.objects.keys())
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    new = [bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = "Mx_" + id
    o.parent = None
    o.rotation_mode = "XYZ"
    ang = {"+Y": 0, "-Y": 180, "-X": -90, "+X": 90}[depan]
    o.rotation_euler = (0, 0, math.radians(ang))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    co = _coords(o)
    s = panjang / (co[:, 1].max() - co[:, 1].min())
    o.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    co = _coords(o)
    o.location = (-(co[:, 0].max() + co[:, 0].min()) / 2, -(co[:, 1].max() + co[:, 1].min()) / 2, -co[:, 2].min())
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    _dec(o, 60000)
    me = o.data
    co = _coords(o)
    H = co[:, 2].max()
    halfw = co[:, 0].max()
    outer = lambda x: np.abs(x) > halfw * 0.55
    r = r_roda or 0.245 * H
    yf = y_depan or _contact(co, True, H, outer)
    yr = y_belakang or _contact(co, False, H, outer)
    print("tengah roda y depan/belakang:", round(yf, 2), round(yr, 2), "jari-jari", round(r, 2))
    spec = {"FL": (-1, yf), "FR": (1, yf), "RL": (-1, yr), "RR": (1, yr)}
    c = np.empty(len(me.polygons) * 3, dtype=np.float32)
    me.polygons.foreach_get("center", c)
    bpy.context.view_layer.objects.active = o
    for k, (sx, yc) in spec.items():
        me = o.data
        c = np.empty(len(me.polygons) * 3, dtype=np.float32)
        me.polygons.foreach_get("center", c)
        c = c.reshape(-1, 3)
        m = (np.sign(c[:, 0]) == sx) & (np.abs(c[:, 0]) > halfw * 0.65) & (np.hypot(c[:, 1] - yc, c[:, 2] - r) < r * 1.12)
        bpy.ops.object.mode_set(mode="EDIT")
        bm = bmesh.from_edit_mesh(o.data)
        bm.faces.ensure_lookup_table()
        for f in bm.faces:
            f.select_set(False)
        for i in np.nonzero(m)[0]:
            bm.faces[int(i)].select_set(True)
        bmesh.update_edit_mesh(o.data)
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        for x in bpy.data.objects:
            if x.name.startswith(o.name + "."):
                x.name = o.name + "_w" + k
        bpy.context.view_layer.objects.active = o
    wheels = {k: bpy.data.objects[o.name + "_w" + k] for k in spec}
    _dec(o, tris_bodi)
    for w in wheels.values():
        _dec(w, tris_roda)
    wl = wheels["FL"]
    vs = _coords(wl)
    ctr = (vs.min(0) + vs.max(0)) / 2
    rr = _coords(wheels["RL"])
    ctr_r = (rr.min(0) + rr.max(0)) / 2
    # tekstur warna dasar 1024px
    mat = o.data.materials[0]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    link = bsdf.inputs["Base Color"].links
    src = link[0].from_node if link else None
    tex = [n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"]
    if src is None or src.type != "TEX_IMAGE":
        src = next((n for n in tex if n.image and n.image.name.startswith("Image_0")), tex[0])
    base = src.image.copy()
    base.scale(1024, 1024)
    base.filepath_raw = os.path.join(OUT, "mobil_%s_warna.png" % id)
    base.file_format = "PNG"
    base.save()
    # ekspor: bodi + satu roda kiri depan
    b = o.copy()
    b.data = o.data.copy()
    b.name = "ShellBody"
    bpy.context.collection.objects.link(b)
    w = wl.copy()
    w.data = wl.data.copy()
    w.name = "WheelPiece"
    bpy.context.collection.objects.link(w)
    bpy.ops.object.select_all(action="DESELECT")
    b.select_set(True)
    w.select_set(True)
    bpy.context.view_layer.objects.active = b
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "mobil_%s.fbx" % id), use_selection=True, axis_forward="-Z",
                             axis_up="Y", global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             mesh_smooth_type="FACE", path_mode="COPY", embed_textures=False)
    bpy.data.objects.remove(b)
    bpy.data.objects.remove(w)
    info = dict(
        tinggi=round(float(H), 2), lebar=round(float(halfw * 2), 2), panjang=panjang,
        wheelRadius=round(float((vs[:, 2].max() - vs[:, 2].min()) / 2), 2),
        wheelWidth=round(float(vs[:, 0].max() - vs[:, 0].min()), 2),
        wheelTrack=round(abs(float(ctr[0])), 2),
        wheelbase=round(abs(float(ctr[1] - ctr_r[1])), 2),
        pusat_roda_z=round(float(ctr[2]), 2),
        segitiga_bodi=len(o.data.polygons),
    )
    print(info)
    return info


def proses_motor(id, path, panjang, depan="-X", tris_bodi=9500, tris_roda=1500):
    """Seperti proses(), untuk motor (dua roda di tengah). Roda depan dan belakang dipisah dari bodi;
    templat roda di FBX = roda depan (VehicleBuilder menempatkannya di depan dan belakang di tengah)."""
    before = set(bpy.data.objects.keys())
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    new = [bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = "Mx_" + id
    o.parent = None
    o.rotation_mode = "XYZ"
    o.rotation_euler = (0, 0, math.radians({"+Y": 0, "-Y": 180, "-X": -90, "+X": 90}[depan]))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    co = _coords(o)
    sc = panjang / (co[:, 1].max() - co[:, 1].min())
    o.scale = (sc, sc, sc)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    co = _coords(o)
    o.location = (-(co[:, 0].max() + co[:, 0].min()) / 2, -(co[:, 1].max() + co[:, 1].min()) / 2, -co[:, 2].min())
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    _dec(o, 60000)
    co = _coords(o)
    H = co[:, 2].max()
    xw = 0.1 * H
    centre = lambda x: np.abs(x) < xw
    yf = _contact(co, True, H, centre)
    yr = _contact(co, False, H, centre)
    r = 0.2 * H
    print("tengah roda y depan/belakang:", round(yf, 2), round(yr, 2))
    bpy.context.view_layer.objects.active = o
    for k, yc in (("F", yf), ("R", yr)):
        me = o.data
        c = np.empty(len(me.polygons) * 3, dtype=np.float32)
        me.polygons.foreach_get("center", c)
        c = c.reshape(-1, 3)
        m = (np.abs(c[:, 0]) < xw) & (np.hypot(c[:, 1] - yc, c[:, 2] - r) < r * 1.1)
        bpy.ops.object.mode_set(mode="EDIT")
        bm = bmesh.from_edit_mesh(o.data)
        bm.faces.ensure_lookup_table()
        for f in bm.faces:
            f.select_set(False)
        for i in np.nonzero(m)[0]:
            bm.faces[int(i)].select_set(True)
        bmesh.update_edit_mesh(o.data)
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        for x in bpy.data.objects:
            if x.name.startswith(o.name + "."):
                x.name = o.name + "_w" + k
        bpy.context.view_layer.objects.active = o
    wf, wr = bpy.data.objects[o.name + "_wF"], bpy.data.objects[o.name + "_wR"]
    _dec(o, tris_bodi)
    _dec(wf, tris_roda)
    _dec(wr, tris_roda)
    vs = _coords(wf)
    ctr = (vs.min(0) + vs.max(0)) / 2
    vr = _coords(wr)
    ctr_r = (vr.min(0) + vr.max(0)) / 2
    mat = o.data.materials[0]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    link = bsdf.inputs["Base Color"].links
    src = link[0].from_node if link else None
    if src is None or src.type != "TEX_IMAGE":
        src = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    base = src.image.copy()
    base.scale(1024, 1024)
    base.filepath_raw = os.path.join(OUT, "mobil_%s_warna.png" % id)
    base.file_format = "PNG"
    base.save()
    b = o.copy()
    b.data = o.data.copy()
    b.name = "ShellBody"
    bpy.context.collection.objects.link(b)
    w = wf.copy()
    w.data = wf.data.copy()
    w.name = "WheelPiece"
    bpy.context.collection.objects.link(w)
    bpy.ops.object.select_all(action="DESELECT")
    b.select_set(True)
    w.select_set(True)
    bpy.context.view_layer.objects.active = b
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "mobil_%s.fbx" % id), use_selection=True, axis_forward="-Z",
                             axis_up="Y", global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             mesh_smooth_type="FACE", path_mode="COPY", embed_textures=False)
    bpy.data.objects.remove(b)
    bpy.data.objects.remove(w)
    info = dict(
        tinggi=round(float(H), 2), lebar=round(float(co[:, 0].max() - co[:, 0].min()), 2), panjang=panjang,
        wheelRadius=round(float((vs[:, 2].max() - vs[:, 2].min()) / 2), 2),
        wheelWidth=round(float(vs[:, 0].max() - vs[:, 0].min()), 2),
        wheelbase=round(abs(float(ctr[1] - ctr_r[1])), 2), pusat_roda_z=round(float(ctr[2]), 2),
        wheel_y_depan=round(float(ctr[1]), 2), wheel_y_belakang=round(float(ctr_r[1]), 2),
        segitiga_bodi=len(o.data.polygons),
    )
    print(info)
    return info


def pad_png(path, objs, pad=10):
    """Tambahkan 'padding' pada tekstur: piksel di luar pulau UV diisi warna pulau terdekat, supaya
    tepi panel tidak membocorkan warna latar (putih/hitam) saat di-mipmap atau difilter di Roblox.
    path = PNG warna dasar; objs = semua objek yang memakai tekstur itu (bodi + roda)."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    mask = np.zeros((h, w), dtype=bool)
    for o in objs:
        me = o.data
        uv = me.uv_layers.active.data
        me.calc_loop_triangles()
        for t in me.loop_triangles:
            pts = np.array([uv[i].uv[:] for i in t.loops], dtype=np.float64) * [w, h]
            x0, y0 = np.floor(pts.min(0)).astype(int) - 1
            x1, y1 = np.ceil(pts.max(0)).astype(int) + 1
            x0, y0 = max(x0, 0), max(y0, 0)
            x1, y1 = min(x1, w - 1), min(y1, h - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            a, b, c = pts
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-9:
                continue
            l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / d
            l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / d
            l3 = 1 - l1 - l2
            eps = -0.04
            inside = (l1 >= eps) & (l2 >= eps) & (l3 >= eps)
            mask[y0:y1 + 1, x0:x1 + 1] |= inside
    covered = mask.copy()
    for _ in range(pad):
        grow = np.zeros_like(mask)
        acc = np.zeros((h, w, 3), dtype=np.float32)
        cnt = np.zeros((h, w), dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = np.roll(mask, (dy, dx), (0, 1))
            c = np.roll(px[:, :, :3], (dy, dx), (0, 1))
            sel = m & ~mask
            acc[sel] += c[sel]
            cnt[sel] += 1
        new = (cnt > 0)
        px[new, :3] = acc[new] / cnt[new][:, None]
        mask = mask | new
    px[:, :, 3] = 1.0
    img.pixels = px.ravel().tolist()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return float(covered.mean())
