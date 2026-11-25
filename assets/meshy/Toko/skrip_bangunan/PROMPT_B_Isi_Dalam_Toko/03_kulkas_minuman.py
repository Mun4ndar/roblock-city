import bpy, bmesh, math, mathutils, os


def ensure_collection(col_name):
    col = bpy.data.collections.get(col_name)
    if col is None:
        col = bpy.data.collections.new(col_name)
        bpy.context.scene.collection.children.link(col)
    else:
        for obj in list(col.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    return col


def rbx_to_bl(x, y_up, z_depth):
    # Konversi koordinat Roblox (X=lebar, Y=tinggi, Z=dalam, depan=-Z)
    # ke koordinat Blender (X=lebar, Y=dalam, Z=tinggi) agar saat ekspor FBX
    # dengan axis_forward='-Z', axis_up='Y', hasil di Roblox tepat sesuai ukuran!
    return (x, z_depth, y_up)


def add_rbx_box(bm, cx, cy, cz, sx, sy, sz, bevel_w=0.0, bevel_segs=2, rot_euler=(0.0, 0.0, 0.0)):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
    # Skala dalam ruang Blender: X=sx, Y=sz (dalam), Z=sy (tinggi)
    for v in verts:
        v.co.x *= sx
        v.co.y *= sz
        v.co.z *= sy

    edges = list({e for v in verts for e in v.link_edges})
    if bevel_w > 0.0:
        res = bmesh.ops.bevel(
            bm,
            geom=edges,
            offset=bevel_w,
            offset_type='OFFSET',
            segments=bevel_segs,
            profile=0.5,
            affect='EDGES',
            clamp_overlap=True,
        )
        part_verts = list(res["verts"])
    else:
        part_verts = list(verts)

    if any(abs(a) > 1e-6 for a in rot_euler):
        rot_mat = mathutils.Euler(rot_euler, 'XYZ').to_matrix()
        bmesh.ops.rotate(bm, verts=part_verts, cent=(0.0, 0.0, 0.0), matrix=rot_mat)

    bx, by, bz = rbx_to_bl(cx, cy, cz)
    for v in part_verts:
        v.co.x += bx
        v.co.y += by
        v.co.z += bz
    return part_verts


def add_rbx_cyl(bm, cx, cy, cz, r1, r2, height, segs=18, axis='Y'):
    # axis='Y' berarti tegak vertikal (tinggi di Roblox Y = Blender Z)
    ret = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segs,
        radius1=r1,
        radius2=r2,
        depth=height,
    )
    verts = ret["verts"]
    if axis == 'X':
        rot_mat = mathutils.Euler((0.0, math.radians(90.0), 0.0), 'XYZ').to_matrix()
        bmesh.ops.rotate(bm, verts=verts, cent=(0.0, 0.0, 0.0), matrix=rot_mat)
    elif axis == 'Z':
        rot_mat = mathutils.Euler((math.radians(90.0), 0.0, 0.0), 'XYZ').to_matrix()
        bmesh.ops.rotate(bm, verts=verts, cent=(0.0, 0.0, 0.0), matrix=rot_mat)

    bx, by, bz = rbx_to_bl(cx, cy, cz)
    for v in verts:
        v.co.x += bx
        v.co.y += by
        v.co.z += bz
    return verts


def add_rbx_sphere(bm, cx, cy, cz, rx, ry, rz, u_segs=16, v_segs=10):
    ret = bmesh.ops.create_uvsphere(bm, u_segments=u_segs, v_segments=v_segs, radius=1.0)
    bx, by, bz = rbx_to_bl(cx, cy, cz)
    for v in ret["verts"]:
        v.co.x = v.co.x * rx + bx
        v.co.y = v.co.y * rz + by
        v.co.z = v.co.z * ry + bz
    return ret["verts"]


def make_mesh_obj(col, name, bm, mat, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def add_rbx_text(col, text_str, size, cx, cy, cz, mat, rot_euler=(math.radians(90.0), 0.0, 0.0), extrude=0.08):
    bx, by, bz = rbx_to_bl(cx, cy, cz)
    bpy.ops.object.text_add(location=(bx, by, bz), rotation=rot_euler)
    txt_obj = bpy.context.active_object
    txt_obj.data.body = text_str
    txt_obj.data.size = size
    txt_obj.data.extrude = extrude
    txt_obj.data.align_x = 'CENTER'
    txt_obj.data.align_y = 'CENTER'
    bpy.ops.object.convert(target='MESH')
    mesh_obj = bpy.context.active_object
    for c in list(mesh_obj.users_collection):
        c.objects.unlink(mesh_obj)
    col.objects.link(mesh_obj)
    mesh_obj.data.materials.append(mat)
    return mesh_obj


def create_proc_mat(name, col1, col2=None, rough1=0.45, rough2=0.65, mode="SOLID", scale=6.0, alpha=1.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (300, 0)
    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = 'BLEND'

    tex_coord = nodes.new("ShaderNodeTexCoord")
    tex_coord.location = (-700, 0)

    if mode == "SOLID" or col2 is None:
        bsdf.inputs["Base Color"].default_value = col1
        bsdf.inputs["Roughness"].default_value = rough1
    elif mode == "NOISE":
        noise = nodes.new("ShaderNodeTexNoise")
        noise.location = (-450, 120)
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 4.0
        links.new(tex_coord.outputs["Object"], noise.inputs["Vector"])

        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.location = (-180, 160)
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[0].color = col1
        ramp.color_ramp.elements[1].position = 0.65
        ramp.color_ramp.elements[1].color = col2
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])

        rramp = nodes.new("ShaderNodeValToRGB")
        rramp.location = (-180, -140)
        rramp.color_ramp.elements[0].color = (rough1, rough1, rough1, 1.0)
        rramp.color_ramp.elements[1].color = (rough2, rough2, rough2, 1.0)
        links.new(noise.outputs["Fac"], rramp.inputs["Fac"])
        links.new(rramp.outputs["Color"], bsdf.inputs["Roughness"])
    elif mode == "CHECKER":
        chk = nodes.new("ShaderNodeTexChecker")
        chk.location = (-450, 120)
        chk.inputs["Scale"].default_value = scale
        chk.inputs["Color1"].default_value = col1
        chk.inputs["Color2"].default_value = col2
        links.new(tex_coord.outputs["Object"], chk.inputs["Vector"])
        links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough1
    elif mode == "WAVE":
        wave = nodes.new("ShaderNodeTexWave")
        wave.location = (-450, 120)
        wave.wave_type = 'BANDS'
        wave.bands_direction = 'DIAGONAL'
        wave.inputs["Scale"].default_value = scale
        links.new(tex_coord.outputs["Object"], wave.inputs["Vector"])

        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.location = (-180, 160)
        ramp.color_ramp.elements[0].position = 0.45
        ramp.color_ramp.elements[0].color = col1
        ramp.color_ramp.elements[1].position = 0.55
        ramp.color_ramp.elements[1].color = col2
        links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough1

    return mat


def bake_and_export_objects(file_stem, objs, join_all=False, origin_override=None):
    export_dir = r"D:\ROBLOX STUDIO\assets\meshy\Toko"
    os.makedirs(export_dir, exist_ok=True)

    if join_all and len(objs) > 1:
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        merged = bpy.context.active_object
        merged.name = file_stem
        objs = [merged]

    if origin_override is not None:
        ox, oy, oz = rbx_to_bl(*origin_override)
        for o in objs:
            for v in o.data.vertices:
                v.co.x -= ox
                v.co.y -= oy
                v.co.z -= oz

    # UV unwrap & bake 512x512 (Base Color & Roughness) untuk setiap objek/material
    orig_engine = bpy.context.scene.render.engine
    orig_samples = bpy.context.scene.cycles.samples
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.device = 'CPU'
    bpy.context.scene.cycles.samples = 4

    for idx, o in enumerate(objs):
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o

        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
        bpy.ops.object.mode_set(mode='OBJECT')

        tag = f"{file_stem}_{o.name}" if len(objs) > 1 else file_stem
        img_col = bpy.data.images.new(f"{tag}_BaseColor", width=512, height=512)
        img_rgh = bpy.data.images.new(f"{tag}_Roughness", width=512, height=512, is_data=True)

        alpha_val = 1.0
        for m in o.data.materials:
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == 'BSDF_PRINCIPLED':
                        alpha_val = n.inputs["Alpha"].default_value
                tn = m.node_tree.nodes.new("ShaderNodeTexImage")
                tn.image = img_col
                m.node_tree.nodes.active = tn

        bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
        img_col.filepath_raw = os.path.join(export_dir, f"{tag}_BaseColor.png")
        img_col.file_format = 'PNG'
        img_col.save()
        img_col.pack()

        for m in o.data.materials:
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == 'TEX_IMAGE' and n.image == img_col:
                        n.image = img_rgh
                        m.node_tree.nodes.active = n

        bpy.ops.object.bake(type='ROUGHNESS', use_clear=True)
        img_rgh.filepath_raw = os.path.join(export_dir, f"{tag}_Roughness.png")
        img_rgh.file_format = 'PNG'
        img_rgh.save()
        img_rgh.pack()

        final_mat = bpy.data.materials.new(name=f"M_{tag}_PBR")
        final_mat.use_nodes = True
        fn = final_mat.node_tree.nodes
        fl = final_mat.node_tree.links
        fn.clear()
        bsdf = fn.new("ShaderNodeBsdfPrincipled")
        out = fn.new("ShaderNodeOutputMaterial")
        fl.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        if alpha_val < 1.0:
            bsdf.inputs["Alpha"].default_value = alpha_val
            final_mat.blend_method = 'BLEND'

        tc = fn.new("ShaderNodeTexImage")
        tc.image = img_col
        fl.new(tc.outputs["Color"], bsdf.inputs["Base Color"])

        tr = fn.new("ShaderNodeTexImage")
        tr.image = img_rgh
        fl.new(tr.outputs["Color"], bsdf.inputs["Roughness"])

        o.data.materials.clear()
        o.data.materials.append(final_mat)

    bpy.context.scene.render.engine = orig_engine
    bpy.context.scene.cycles.samples = orig_samples

    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

    fbx_path = os.path.join(export_dir, f"{file_stem}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        axis_forward='-Z',
        axis_up='Y',
        global_scale=1.0,
        apply_unit_scale=True,
        path_mode='COPY',
        embed_textures=True,
    )
    print(f"SELESAI: {file_stem}")

def build():
    stem = "kulkas_minuman"
    col = ensure_collection(stem)
    body_objs = []

    mat_body = create_proc_mat("Mat_KulkasPutih", (0.94, 0.96, 0.98, 1.0), rough1=0.32)
    mat_panel = create_proc_mat("Mat_PanelBiru", (0.12, 0.46, 0.92, 1.0), rough1=0.35)
    mat_txt = create_proc_mat("Mat_TeksPutih", (0.99, 0.99, 1.0, 1.0), rough1=0.35)
    mat_led = create_proc_mat("Mat_StripPutih", (1.0, 1.0, 0.96, 1.0), rough1=0.15)
    mat_glass = create_proc_mat("Mat_KacaKulkas", (0.65, 0.90, 0.99, 1.0), rough1=0.10, alpha=0.36)
    drink_mats = [
        create_proc_mat("Mat_MinumanMerah", (0.92, 0.18, 0.20, 1.0), rough1=0.25),
        create_proc_mat("Mat_MinumanBiru", (0.16, 0.56, 0.96, 1.0), rough1=0.25),
        create_proc_mat("Mat_MinumanOranye", (0.98, 0.56, 0.10, 1.0), rough1=0.25),
    ]

    # Ukuran 5 (X) x 2.5 (Z) x 7 (Y)
    bm_cab = bmesh.new()
    # Bawah, belakang, atas, kiri, kanan
    add_rbx_box(bm_cab, 0.0, 0.45, 0.0, 5.0, 0.90, 2.5, bevel_w=0.04, bevel_segs=2)
    add_rbx_box(bm_cab, 0.0, 3.50, 1.12, 5.0, 6.20, 0.26)
    add_rbx_box(bm_cab, -2.35, 3.50, 0.0, 0.30, 6.20, 2.5)
    add_rbx_box(bm_cab,  2.35, 3.50, 0.0, 0.30, 6.20, 2.5)
    # 4 Rak dalam kulkas
    for sy in (1.8, 3.0, 4.2, 5.4):
        add_rbx_box(bm_cab, 0.0, sy, 0.05, 4.3, 0.10, 1.9)
    # Bingkai pintu kaca depan (Z = -1.18)
    add_rbx_box(bm_cab, -2.15, 3.45, -1.18, 0.28, 5.10, 0.18)
    add_rbx_box(bm_cab,  2.15, 3.45, -1.18, 0.28, 5.10, 0.18)
    add_rbx_box(bm_cab,  0.0,  1.00, -1.18, 4.58, 0.24, 0.18)
    add_rbx_box(bm_cab,  0.0,  5.90, -1.18, 4.58, 0.24, 0.18)
    add_rbx_box(bm_cab, -1.85, 3.45, -1.32, 0.10, 1.20, 0.12)
    body_objs.append(make_mesh_obj(col, "KabinetKulkas", bm_cab, mat_body))

    # Panel atas biru bertulisan "Minuman Dingin" (Y=6.05..7.0)
    bm_top = bmesh.new()
    add_rbx_box(bm_top, 0.0, 6.52, -0.02, 5.0, 0.96, 2.52, bevel_w=0.04, bevel_segs=2)
    body_objs.append(make_mesh_obj(col, "PanelAtas", bm_top, mat_panel))
    body_objs.append(add_rbx_text(col, "Minuman Dingin", 0.36, 0.0, 6.52, -1.30, mat_txt, extrude=0.04))

    # Lampu strip putih di dalam sisi kiri & kanan
    bm_led = bmesh.new()
    add_rbx_box(bm_led, -2.14, 3.45, -0.95, 0.08, 4.8, 0.08)
    add_rbx_box(bm_led,  2.14, 3.45, -0.95, 0.08, 4.8, 0.08)
    body_objs.append(make_mesh_obj(col, "LampuStrip", bm_led, mat_led))

    # Isi botol dan kaleng warna-warni
    for d_i, dmat in enumerate(drink_mats):
        bm_d = bmesh.new()
        for r_i, sy in enumerate((1.8, 3.0, 4.2, 5.4)):
            for cx_i in range(-2, 3):
                if (cx_i + r_i) % 3 == d_i:
                    for cz in (-0.45, 0.25):
                        add_rbx_cyl(bm_d, cx_i * 0.78, sy + 0.42, cz, 0.20, 0.20, 0.72, segs=12, axis='Y')
        body_objs.append(make_mesh_obj(col, f"Minuman_{d_i}", bm_d, dmat))

    # Kaca kulkas terpisah bernama "Kaca"
    bm_glass = bmesh.new()
    add_rbx_box(bm_glass, 0.0, 3.45, -1.18, 4.02, 4.66, 0.06)
    glass_obj = make_mesh_obj(col, "Kaca", bm_glass, mat_glass)

    # Join semua bagian bodi menjadi satu mesh, pertahankan "Kaca" terpisah
    bpy.ops.object.select_all(action='DESELECT')
    for o in body_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body_objs[0]
    bpy.ops.object.join()
    joined_body = bpy.context.active_object
    joined_body.name = stem

    bake_and_export_objects(stem, [joined_body, glass_obj], join_all=False)


if __name__ == "__main__":
    build()
