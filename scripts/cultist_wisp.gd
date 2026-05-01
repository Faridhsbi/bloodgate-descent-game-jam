extends CharacterBody2D

@export var speed: float = 55.0
@export var hp: float = 12.0
@export var damage: float = 8.0

var player: Node2D = null
var _anim_time: float = 0.0
var _anim_index: int = 0
var _dead: bool = false
var _hit_flash_timer: float = 0.0
var _base_modulate: Color = Color.WHITE

const HIT_FLASH_DURATION: float = 0.12
const HIT_FLASH_COLOR := Color(1.5, 0.3, 0.3, 1.0)

const FRAMES: Array[String] = [
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/skull/v2/skull_v2_1.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/skull/v2/skull_v2_2.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/skull/v2/skull_v2_3.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/skull/v2/skull_v2_4.png"
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: WorldHealthBar = $WorldHealthBar
@onready var raycast: RayCast2D = $RayCast2D # [BARU] Hubungkan RayCast
@onready var move_sfx: AudioStreamPlayer2D = $MoveSfx
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx

func _ready() -> void:
	add_to_group("enemies")
	_base_modulate = sprite.modulate
	
	# Setting layer default via kode (tapi pastikan Mask Player 1 mati di editor ya!)
	collision_layer = 4
	collision_mask = 16 # Hanya mendeteksi Tembok (Bit 5 / Nilai 16)
	
	player = get_tree().get_first_node_in_group("player")
	health_bar.setup(hp, hp)
	_apply_frame()
	if move_sfx:
		move_sfx.max_distance = 240.0
		move_sfx.attenuation = 2.0
	if hit_sfx:
		hit_sfx.max_distance = 240.0
		hit_sfx.attenuation = 2.0

func _physics_process(delta: float) -> void:
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			sprite.modulate = _base_modulate

	if _dead:
		_set_move_sfx_playing(false)
		return

	_anim_time += delta
	if _anim_time >= 0.12:
		_anim_time = 0.0
		_anim_index = (_anim_index + 1) % FRAMES.size()
		_apply_frame()

	var is_visible := false

	# --- [PERBAIKAN LOGIKA PANDANGAN WISP] ---
	if player and is_instance_valid(player):
		raycast.target_position = to_local(player.global_position)
		raycast.force_raycast_update()
		is_visible = not raycast.is_colliding()

	var is_moving := false
	if player and is_instance_valid(player) and is_visible:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
		is_moving = true
		
		sprite.flip_h = dir.x < 0.0
		
		# Deteksi jarak manual untuk damage (karena deteksi tabrakan fisik player dimatikan)
		if global_position.distance_to(player.global_position) < 14.0:
			if player.has_method("take_damage"):
				player.take_damage(damage)
			_die()
	else:
		# Jika pemain tak terlihat, wisp melayang diam
		velocity = Vector2.ZERO

	_set_move_sfx_playing(is_moving)

	# Hancur jika menabrak tembok
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is TileMapLayer or collider is StaticBody2D:
			_die()
			return

func take_damage(amount: float) -> void:
	if _dead:
		return
	hit_sfx.play()
	hp -= amount
	health_bar.set_health(hp, hp) # Parameter diperbaiki agar bar update normal
	sprite.modulate = HIT_FLASH_COLOR
	_hit_flash_timer = HIT_FLASH_DURATION
	if hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	_set_move_sfx_playing(false)
	queue_free()

func _apply_frame() -> void:
	sprite.texture = load(FRAMES[_anim_index])

func _set_move_sfx_playing(playing: bool) -> void:
	if not move_sfx:
		return
	if playing:
		if not move_sfx.playing:
			move_sfx.play()
	else:
		if move_sfx.playing:
			move_sfx.stop()
