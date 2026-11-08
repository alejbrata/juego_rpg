class_name GameSession
extends RefCounted

# Small in-memory state shared explicitly by the flow and the current scene.
# PV/PM are not persisted yet: each encounter uses the configured maxima.
enum Mode { EXPLORING, BATTLE, DEFEAT }

const SPAWN := Vector3(-5, 0.05, 4)
var mode: Mode = Mode.EXPLORING
var area_id: String = "eclipse_clearing"
var party := PartyState.test_party()
var heroes: Array[CombatantData] = [preload("res://data/kael.tres"), preload("res://data/lyra.tres"), preload("res://data/nira.tres")]
var leader_position: Vector3 = SPAWN
var defeated_encounters: Array[String] = []
var message: String = "Acércate a un Centinela para entrar en combate."

func mark_defeated(encounter_id: String) -> void:
	if not defeated_encounters.has(encounter_id):
		defeated_encounters.append(encounter_id)
