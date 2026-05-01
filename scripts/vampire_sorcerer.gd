extends CharacterBody2D

enum State { IDLE, REPOSITION, CAST, HURT, DEAD }

@export var max_hp: float = 45.0
@export var speed: float = 48.0
@export var retreat_distance: float = 96.0
@export var preferred_distance: float = 160.0
@export var shot_cooldown: float = 2.2
@export var projectile_damage: float = 10.0

var hp: float = max_hp
var state: State = State.IDLE
var player: Node2D = null
var shot_timer: float = 0.0
var hurt_timer: float = 0.0
var strafe_sign: float = 1.0

const VOID_SCYTHE_SCENE = preload("res://scenes/VoidScythe.tscn")
const SFX_VOID_SCYTHE_OPTIONS: Array[AudioStream] = [
	preload("res://audio/266168__plasterbrain__shooting-star-2.wav"),
	preload("res://audio/77_flesh_02.wav")
]
const SFX_VAMPIRE_DEATH := preload("res://audio/vampire_grawl.wav")
const FRAMES: Array[String] = [
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_1.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_2.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_3.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_4.png"
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: WorldHealthBar = $WorldHealthBar
@onready var raycast: RayCast2D = $RayCast2D # [BARU] Hubungkan RayCast2D
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx

var _anim_time: float = 0.0
var _anim_index: int = 0

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	health_bar.setup(max_hp, hp)
	if hit_sfx:
		hit_sfx.max_distance = 240.0
		hit_sfx.attenuation = 2.0
	_apply_frame()
	shot_timer = randf_range(0.3, 1.0)
	strafe_sign = -1.0 if randi() % 2 == 0 else 1.0

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_animate(delta)
	
	if state == State.HURT:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			state = State.IDLE
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var dir := to_player.normalized()

	# --- [PERBAIKAN LOGIKA RAYCAST & PANDANGAN] ---
	raycast.target_position = to_local(player.global_position)
	raycast.force_raycast_update()
	var is_visible: bool = not raycast.is_colliding()

	if is_visible:
		# Hanya kurangi cooldown tembakan jika target terlihat
		shot_timer -= delta
		
		if distance < retreat_distance:
			state = State.REPOSITION
			var retreat := -dir + dir.orthogonal() * 0.45 * strafe_sign
			velocity = retreat.normalized() * speed
		elif distance > preferred_distance + 24.0:
			state = State.REPOSITION
			velocity = dir * speed * 0.85
		else:
			state = State.CAST
			velocity = dir.orthogonal() * speed * 0.35 * strafe_sign
			if shot_timer <= 0.0:
				_fire_triple_void(dir)
				shot_timer = shot_cooldown
				strafe_sign *= -1.0
	else:
		# Jika terhalang tembok, diam dan jangan curang menembak dari balik tembok
		state = State.IDLE
		velocity = Vector2.ZERO
	# ----------------------------------------------

	move_and_slide()
	sprite.flip_h = dir.x < 0.0

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	hit_sfx.play()
	hp -= amount
	health_bar.set_health(hp, max_hp)
	sprite.modulate = Color(1.4, 0.9, 1.8, 1.0)
	hurt_timer = 0.15
	state = State.HURT
	if hp <= 0.0:
		state = State.DEAD
		_play_sfx(SFX_VAMPIRE_DEATH)
		queue_free()

func _fire_triple_void(base_dir: Vector2) -> void:
	if SFX_VOID_SCYTHE_OPTIONS.size() > 0:
		var scythe_sfx: AudioStream = SFX_VOID_SCYTHE_OPTIONS[randi() % SFX_VOID_SCYTHE_OPTIONS.size()]
		_play_sfx(scythe_sfx)
	var angles: Array[float] = [-14.0, 0.0, 14.0]
	for angle_deg in angles:
		var projectile: Node = VOID_SCYTHE_SCENE.instantiate()
		projectile.global_position = global_position + base_dir * 10.0
		if projectile.has_method("setup"):
			projectile.setup(base_dir.rotated(deg_to_rad(angle_deg)), projectile_damage)
		get_parent().add_child(projectile)

func _animate(delta: float) -> void:
	_anim_time += delta
	if _anim_time >= 0.12:
		_anim_time = 0.0
		_anim_index = (_anim_index + 1) % FRAMES.size()
		_apply_frame()

	if state != State.HURT:
		sprite.modulate = Color(0.83, 0.66, 1.15, 1.0)

func _apply_frame() -> void:
	sprite.texture = load(FRAMES[_anim_index])

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
