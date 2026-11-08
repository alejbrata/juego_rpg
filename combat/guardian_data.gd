class_name GuardianData
extends Resource

@export var id: String = ""
@export var label: String = ""
@export_enum("physical", "fire", "ice", "neutral") var element: String = "fire"
@export var summon_label: String = ""
@export var base_damage: int = 40
@export var defense_reduction: float = 0.25
@export var debuff_rounds: int = 2
@export var level_thresholds: PackedInt32Array = [0, 100, 250, 500]
@export var passive_names: PackedStringArray = []
@export var resistance_bonus: float = 0.1
@export var damage_bonus: float = 0.1
@export var weakness_re_bonus: int = 5
@export var summon_base_bonus: float = 0.2

func validation_error() -> String:
	if id.is_empty() or not element in ["physical", "fire", "ice", "neutral"]:
		return "Identidad o elemento de Guardián inválido."
	if base_damage < 1 or defense_reduction < 0.0 or defense_reduction > 1.0 or debuff_rounds < 1:
		return "Efecto de Guardián inválido."
	if level_thresholds.size() != 4 or level_thresholds[0] != 0:
		return "Se requieren cuatro umbrales de nivel desde 0 PA."
	for i in range(1, level_thresholds.size()):
		if level_thresholds[i] <= level_thresholds[i - 1]:
			return "Los umbrales de PA deben ser crecientes."
	if resistance_bonus < 0.0 or resistance_bonus > 1.0 or damage_bonus < 0.0 or weakness_re_bonus < 0 or summon_base_bonus < 0.0:
		return "Pasivas de Guardián inválidas."
	return ""
