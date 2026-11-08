class_name PartyState
extends RefCounted

# Explicit in-memory run state. Share this instance across battles; never serialize
# combatants or modify definition Resources to transfer RE, progress or equipment.
var resonance: int = 0:
	set(value):
		resonance = clampi(value, 0, 100)

var _definitions: Dictionary[String, GuardianData] = {}
var _progress: Dictionary[String, GuardianProgress] = {}
var _bindings: Dictionary[String, String] = {} # character ID -> guardian ID
var _battle_owner: WeakRef

static func test_party() -> PartyState:
	var result := PartyState.new()
	result.register_guardian(preload("res://data/ignar.tres"))
	result.equip("ignar", "lyra")
	return result

func in_battle() -> bool:
	return _battle_owner != null and _battle_owner.get_ref() != null

func begin_battle(owner: RefCounted) -> String:
	if in_battle() and _battle_owner.get_ref() != owner:
		return "La partida ya tiene un combate activo."
	_battle_owner = weakref(owner)
	return ""

func end_battle(owner: RefCounted) -> void:
	if in_battle() and _battle_owner.get_ref() == owner:
		_battle_owner = null

func register_guardian(definition: GuardianData) -> String:
	if in_battle():
		return "No se pueden cambiar Guardianes durante el combate."
	if definition == null:
		return "Guardián inexistente."
	var error := definition.validation_error()
	if not error.is_empty():
		return error
	if _definitions.has(definition.id):
		return "Guardián ya registrado."
	_definitions[definition.id] = definition
	_progress[definition.id] = GuardianProgress.new()
	return ""

func equip(guardian_id: String, character_id: String) -> String:
	if in_battle():
		return "No se puede cambiar el vínculo durante el combate."
	if not _definitions.has(guardian_id) or character_id.is_empty():
		return "Guardián o portador inválido."
	if _bindings.has(character_id) and _bindings[character_id] != guardian_id:
		return "El personaje ya tiene un Guardián."
	for carrier in _bindings.keys():
		if _bindings[carrier] == guardian_id:
			_bindings.erase(carrier)
	_bindings[character_id] = guardian_id
	return ""

func unequip(character_id: String) -> String:
	if in_battle():
		return "No se puede cambiar el vínculo durante el combate."
	_bindings.erase(character_id)
	return ""

func guardian_for(character_id: String) -> GuardianData:
	return _definitions.get(_bindings.get(character_id, ""))

func definition(guardian_id: String) -> GuardianData:
	return _definitions.get(guardian_id)

func progress(guardian_id: String) -> GuardianProgress:
	return _progress.get(guardian_id)

func guardian_level(character_id: String) -> int:
	var guardian := guardian_for(character_id)
	return _progress[guardian.id].level(guardian) if guardian != null else 0

func reward_victory(character_ids: Array[String]) -> void:
	# Engine invokes this once per victory, including equipped fallen carriers.
	for character_id in character_ids:
		var guardian := guardian_for(character_id)
		if guardian != null:
			_progress[guardian.id].affinity += 50
