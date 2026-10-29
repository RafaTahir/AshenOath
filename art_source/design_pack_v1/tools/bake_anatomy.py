"""Bake authored facial surface shading into a private character atlas.

The retained atlas and source mesh are never written. No procedural material
or per-frame skin shader is required by the exported game resource.
"""

import math

import bmesh
import bpy


def bake_anwen_surface(obj, face_vertices, destination, prefix="C01", tint=(1, 1, 1), age=1.0, skin_color=None, head_offset=0.0):
    colors = obj.data.color_attributes.new(name="AuthoredSurface", type="FLOAT_COLOR", domain="POINT")
    for index, vertex in enumerate(obj.data.vertices):
        color = [1.0, 1.0, 1.0, 0.0 if skin_color is not None else 1.0]
        if index in face_vertices:
            x, y, z = vertex.co
            z -= head_offset
            front = max(0, min(1, (.025 - y) / .075))
            eye = math.exp(-((abs(x) - .033) / .024) ** 2 * 2
                           - ((z - 1.642) / .012) ** 2 * 2) * front
            cheek = math.exp(-((abs(x) - .052) / .028) ** 2 * 2
                             - ((z - 1.623) / .032) ** 2 * 2) * front
            wrinkle = 0.0
            for level in (1.703, 1.715, 1.726):
                line = level + .002 * math.cos(x * 47)
                wrinkle += .045 * math.exp(-((z - line) / .0012) ** 2) * math.exp(-(x / .060) ** 4)
            nasal_line = .017 + max(0, min(1, (1.626 - z) / .043)) * .017
            fold = math.exp(-((abs(x) - nasal_line) / .0018) ** 2)
            fold *= math.exp(-((z - 1.606) / .025) ** 4) * .055
            skin = math.exp(-((z - 1.647) / .14) ** 6)
            fleck = max(0, math.sin(x * 1337 + math.sin(z * 731))
                        * math.sin(z * 1549 + y * 983) - .62) * .075 * cheek
            dim = (wrinkle + fold + fleck) * front * skin * age
            color = [(1 - eye * .065 * age - dim) * tint[0],
                     (1 - eye * .11 * age - cheek * .018 - dim) * tint[1],
                     (1 - eye * .12 * age - cheek * .025 - dim) * tint[2], 1]
            if skin_color is not None:
                color = [(1-eye*.065*age-dim)*skin_color[0],
                         (1-eye*.11*age-cheek*.018-dim)*skin_color[1],
                         (1-eye*.12*age-cheek*.025-dim)*skin_color[2],1]
        colors.data[index].color = color

    original = obj.data.materials[0]
    authored = original.copy()
    authored.name = prefix + "_PrivateAnatomyAtlas"
    obj.data.materials[0] = authored
    nodes, links = authored.node_tree.nodes, authored.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    original_color = bsdf.inputs["Base Color"].links[0].from_socket
    output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
    emission = nodes.new("ShaderNodeEmission")
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = colors.name
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MIX" if skin_color is not None else "MULTIPLY"
    multiply.inputs[0].default_value = 1
    if skin_color is not None:
        links.new(attribute.outputs["Alpha"], multiply.inputs[0])
    links.new(original_color, multiply.inputs[1])
    links.new(attribute.outputs["Color"], multiply.inputs[2])
    links.new(multiply.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    atlas = bpy.data.images.new(prefix + "_AnatomyBasecolor", width=2048, height=1024, alpha=False)
    atlas.colorspace_settings.name = "sRGB"
    atlas.generated_color = (.35, .27, .20, 1)
    target = nodes.new("ShaderNodeTexImage")
    target.image = atlas
    nodes.active = target

    # The hand's replacement UVs overlap the source peasant tile. Bake only
    # faces belonging to the original atlas, retaining their exact UV layout.
    bake_object = obj.copy()
    bake_object.data = obj.data.copy()
    bpy.context.collection.objects.link(bake_object)
    bake_object.name = "BUILD_AnatomyBake"
    bake_object.modifiers.clear()
    bm = bmesh.new()
    bm.from_mesh(bake_object.data)
    bmesh.ops.delete(bm, geom=[face for face in bm.faces if face.material_index != 0], context="FACES")
    bm.to_mesh(bake_object.data)
    bm.free()
    bake_object.data.materials.clear()
    bake_object.data.materials.append(authored)
    bpy.ops.object.select_all(action="DESELECT")
    bake_object.select_set(True)
    bpy.context.view_layer.objects.active = bake_object
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.render.bake.margin = 8
    bpy.ops.object.bake(type="EMIT")
    atlas.filepath_raw = str(destination / (prefix + "_anatomy_basecolor.png"))
    atlas.file_format = "PNG"
    atlas.save()
    links.new(target.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = .76
    for node in (emission, attribute, multiply):
        nodes.remove(node)
    bake_data = bake_object.data
    bpy.data.objects.remove(bake_object, do_unlink=True)
    bpy.data.meshes.remove(bake_data)
    obj.data.color_attributes.remove(colors)
