class_name KaelModel
extends Node3D

const ASSET_PATH := "res://assets/characters/kael/kael.glb"
const REQUIRED: Array[String] = ["Idle", "Walk", "Attack", "Hurt", "Defend", "KO"]

var asset: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var weapon: Node3D
var current_clip: String = ""
var load_error: String = ""
var authored_sections: int = 0
var walk_reference_speed: float = 4.0
var lunge_distance: float = 0.65
var _locomotion_blend: float = 0.0
var _presentation_durations: Dictionary = {}
var _base_pose: String = "Idle"
var _flash: Tween

func load_asset(path: String = ASSET_PATH, report_warning: bool = true) -> bool:
	if not ResourceLoader.exists(path, "PackedScene"):
		return _fail("No existe el GLB de Kael: %s. Se usará el modelo procedural." % path, report_warning)
	var packed := load(path) as PackedScene
	if packed == null:
		return _fail("No se pudo importar el GLB de Kael. Se usará el modelo procedural.", report_warning)
	asset = packed.instantiate() as Node3D
	add_child(asset)
	var rigs := asset.find_children("*", "Skeleton3D", true, false)
	var players := asset.find_children("*", "AnimationPlayer", true, false)
	if rigs.is_empty() or players.is_empty():
		return _fail("GLB de Kael sin esqueleto o AnimationPlayer; usando fallback procedural.", report_warning)
	skeleton = rigs[0] as Skeleton3D
	animation_player = players[0] as AnimationPlayer
	weapon = asset.find_child("KaelSword", true, false) as Node3D
	for clip in REQUIRED:
		if not animation_player.has_animation(clip):
			return _fail("GLB de Kael sin animación %s; usando fallback procedural." % clip, report_warning)
	if weapon == null:
		return _fail("GLB de Kael sin espada; usando fallback procedural.", report_warning)
	# Import resources are shared; loop flags and playback must stay per instance.
	for library_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(library_name).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as AnimationLibrary
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
	for clip in REQUIRED:
		animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in ["Idle", "Walk"] else Animation.LOOP_NONE
	animation_player.animation_finished.connect(_on_finished)
	var manifest_path := path.get_basename() + "_manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary:
			authored_sections = int(manifest.get("authored_sections", 0))
			walk_reference_speed = maxf(0.1, float(manifest.get("walk_reference_speed", 4.0)))
			lunge_distance = maxf(0.0, float(manifest.get("lunge_distance", 0.65)))
			_locomotion_blend = clampf(float(manifest.get("locomotion_blend", 0.0)), 0.0, 0.25)
			_presentation_durations = manifest.get("presentation_durations", {})
	reset_pose()
	return true

func _fail(message: String, report_warning: bool) -> bool:
	load_error = message
	if is_instance_valid(asset):
		remove_child(asset)
		asset.free()
	asset = null
	skeleton = null
	animation_player = null
	weapon = null
	if report_warning:
		push_warning(message)
	return false

func reset_pose(pose: String = "Idle") -> void:
	if _flash != null:
		_flash.kill()
	for mesh in asset.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = null
	animation_player.stop()
	skeleton.reset_bone_poses()
	set_pose(pose)

func set_pose(pose: String) -> void:
	_base_pose = pose
	current_clip = pose
	animation_player.speed_scale = 1.0
	animation_player.play(pose)
	animation_player.advance(0)
	if pose in ["KO", "Defend"]:
		animation_player.seek(animation_player.get_animation(pose).length, true)
		animation_player.pause()

func play_action(clip: String, duration: float) -> void:
	current_clip = clip
	animation_player.speed_scale = animation_player.get_animation(clip).length / maxf(0.001, duration)
	animation_player.play(clip, 0.02)
	animation_player.advance(0)

func set_walking(moving: bool, speed_ratio: float = 1.0) -> void:
	var clip := "Walk" if moving else "Idle"
	if current_clip != clip:
		_base_pose = clip
		current_clip = clip
		animation_player.play(clip, _locomotion_blend)
		animation_player.advance(0)
	animation_player.speed_scale = clampf(speed_ratio * 4.0 / walk_reference_speed, 0.3, 2.5) if moving else 1.0

func presentation_duration(clip: String) -> float:
	return maxf(0.05, float(_presentation_durations.get(clip, 0.36)))

func _on_finished(clip: StringName) -> void:
	if clip in ["Attack", "Hurt"]:
		set_pose(_base_pose)
	elif clip in ["KO", "Defend"]:
		animation_player.pause()

func flash(color: Color, duration: float) -> void:
	if _flash != null:
		_flash.kill()
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(color, 0.45)
	for mesh in asset.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = overlay
	_flash = create_tween()
	_flash.tween_property(overlay, "albedo_color:a", 0.0, maxf(0.001, duration))
