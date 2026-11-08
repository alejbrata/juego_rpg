extends CharacterBody3D

@export var movement_speed: float = 4.0
@export var use_imported_kael: bool = true
var movement_enabled: bool = true
var _external_input: Vector2 = Vector2.ZERO
var _use_external_input: bool = false
var model: BattleActorVisual

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.6
	collider.shape = capsule
	collider.position.y = 0.85
	add_child(collider)
	model = BattleActorVisual.new()
	model.prefer_imported_kael = use_imported_kael
	add_child(model)
	model.build(BattleEngine.Fighter.new(preload("res://data/kael.tres"), false))
	model.caption.visible = false
	model.turn_ring.visible = false
	model.shield.visible = false
	var label := Label3D.new()
	label.text = "Kael"
	label.position.y = 2.3
	label.font_size = 30
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

# Future touch controls can supply a vector without changing movement/collision.
func set_movement_input(value: Vector2) -> void:
	_external_input = value.limit_length(1.0)
	_use_external_input = true

func clear_movement_input() -> void:
	_external_input = Vector2.ZERO
	_use_external_input = false

func _keyboard_input() -> Vector2:
	var axis := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	axis += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return axis.limit_length(1.0)

func _physics_process(delta: float) -> void:
	var axis := (_external_input if _use_external_input else _keyboard_input()) if movement_enabled else Vector2.ZERO
	var direction := Vector3(axis.x, 0, axis.y)
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed
	velocity.y -= 9.8 * delta
	move_and_slide()
	if model.imported_model != null:
		model.imported_model.set_walking(Vector2(velocity.x, velocity.z).length() > 0.05, movement_speed / 4.0)
	if direction.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12))
