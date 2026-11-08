"""Rebuild Kael with Blender 5.2: blender --background --factory-startup --python tools/blender/build_kael.py.

Only writes this project's Kael source/export/manifest. No downloads, addons or
saved preferences. Geometry is lofted/hand-authored, with normalized joint weights.
Blender coordinates: metres, Z up, face -Y -> glTF/Godot Y up, face +Z.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/characters/kael"
PALETTE = {
    "Cloth": ("2e496b", 0.0, 0.95), "BlueTrim": ("557a98", 0.1, 0.8),
    "Steel": ("9aafb9", 0.65, 0.48), "SteelEdge": ("d0d6cd", 0.65, 0.42),
    "Leather": ("775039", 0.0, 0.85), "DarkLeather": ("3f3431", 0.0, 0.9),
    "Skin": ("e7b78f", 0.0, 0.9), "Hair": ("573722", 0.0, 0.9),
    "HairLight": ("805230", 0.0, 0.9), "EyeWhite": ("f0e3cd", 0.0, 0.7),
    "Iris": ("5b5437", 0.0, 0.8), "Pupil": ("19232a", 0.0, 0.9),
    "Lip": ("96624c", 0.0, 0.9), "Gold": ("c5a16b", 0.55, 0.6),
}


def linear(hex_value):
    rgb = [int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb) + (1,)


class MeshBuilder:
    def __init__(self):
        self.vertices, self.faces, self.materials, self.weights = [], [], [], []
        self.smooth = []
        self.parts = 0

    def vertex(self, xyz, weights):
        total = sum(weights.values())
        assert total > 0 and len(weights) <= 4
        self.weights.append({k: v / total for k, v in weights.items() if v > 0})
        self.vertices.append(tuple(xyz))
        return len(self.vertices) - 1

    def face(self, vertices, material, smooth=True):
        self.faces.append(tuple(vertices))
        self.materials.append(list(PALETTE).index(material))
        self.smooth.append(smooth)

    def loft(self, profiles, material, segments=10, smooth=True):
        """Profiles: centre, section radii, bone weights. Shared ring topology."""
        self.parts += 1
        axis = (Vector(profiles[-1][0]) - Vector(profiles[0][0])).normalized()
        u = Vector((1, 0, 0)) if abs(axis.z) > 0.8 else axis.cross(Vector((0, 1, 0))).normalized()
        v = axis.cross(u).normalized()
        rows = []
        for centre, rx, ry, weights in profiles:
            rows.append([self.vertex(Vector(centre) + u * (math.cos(i * math.tau / segments) * rx)
                                      + v * (math.sin(i * math.tau / segments) * ry), weights)
                         for i in range(segments)])
        for a, b in zip(rows, rows[1:]):
            for i in range(segments):
                j = (i + 1) % segments
                self.face((a[i], a[j], b[j], b[i]), material, smooth)
        self.face(tuple(reversed(rows[0])), material, smooth)
        self.face(rows[-1], material, smooth)

    def ellipsoid(self, centre, radii, material, bone="head", segments=12, rings=7, facial=False):
        self.parts += 1
        rows = []
        for j in range(1, rings):
            phi = math.pi * j / rings
            row = []
            for i in range(segments):
                theta = i * math.tau / segments
                point = Vector((radii[0] * math.sin(phi) * math.cos(theta),
                                radii[1] * math.sin(phi) * math.sin(theta), radii[2] * math.cos(phi)))
                if facial:
                    # Defined chin/jaw, cheek volume and a flatter facial plane.
                    if point.z < -0.05:
                        point.x *= 0.88 + 0.12 * (point.z + radii[2]) / radii[2]
                    if point.y < -radii[1] * 0.6:
                        point.y = -radii[1] * 0.90
                row.append(self.vertex(Vector(centre) + point, {bone: 1}))
            rows.append(row)
        top = self.vertex(Vector(centre) + Vector((0, 0, radii[2])), {bone: 1})
        bottom = self.vertex(Vector(centre) - Vector((0, 0, radii[2])), {bone: 1})
        for i in range(segments):
            k = (i + 1) % segments
            self.face((top, rows[0][i], rows[0][k]), material)
            self.face((bottom, rows[-1][k], rows[-1][i]), material)
        for a, b in zip(rows, rows[1:]):
            for i in range(segments):
                k = (i + 1) % segments
                self.face((a[i], b[i], b[k], a[k]), material)

    def patch(self, points, material, bone, smooth=False):
        self.parts += 1
        self.face([self.vertex(p, {bone: 1}) for p in points], material, smooth)

    def ribbon(self, start, end, width, material, bone):
        a, b = Vector(start), Vector(end)
        side = (b - a).cross(Vector((0, -1, 0))).normalized() * width * 0.5
        self.patch([a - side, a + side, b + side, b - side], material, bone)

    def object(self, name, rig, materials):
        mesh = bpy.data.meshes.new(name + "Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        for material in materials:
            mesh.materials.append(material)
        for polygon, material, smooth in zip(mesh.polygons, self.materials, self.smooth):
            polygon.material_index, polygon.use_smooth = material, smooth
        for bone in rig.data.bones:
            obj.vertex_groups.new(name=bone.name)
        for i, weights in enumerate(self.weights):
            for bone, weight in weights.items():
                obj.vertex_groups[bone].add([i], weight, 'REPLACE')
        obj.parent = rig
        modifier = obj.modifiers.new("KaelSkin", 'ARMATURE')
        modifier.object = rig
        # Recalculate consistent outward normals on every authored surface.
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        obj.select_set(False)
        obj["authored_sections"] = self.parts
        return obj


def build_rig():
    data = bpy.data.armatures.new("KaelSkeleton")
    rig = bpy.data.objects.new("KaelRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bones = [
        ("root", (0, 0, 0), (0, 0, .15), None),
        ("pelvis", (0, 0, .91), (0, 0, 1.08), "root"),
        ("spine", (0, 0, 1.08), (0, 0, 1.48), "pelvis"),
        ("neck", (0, 0, 1.48), (0, 0, 1.61), "spine"),
        ("head", (0, 0, 1.61), (0, 0, 2.06), "neck"),
    ]
    for sign, suffix in [(-1, "L"), (1, "R")]:
        bones += [
            ("upper_arm." + suffix, (sign * .33, 0, 1.43), (sign * .55, -.025, 1.17), "spine"),
            ("forearm." + suffix, (sign * .55, -.025, 1.17), (sign * .63, -.12, .93), "upper_arm." + suffix),
            ("hand." + suffix, (sign * .63, -.12, .93), (sign * .63, -.22, .84), "forearm." + suffix),
            ("thigh." + suffix, (sign * .18, 0, .94), (sign * .2, -.015, .52), "pelvis"),
            ("calf." + suffix, (sign * .2, -.015, .52), (sign * .2, 0, .17), "thigh." + suffix),
            ("foot." + suffix, (sign * .2, 0, .17), (sign * .2, -.24, .09), "calf." + suffix),
        ]
    for name, head, tail, parent in bones:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.show_in_front = True
    return rig


def build_body():
    b = MeshBuilder()
    b.loft([((0, 0, z), rx, ry, weights) for z, rx, ry, weights in [
        (.85, .29, .18, {"pelvis": 1}), (1.0, .28, .17, {"pelvis": .7, "spine": .3}),
        (1.15, .32, .19, {"spine": 1}), (1.33, .39, .22, {"spine": 1}),
        (1.45, .36, .19, {"spine": 1}), (1.51, .16, .13, {"spine": .5, "neck": .5})]], "Cloth", 12)
    b.loft([((0, 0, .83), .34, .2, {"pelvis": 1}), ((0, 0, .96), .29, .18, {"pelvis": 1})], "BlueTrim", 12)
    b.loft([((0, 0, .97), .301, .19, {"pelvis": 1}), ((0, 0, 1.035), .29, .185, {"pelvis": 1})], "Leather", 12)
    b.patch([(-.06, -.199, .975), (.065, -.199, .975), (.065, -.195, 1.035), (-.06, -.195, 1.035)], "Gold", "pelvis")
    b.ribbon((-.3, -.215, 1.45), (.23, -.196, 1.025), .07, "Leather", "spine")
    # Fitted chest plate, rather than an isolated spherical breastplate.
    b.patch([(-.27, -.216, 1.38), (-.23, -.229, 1.18), (0, -.25, 1.12), (.23, -.229, 1.18), (.27, -.216, 1.38), (0, -.24, 1.43)], "BlueTrim", "spine")
    b.ribbon((-.25, -.236, 1.37), (0, -.264, 1.42), .018, "SteelEdge", "spine")
    b.ribbon((0, -.264, 1.42), (.25, -.236, 1.37), .018, "SteelEdge", "spine")
    b.loft([((0, 0, 1.48), .15, .12, {"neck": 1}), ((0, 0, 1.65), .125, .11, {"head": 1})], "Skin", 10)
    b.loft([((0, -.015, 1.48), .2, .145, {"neck": 1}), ((0, -.015, 1.55), .16, .125, {"neck": 1})], "Leather", 12)
    for sign, suffix in [(-1, "L"), (1, "R")]:
        thigh, calf, foot = "thigh." + suffix, "calf." + suffix, "foot." + suffix
        b.loft([((sign * x, y, z), rx, ry, weights) for x, y, z, rx, ry, weights in [
            (.18, 0, .94, .16, .15, {thigh: .8, "pelvis": .2}), (.19, 0, .79, .155, .145, {thigh: 1}),
            (.2, -.01, .63, .125, .12, {thigh: 1}), (.2, -.015, .52, .12, .11, {thigh: .5, calf: .5}),
            (.2, -.01, .45, .115, .11, {calf: 1}), (.2, 0, .3, .10, .10, {calf: 1}),
            (.2, 0, .18, .09, .09, {calf: 1})]], "DarkLeather", 10)
        b.loft([((sign * .2, -.105, .055), .14, .24, {foot: 1}), ((sign * .2, -.105, .13), .145, .23, {foot: 1}),
                ((sign * .2, -.015, .22), .115, .13, {calf: .8, foot: .2}), ((sign * .2, 0, .34), .12, .115, {calf: 1})], "Leather", 10)
        b.loft([((sign * .2, 0, .3), .124, .12, {calf: 1}), ((sign * .2, 0, .345), .124, .12, {calf: 1})], "Gold", 10)
        b.ellipsoid((sign * .2, -.115, .55), (.105, .035, .12), "Steel", thigh, 8, 4)
        upper, forearm, hand = "upper_arm." + suffix, "forearm." + suffix, "hand." + suffix
        b.loft([((sign * x, y, z), rx, ry, weights) for x, y, z, rx, ry, weights in [
            (.32, 0, 1.43, .14, .145, {upper: .7, "spine": .3}), (.44, -.01, 1.32, .145, .13, {upper: 1}),
            (.54, -.025, 1.2, .115, .11, {upper: .7, forearm: .3}), (.56, -.035, 1.14, .105, .1, {upper: .4, forearm: .6}),
            (.6, -.08, 1.03, .095, .09, {forearm: 1}), (.63, -.12, .93, .08, .075, {forearm: .8, hand: .2})]], "Cloth", 10)
        b.loft([((sign * .6, -.075, 1.06), .106, .095, {forearm: 1}), ((sign * .63, -.12, .93), .095, .085, {forearm: .5, hand: .5}),
                ((sign * .64, -.17, .84), .085, .09, {hand: 1})], "DarkLeather", 10)
        b.ellipsoid((sign * .645, -.17, .87), (.10, .095, .12), "Leather", hand, 10, 5)
        b.ellipsoid((sign * .57, -.215, .87), (.04, .06, .065), "Leather", hand, 8, 4)
        b.ellipsoid((sign * .4, 0, 1.43), (.24, .215, .16), "Steel" if sign < 0 else "Leather", upper, 10, 5)
        b.ellipsoid((sign * .39, -.025, 1.51), (.18, .18, .065), "SteelEdge" if sign < 0 else "Gold", upper, 10, 4)
    b.ellipsoid((-.32, .09, .92), (.12, .12, .17), "Leather", "pelvis", 10, 5)
    b.ellipsoid((0, 0, 1.805), (.275, .25, .285), "Skin", "head", 16, 10, facial=True)
    for sign in [-1, 1]:
        b.ellipsoid((sign * .27, 0, 1.8), (.045, .06, .085), "Skin", segments=8, rings=5)
        b.ellipsoid((sign * .105, -.227, 1.835), (.073, .012, .032), "EyeWhite", segments=12, rings=5)
        b.ellipsoid((sign * .108, -.239, 1.831), (.024, .005, .028), "Iris", segments=10, rings=5)
        b.ellipsoid((sign * .108, -.244, 1.832), (.012, .003, .023), "Pupil", segments=8, rings=4)
        b.ribbon((sign * .045, -.251, 1.882), (sign * .173, -.232, 1.908), .024, "Hair", "head")
    b.patch([(-.047, -.232, 1.80), (0, -.315, 1.75), (.047, -.232, 1.80), (0, -.245, 1.84)], "Skin", "head", True)
    b.ribbon((-.052, -.233, 1.685), (.056, -.233, 1.681), .012, "Lip", "head")
    # Hair cap and individually lofted curved locks, no primitive cone spikes.
    b.ellipsoid((0, .03, 1.975), (.285, .255, .16), "Hair", segments=14, rings=7)
    for i in range(8):
        x = -.23 + i * .064
        b.loft([((x * .7, .03, 2.07), .085, .06, {"head": 1}),
                ((x + .025 * math.sin(i * 2), -.12, 2.075 + .065 * math.sin(i * 2.3)), .08, .055, {"head": 1}),
                ((x + .035, -.23, 1.94 + .045 * math.sin(i * 2)), .055, .035, {"head": 1}),
                ((x + .06, -.24, 1.89 + .05 * math.sin(i * 2)), .006, .006, {"head": 1})], "HairLight" if i in (1, 5) else "Hair", 7, True)
    for sign in [-1, 1]:
        b.loft([((sign * .22, .075, 2.02), .10, .06, {"head": 1}),
                ((sign * .285, .04, 1.94), .075, .055, {"head": 1}),
                ((sign * .277, -.02, 1.82), .012, .015, {"head": 1})], "Hair", 6, False)
    return b


def build_sword():
    b = MeshBuilder()
    hand = {"hand.R": 1}
    # Every vertex is bound to the right hand; no runtime attachment workaround.
    b.loft([((.645, -.18, .77), .045, .04, hand), ((.645, -.18, 1.04), .045, .04, hand)], "DarkLeather", 8)
    b.ellipsoid((.645, -.18, .77), (.065, .055, .055), "Gold", "hand.R", 8, 4)
    b.loft([((.46, -.18, 1.035), .04, .04, hand), ((.645, -.18, 1.08), .05, .045, hand),
            ((.83, -.18, 1.035), .04, .04, hand)], "Gold", 6, False)
    # Diamond-section blade and original tapered leaf tip.
    b.loft([((.645, -.18, 1.075), .075, .025, hand), ((.645, -.18, 1.38), .085, .03, hand),
            ((.645, -.18, 1.79), .055, .023, hand), ((.645, -.18, 1.96), .002, .002, hand)], "SteelEdge", 4, False)
    return b


def animate(rig):
    lengths = {"Idle": 61, "Walk": 25, "Attack": 19, "Hurt": 13, "Defend": 13, "KO": 25}
    rig.animation_data_create()
    for name, end in lengths.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True # Preserve every clip when reopening the .blend.
        rig.animation_data.action = action
        for frame in range(1, end + 1):
            t = (frame - 1) / (end - 1)
            for bone in rig.pose.bones:
                bone.rotation_mode = 'XYZ'
                bone.rotation_euler = (0, 0, 0)
                bone.location = (0, 0, 0)
            p = rig.pose.bones
            if name == "Idle":
                wave = math.sin(t * math.tau)
                p["spine"].rotation_euler.x = wave * .018
                p["pelvis"].location.y = wave * .008
                p["head"].rotation_euler.y = wave * .02
                p["forearm.R"].rotation_euler.x = -.07
            elif name == "Walk":
                wave = math.sin(t * math.tau)
                p["pelvis"].location.y = .012 * (1 - math.cos(t * math.tau * 2))
                for sign, suffix in [(-1, "L"), (1, "R")]:
                    p["thigh." + suffix].rotation_euler.x = sign * wave * .32
                    p["calf." + suffix].rotation_euler.x = max(0, -sign * wave) * .5
                    p["foot." + suffix].rotation_euler.x = -max(0, -sign * wave) * .2
                    p["upper_arm." + suffix].rotation_euler.x = -sign * wave * (.17 if suffix == "R" else .3)
            elif name == "Attack":
                # Explicit anticipation -> diagonal slash -> recovery poses.
                keys = [(0, (0, 0, 0), 0, 0, 0), (.25, (-1.3, 0, -.35), -.55, -.35, -.18),
                        (.55, (-.25, 0, .65), .3, .55, .2), (1, (0, 0, 0), 0, 0, 0)]
                a, z = next((a, z) for a, z in zip(keys, keys[1:]) if a[0] <= t <= z[0])
                u = (t - a[0]) / (z[0] - a[0])
                u = u * u * (3 - 2 * u)
                p["upper_arm.R"].rotation_euler = Vector(a[1]).lerp(Vector(z[1]), u)
                p["forearm.R"].rotation_euler.x = a[2] * (1 - u) + z[2] * u
                p["hand.R"].rotation_euler.z = a[3] * (1 - u) + z[3] * u
                p["spine"].rotation_euler.y = a[4] * (1 - u) + z[4] * u
                p["upper_arm.L"].rotation_euler.x = -.2 * math.sin(t * math.pi)
            elif name == "Hurt":
                hit = math.sin(t * math.pi)
                p["spine"].rotation_euler.x = -.24 * hit
                p["head"].rotation_euler.x = .13 * hit
                p["pelvis"].location.z = .05 * hit
            elif name == "Defend":
                bend = min(1, t * 2)
                p["upper_arm.R"].rotation_euler.x = -.7 * bend
                p["forearm.R"].rotation_euler.x = -.8 * bend
                p["upper_arm.L"].rotation_euler.x = -.6 * bend
                p["forearm.L"].rotation_euler.x = -.8 * bend
                p["spine"].rotation_euler.x = .08 * bend
            else:
                fall = t * t * (3 - 2 * t)
                p["root"].rotation_euler.x = -math.pi * .48 * fall
                p["root"].location.z = .15 * fall
                p["upper_arm.R"].rotation_euler.z = -.25 * fall
                p["head"].rotation_euler.x = .1 * fall
            for bone in rig.pose.bones:
                bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)
                bone.keyframe_insert(data_path="location", frame=frame, group=bone.name)
        action["loop"] = name in ("Idle", "Walk")
    rig.animation_data.action = bpy.data.actions["Idle"]
    bpy.context.scene.frame_set(1)
    return lengths


def main():
    if not bpy.app.background:
        raise RuntimeError("Run in a separate Blender --background --factory-startup process; do not replace a live scene.")
    if bpy.app.version < (5, 2, 0):
        raise RuntimeError("Kael pipeline requires Blender 5.2 or newer")
    # Intended for --factory-startup: never touches a user's live Blender scene.
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    OUT.mkdir(parents=True, exist_ok=True)
    materials = []
    for name, (hex_value, metallic, roughness) in PALETTE.items():
        material = bpy.data.materials.new(name)
        material.diffuse_color = linear(hex_value)
        if material.node_tree is None:
            material.use_nodes = True
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = linear(hex_value)
        shader.inputs["Metallic"].default_value = metallic
        shader.inputs["Roughness"].default_value = roughness
        materials.append(material)
    rig = build_rig()
    body_builder, sword_builder = build_body(), build_sword()
    body = body_builder.object("KaelBody", rig, materials)
    sword = sword_builder.object("KaelSword", rig, materials)
    bpy.context.scene.render.fps = 30
    lengths = animate(rig)
    bpy.context.scene.frame_end = 61
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (rig, body, sword):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    # A staging filename avoids writing .blend1 backups next to the source.
    staging = OUT / "kael.generated.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(staging), check_existing=False)
    staging.replace(OUT / "kael.blend")
    export_asset()


def export_asset():
    rig = bpy.data.objects["KaelRig"]
    body = bpy.data.objects["KaelBody"]
    sword = bpy.data.objects["KaelSword"]
    lengths = {name: int(bpy.data.actions[name].frame_range[1] - bpy.data.actions[name].frame_range[0] + 1) for name in ["Idle", "Walk", "Attack", "Hurt", "Defend", "KO"]}
    for obj in (body, sword):
        for vertex in obj.data.vertices:
            assert abs(sum(group.weight for group in vertex.groups) - 1.0) < 0.0001, "Unweighted or unnormalized vertex"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (rig, body, sword):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(OUT / "kael.glb"), export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=False, export_skins=True, export_def_bones=False,
                              export_animations=True, export_animation_mode='ACTIONS',
                              export_merge_animation='ACTION', export_anim_single_armature=True,
                              export_extras=True, export_force_sampling=True)
    triangles = 0
    for obj in (body, sword):
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    report = {"blender": bpy.app.version_string, "units": "metres", "godot_forward": "+Z",
              "vertices": len(body.data.vertices) + len(sword.data.vertices), "triangles": triangles,
              "bones": [b.name for b in rig.data.bones], "animations": {k: (v - 1) / 30 for k, v in lengths.items()},
              "authored_sections": int(body.get("authored_sections", 0)) + int(sword.get("authored_sections", 0)),
              "glb_sha256": hashlib.sha256((OUT / "kael.glb").read_bytes()).hexdigest(),
              "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "blend_sha256": hashlib.sha256((OUT / "kael.blend").read_bytes()).hexdigest()}
    assert triangles < 7000, report
    (OUT / "kael_manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("KAEL_BUILD", json.dumps(report))


if __name__ == "__main__":
    main()
