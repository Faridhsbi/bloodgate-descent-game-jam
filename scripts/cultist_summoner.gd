extends CharacterBody2D

@export var max_hp: float = 38.0
@export var speed: float = 42.0
@export var summon_cooldown: float = 4.0
@export var panic_distance: float = 110.0
@export var wander_radius: float = 44.0

var hp: float = max_hp
var player: Node2D = null
var wander_center: Vector2
var wander_target: Vector2
var summon_timer: float = 0.0
var _anim_time: float = 0.0
var _anim_index: int = 0
var _hurt_timer: float = 0.0
var _dead: bool = false

const WISP_SCYTHE_SCENE = preload("res://scenes/CultistWisp.tscn")
const FRAMES: Array[String] = [
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_1.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_2.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_3.png",
	"res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/vampire/v2/vampire_v2_4.png"
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var crown: Sprite2D = $BlueFlameCrown
@onready var health_bar: WorldHealthBar = $WorldHealthBar
@onready var raycast: RayCast2D = $RayCast2D # [BARU] Hubungkan RayCast

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	wander_center = global_position
	wander_target = wander_center
	summon_timer = randf_range(1.0, summon_cooldown)
	health_bar.setup(max_hp, hp)
	_apply_frame()

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_animate(delta)

	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			sprite.modulate = Color(0.72, 0.8, 0.95, 1.0)
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	summon_timer -= delta
	var move_dir := Vector2.ZERO
	var is_visible := false

	# --- [PERBAIKAN LOGIKA PANDANGAN] ---
	if player and is_instance_valid(player):
		raycast.target_position = to_local(player.global_position)
		raycast.force_raycast_update()
		is_visible = not raycast.is_colliding()

	if player and is_instance_valid(player) and is_visible:
		# Jika pemain TERLIHAT, panik atau memanggil Wisp
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		
		if distance < panic_distance:
			move_dir = (-to_player.normalized() + to_player.normalized().orthogonal() * 0.5).normalized()
		else:
			if global_position.distance_to(wander_target) < 8.0:
				_pick_new_wander_target()
			move_dir = (wander_target - global_position).normalized()

		if summon_timer <= 0.0 and distance < 230.0:
			_spawn_wisp()
			summon_timer = summon_cooldown
	else:
		# Jika pemain TIDAK TERLIHAT, santai jalan-jalan (Wander)
		if global_position.distance_to(wander_target) < 8.0:
			_pick_new_wander_target()
		move_dir = (wander_target - global_position).normalized()

	velocity = move_dir * speed
	move_and_slide()
	
	if absf(move_dir.x) > 0.05:
		sprite.flip_h = move_dir.x < 0.0
		crown.flip_h = sprite.flip_h

func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	health_bar.set_health(hp, max_hp)
	sprite.modulate = Color(1.35, 0.85, 0.95, 1.0)
	_hurt_timer = 0.15
	if hp <= 0.0:
		_dead = true
		queue_free()

func _spawn_wisp() -> void:
	var wisp: Node = WISP_SCYTHE_SCENE.instantiate()
	
	# --- [PERBAIKAN LOGIKA SPAWN] ---
	var spawn_offset := Vector2.ZERO
	
	# Cek jika pemain ada, munculkan Wisp 12 piksel DI DEPAN Cultist menghadap pemain
	if player and is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		spawn_offset = dir * 12.0 
	else:
		# Jika pemain tidak ada, munculkan tepat di badan Cultist (paling aman dari tembok)
		spawn_offset = Vector2(0, 0)
		
	wisp.global_position = global_position + spawn_offset
	# --------------------------------
	
	get_parent().add_child(wisp)

func _pick_new_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(14.0, wander_radius)
	wander_target = wander_center + Vector2.RIGHT.rotated(angle) * radius

func _animate(delta: float) -> void:
	_anim_time += delta
	if _anim_time >= 0.13:
		_anim_time = 0.0
		_anim_index = (_anim_index + 1) % FRAMES.size()
		_apply_frame()
	crown.modulate = Color(0.7 + sin(Time.get_ticks_msec() * 0.008) * 0.12, 1.0, 1.25, 0.95)

func _apply_frame() -> void:
	sprite.texture = load(FRAMES[_anim_index])
