class_name BattleAbility
extends Resource

@export var label: String = ""
@export var cost: int = 0
@export_enum("physical", "magic", "heal", "guard", "protect", "haste") var effect: String = "physical"
@export var power: int = 0
@export_enum("enemy", "ally", "self") var target_kind: String = "enemy"
@export_enum("physical", "fire", "ice", "neutral") var element: String = "neutral"
# Only offensive area actions are supported; none are assigned in this prototype.
@export var is_area: bool = false
