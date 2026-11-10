class_name IgnarModel
extends Node3D
## Iteration 1.7: Ignar HD, the fire Guardian built in the same pipeline as the HD
## party (tools/blender/build_ignar_hd.py: Quaternius skeleton and animation library,
## obsidian plates over a molten body, after the designer's sheet). Like the party,
## the asset lives in git-ignored assets/third_party/; without it (or with another
## party style) the summon keeps the procedural volcanic golem.
## Presentation only: clips Appear (lands), Idle and Attack (Juicio de Ceniza).

const PATH := "res://assets/third_party/ignar_hd/ignar.gltf"
const CLIPS: Array[String] = ["Idle", "Appear", "Attack"]

var asset: Node3D
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var head_anchor: Node3D
var chest_anchor: Node3D
var attack_contact: float = 0.42
var authored_sections: int = 0
var load_error: String = ""

static func available() -> bool:
	return KaelModel.party_style() == "hd" and ResourceLoader.exists(PATH, "PackedScene")

func load_asset(path: String = PATH) -> bool:
	var packed := load(path) as PackedScene if ResourceLoader.exists(path, "PackedScene") else null
	if packed == null:
		load_error = "No existe el modelo HD de Ignar: " + path
		return false
	asset = packed.instantiate() as Node3D
	add_child(asset)
	var players := asset.find_children("*", "AnimationPlayer", true, false)
	var rigs := asset.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or rigs.is_empty():
		load_error = "Ignar HD sin esqueleto o animaciones"
		return false
	animation_player = players[0]
	skeleton = rigs[0]
	for clip in CLIPS:
		if not animation_player.has_animation(clip):
			load_error = "Ignar HD sin animación " + clip
			return false
	# Imported libraries are shared resources: loop flags stay per instance.
	for library_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(library_name).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as AnimationLibrary
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
	for clip in CLIPS:
		animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip == "Idle" else Animation.LOOP_NONE
	animation_player.animation_finished.connect(func(_clip: StringName) -> void: animation_player.play("Idle", 0.2))
	head_anchor = _anchor("Head")
	chest_anchor = _anchor("spine_03")
	var manifest_path := path.get_basename() + "_manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary:
			attack_contact = clampf(float(manifest.get("attack_contact", attack_contact)), 0.1, 0.9)
			authored_sections = int(manifest.get("authored_sections", 0))
	animation_player.play("Idle")
	return true

func _anchor(bone: String) -> Node3D:
	if skeleton.find_bone(bone) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = bone + "Anchor"
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment

func set_time_scale(time_scale: float) -> void:
	if animation_player != null:
		animation_player.speed_scale = 1.0 / maxf(time_scale, 0.001)

func play(clip: String) -> void:
	if animation_player != null and animation_player.has_animation(clip):
		animation_player.play(clip, 0.1)

func duration(clip: String) -> float:
	if animation_player == null or not animation_player.has_animation(clip):
		return 0.0
	return animation_player.get_animation(clip).length
