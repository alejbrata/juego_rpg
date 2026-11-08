"""Rebuild Kael with Blender 5.2: blender --background --factory-startup --python tools/blender/build_kael.py.

Only writes this project's Kael source/export/manifest. No downloads, addons or
saved preferences. Geometry is lofted/hand-authored, with normalized joint weights.
Blender coordinates: metres, Z up, face -Y -> glTF/Godot Y up, face +Z.
"""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
sys.path.insert(0, str(Path(__file__).resolve().parent))
import kael_art
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


class MeshBuilder:
    def __init__(self):
        self.vertices, self.faces, self.materials, self.weights = [], [], [], []
        self.smooth = []
        self.parts = 0
        self.uvs = []

    def vertex(self, xyz, weights):
        total = sum(weights.values())
        assert total > 0 and len(weights) <= 4
        self.weights.append({k: v / total for k, v in weights.items() if v > 0})
        self.vertices.append(tuple(xyz))
        return len(self.vertices) - 1

    def face(self, vertices, material, smooth=True, uv=None):
        self.faces.append(tuple(vertices))
        self.materials.append(list(PALETTE).index(material))
        self.smooth.append(smooth)
        self.uvs.append(uv or [(0.5 + .47 * math.cos(i * math.tau / len(vertices)), 0.5 + .47 * math.sin(i * math.tau / len(vertices))) for i in range(len(vertices))])

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
        for row, (a, b) in enumerate(zip(rows, rows[1:])):
            for i in range(segments):
                j = (i + 1) % segments
                self.face((a[i], a[j], b[j], b[i]), material, smooth, [(i/segments,row/(len(rows)-1)),((i+1)/segments,row/(len(rows)-1)),((i+1)/segments,(row+1)/(len(rows)-1)),(i/segments,(row+1)/(len(rows)-1))])
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
        uv_layer = mesh.uv_layers.new(name="KaelAtlasUV")
        for polygon, tile, smooth, uv in zip(mesh.polygons, self.materials, self.smooth, self.uvs):
            name = list(PALETTE)[tile]
            polygon.material_index = 1 if name in ("Steel", "SteelEdge", "Gold") else 0
            polygon.use_smooth = smooth
            col, row = tile % 4, tile // 4
            for loop_index, (u, v) in zip(polygon.loop_indices, uv):
                uv_layer.data[loop_index].uv = ((col + .02 + .96 * u) / 4, (row + .02 + .96 * v) / 4)
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


def build_body():
    return kael_art.build_body(MeshBuilder)


def build_sword():
    return kael_art.build_sword(MeshBuilder)


def main():
    if not bpy.app.background:
        raise RuntimeError("Run in a separate Blender --background --factory-startup process; do not replace a live scene.")
    if bpy.app.version < (5, 2, 0):
        raise RuntimeError("Kael pipeline requires Blender 5.2 or newer")
    # Preserve the exact previous skeleton and actions, replacing only the meshes.
    source = OUT / "v08" / "kael.blend"
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = bpy.data.objects["KaelRig"]
    for name in ("KaelBody", "KaelSword"):
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    OUT.mkdir(parents=True, exist_ok=True)
    materials = kael_art.painted_materials(PALETTE, OUT)
    body_builder, sword_builder = build_body(), build_sword()
    body = body_builder.object("KaelBody", rig, materials)
    sword = sword_builder.object("KaelSword", rig, materials)
    bpy.context.scene.render.fps = 30
    rig.animation_data.action = bpy.data.actions["Idle"]
    bpy.context.scene.frame_set(1)
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
    report.update({"art_revision": "0.9", "materials": len({m.name for obj in (body, sword) for m in obj.data.materials}),
                   "surfaces": sum(len({p.material_index for p in obj.data.polygons}) for obj in (body, sword)),
                   "textures": [{"name": "kael_atlas.png", "width": 1024, "height": 1024, "rgba8_bytes": 4194304}],
                   "atlas_sha256": hashlib.sha256((OUT / "kael_atlas.png").read_bytes()).hexdigest(),
                   "art_script_sha256": hashlib.sha256((ROOT / "tools/blender/kael_art.py").read_bytes()).hexdigest(),
                   "glb_bytes": (OUT / "kael.glb").stat().st_size})
    blob = (OUT / "kael.glb").read_bytes()
    json_length, chunk_type = struct.unpack_from("<II", blob, 12)
    gltf = json.loads(blob[20:20 + json_length])
    assert chunk_type == 0x4E4F534A
    assert all("uri" not in buffer for buffer in gltf["buffers"]), "External buffer"
    assert all("uri" not in image for image in gltf.get("images", [])), "External texture"
    primitives = [p for mesh in gltf["meshes"] for p in mesh["primitives"]]
    report["exported_vertices"] = sum(gltf["accessors"][p["attributes"]["POSITION"]]["count"] for p in primitives)
    report["exported_triangles"] = sum(gltf["accessors"][p["indices"]]["count"] // 3 for p in primitives)
    report["source_v08_sha256"] = hashlib.sha256((OUT / "v08/kael.blend").read_bytes()).hexdigest()
    assert report["exported_triangles"] == triangles
    assert triangles <= 12000, report
    (OUT / "kael_manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("KAEL_BUILD", json.dumps(report))


if __name__ == "__main__":
    main()
