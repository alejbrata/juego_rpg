class_name CombatantData
extends Resource

@export var id: String = ""
@export var label: String = ""
@export var max_hp: int = 1
@export var max_mp: int = 0
@export var strength: int = 0
@export var magic: int = 0
@export var defense: int = 0
@export var resistance: int = 0
@export var speed: int = 0
@export var abilities: Array[BattleAbility] = []
@export var weaknesses: Array[String] = []
@export var resistances: Array[String] = []

func validation_error() -> String:
	for element in weaknesses + resistances:
		if not element in ["physical", "fire", "ice", "neutral"]:
			return "Elemento desconocido: %s." % element
		if weaknesses.has(element) and resistances.has(element):
			return "%s no puede ser débil y resistente a %s." % [label, element]
	return ""

func element_multiplier(element: String) -> float:
	if element == "neutral":
		return 1.0
	if weaknesses.has(element):
		return 1.5
	if resistances.has(element):
		return 0.5
	return 1.0
