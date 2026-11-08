class_name ExpeditionMission
extends RefCounted

const CLUES: Array[String] = ["camp", "crystal", "inscription"]
const SENTINELS: Array[String] = ["clearing_sentinel_a", "clearing_sentinel_b"]

var intro_seen: bool = false
var investigated: Array[String] = []
var revelation_started: bool = false
var completed: bool = false

func investigate(id: String) -> bool:
	if not CLUES.has(id) or investigated.has(id):
		return false
	investigated.append(id)
	return true

func all_clues() -> bool:
	for id in CLUES:
		if not investigated.has(id):
			return false
	return true

func sentinels_defeated(defeated: Array[String]) -> bool:
	for id in SENTINELS:
		if not defeated.has(id):
			return false
	return true

func revelation_available(defeated: Array[String]) -> bool:
	return intro_seen and all_clues() and sentinels_defeated(defeated) and not revelation_started and not completed

func begin_revelation(defeated: Array[String]) -> bool:
	if not revelation_available(defeated):
		return false
	revelation_started = true
	return true

func finish_revelation() -> bool:
	if not revelation_started or completed:
		return false
	completed = true
	return true

func objective(defeated: Array[String]) -> String:
	if completed:
		return "La expedición perdida · Completada"
	if revelation_available(defeated) or revelation_started:
		return "Examina la anomalía junto a las ruinas"
	if investigated.is_empty():
		return "Investiga el claro"
	if not all_clues():
		return "Encuentra pistas de la expedición"
	return "Neutraliza a los Centinelas"
