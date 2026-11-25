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
    stem = "meja_kasir"
    col = ensure_collection(stem)
    objs = []

    mat_counter = create_proc_mat("Mat_MejaBiru", (0.16, 0.52, 0.94, 1.0), rough1=0.40)
    mat_top = create_proc_mat("Mat_TopPutih", (0.95, 0.96, 0.98, 1.0), rough1=0.35)
    mat_pos = create_proc_mat("Mat_MesinKasir", (0.22, 0.25, 0.30, 1.0), rough1=0.38)
    mat_screen = create_proc_mat("Mat_LayarHijau", (0.18, 0.82, 0.52, 1.0), rough1=0.18)
    mat_candy = create_proc_mat("Mat_PermenWarna", (0.98, 0.36, 0.56, 1.0), (0.98, 0.84, 0.14, 1.0), mode="NOISE", scale=18.0)

    # Ukuran 8 (X) x 3 (Z) x 3.4 (Y)
    bm_base = bmesh.new()
    # Meja utama & meja samping bentuk L ringan
    add_rbx_box(bm_base, 0.0, 1.55, 0.0, 8.0, 3.10, 2.6, bevel_w=0.05, bevel_segs=2)
    # Rak depan kecil keranjang permen di sisi pelanggan (-Z)
    add_rbx_box(bm_base, -2.4, 1.15, -1.35, 2.4, 2.30, 0.45, bevel_w=0.03, bevel_segs=1)
    objs.append(make_mesh_obj(col, "BadanMeja", bm_base, mat_counter))

    # Daun meja atas putih & tempat kantong plastik di ujung kanan (X=+3.3)
    bm_top = bmesh.new()
    add_rbx_box(bm_top, 0.0, 3.22, 0.0, 8.2, 0.24, 2.8, bevel_w=0.04, bevel_segs=2)
    # Tiang gantungan kantong plastik
    add_rbx_cyl(bm_top, 3.3, 3.85, 0.0, 0.06, 0.06, 1.1, segs=10, axis='Y')
    add_rbx_box(bm_top, 3.3, 4.35, 0.0, 0.90, 0.08, 0.08)
    add_rbx_box(bm_top, 3.3, 3.85, 0.0, 0.82, 0.85, 0.16, bevel_w=0.02, bevel_segs=1)
    objs.append(make_mesh_obj(col, "TopMejaPlastik", bm_top, mat_top))

    # Mesin kasir & timbangan kecil di atas meja
    bm_pos = bmesh.new()
    # Laci uang & bodi kasir (X=-0.8)
    add_rbx_box(bm_pos, -0.8, 3.55, 0.1, 1.5, 0.42, 1.3, bevel_w=0.03, bevel_segs=2)
    # Monitor kasir sederhana tanpa merek
    add_rbx_box(bm_pos, -0.8, 4.25, 0.1, 1.35, 0.95, 0.16, bevel_w=0.03, bevel_segs=2, rot_euler=(0.25, 0.0, 0.0))
    # Timbangan digital kecil (X=1.2)
    add_rbx_box(bm_pos, 1.2, 3.48, -0.1, 1.1, 0.28, 1.1, bevel_w=0.03, bevel_segs=2)
    add_rbx_box(bm_pos, 1.2, 3.68, -0.1, 1.0, 0.08, 1.0, bevel_w=0.02, bevel_segs=1)
    objs.append(make_mesh_obj(col, "MesinKasirTimbangan", bm_pos, mat_pos))

    # Layar mesin kasir
    bm_scr = bmesh.new()
    add_rbx_box(bm_scr, -0.8, 4.25, 0.02, 1.15, 0.76, 0.04, rot_euler=(0.25, 0.0, 0.0))
    objs.append(make_mesh_obj(col, "LayarKasir", bm_scr, mat_screen))

    # Keranjang permen warna-warni di depan meja (X=-2.4, Y=2.45, Z=-1.35)
    bm_cnd = bmesh.new()
    for cx in (-3.1, -2.4, -1.7):
        add_rbx_sphere(bm_cnd, cx, 2.45, -1.35, 0.26, 0.22, 0.22)
    objs.append(make_mesh_obj(col, "PermenKasir", bm_cnd, mat_candy))

    bake_and_export_objects(stem, objs, join_all=True)


if __name__ == "__main__":
    build()
