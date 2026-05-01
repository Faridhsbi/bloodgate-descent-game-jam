extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var current_state = State.IDLE

@export var speed: float = 110.0
@export var hp: float = 50.0
@export var damage: float = 10.0
@export var attack_speed: float = 1.5

const SFX_SWORD_HIT := preload("res://audio/26_sword_hit_1.wav")
const SFX_DEATH := preload("res://audio/skeleton_death.mp3")

var player: CharacterBody2D = null
var max_hp: float = 0.0

@onready var anim_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var attack_area = $AttackArea
@onready var health_bar: WorldHealthBar = $WorldHealthBar
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx

# --- [1. BARU] Tambahkan referensi ke node RayCast2D ---
@onready var raycast: RayCast2D = $RayCast2D 

func _ready():
	max_hp = hp
	anim_player.play("idle")
	add_to_group("enemies")
	set_collision_mask_value(1, false)  
	set_collision_mask_value(5, true)   
	health_bar.setup(max_hp, hp)
	if hit_sfx:
		hit_sfx.max_distance = 240.0
		hit_sfx.attenuation = 2.0

func _physics_process(delta):
	if current_state == State.DEAD or current_state == State.HURT:
		return

	# --- [2. BARU] LOGIKA GARIS PANDANG (LINE OF SIGHT) ---
	# Kita cek ini setiap frame asalkan player berada di dalam area lingkaran
	if player:
		# Arahkan laser ke posisi pemain
		raycast.target_position = to_local(player.global_position)
		raycast.force_raycast_update()
		
		# is_visible bernilai TRUE jika laser TIDAK menabrak tembok
		var is_visible = not raycast.is_colliding()
		
		# Jika Skeleton sedang diam dan melihat pemain -> Kejar!
		if current_state == State.IDLE and is_visible:
			change_state(State.CHASE)
		# Jika sedang mengejar tapi pemain sembunyi di balik tembok -> Berhenti!
		elif current_state == State.CHASE and not is_visible:
			change_state(State.IDLE)
	# ------------------------------------------------------

	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.CHASE:
			if player:
				# 1. Hitung jarak dari Skeleton ke Player
				var distance_to_player = global_position.distance_to(player.global_position)
				
				# 2. Tentukan batas jarak minimum (misal: 20 pixel, sesuaikan dengan lebar collision Anda)
				var min_distance = 10
				
				# 3. Hanya jalan maju jika jaraknya masih lebih besar dari batas minimum
				if distance_to_player > min_distance:
					var direction = (player.global_position - global_position).normalized()
					velocity = direction * speed
				else:
					# Jika sudah sangat dekat/menempel, BERHENTI memaksa maju!
					velocity = Vector2.ZERO
				
				# 4. Logika Flip Sprite tetap berjalan agar selalu menghadap Player
				var direction_x = player.global_position.x - global_position.x
				if direction_x < 0:
					sprite.flip_h = true
					attack_area.scale.x = -1 
				elif direction_x > 0:
					sprite.flip_h = false
					attack_area.scale.x = 1
			else:
				velocity = Vector2.ZERO
				change_state(State.IDLE)
		State.ATTACK:
			velocity = Vector2.ZERO
			
	move_and_slide()

func change_state(new_state):
	current_state = new_state
	anim_player.speed_scale = 1.0 
	
	match current_state:
		State.IDLE:
			anim_player.play("idle")
		State.CHASE:
			anim_player.play("move")
		State.ATTACK:
			anim_player.speed_scale = attack_speed 
			_play_sfx(SFX_SWORD_HIT, -8.0)
			anim_player.play("attack")
		State.HURT:
			anim_player.play("hurt")
		State.DEAD:
			_play_sfx(SFX_DEATH, -2.0, 1.25)
			anim_player.play("death")

# --- [3. UPDATE] Fungsi Deteksi Area ---
func _on_detection_area_body_entered(body):
	if body.name == "Player":
		# HANYA simpan data player, jangan langsung ganti state CHASE!
		# Keputusan untuk mengejar (CHASE) sekarang ditentukan oleh RayCast di _physics_process
		player = body 

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
		if current_state == State.CHASE:
			change_state(State.IDLE)

func _on_attack_area_body_entered(body):
	if body.name == "Player" and current_state == State.CHASE:
		change_state(State.ATTACK)

func hit_player():
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.name == "Player":
			if body.has_method("take_damage"):
				body.take_damage(damage)
			break

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		if player and attack_area.overlaps_body(player):
			change_state(State.ATTACK) 
		elif player:
			change_state(State.CHASE)  
		else:
			change_state(State.IDLE)   
			
	elif anim_name == "hurt":
		if hp <= 0:
			change_state(State.DEAD)
		else:
			change_state(State.CHASE if player else State.IDLE)
			
	elif anim_name == "death":
		queue_free()

func take_damage(amount):
	if current_state == State.DEAD:
		return
	hit_sfx.play()
	hp -= amount
	health_bar.set_health(hp, max_hp)
	if hp > 0:
		change_state(State.HURT)
	else:
		change_state(State.DEAD)

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
