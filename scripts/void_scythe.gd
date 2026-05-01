extends Area2D

@export var speed: float = 240.0
@export var damage: float = 12.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _anim_time: float = 0.0
var _anim_index: int = 0

const ANIM_FRAMES := [284, 285, 286, 287]

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_frame()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	_anim_time += delta

	if _anim_time >= 0.06:
		_anim_time = 0.0
		_anim_index = (_anim_index + 1) % ANIM_FRAMES.size()
		_update_frame()

	if _age >= lifetime:
		queue_free()

func setup(new_direction: Vector2, new_damage: float = damage) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		return

	if body is TileMapLayer or body is StaticBody2D or body.name.begins_with("Door"):
		queue_free()

func _update_frame() -> void:
	var frame_number: int = ANIM_FRAMES[_anim_index]
	sprite.frame_coords = Vector2i(frame_number % sprite.hframes, frame_number / sprite.hframes)
