class_name BattleAbility
extends Resource

@export var label: String = ""
@export var cost: int = 0
@export_enum("physical", "magic", "heal", "guard", "haste") var effect: String = "physical"
@export var power: int = 0
@export_enum("enemy", "ally", "self") var target_kind: String = "enemy"
