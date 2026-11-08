class_name EncounterData
extends Resource

@export var id: String = ""
@export var label: String = "Centinela"
@export var map_position: Vector3 = Vector3.ZERO
@export_range(0.5, 2.5) var detection_radius: float = 1.0
@export var enemies: Array[CombatantData] = []

func validation_error() -> String:
	if id.is_empty() or enemies.is_empty() or detection_radius <= 0:
		return "Encuentro sin identificador, enemigos o radio válido."
	for enemy in enemies:
		if enemy == null:
			return "Enemigo inexistente en el encuentro."
		var error := enemy.validation_error()
		if not error.is_empty():
			return error
	return ""
