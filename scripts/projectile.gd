extends Area2D

@export var speed: float = 200.0
@export var damage: float = 10.0

var direction: Vector2 = Vector2.ZERO

func _ready():
	# Memastikan bahwa proyektil mendeteksi tabrakan dengan musuh dan Tembok! (Mask=31 menjangkau layer 1, 2, 3, 4, 5)
	collision_mask = 31
	
	# Hancurkan peluru setelah 2 detik agar tidak bocor di memory
	$LifeTimer.timeout.connect(queue_free)
	$LifeTimer.start()
	
	# Hubungkan signal saat menabrak sesuatu (body = CharacterBody2D/StaticBody2D)
	body_entered.connect(_on_body_entered)
	
	# Rotasi peluru sesuai dengan arah tembakan (Dynamic Rotation)
	rotation = direction.angle()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body: Node2D):
	# Abaikan jika peluru menabrak pemain sendiri
	if body.name == "Player":
		return
		
	# Cek apakah objek yang ditabrak punya wujud fungsi take_damage (musuh)
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
	# Hancurkan peluru paska menabrak (kena musuh ATAU dinding)
	queue_free()
