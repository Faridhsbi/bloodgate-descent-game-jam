extends Area2D

@export var speed: float = 300.0
@export var damage: float = 50.0

var direction: Vector2 = Vector2.ZERO

@onready var sprite = $AnimatedSprite2D

func _ready():
	collision_mask = 31
	
	# Limited range
	$LifeTimer.timeout.connect(queue_free)
	$LifeTimer.start()
	
	body_entered.connect(_on_body_entered)
	
	# Determine Animation and orientation
	if abs(direction.x) > abs(direction.y):
		sprite.play("right")
		if direction.x < 0:
			sprite.flip_h = true # if negative X (LEFT), flip horizontal
	else:
		sprite.play("down")
		if direction.y < 0:
			sprite.flip_v = true # if negative Y (UP), flip vertical

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		return
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
	queue_free()
