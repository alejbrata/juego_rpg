class_name CompanionModel
extends KaelModel

const ASSET_PATHS := {
	"lyra": "res://assets/characters/lyra/lyra.glb",
	"nira": "res://assets/characters/nira/nira.glb",
}

var hero_id: String = "lyra"

func _asset_label() -> String:
	return hero_id.capitalize()

func _weapon_name() -> String:
	return "Focus"

func _required_clips() -> Array[String]:
	var clips: Array[String] = REQUIRED.duplicate()
	clips.append("Cast" if hero_id == "lyra" else "Support")
	return clips

func load_asset(path: String = "", report_warning: bool = true) -> bool:
	if not ASSET_PATHS.has(hero_id):
		return _fail("No hay un modelo importado configurado para %s." % hero_id, report_warning)
	return super.load_asset(ASSET_PATHS[hero_id] if path.is_empty() else path, report_warning)

func clip_for_effect(kind: String) -> String:
	if hero_id == "lyra" and kind == "magic":
		return "Cast"
	if hero_id == "nira" and kind in ["heal", "haste"]:
		return "Support"
	return super.clip_for_effect(kind)

func _on_finished(clip: StringName) -> void:
	if clip in ["Cast", "Support"]:
		set_pose(_base_pose)
	else:
		super._on_finished(clip)
