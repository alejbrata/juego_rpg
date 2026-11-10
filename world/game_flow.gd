extends Node

var session := GameSession.new()
var zone: Node3D
var battle: Node3D
var active_encounter: EncounterData

func _ready() -> void:
	TouchControls.configure(get_tree())
	_open_zone()
	# Debug builds on phones log a performance line to logcat every 5 s
	# (adb logcat -s godot:I | findstr RENDIMIENTO). Not present in release builds.
	if OS.has_feature("mobile") and OS.is_debug_build():
		var timer := Timer.new()
		timer.wait_time = 5.0
		timer.autostart = true
		timer.timeout.connect(_log_performance)
		add_child(timer)

func _log_performance() -> void:
	print("RENDIMIENTO fps=%d frame_ms=%.1f mem_static_mb=%.0f video_mb=%.0f tex_mb=%.0f prims=%d escena=%s" % [
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"combate" if is_instance_valid(battle) else "exploración"])

func _open_zone() -> void:
	zone = preload("res://scenes/forest_zone.tscn").instantiate()
	zone.session = session
	zone.encounter_requested.connect(_on_encounter_requested)
	zone.new_game_requested.connect(func() -> void: new_game.call_deferred())
	add_child(zone)

func _on_encounter_requested(encounter: EncounterData) -> void:
	if session.mode != GameSession.Mode.EXPLORING:
		return
	# Area3D signals can arrive while physics queries are flushing. Gate input
	# immediately, but detach collision objects and load battle outside that flush.
	session.mode = GameSession.Mode.BATTLE
	session.leader_position = zone.player.position
	_begin_encounter.call_deferred(encounter, session)

func _begin_encounter(encounter: EncounterData, expected_session: GameSession) -> void:
	if expected_session != session or session.mode != GameSession.Mode.BATTLE:
		return
	var error := encounter.validation_error()
	if not error.is_empty():
		session.mode = GameSession.Mode.EXPLORING
		session.message = error
		zone.refresh_from_session()
		return
	active_encounter = encounter
	remove_child(zone) # Retains position and geometry, disables physics/camera/HUD.
	battle = preload("res://scenes/battle_3d.tscn").instantiate()
	battle.configure_encounter(session.heroes, encounter.enemies, session.party)
	battle.battle_finished.connect(_on_battle_finished)
	add_child(battle)
	battle.hud.return_to_zone_requested.connect(_on_return_requested)
	battle.hud.battle_reset.connect(func() -> void: session.mode = GameSession.Mode.BATTLE)

func _on_battle_finished(result: int) -> void:
	if result == BattleEngine.Phase.VICTORY:
		_finish_victory.call_deferred()
	elif result == BattleEngine.Phase.DEFEAT:
		session.mode = GameSession.Mode.DEFEAT

func _finish_victory() -> void:
	if not is_instance_valid(battle) or battle.hud.engine.phase != BattleEngine.Phase.VICTORY:
		return
	session.mark_defeated(active_encounter.id)
	session.message = "%s ha caído. El rastro de la expedición continúa entre las ruinas." % active_encounter.label
	_return_to_zone(false)

func _on_return_requested() -> void:
	if is_instance_valid(battle) and not battle.playing and battle.event_queue.is_empty() and battle.hud.engine.phase == BattleEngine.Phase.DEFEAT:
		_return_to_zone.call_deferred(true)

func _return_to_zone(after_defeat: bool) -> void:
	battle.hud.engine.abort()
	remove_child(battle)
	battle.queue_free()
	battle = null
	active_encounter = null
	session.mode = GameSession.Mode.EXPLORING
	if after_defeat:
		session.leader_position = GameSession.SPAWN
		session.message = "El grupo ha conseguido retirarse. Las pistas siguen en el claro."
	zone.player.position = session.leader_position
	add_child(zone)
	zone.refresh_from_session()

func new_game() -> void:
	if is_instance_valid(battle):
		battle.hud.engine.abort()
		remove_child(battle)
		battle.queue_free()
		battle = null
	if is_instance_valid(zone):
		if zone.get_parent() == self:
			remove_child(zone)
		zone.queue_free()
	active_encounter = null
	session = GameSession.new()
	_open_zone()

func _exit_tree() -> void:
	# A detached exploration scene is deliberately retained during battle.
	if is_instance_valid(zone) and zone.get_parent() == null:
		zone.free()
	if is_instance_valid(battle):
		battle.hud.engine.abort()
