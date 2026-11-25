import bpy, bmesh, math, mathutils
import os


def ensure_collection(col_name):
    col = bpy.data.collections.get(col_name)
    if col is None:
        col = bpy.data.collections.new(col_name)
        bpy.context.scene.collection.children.link(col)
    else:
        for obj in list(col.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    return col


def make_bmesh_object(col, name, bm, mat=None, smooth=True):
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


def add_cylinder(bm, r1, r2, height, segs=18, z_offset=0.0, cap_ends=True):
    ret = bmesh.ops.create_cone(
        bm,
        cap_ends=cap_ends,
        cap_tris=False,
        segments=segs,
        radius1=r1,
        radius2=r2,
        depth=height,
    )
    for v in ret["verts"]:
        v.co.z += z_offset
    return ret["verts"]


def add_uv_sphere(bm, radius, u_segs=18, v_segs=12, scale=(1.0, 1.0, 1.0), offset=(0.0, 0.0, 0.0)):
    ret = bmesh.ops.create_uvsphere(bm, u_segments=u_segs, v_segments=v_segs, radius=radius)
    for v in ret["verts"]:
        v.co.x = v.co.x * scale[0] + offset[0]
        v.co.y = v.co.y * scale[1] + offset[1]
        v.co.z = v.co.z * scale[2] + offset[2]
    return ret["verts"]


def add_beveled_box(bm, size, offset=(0.0, 0.0, 0.0), bevel_w=0.008, bevel_segs=2, rot_euler=(0.0, 0.0, 0.0)):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
    for v in verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
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
    for v in part_verts:
        v.co.x += offset[0]
        v.co.y += offset[1]
        v.co.z += offset[2]
    return part_verts


def create_proc_material(name, color1, color2=None, rough1=0.35, rough2=0.55, mode="SOLID", scale=12.0, alpha=1.0):
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

    if mode == "SOLID" or color2 is None:
        bsdf.inputs["Base Color"].default_value = color1
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
        ramp.color_ramp.elements[0].color = color1
        ramp.color_ramp.elements[1].position = 0.65
        ramp.color_ramp.elements[1].color = color2
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])

        rramp = nodes.new("ShaderNodeValToRGB")
        rramp.location = (-180, -140)
        rramp.color_ramp.elements[0].color = (rough1, rough1, rough1, 1.0)
        rramp.color_ramp.elements[1].color = (rough2, rough2, rough2, 1.0)
        links.new(noise.outputs["Fac"], rramp.inputs["Fac"])
        links.new(rramp.outputs["Color"], bsdf.inputs["Roughness"])
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
        ramp.color_ramp.elements[0].color = color1
        ramp.color_ramp.elements[1].position = 0.55
        ramp.color_ramp.elements[1].color = color2
        links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough1
    elif mode == "CHECKER":
        chk = nodes.new("ShaderNodeTexChecker")
        chk.location = (-450, 120)
        chk.inputs["Scale"].default_value = scale
        chk.inputs["Color1"].default_value = color1
        chk.inputs["Color2"].default_value = color2
        links.new(tex_coord.outputs["Object"], chk.inputs["Vector"])
        links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough2

    return mat


def add_3d_label_text(col, text_str, size, loc, rot_euler, mat):
    bpy.ops.object.text_add(location=loc, rotation=rot_euler)
    txt_obj = bpy.context.active_object
    txt_obj.data.body = text_str
    txt_obj.data.size = size
    txt_obj.data.extrude = 0.002
    txt_obj.data.align_x = 'CENTER'
    txt_obj.data.align_y = 'CENTER'
    bpy.ops.object.convert(target='MESH')
    mesh_obj = bpy.context.active_object
    # Pindahkan ke collection target
    for c in list(mesh_obj.users_collection):
        c.objects.unlink(mesh_obj)
    col.objects.link(mesh_obj)
    mesh_obj.data.materials.append(mat)
    return mesh_obj


def join_bake_and_export(col, item_name, objs, grip_offset=(0.0, 0.0, 0.0), export_rot=(0.0, 0.0, 0.0)):
    export_dir = r"D:\ROBLOX STUDIO\assets\meshy\Toko"
    os.makedirs(export_dir, exist_ok=True)

    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    main_obj = bpy.context.active_object
    main_obj.name = item_name

    # Geser geometri sehingga origin berada tepat di titik genggam tangan (0,0,0)
    if any(abs(v) > 1e-6 for v in grip_offset):
        for v in main_obj.data.vertices:
            v.co.x -= grip_offset[0]
            v.co.y -= grip_offset[1]
            v.co.z -= grip_offset[2]

    # Terapkan rotasi arah hadap -Z dan atas +Y
    if any(abs(a) > 1e-6 for a in export_rot):
        main_obj.rotation_euler = mathutils.Euler(export_rot, 'XYZ')
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # Smart UV Project rapi untuk proses Bake 512x512
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

    # Bake tekstur prosedural ke gambar 512x512 (Base Color & Roughness) dan pack ke file
    img_col = bpy.data.images.new(f"{item_name}_BaseColor", width=512, height=512)
    img_rgh = bpy.data.images.new(f"{item_name}_Roughness", width=512, height=512, is_data=True)

    for mat in main_obj.data.materials:
        if mat and mat.use_nodes:
            nodes = mat.node_tree.nodes
            tex_node = nodes.new("ShaderNodeTexImage")
            tex_node.image = img_col
            nodes.active = tex_node

    orig_engine = bpy.context.scene.render.engine
    orig_samples = bpy.context.scene.cycles.samples
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.device = 'CPU'
    bpy.context.scene.cycles.samples = 4

    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
    img_col.filepath_raw = os.path.join(export_dir, f"{item_name}_BaseColor.png")
    img_col.file_format = 'PNG'
    img_col.save()
    img_col.pack()

    for mat in main_obj.data.materials:
        if mat and mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image == img_col:
                    n.image = img_rgh
                    mat.node_tree.nodes.active = n

    bpy.ops.object.bake(type='ROUGHNESS', use_clear=True)
    img_rgh.filepath_raw = os.path.join(export_dir, f"{item_name}_Roughness.png")
    img_rgh.file_format = 'PNG'
    img_rgh.save()
    img_rgh.pack()

    # Buat satu material PBR final menggunakan hasil bake 512x512
    final_mat = bpy.data.materials.new(name=f"M_{item_name}_PBR")
    final_mat.use_nodes = True
    fnodes = final_mat.node_tree.nodes
    flinks = final_mat.node_tree.links
    fnodes.clear()
    fbsdf = fnodes.new("ShaderNodeBsdfPrincipled")
    fout = fnodes.new("ShaderNodeOutputMaterial")
    flinks.new(fbsdf.outputs["BSDF"], fout.inputs["Surface"])

    t_col = fnodes.new("ShaderNodeTexImage")
    t_col.image = img_col
    flinks.new(t_col.outputs["Color"], fbsdf.inputs["Base Color"])

    t_rgh = fnodes.new("ShaderNodeTexImage")
    t_rgh.image = img_rgh
    flinks.new(t_rgh.outputs["Color"], fbsdf.inputs["Roughness"])

    main_obj.data.materials.clear()
    main_obj.data.materials.append(final_mat)

    bpy.context.scene.render.engine = orig_engine
    bpy.context.scene.cycles.samples = orig_samples

    # Ekspor FBX sesuai parameter wajib
    bpy.ops.object.select_all(action='DESELECT')
    main_obj.select_set(True)
    bpy.context.view_layer.objects.active = main_obj
    fbx_path = os.path.join(export_dir, f"{item_name}.fbx")
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
    print(f"SELESAI: {item_name}")

def build():
    item_name = "boneka_beruang"
    col = ensure_collection(item_name)
    objs = []

    mat_fur = create_proc_material("Mat_TeddyFur", (0.52, 0.28, 0.12, 1.0), (0.64, 0.36, 0.16, 1.0), rough1=0.78, rough2=0.90, mode="NOISE", scale=32.0)
    mat_cream = create_proc_material("Mat_TeddyCream", (0.92, 0.78, 0.58, 1.0), rough1=0.72)
    mat_eye = create_proc_material("Mat_TeddyEye", (0.08, 0.07, 0.07, 1.0), rough1=0.18)
    mat_bow = create_proc_material("Mat_TeddyBow", (0.92, 0.16, 0.22, 1.0), rough1=0.45)

    # Badan, kepala, telinga, tangan, dan kaki beruang duduk (tinggi ~0.26 m)
    bm_fur = bmesh.new()
    # Badan gemuk duduk
    add_uv_sphere(bm_fur, 0.068, u_segs=18, v_segs=12, scale=(1.05, 0.95, 1.12), offset=(0.0, 0.0, 0.075))
    # Kepala bulat
    add_uv_sphere(bm_fur, 0.062, u_segs=18, v_segs=12, scale=(1.08, 0.98, 1.0), offset=(0.0, -0.005, 0.185))
    # Telinga kiri & kanan
    add_uv_sphere(bm_fur, 0.022, u_segs=12, v_segs=8, scale=(1.0, 0.55, 1.0), offset=(-0.048, -0.005, 0.235))
    add_uv_sphere(bm_fur, 0.022, u_segs=12, v_segs=8, scale=(1.0, 0.55, 1.0), offset=(0.048, -0.005, 0.235))
    # Tangan kiri & kanan
    add_uv_sphere(bm_fur, 0.024, u_segs=12, v_segs=8, scale=(0.85, 0.9, 1.65), offset=(-0.075, -0.015, 0.095))
    add_uv_sphere(bm_fur, 0.024, u_segs=12, v_segs=8, scale=(0.85, 0.9, 1.65), offset=(0.075, -0.015, 0.095))
    # Kaki duduk menjulur ke depan (-Y)
    add_uv_sphere(bm_fur, 0.028, u_segs=12, v_segs=8, scale=(0.95, 1.65, 0.85), offset=(-0.042, -0.055, 0.026))
    add_uv_sphere(bm_fur, 0.028, u_segs=12, v_segs=8, scale=(0.95, 1.65, 0.85), offset=(0.042, -0.055, 0.026))
    objs.append(make_bmesh_object(col, "TeddyBody", bm_fur, mat_fur))

    # Perut krem, moncong krem, dalam telinga, dan telapak kaki
    bm_cream = bmesh.new()
    add_uv_sphere(bm_cream, 0.046, u_segs=14, v_segs=10, scale=(0.95, 0.45, 1.05), offset=(0.0, -0.048, 0.076))
    add_uv_sphere(bm_cream, 0.024, u_segs=14, v_segs=10, scale=(1.15, 0.75, 0.85), offset=(0.0, -0.058, 0.172))
    add_uv_sphere(bm_cream, 0.020, u_segs=10, v_segs=8, scale=(0.9, 0.3, 0.8), offset=(-0.042, -0.095, 0.026))
    add_uv_sphere(bm_cream, 0.020, u_segs=10, v_segs=8, scale=(0.9, 0.3, 0.8), offset=(0.042, -0.095, 0.026))
    objs.append(make_bmesh_object(col, "TeddyCreamParts", bm_cream, mat_cream))

    # Mata kancing & hidung hitam mengilap
    bm_eye = bmesh.new()
    add_uv_sphere(bm_eye, 0.008, u_segs=10, v_segs=8, offset=(-0.022, -0.062, 0.194))
    add_uv_sphere(bm_eye, 0.008, u_segs=10, v_segs=8, offset=(0.022, -0.062, 0.194))
    add_uv_sphere(bm_eye, 0.010, u_segs=10, v_segs=8, scale=(1.2, 0.7, 0.85), offset=(0.0, -0.074, 0.178))
    objs.append(make_bmesh_object(col, "TeddyEyesNose", bm_eye, mat_eye))

    # Pita merah lucu di leher
    bm_bow = bmesh.new()
    add_uv_sphere(bm_bow, 0.014, u_segs=10, v_segs=8, scale=(1.5, 0.6, 0.9), offset=(-0.016, -0.052, 0.135))
    add_uv_sphere(bm_bow, 0.014, u_segs=10, v_segs=8, scale=(1.5, 0.6, 0.9), offset=(0.016, -0.052, 0.135))
    objs.append(make_bmesh_object(col, "TeddyBow", bm_bow, mat_bow))

    # Origin di pusat badan boneka beruang (0, 0, 0.10)
    join_bake_and_export(col, item_name, objs, grip_offset=(0.0, 0.0, 0.10))


if __name__ == "__main__":
    build()
