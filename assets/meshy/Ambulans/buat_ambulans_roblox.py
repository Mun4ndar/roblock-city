import os
import math
import bpy
import bmesh
from mathutils import Vector, Matrix


def get_script_dir():
    try:
        return os.path.dirname(os.path.abspath(__file__))
    except NameError:
        if bpy.data.filepath:
            return os.path.dirname(bpy.data.filepath)
        return os.getcwd()


def load_pbr_image(tex_dir, filename, colorspace):
    path = os.path.join(tex_dir, filename)
    if os.path.exists(path):
        img = bpy.data.images.load(path, check_existing=True)
        img.colorspace_settings.name = colorspace
        return img
    return None


def create_pbr_material(tex_dir, mat_name="M_Ambulans"):
    mat = bpy.data.materials.get(mat_name)
    if mat is None:
        mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (220, 0)

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (550, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    # Albedo (1024x1024)
    img_alb = load_pbr_image(tex_dir, "IndoAmbulance_Albedo.png", "sRGB")
    if img_alb:
        tex_alb = nodes.new("ShaderNodeTexImage")
        tex_alb.image = img_alb
        tex_alb.location = (-320, 320)
        links.new(tex_alb.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (0.95, 0.96, 0.98, 1.0)

    # Metallic (1024x1024)
    img_met = load_pbr_image(tex_dir, "IndoAmbulance_Metallic.png", "Non-Color")
    if img_met:
        tex_met = nodes.new("ShaderNodeTexImage")
        tex_met.image = img_met
        tex_met.location = (-320, 60)
        links.new(tex_met.outputs["Color"], bsdf.inputs["Metallic"])

    # Roughness (1024x1024)
    img_rgh = load_pbr_image(tex_dir, "IndoAmbulance_Roughness.png", "Non-Color")
    if img_rgh:
        tex_rgh = nodes.new("ShaderNodeTexImage")
        tex_rgh.image = img_rgh
        tex_rgh.location = (-320, -200)
        links.new(tex_rgh.outputs["Color"], bsdf.inputs["Roughness"])

    # Normal (1024x1024)
    img_nrm = load_pbr_image(tex_dir, "IndoAmbulance_Normal.png", "Non-Color")
    if img_nrm:
        tex_nrm = nodes.new("ShaderNodeTexImage")
        tex_nrm.image = img_nrm
        tex_nrm.location = (-580, -480)
        nrm_map = nodes.new("ShaderNodeNormalMap")
        nrm_map.location = (-240, -480)
        links.new(tex_nrm.outputs["Color"], nrm_map.inputs["Color"])
        links.new(nrm_map.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def assign_box_uv(bm, uv_layer, faces, u0, v0, u1, v1, axis="AUTO"):
    for f in faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        if axis == "SIDE" or (axis == "AUTO" and ax >= ay and ax >= az):
            coords = [(l.vert.co.y, l.vert.co.z) for l in f.loops]
        elif axis == "FRONT" or (axis == "AUTO" and ay >= ax and ay >= az):
            coords = [(l.vert.co.x, l.vert.co.z) for l in f.loops]
        else:
            coords = [(l.vert.co.x, l.vert.co.y) for l in f.loops]

        min_u = min(c[0] for c in coords)
        max_u = max(c[0] for c in coords)
        min_v = min(c[1] for c in coords)
        max_v = max(c[1] for c in coords)
        du = max(max_u - min_u, 1e-5)
        dv = max(max_v - min_v, 1e-5)

        for loop, (cu, cv) in zip(f.loops, coords):
            nu = u0 + ((cu - min_u) / du) * (u1 - u0)
            nv = v0 + ((cv - min_v) / dv) * (v1 - v0)
            loop[uv_layer].uv = (nu, nv)


def add_beveled_part(bm, uv_layer, size, center, uv_rect, bevel_offset=0.04, bevel_segs=3, axis="AUTO"):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
    sx, sy, sz = size
    cx, cy, cz = center
    for v in verts:
        v.co.x = v.co.x * sx + cx
        v.co.y = v.co.y * sy + cy
        v.co.z = v.co.z * sz + cz

    edges = list({e for v in verts for e in v.link_edges})
    if bevel_offset > 0.0:
        bmesh.ops.bevel(
            bm,
            geom=edges,
            offset=bevel_offset,
            offset_type='OFFSET',
            segments=bevel_segs,
            profile=0.5,
            affect='EDGES',
            clamp_overlap=True,
        )

    part_faces = list({f for v in bm.verts if (v.co - Vector(center)).length < max(size) * 1.5 for f in v.link_faces})
    # Filter faces belonging strictly to this sub-component via flood fill from initial verts
    seed_verts = set()
    for v in bm.verts:
        if (abs(v.co.x - cx) <= sx * 0.51 and
            abs(v.co.y - cy) <= sy * 0.51 and
            abs(v.co.z - cz) <= sz * 0.51):
            seed_verts.add(v)
    part_faces = [f for f in bm.faces if all(v in seed_verts for v in f.verts)]
    assign_box_uv(bm, uv_layer, part_faces, *uv_rect, axis=axis)
    return part_faces


def build_curved_van_body(bm, uv_layer):
    # Profil X-Z dan Y-Z dengan kap melengkung dan bevel halus
    # Z=0.0 adalah titik bawah roda (ground), sehingga bagian bawah sasis di Z=0.38
    y_stations = [
        (-2.35, 0.96, 0.38, 2.18, 0.00),  # Belakang
        (-1.45, 0.98, 0.38, 2.20, 0.00),  # Roda belakang
        (0.55,  0.98, 0.38, 2.20, 0.00),  # Pilar B (akhir boks belakang)
        (0.95,  0.97, 0.38, 2.16, 0.02),  # Atas kaca depan
        (1.48,  0.95, 0.38, 1.38, 0.14),  # Pangkal kap mesin melengkung
        (1.88,  0.93, 0.38, 1.24, 0.18),  # Tengah kap melengkung
        (2.18,  0.90, 0.40, 1.06, 0.16),  # Ujung depan kap melengkung
        (2.30,  0.86, 0.44, 0.88, 0.10),  # Hidung depan / grille
    ]

    # Profil cross-section 12 titik mengelilingi bodi (membulat di atap & sudut bawah)
    rings = []
    for y, hw, z_bot, z_top, arch in y_stations:
        h = z_top - z_bot
        pts = [
            (-hw * 0.88, y, z_bot),
            (0.0,        y, z_bot),
            (hw * 0.88,  y, z_bot),
            (hw,         y, z_bot + h * 0.16),
            (hw,         y, z_bot + h * 0.58),
            (hw * 0.95,  y, z_top - h * 0.10),
            (hw * 0.72,  y, z_top + arch * 0.75),
            (0.0,        y, z_top + arch),
            (-hw * 0.72, y, z_top + arch * 0.75),
            (-hw * 0.95, y, z_top - h * 0.10),
            (-hw,        y, z_bot + h * 0.58),
            (-hw,        y, z_bot + h * 0.16),
        ]
        rings.append([bm.verts.new(p) for p in pts])

    n_pts = len(rings[0])
    for r_idx in range(len(rings) - 1):
        r0 = rings[r_idx]
        r1 = rings[r_idx + 1]
        for i in range(n_pts):
            ni = (i + 1) % n_pts
            f = bm.faces.new((r0[i], r0[ni], r1[ni], r1[i]))
            # Pemetaan UV berdasarkan bagian bodi
            if r_idx <= 1 and i in (3, 4, 9, 10):
                # Sisi boks ambulans (strip merah-oranye + tulisan AMBULANS)
                assign_box_uv(bm, uv_layer, [f], 0.01, 0.76, 0.49, 0.99, axis="SIDE")
            elif r_idx in (4, 5, 6) and i in (5, 6, 7, 8):
                # Kap mesin melengkung (tulisan AMBULANS kap)
                assign_box_uv(bm, uv_layer, [f], 0.51, 0.76, 0.74, 0.99, axis="TOP")
            elif r_idx in (2, 3) and i in (5, 6, 7, 8):
                # Kaca depan (windshield)
                assign_box_uv(bm, uv_layer, [f], 0.02, 0.52, 0.23, 0.73, axis="FRONT")
            elif r_idx in (2, 3) and i in (4, 9):
                # Kaca pintu samping
                assign_box_uv(bm, uv_layer, [f], 0.02, 0.52, 0.23, 0.73, axis="SIDE")
            else:
                # Bodi putih glossy
                assign_box_uv(bm, uv_layer, [f], 0.28, 0.28, 0.58, 0.47, axis="AUTO")

    # Tutup belakang (Rear double doors)
    f_rear = bm.faces.new(list(reversed(rings[0])))
    assign_box_uv(bm, uv_layer, [f_rear], 0.76, 0.76, 0.99, 0.99, axis="FRONT")

    # Tutup hidung depan (Grille)
    f_front = bm.faces.new(rings[-1])
    assign_box_uv(bm, uv_layer, [f_front], 0.77, 0.52, 0.98, 0.73, axis="FRONT")


def build_body_object(collection, mat):
    mesh = bpy.data.meshes.new("Body_Mesh")
    obj = bpy.data.objects.new("Body", mesh)
    collection.objects.link(obj)
    obj.data.materials.append(mat)

    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    # 1. Bodi utama dengan kap melengkung
    build_curved_van_body(bm, uv_layer)

    # 2. Bumper depan & belakang ber-bevel
    add_beveled_part(bm, uv_layer, (1.92, 0.24, 0.26), (0.0, 2.28, 0.46), (0.77, 0.52, 0.98, 0.73), bevel_offset=0.05, bevel_segs=3)
    add_beveled_part(bm, uv_layer, (1.98, 0.22, 0.24), (0.0, -2.36, 0.44), (0.77, 0.52, 0.98, 0.73), bevel_offset=0.04, bevel_segs=3)

    # 3. Spion kiri & kanan (tangkai + rumah kaca ber-bevel)
    for side in (-1.0, 1.0):
        add_beveled_part(bm, uv_layer, (0.18, 0.06, 0.05), (side * 1.02, 1.28, 1.46), (0.77, 0.52, 0.98, 0.73), bevel_offset=0.01, bevel_segs=2)
        add_beveled_part(bm, uv_layer, (0.12, 0.16, 0.22), (side * 1.12, 1.26, 1.50), (0.28, 0.28, 0.58, 0.47), bevel_offset=0.03, bevel_segs=3)

    # 4. Gagang pintu (2 pintu depan, pintu samping, 2 pintu belakang ganda)
    door_handles = [
        (-0.99, 0.68, 1.15, (0.05, 0.16, 0.05)),
        (0.99,  0.68, 1.15, (0.05, 0.16, 0.05)),
        (0.99, -0.35, 1.15, (0.05, 0.16, 0.05)),
        (-0.12, -2.37, 1.12, (0.14, 0.05, 0.05)),
        (0.12,  -2.37, 1.12, (0.14, 0.05, 0.05)),
    ]
    for hx, hy, hz, hdim in door_handles:
        add_beveled_part(bm, uv_layer, hdim, (hx, hy, hz), (0.77, 0.52, 0.98, 0.73), bevel_offset=0.01, bevel_segs=2)

    # 5. Roof Light Bar (Sirine Merah - Putih - Biru melengkung di atap)
    add_beveled_part(bm, uv_layer, (0.52, 0.24, 0.14), (-0.34, 0.75, 2.26), (0.27, 0.52, 0.35, 0.73), bevel_offset=0.03, bevel_segs=3)
    add_beveled_part(bm, uv_layer, (0.16, 0.25, 0.15), (0.00,  0.75, 2.26), (0.28, 0.28, 0.58, 0.47), bevel_offset=0.02, bevel_segs=2)
    add_beveled_part(bm, uv_layer, (0.52, 0.24, 0.14), (0.34,  0.75, 2.26), (0.40, 0.52, 0.48, 0.73), bevel_offset=0.03, bevel_segs=3)

    # 6. Lampu depan (Headlights + Sein Oranye) & Lampu belakang (Taillights)
    for side in (-1.0, 1.0):
        # Headlight
        add_beveled_part(bm, uv_layer, (0.30, 0.12, 0.16), (side * 0.68, 2.24, 0.74), (0.02, 0.39, 0.10, 0.48), bevel_offset=0.02, bevel_segs=2)
        # Front Turn Signal (Orange)
        add_beveled_part(bm, uv_layer, (0.12, 0.12, 0.16), (side * 0.86, 2.20, 0.74), (0.02, 0.27, 0.22, 0.36), bevel_offset=0.02, bevel_segs=2)
        # Taillight
        add_beveled_part(bm, uv_layer, (0.16, 0.10, 0.38), (side * 0.84, -2.35, 0.86), (0.14, 0.39, 0.23, 0.48), bevel_offset=0.02, bevel_segs=2)

    # 7. Fender / Lengkungan Roda (Wheel Arches)
    for side in (-1.0, 1.0):
        for wy in (1.42, -1.45):
            add_beveled_part(bm, uv_layer, (0.14, 0.88, 0.16), (side * 0.96, wy, 0.74), (0.28, 0.28, 0.58, 0.47), bevel_offset=0.03, bevel_segs=2)

    # Subdivide satu level secara selektif agar segitiga berada tepat di rentang 3.000 - 10.000
    bmesh.ops.subdivide_edges(
        bm,
        edges=list(bm.edges),
        cuts=1,
        use_grid_fill=True,
    )

    # Pastikan semua normal menghadap keluar dan smooth shading aktif
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True

    bm.to_mesh(mesh)
    bm.free()

    # Origin bodi berada di (0, 0, 0) tepat di tengah bawah antara roda
    obj.location = (0.0, 0.0, 0.0)
    return obj


def build_wheel_object(collection, mat, name, center_pos, radius=0.38, width=0.26, segments=24):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.data.materials.append(mat)

    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    # Buat profil ban & velg 24 sisi dengan bevel dan cekungan velg silver
    # Dibangun lokal di (0,0,0) sehingga origin objek tepat di tengah poros roda
    half_w = width * 0.5
    r_outer = radius
    r_shoulder = radius * 0.93
    r_rim = radius * 0.62
    r_hub = radius * 0.22

    # Ring X-axis (lebar roda) vs Radius
    profile_rings = [
        (-half_w * 0.72, r_hub),
        (-half_w * 0.78, r_rim),
        (-half_w * 0.96, r_rim * 1.04),
        (-half_w,        r_shoulder),
        (-half_w * 0.85, r_outer),
        (half_w * 0.85,  r_outer),
        (half_w,         r_shoulder),
        (half_w * 0.96,  r_rim * 1.04),
        (half_w * 0.78,  r_rim),
        (half_w * 0.72,  r_hub),
    ]

    rings = []
    for x_pos, rad in profile_rings:
        ring_verts = []
        for s in range(segments):
            ang = (2.0 * math.pi * s) / segments
            y = math.cos(ang) * rad
            z = math.sin(ang) * rad
            ring_verts.append(bm.verts.new((x_pos, y, z)))
        rings.append(ring_verts)

    # Tutup pusat poros kiri & kanan
    v_center_l = bm.verts.new((-half_w * 0.68, 0.0, 0.0))
    v_center_r = bm.verts.new((half_w * 0.68, 0.0, 0.0))

    for r_idx in range(len(rings) - 1):
        r0 = rings[r_idx]
        r1 = rings[r_idx + 1]
        for s in range(segments):
            ns = (s + 1) % segments
            f = bm.faces.new((r0[s], r0[ns], r1[ns], r1[s]))
            f.smooth = True
            # Mapping UV ke Tile Ban & Velg (u: 0.51..0.74, v: 0.51..0.74)
            if r_idx in (0, 1, 7, 8):
                # Area velg silver
                for loop in f.loops:
                    co = loop.vert.co
                    u = 0.625 + (co.y / r_outer) * 0.105
                    v = 0.625 + (co.z / r_outer) * 0.105
                    loop[uv_layer].uv = (u, v)
            else:
                # Area tapak & dinding ban hitam
                coords = [(0.515, 0.515), (0.545, 0.515), (0.545, 0.735), (0.515, 0.735)]
                for i, loop in enumerate(f.loops):
                    loop[uv_layer].uv = coords[i % 4]

    # Fan faces untuk tutup hub tengah
    for s in range(segments):
        ns = (s + 1) % segments
        f_l = bm.faces.new((rings[0][ns], rings[0][s], v_center_l))
        f_r = bm.faces.new((rings[-1][s], rings[-1][ns], v_center_r))
        for f in (f_l, f_r):
            f.smooth = True
            for loop in f.loops:
                co = loop.vert.co
                u = 0.625 + (co.y / r_outer) * 0.105
                v = 0.625 + (co.z / r_outer) * 0.105
                loop[uv_layer].uv = (u, v)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    # Set lokasi roda di posisi poros masing-masing (origin tetap di tengah poros)
    obj.location = center_pos
    return obj


def count_collection_triangles(collection):
    total_tris = 0
    for obj in collection.objects:
        if obj.type == 'MESH':
            for poly in obj.data.polygons:
                total_tris += len(poly.vertices) - 2
    return total_tris


def main():
    asset_name = "ambulans"
    tex_dir = get_script_dir()

    # Buat koleksi baru bernama 'ambulans' tanpa menghapus objek lain di scene
    col = bpy.data.collections.get(asset_name)
    if col is None:
        col = bpy.data.collections.new(asset_name)
        bpy.context.scene.collection.children.link(col)
    else:
        for old_obj in list(col.objects):
            bpy.data.objects.remove(old_obj, do_unlink=True)

    # Buat material PBR 1024x1024
    mat = create_pbr_material(tex_dir, mat_name="M_Ambulans")

    # Bangun Bodi & 4 Roda (24 sisi)
    body_obj = build_body_object(col, mat)

    wheel_specs = [
        ("Wheel_FL", (-0.88,  1.42, 0.38)),
        ("Wheel_FR", (0.88,   1.42, 0.38)),
        ("Wheel_RL", (-0.88, -1.45, 0.38)),
        ("Wheel_RR", (0.88,  -1.45, 0.38)),
    ]
    wheel_objs = [
        build_wheel_object(col, mat, w_name, w_pos, radius=0.38, width=0.26, segments=24)
        for w_name, w_pos in wheel_specs
    ]

    all_meshes = [body_obj] + wheel_objs

    # Terapkan skala & rotasi transformasi tanpa mengubah posisi origin roda/bodi
    bpy.ops.object.select_all(action='DESELECT')
    for obj in all_meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = body_obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    tri_count = count_collection_triangles(col)
    print(f"[{asset_name}] Total segitiga mesh: {tri_count} triangles")

    # Ekspor hanya objek mesh di koleksi 'ambulans' ke ambulans.fbx
    fbx_path = os.path.join(tex_dir, f"{asset_name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        object_types={'MESH'},
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        use_space_transform=True,
        bake_space_transform=True,
        axis_forward='-Z',
        axis_up='Y',
        mesh_smooth_type='FACE',
        path_mode='COPY',
        embed_textures=True,
    )
    print(f"[{asset_name}] Berhasil diekspor ke: {fbx_path}")


if __name__ == "__main__":
    main()
