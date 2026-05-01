extends CharacterBody2D
## Minion Head — Kepala kecil yang di-spawn Boss.
## Mengejar player selama 3 detik, lalu dash bunuh diri + ledakan.
## 1-hit KO. 60% chance drop Stamina Flask saat mati.
## Spritesheet: Vampires3_Attack_head.png (12x4, normal per arah)

@export var chase_speed: float = 60.0
@export var suicide_dash_speed: float = 250.0
@export var hp: float = 10.0  # 1-hit KO dari proyektil player (damage 10)
@export var explosion_damage: float = 15.0
@export var suicide_timer_duration: float = 3.0

var target_player: Node2D = null
var is_dead: bool = false
var suicide_mode: bool = false
var suicide_timer: float = 0.0
var suicide_direction: Vector2 = Vector2.ZERO

# Animasi
var anim_frame: int = 0
var anim_timer: float = 0.0
var current_row: int = 0

const STAMINA_FLASK_SCENE = preload("res://scenes/items/StaminaFlask.tscn")
const SFX_VAMPIRE_DEATH := preload("res://audio/vampire_grawl.wav")
const ASSET_PATH = "res://assets/free-vampire-4-direction-pixel-character-sprite-pack/PNG/Vampires3/Attack/Vampires3_Attack_head.png"

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: WorldHealthBar = $WorldHealthBar
@onready var move_sfx: AudioStreamPlayer2D = $MoveSfx
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx

func _ready():
	sprite.texture = load(ASSET_PATH)
	sprite.hframes = 12
	sprite.vframes = 4
	
	# Collision: Layer 3 (enemy), mask Player (1) dan Wall (5)
	collision_layer = 4
	set_collision_mask_value(1, false)  # Jangan tabrakan fisik dengan player
	set_collision_mask_value(5, true)   # Tabrakan dengan wall
	
	add_to_group("enemies")
	suicide_timer = suicide_timer_duration
	health_bar.setup(hp, hp)
	if move_sfx:
		move_sfx.max_distance = 240.0
		move_sfx.attenuation = 2.0
	if hit_sfx:
		hit_sfx.max_distance = 240.0
		hit_sfx.attenuation = 2.0
	move_sfx.play()

func _physics_process(delta: float):
	if is_dead:
		return
	
	_animate(delta)
	
	if suicide_mode:
		_process_suicide(delta)
	else:
		_process_chase(delta)
		suicide_timer -= delta
		if suicide_timer <= 0:
			_start_suicide()
	
	move_and_slide()
	_die_if_hit_wall()

func _process_chase(delta: float):
	if target_player and is_instance_valid(target_player):
		var dir = (target_player.global_position - global_position).normalized()
		current_row = _dir_to_row(dir)
		velocity = dir * chase_speed
		
		# Jika selama mengejar target sudah bersentuhan (jarak < 15), meledak langsung!
		var dist = global_position.distance_to(target_player.global_position)
		if dist < 15:
			_explode()
	else:
		velocity = Vector2.ZERO

func _start_suicide():
	suicide_mode = true
	if target_player and is_instance_valid(target_player):
		suicide_direction = (target_player.global_position - global_position).normalized()
	else:
		suicide_direction = Vector2.RIGHT
	current_row = _dir_to_row(suicide_direction)
	# Visual: berubah merah saat mau meledak
	sprite.modulate = Color(1.5, 0.3, 0.3, 1.0)

func _process_suicide(_delta: float):
	velocity = suicide_direction * suicide_dash_speed
	
	# Cek apakah sudah dekat player untuk meledak
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist < 15:
			_explode()

func _explode():
	# Berikan damage ke player jika dalam jangkauan
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist < 30 and target_player.has_method("take_damage"):
			target_player.take_damage(explosion_damage)
			if target_player.has_method("apply_knockback"):
				var kb = (target_player.global_position - global_position).normalized() * 200
				target_player.apply_knockback(kb)
	_die()

func take_damage(amount: float):
	if is_dead:
		return
	hit_sfx.play()
	hp -= amount
	health_bar.set_health(hp)
	if hp <= 0:
		_die()

func _die(can_drop_flask: bool = true):
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	move_sfx.stop()
	_play_sfx(SFX_VAMPIRE_DEATH, -6.0, 1.35)
	
	# 60% chance drop Stamina Flask
	if can_drop_flask and randf() < 0.6:
		var flask = STAMINA_FLASK_SCENE.instantiate()
		flask.global_position = global_position
		get_parent().add_child(flask)
	
	# Hapus dari group lalu hilang
	remove_from_group("enemies")
	queue_free()

func _play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.bus = "SFX"
	sfx.volume_db = volume_db
	sfx.pitch_scale = pitch_scale
	sfx.max_distance = 240.0
	sfx.attenuation = 2.0
	var parent := get_tree().current_scene
	if parent:
		parent.add_child(sfx)
	else:
		add_child(sfx)
	sfx.global_position = global_position
	sfx.finished.connect(sfx.queue_free)
	sfx.play()

func _die_if_hit_wall() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is TileMapLayer:
			_die(false)
			return
		if collider is CollisionObject2D and collider.get_collision_layer_value(5):
			_die(false)
			return

func _animate(delta: float):
	anim_timer += delta
	if anim_timer >= 0.08:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 12
		sprite.frame_coords = Vector2i(anim_frame, current_row)

func _dir_to_row(dir: Vector2) -> int:
	if abs(dir.x) > abs(dir.y):
		return 3 if dir.x > 0 else 2
	else:
		return 0 if dir.y > 0 else 1
