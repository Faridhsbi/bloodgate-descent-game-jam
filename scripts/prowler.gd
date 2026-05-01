extends Area2D
## Prowler Projectile — Peluru sihir homing yang mengunci target.
## State: HOMING → LOCKING → DASHING
## Spritesheet: Vampires3_Attack_magic.png (12x4)
## Col 0-5: animasi mengejar, Col 6-11: animasi hit

enum ProwlerState { HOMING, LOCKING, DASHING }
var state = ProwlerState.HOMING

@export var homing_speed: float = 80.0
@export var dash_speed_value: float = 500.0
@export var damage: float = 30.0
@export var knockback_force: float = 250.0
@export var lock_radius: float = 50.0
@export var lock_duration: float = 0.2
@export var lifetime: float = 5.0

var initial_direction: Vector2 = Vector2.RIGHT
var target: Node2D = null
var locked_direction: Vector2 = Vector2.ZERO
var lock_timer: float = 0.0
var life_timer: float = 0.0

# Animasi
var anim_frame: int = 0
var anim_timer: float = 0.0
var current_row: int = 0
var has_spawned: bool = false
var avoidance_side: int = 0  # Komitmen sisi penghindar: -1=kiri, 1=kanan, 0=bebas

@onready var sprite: Sprite2D = $Sprite2D
@onready var haunt_sfx: AudioStreamPlayer2D = $HauntSfx

func _ready():
	sprite.hframes = 12
	sprite.vframes = 4
	sprite.visible = true
	$AnimatedSprite2D.visible = false
	if haunt_sfx:
		haunt_sfx.max_distance = 240.0
		haunt_sfx.attenuation = 2.0
	
	# Collision: detect Player (layer 1) dan Wall (layer 5)
	collision_mask = 17  # bit 1 + bit 5
	monitoring = true
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	life_timer += delta
	if life_timer >= lifetime:
		queue_free()
		return
	
	_animate(delta)
	
	match state:
		ProwlerState.HOMING:
			_process_homing(delta)
		ProwlerState.LOCKING:
			_process_locking(delta)
		ProwlerState.DASHING:
			_process_dashing(delta)

func _process_homing(delta: float):
	var move_dir: Vector2
	
	if target and is_instance_valid(target):
		move_dir = (target.global_position - global_position).normalized()
		move_dir = _get_avoidance_dir(move_dir) # Menghindari obstacle (barrel)
		
		# Cek apakah target masuk radius lock-on
		var dist = global_position.distance_to(target.global_position)
		if dist <= lock_radius:
			# LOCK ON! Kunci posisi dan mulai countdown
			locked_direction = move_dir
			lock_timer = lock_duration
			state = ProwlerState.LOCKING
			# Visual feedback: berubah merah terang
			sprite.modulate = Color(1.5, 0.3, 0.3, 1.0)
			$AnimatedSprite2D.modulate = Color(1.5, 0.3, 0.3, 1.0)
			return
	else:
		move_dir = initial_direction
	
	current_row = _dir_to_row(move_dir)
	position += move_dir * homing_speed * delta
	
	if has_spawned:
		var anim_name = "haunt_down"
		if current_row == 0: anim_name = "haunt_down"
		elif current_row == 1: anim_name = "haunt_up"
		elif current_row == 2: anim_name = "haunt_left"
		elif current_row == 3: anim_name = "haunt_right"
		$AnimatedSprite2D.play(anim_name)

func _process_locking(delta: float):
	# Berhenti sejenak sambil mengunci target (telegraphing)
	lock_timer -= delta
	if lock_timer <= 0:
		state = ProwlerState.DASHING
		sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)  # Lebih terang saat melesat
		$AnimatedSprite2D.modulate = Color(2.0, 0.5, 0.5, 1.0)

func _process_dashing(delta: float):
	# MELESAT LURUS ke arah yang sudah dikunci!
	position += locked_direction * dash_speed_value * delta

func _animate(delta: float):
	if not has_spawned:
		anim_timer += delta
		if anim_timer >= 0.08:
			anim_timer = 0.0
			anim_frame += 1
			if anim_frame > 5:
				has_spawned = true
				sprite.visible = false
				$AnimatedSprite2D.visible = true
			else:
				sprite.frame_coords = Vector2i(anim_frame, current_row)

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var kb_dir = (body.global_position - global_position).normalized()
			body.apply_knockback(kb_dir * knockback_force)
		# Ganti ke animasi hit (col 6-11)
		_play_hit_and_die()
	
	# Mengecek tipe kelas secara aman
	elif body is TileMapLayer or body is StaticBody2D:
		# Jika menabrak Tembok (TileMapLayer) atau objek rintangan lain (StaticBody2D)
		queue_free()

func _play_hit_and_die():
	# Tampilkan beberapa frame hit lalu hancur
	$AnimatedSprite2D.visible = false
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.frame_coords = Vector2i(6, current_row)
	set_physics_process(false)
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _dir_to_row(dir: Vector2) -> int:
	if abs(dir.x) > abs(dir.y):
		return 3 if dir.x > 0 else 2
	else:
		return 0 if dir.y > 0 else 1

# Fungsi untuk menghindari halangan (barrel/tembok) dengan komitmen sisi.
func _get_avoidance_dir(base_dir: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + base_dir * 30.0, 16)
	var result = space_state.intersect_ray(query)
	
	if not result:
		avoidance_side = 0
		return base_dir
	
	# Ada halangan, hitung arah geser berdasarkan normal
	var obstacle_normal = result.normal
	var perp_cw = Vector2(-obstacle_normal.y, obstacle_normal.x)
	var perp_ccw = Vector2(obstacle_normal.y, -obstacle_normal.x)
	
	if avoidance_side == 0:
		if base_dir.dot(perp_cw) >= base_dir.dot(perp_ccw):
			avoidance_side = 1
		else:
			avoidance_side = -1
	
	var chosen_perp = perp_cw if avoidance_side == 1 else perp_ccw
	return (chosen_perp * 0.7 + base_dir * 0.3).normalized()
