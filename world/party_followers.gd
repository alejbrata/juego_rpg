class_name PartyFollowers
extends Node3D
## 1.4: Lyra and Nira walk behind Kael in exploration. Presentation only: no physics
## bodies, collisions, encounters or mission logic. They tread the leader's own
## recorded path, so they never cut through walls the leader walked around.

const HEROES := ["lyra", "nira"]
const GAPS := [1.2, 2.3]     # distance along the path behind the leader (m)
const STEP := 0.08           # trail resolution (m)
const TELEPORT := 1.5        # leader jumps farther than this (new game, return): reseed

var leader: Node3D
var height := 0.0
var members: Array[BattleActorVisual] = []
var _trail: Array[Vector3] = []   # newest first; the leader's position is prepended live

static func enabled() -> bool:
	return bool(ProjectSettings.get_setting("visuals/party/followers", true)) and KaelModel.party_style() == "hd"

func setup(lead: Node3D, model_height: float) -> void:
	leader = lead
	height = model_height
	for id: String in HEROES:
		var visual := BattleActorVisual.new()
		visual.name = id.capitalize()
		add_child(visual)
		visual.build(BattleEngine.Fighter.new(load("res://data/%s.tres" % id), false))
		visual.caption.visible = false
		visual.turn_ring.visible = false
		visual.shield.visible = false
		if visual.nameplate != null:
			visual.nameplate.visible = false
		members.append(visual)
	reset_trail()

## Straight line behind the leader, towards the clearing centre (open ground).
func reset_trail() -> void:
	var back := Vector3(-leader.position.x, 0, -leader.position.z)
	back = back.normalized() if back.length() > 0.5 else Vector3.BACK
	_trail.clear()
	for i in int(GAPS[-1] / STEP) + 3:
		_trail.append(leader.position + back * STEP * (i + 1))
	_place(0.0)

func _physics_process(delta: float) -> void:
	if leader == null:
		return
	var head := leader.position
	if head.distance_to(_trail[0]) > TELEPORT:
		reset_trail()
		return
	if head.distance_to(_trail[0]) >= STEP:
		_trail.push_front(head)
		while _trail.size() > int(GAPS[-1] / STEP) * 3 + 8:
			_trail.pop_back()
	_place(delta)

func point_at(distance: float) -> Vector3:
	var previous := leader.position
	var left := distance
	for point in _trail:
		var segment := previous.distance_to(point)
		if segment >= left and segment > 0.0:
			return previous.lerp(point, left / segment)
		left -= segment
		previous = point
	return previous

func _place(delta: float) -> void:
	for i in members.size():
		var member := members[i]
		var target := point_at(GAPS[i]) + Vector3.UP * height
		var motion := target - member.position
		member.position = target
		if delta <= 0.0:
			member.rotation.y = atan2(leader.position.x - target.x, leader.position.z - target.z)
			continue
		var speed := Vector2(motion.x, motion.z).length() / delta
		if member.imported_model != null:
			member.imported_model.set_walking(speed > 0.05, speed / 4.0)
		if speed > 0.05:
			member.rotation.y = lerp_angle(member.rotation.y, atan2(motion.x, motion.z), minf(1.0, delta * 10))
