extends CharacterBody2D

enum State { IDLE, CHASE, PREPARE, DASH, HURT, DEAD }

@export var max_hp: float = 70.0
@export var move_speed: float = 48.0
@export var dash_speed: float = 320.0
@export var dash_damage: float = 18.0
@export var dash_range: float = 96.0
@export var dash_cooldown: float = 2.4
@export var lifesteal_amount: float = 10.0

var hp: float = max_hp
var player: Node2D = null
var state: State = State.IDLE
var dash_dir: Vector2 = Vector2.RIGHT
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var prep_timer: float = 0.0
var hurt_timer: float = 0.0
var hit_player_this_dash: bool = false
var _frame_timer: float = 0.0
var _frame_index: int = 0

const TEX_IDLE = "res://assets/Enemy_Animations_Set/Enemy_Animations_Set/enemies-vampire_idle.png"
const TEX_MOVE = "res://assets/Enemy_Animations_Set/Enemy_Animations_Set/enemies-vampire_movement.png"
const TEX_ATTACK = "res://assets/Enemy_Animations_Set/Enemy_Animations_Set/enemies-vampire_attack.png"
const TEX_HURT = "res://assets/Enemy_Animations_Set/Enemy_Animations_Set/enemies-vampire_take_damage.png"
const TEX_DEATH = "res://assets/Enemy_Animations_Set/Enemy_Animations_Set/enemies-vampire_death.png"
const SFX_BITE := preload("res://audio/08_Bite_04.wav")
const SFX_VAMPIRE_DEATH := preload("res://audio/vampire_grawl.wav")

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: WorldHealthBar = $WorldHealthBar
@onready var hitbox: Area2D = $DashHitbox
@onready var dash_hitbox_shape: CollisionShape2D = $DashHitbox/CollisionShape2D
@onready var raycast: RayCast2D = $RayCast2D # [BARU] Hubungkan Raycast
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	health_bar.setup(max_hp, hp)
	if hit_sfx:
		hit_sfx.max_distance = 240.0
		hit_sfx.attenuation = 2.0
	#hitbox.body_entered.connect(_on_dash_hitbox_body_entered)
	_play_state(State.IDLE)

func _physics_process(delta: float) -> void:
	# [PERBAIKAN BUG 1] Pindahkan _tick_animation ke atas sebelum return!
	_tick_animation(delta)
	
	if state == State.DEAD:
		return
	_tick_animation(delta)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var dir := to_player.normalized()
	
	# [PERBAIKAN BUG 2] Cek Line of Sight (Garis Pandang)
	raycast.target_position = to_local(player.global_position)
	raycast.force_raycast_update()
	var is_visible = not raycast.is_colliding() # True jika tidak terhalang tembok

	sprite.flip_h = dir.x < 0.0
	dash_hitbox_shape.position.x = -8.0 if dir.x < 0.0 else 8.0

	match state:
		State.HURT:
			hurt_timer -= delta
			if hurt_timer <= 0.0:
				_play_state(State.CHASE)
		State.PREPARE:
			prep_timer -= delta
			velocity = Vector2.ZERO
			if prep_timer <= 0.0:
				hit_player_this_dash = false
				dash_dir = dir
				dash_timer = 0.34
				_play_state(State.DASH)
		State.DASH:
			velocity = dash_dir * dash_speed
			move_and_slide()
			dash_timer -= delta
			
			# --- [PERBAIKAN LOGIKA HITBOX] ---
			# Mengecek damage secara terus-menerus selama Dash berlangsung
			if not hit_player_this_dash:
				var overlapping_bodies = hitbox.get_overlapping_bodies()
				for body in overlapping_bodies:
					if body.name == "Player":
						if body.has_method("take_damage"):
							body.take_damage(dash_damage)
						_play_sfx(SFX_BITE)
						# Lifesteal
						hp = minf(hp + lifesteal_amount, max_hp)
						health_bar.set_health(hp, max_hp)
						hit_player_this_dash = true
						break # Langsung keluar dari loop jika sudah mengenai Player
			# ---------------------------------
			
			for i in range(get_slide_collision_count()):
				var collision := get_slide_collision(i)
				var collider := collision.get_collider()
				if collider is TileMapLayer or collider is StaticBody2D:
					_end_dash()
					return
			
			if dash_timer <= 0.0:
				_end_dash()
			return
		_:
			# Hanya izinkan Dash atau Chase JIKA is_visible == true
			if is_visible and distance <= dash_range and dash_cooldown_timer <= 0.0:
				prep_timer = 0.35
				dash_dir = dir
				_play_state(State.PREPARE)
				velocity = Vector2.ZERO
			elif is_visible and distance > 18.0:
				_play_state(State.CHASE)
				velocity = dir * move_speed
			else:
				# Jika terhalang tembok (tidak visible), paksa kembali ke IDLE
				_play_state(State.IDLE)
				velocity = Vector2.ZERO

	move_and_slide()

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	hit_sfx.play()
	hp -= amount
	health_bar.set_health(hp, max_hp)
	if hp <= 0.0:
		_play_state(State.DEAD)
		return
	hurt_timer = 0.18
	_play_state(State.HURT)

#func _on_dash_hitbox_body_entered(body: Node) -> void:
	#if state != State.DASH or hit_player_this_dash:
		#return
	#if body.name == "Player":
		#if body.has_method("take_damage"):
			#body.take_damage(dash_damage)
		#hp = minf(hp + lifesteal_amount, max_hp)
		#health_bar.set_health(hp, max_hp)
		#hit_player_this_dash = true

func _end_dash() -> void:
	dash_cooldown_timer = dash_cooldown
	velocity = Vector2.ZERO
	_play_state(State.IDLE)

func _play_state(new_state: State) -> void:
	if state == new_state and new_state != State.CHASE:
		return
	state = new_state
	_frame_index = 0
	_frame_timer = 0.0

	match state:
		State.IDLE:
			sprite.texture = load(TEX_IDLE)
			sprite.hframes = 6
			sprite.frame = 0
		State.CHASE:
			sprite.texture = load(TEX_MOVE)
			sprite.hframes = 8
			sprite.frame = 0
		State.PREPARE, State.DASH:
			sprite.texture = load(TEX_ATTACK)
			sprite.hframes = 16
			sprite.frame = 0
		State.HURT:
			sprite.texture = load(TEX_HURT)
			sprite.hframes = 5
			sprite.frame = 0
		State.DEAD:
			_play_sfx(SFX_VAMPIRE_DEATH)
			sprite.texture = load(TEX_DEATH)
			sprite.hframes = 14
			sprite.frame = 0

func _tick_animation(delta: float) -> void:
	var speed_scale := 0.09
	var frame_count := sprite.hframes
	match state:
		State.CHASE:
			speed_scale = 0.075
		State.PREPARE:
			speed_scale = 0.07
		State.DASH:
			speed_scale = 0.05
		State.HURT:
			speed_scale = 0.06
		State.DEAD:
			speed_scale = 0.08

	_frame_timer += delta
	if _frame_timer < speed_scale:
		return
	_frame_timer = 0.0

	if state == State.DEAD:
		if _frame_index < frame_count - 1:
			_frame_index += 1
			sprite.frame = _frame_index
		else:
			queue_free()
		return

	if state == State.HURT:
		if _frame_index < frame_count - 1:
			_frame_index += 1
			sprite.frame = _frame_index
		return

	if state == State.PREPARE:
		_frame_index = min(_frame_index + 1, 5)
		sprite.frame = _frame_index
		return

	if state == State.DASH:
		_frame_index = (_frame_index + 1) % 10
		sprite.frame = 6 + _frame_index
		return

	_frame_index = (_frame_index + 1) % frame_count
	sprite.frame = _frame_index

func _play_sfx(stream: AudioStream) -> void:
	if not stream:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.bus = "SFX"
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
