extends CharacterBody2D
## Boss Vampire — State Machine dengan 2 fase pertarungan.
## Semua aset menggunakan Vampires3 (12 kolom × 4 baris).
## Row: 0=Down, 1=Up, 2=Left, 3=Right

enum State {
	IDLE, CHASE, MAGIC_CHARGE, FULL_ATTACK, BITING,
	WHIFF_STUN, SPAWN_MINION, SHADOW_STEP, SHADOW_EMERGE, HURT, DEAD
}

var current_state = State.IDLE
var phase: int = 1

# --- STATS ---
@export var max_hp: float = 500.0
var hp: float = max_hp
@export var chase_speed: float = 70.0
@export var dash_speed: float = 300.0
@export var magic_damage: float = 20.0
@export var bite_damage: float = 25.0
@export var bite_lifesteal: float = 15.0
@export var knockback_force: float = 300.0
@export var wait_for_intro: bool = true
var encounter_started: bool = false

# --- COOLDOWNS ---
var attack_timer: float = 1.0 # Saat mulai, boss langsung bersiap menyerang
@export var phase1_cooldown: float = 1.5 # Jeda antar serangan di Fase 1 (lebih cepat)
@export var phase2_cooldown: float = 1.0 # Jeda antar serangan di Fase 2 (sangat cepat)

# --- ANIMATION (code-driven) ---
var anim_frame: int = 0
var anim_timer: float = 0.0
var anim_speed: float = 0.1  # detik per frame
var min_frame: int = 0
var max_frame: int = 11
var current_row: int = 0
var anim_looping: bool = true

# --- STATE-SPECIFIC ---
var player: Node2D = null
var dash_target: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.ZERO
var whiff_timer: float = 0.0
var shadow_timer: float = 0.0
var shadow_angle: float = 0.0
var stun_timer: float = 0.0
var phase2_active: bool = false
var damage_flash_timer: float = 0.0
var avoidance_side: int = 0  # 0 = tidak menghindar, 1 = kanan, -1 = kiri
var chase_attack_timer: float = 2.0  # Timer agar boss bisa menyerang dari jauh saat mengejar

# --- FLASK DROPS ---
const HP_DROP_THRESHOLDS = [425, 325, 200]
var dropped_at: Array = []

# --- BARREL DROPS ---
const BARREL_DROP_THRESHOLDS = [400]
var barrel_dropped_at: Array = []

# --- POWER FLASK DROPS ---
const POWER_DROP_THRESHOLDS = [300]
var power_dropped_at: Array = []

# --- TEXTURES (di-load saat _ready) ---
var tex_idle: Texture2D
var tex_run: Texture2D
var tex_attack_body: Texture2D
var tex_attack_full: Texture2D
var tex_attack_magic: Texture2D
var tex_attack_head: Texture2D
var tex_hurt: Texture2D
var tex_death: Texture2D
var tex_shadow: Texture2D

# --- PRELOADS ---
const PROWLER_SCENE = preload("res://scenes/ProwlerProjectile.tscn")
const MINION_SCENE = preload("res://scenes/MinionHead.tscn")
const HEALTH_FLASK_SCENE = preload("res://scenes/items/HealthFlask.tscn")
const STAMINA_FLASK_SCENE = preload("res://scenes/items/StaminaFlask.tscn")
const BARREL_SCENE = preload("res://scenes/items/Barrel.tscn")
const POWER_FLASK_SCENE = preload("res://scenes/items/PowerFlask.tscn")
const SFX_BITE := preload("res://audio/08_Bite_04.wav")
const SFX_BOSS_APPEAR := preload("res://audio/boss muncul.wav")
const SFX_BLOOD_MODE := preload("res://audio/transisi blood mode.wav")
const SFX_SHADOW_MODE := preload("res://audio/mode menghilang.wav")
const SFX_VAMPIRE_DEATH := preload("res://audio/vampire_grawl.wav")

# --- NODE REFERENCES ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow_sprite: Sprite2D = $ShadowSprite
@onready var detection_area: Area2D = $DetectionArea
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var shadow_hitbox: Area2D = $ShadowHitbox
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx

const ASSET_BASE = "res://assets/free-vampire-4-direction-pixel-character-sprite-pack/PNG/Vampires3/"

func _ready():
	_load_textures()
	sprite.hframes = 12
	sprite.vframes = 4
	shadow_sprite.hframes = 12
	shadow_sprite.vframes = 4
	shadow_sprite.visible = false
	shadow_hitbox.visible = false
	
	# Collision: Boss di Layer 3 (Enemy), detect Wall (Layer 5) 
	# (Kita MENGHILANGKAN layer 1/Player agar tidak saling blokir/dorong secara fisik)
	collision_layer = 4  
	set_collision_mask_value(1, false)
	set_collision_mask_value(5, true)
	
	add_to_group("enemies")
	add_to_group("boss")
	_update_boss_ui()
	if hit_sfx:
		hit_sfx.max_distance = 240.0
		hit_sfx.attenuation = 2.0
	
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	
	# Jika Player tidak sengaja menyentuh hitbox boss dengan badannya, langsung gigit!
	melee_hitbox.body_entered.connect(_on_melee_hitbox_entered)
	
	_change_state(State.IDLE)

func _load_textures():
	tex_idle = load(ASSET_BASE + "Idle/Vampires3_Idle_body.png")
	tex_run = load(ASSET_BASE + "Run/Vampires3_Run_body.png")
	tex_attack_body = load(ASSET_BASE + "Attack/Vampires3_Attack_body.png")
	tex_attack_full = load(ASSET_BASE + "Attack/Vampires3_Attack_full.png")
	tex_attack_magic = load(ASSET_BASE + "Attack/Vampires3_Attack_magic.png")
	tex_attack_head = load(ASSET_BASE + "Attack/Vampires3_Attack_head.png")
	tex_hurt = load(ASSET_BASE + "Hurt/Vampires3_Hurt_body.png") # 4 hframes
	tex_death = load(ASSET_BASE + "Death/Vampires3_Death_full.png") # 11 hframes
	tex_shadow = load(ASSET_BASE + "Idle/Vampires3_Idle_shadow.png") # 4 hframes

# ============================================================
# PHYSICS PROCESS
# ============================================================
func _physics_process(delta: float):
	if current_state == State.DEAD:
		_animate(delta)
		return

	if wait_for_intro and not encounter_started:
		velocity = Vector2.ZERO
		_animate(delta)
		return
	
	# Flash red effect timer untuk indikator damage
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if damage_flash_timer <= 0:
			sprite.modulate = Color.WHITE
			
	_animate(delta)
	
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.MAGIC_CHARGE:
			_process_magic_charge(delta)
		State.FULL_ATTACK:
			_process_full_attack(delta)
		State.BITING:
			_process_biting(delta)
		State.WHIFF_STUN:
			_process_whiff_stun(delta)
		State.SPAWN_MINION:
			_process_spawn_minion(delta)
		State.SHADOW_STEP:
			_process_shadow_step(delta)
		State.SHADOW_EMERGE:
			_process_shadow_emerge(delta)
		State.HURT:
			_process_hurt(delta)
	
	move_and_slide()

# ============================================================
# ANIMASI (code-driven, karena spritesheet 12x4)
# ============================================================
func _animate(delta: float):
	anim_timer += delta
	if anim_timer >= anim_speed:
		anim_timer = 0.0
		anim_frame += 1
		if anim_frame > max_frame:
			if anim_looping:
				anim_frame = min_frame
			else:
				anim_frame = max_frame
				_on_anim_finished()
		sprite.frame_coords = Vector2i(anim_frame, current_row)

func _set_anim(texture: Texture2D, h_frames: int, from_col: int, to_col: int, loop: bool = true, speed: float = 0.1):
	sprite.texture = texture
	sprite.hframes = h_frames
	min_frame = from_col
	max_frame = to_col
	anim_frame = from_col
	anim_looping = loop
	anim_speed = speed
	anim_timer = 0.0
	
	# Clamp frame_coords x to avoid out-of-bounds crash if transition happens midway
	if anim_frame >= h_frames:
		anim_frame = 0
	sprite.frame_coords = Vector2i(anim_frame, current_row)

func _dir_to_row(dir: Vector2) -> int:
	if abs(dir.x) > abs(dir.y):
		return 3 if dir.x > 0 else 2  # Right / Left
	else:
		return 0 if dir.y > 0 else 1  # Down / Up

func _face_player():
	if player:
		var dir = (player.global_position - global_position).normalized()
		current_row = _dir_to_row(dir)

# Fungsi untuk boss memutar menghindari rintangan (Barrel/Tembok)
# Menggunakan "persistent side" agar boss berkomitmen ke satu sisi sampai jalan bebas.
func _get_avoidance_dir(base_dir: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	# Cast sejauh 50 pixel ke arah target
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + base_dir * 50.0, 16)
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	
	if not result:
		# Jalan bebas, reset komitmen sisi
		avoidance_side = 0
		return base_dir
	
	# Ada halangan! Hitung arah geser berdasarkan normal tabrakan.
	var obstacle_normal = result.normal
	# Perpendicular: 2 arah tegak lurus dari normal
	var perp_cw = Vector2(-obstacle_normal.y, obstacle_normal.x)   # Searah jarum jam
	var perp_ccw = Vector2(obstacle_normal.y, -obstacle_normal.x)  # Berlawanan jarum jam
	
	# Jika belum berkomitmen ke sisi manapun, pilih sisi yang lebih dekat ke arah target
	if avoidance_side == 0:
		if base_dir.dot(perp_cw) >= base_dir.dot(perp_ccw):
			avoidance_side = 1   # Berkomitmen ke kanan (clockwise)
		else:
			avoidance_side = -1  # Berkomitmen ke kiri (counter-clockwise)
	
	var chosen_perp = perp_cw if avoidance_side == 1 else perp_ccw
	
	# Campurkan: 70% geser samping + 30% maju agar boss perlahan memutar
	return (chosen_perp * 0.7 + base_dir * 0.3).normalized()

# ============================================================
# STATE PROCESSORS
# ============================================================
func _process_idle(delta: float):
	velocity = Vector2.ZERO
	attack_timer -= delta
	if attack_timer <= 0.0 and player:
		_choose_attack()

func _process_chase(delta: float):
	if not player:
		_change_state(State.IDLE)
		return
	
	var dir = (player.global_position - global_position).normalized()
	dir = _get_avoidance_dir(dir) # Hindari barrel/tembok
	
	current_row = _dir_to_row(dir)
	velocity = dir * chase_speed
	
	var dist = global_position.distance_to(player.global_position)
	# Jika cukup dekat, langsung pilih serangan
	if dist < 40:
		_choose_attack()
	else:
		# Boss tetap bisa menyerang dari jauh jika terlalu lama mengejar
		# (mencegah boss diam ngestuck di belakang barrel tanpa pernah menyerang)
		chase_attack_timer -= delta
		if chase_attack_timer <= 0.0:
			chase_attack_timer = _get_cooldown()
			_choose_attack()

func _process_magic_charge(delta: float):
	velocity = Vector2.ZERO
	_face_player()

func _process_full_attack(_delta: float):
	velocity = dash_direction * dash_speed
	
	# Cek apakah sudah melewati titik target
	var to_target = dash_target - global_position
	if to_target.dot(dash_direction) <= 0 or global_position.distance_to(dash_target) < 15:
		# Sudah sampai/melewati target
		_check_bite_hit()

func _process_biting(_delta: float):
	velocity = Vector2.ZERO

func _process_whiff_stun(delta: float):
	velocity = Vector2.ZERO
	whiff_timer -= delta
	if whiff_timer <= 0:
		_change_state(State.CHASE)

func _process_spawn_minion(_delta: float):
	velocity = Vector2.ZERO

func _process_shadow_step(delta: float):
	velocity = Vector2.ZERO
	shadow_timer -= delta
	shadow_angle += delta * 3.0
	
	if player and shadow_sprite.visible:
		var offset = Vector2(cos(shadow_angle), sin(shadow_angle)) * 60
		shadow_sprite.global_position = player.global_position + offset
		shadow_hitbox.global_position = shadow_sprite.global_position
		
		# Animasi shadow
		var shadow_row = _dir_to_row(-offset.normalized())
		shadow_sprite.frame_coords = Vector2i(anim_frame % shadow_sprite.hframes, shadow_row)
	
	if shadow_timer <= 0:
		_emerge_from_shadow()

func _process_shadow_emerge(_delta: float):
	velocity = Vector2.ZERO

func _process_hurt(_delta: float):
	velocity = Vector2.ZERO

# ============================================================
# STATE CHANGES
# ============================================================
func _change_state(new_state: State):
	current_state = new_state
	
	match current_state:
		State.IDLE:
			_face_player()
			_set_anim(tex_idle, 4, 0, 3, true, 0.1)
		
		State.CHASE:
			_set_anim(tex_run, 8, 0, 7, true, 0.08)
		
		State.MAGIC_CHARGE:
			_face_player()
			_set_anim(tex_attack_magic, 12, 0, 5, false, 0.12)
		
		State.FULL_ATTACK:
			_face_player()
			if player:
				dash_target = player.global_position
				dash_direction = (dash_target - global_position).normalized()
				current_row = _dir_to_row(dash_direction)
			_set_anim(tex_attack_full, 12, 0, 5, false, 0.07)
		
		State.BITING:
			_set_anim(tex_attack_full, 12, 6, 11, false, 0.08)
		
		State.WHIFF_STUN:
			whiff_timer = 1.5
			_set_anim(tex_hurt, 4, 0, 3, true, 0.15)  # terhuyung
		
		State.SPAWN_MINION:
			_face_player()
			_set_anim(tex_attack_head, 12, 0, 11, false, 0.1)
		
		State.SHADOW_STEP:
			shadow_timer = 2.5
			shadow_angle = 0.0
			_play_sfx(SFX_SHADOW_MODE)
			sprite.modulate.a = 0.0  # Boss invisible
			shadow_sprite.visible = true
			shadow_sprite.texture = tex_shadow
			shadow_sprite.hframes = 4
			_set_anim(tex_idle, 4, 0, 3, true, 0.1)
		
		State.SHADOW_EMERGE:
			sprite.modulate.a = 1.0
			sprite.modulate = Color.WHITE
			shadow_sprite.visible = false
			shadow_hitbox.visible = false
			shadow_hitbox.monitoring = false
			_face_player()
			_set_anim(tex_attack_magic, 12, 0, 5, false, 0.1)
			var cam = get_viewport().get_camera_2d()
			if cam and cam.has_node("ShakeAnimationPlayer"):
				cam.get_node("ShakeAnimationPlayer").play("shake")
		
		State.HURT:
			_set_anim(tex_hurt, 4, 0, 3, false, 0.08)
		
		State.DEAD:
			# Kita tambahkan parameter volume_db, misalnya 10.0 untuk membuatnya lebih keras
			_play_sfx(SFX_VAMPIRE_DEATH, 20.0)
			_set_anim(tex_death, 11, 0, 10, false, 0.1)

# ============================================================
# ATTACK SELECTION
# ============================================================
func _choose_attack():
	var dist = 999.0
	if player:
		dist = global_position.distance_to(player.global_position)
	
	var choices: Array = []
	
	if phase == 1:
		# Fase 1: lebih sering magic
		choices = [State.MAGIC_CHARGE, State.MAGIC_CHARGE, State.MAGIC_CHARGE,
				   State.FULL_ATTACK, State.SPAWN_MINION]
	else:
		# Fase 2: lebih agresif
		choices = [State.MAGIC_CHARGE, State.FULL_ATTACK, State.FULL_ATTACK,
				   State.SHADOW_STEP, State.SPAWN_MINION, State.SHADOW_STEP]
	
	# Jika jauh, prioritaskan magic/shadow
	if dist > 100:
		if phase == 2 and randf() < 0.3:
			_change_state(State.SHADOW_STEP)
			return
		_change_state(State.MAGIC_CHARGE)
		return
	
	var chosen = choices[randi() % choices.size()]
	_change_state(chosen)

# ============================================================
# ANIMATION CALLBACKS
# ============================================================
func _on_anim_finished():
	match current_state:
		State.MAGIC_CHARGE:
			_fire_prowlers()
			attack_timer = _get_cooldown()
			_change_state(State.IDLE)
		
		State.FULL_ATTACK:
			# Animasi charge selesai, cek hit
			_check_bite_hit()
		
		State.BITING:
			attack_timer = _get_cooldown()
			_change_state(State.IDLE if not player else State.CHASE)
		
		State.SPAWN_MINION:
			_do_spawn_minions()
			attack_timer = _get_cooldown()
			_change_state(State.IDLE)
		
		State.SHADOW_EMERGE:
			_fire_prowlers()
			attack_timer = _get_cooldown()
			_change_state(State.IDLE if not player else State.CHASE)
		
		State.HURT:
			if hp <= 0:
				_change_state(State.DEAD)
			else:
				_change_state(State.CHASE if player else State.IDLE)
		
		State.DEAD:
			var menu_manager := get_node_or_null("/root/MenuManager")
			if menu_manager:
				menu_manager.call_deferred("show_win_screen_after_delay", 0.5)
			queue_free()

# ============================================================
# ATTACK IMPLEMENTATIONS
# ============================================================
func _fire_prowlers():
	if not player:
		return
	var dir = (player.global_position - global_position).normalized()
	
	if phase == 2:
		# Fase 2: 3 prowler menyebar (kipas)
		for angle_offset in [-0.3, 0.0, 0.3]:
			var rotated = dir.rotated(angle_offset)
			_spawn_single_prowler(rotated)
	else:
		# Fase 1: 1 prowler
		_spawn_single_prowler(dir)

func _spawn_single_prowler(direction: Vector2):
	var prowler = PROWLER_SCENE.instantiate()
	prowler.global_position = global_position + direction * 20
	prowler.initial_direction = direction
	prowler.target = player
	prowler.damage = magic_damage
	get_parent().add_child(prowler)

func _check_bite_hit():
	velocity = Vector2.ZERO
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_node("ShakeAnimationPlayer"):
		cam.get_node("ShakeAnimationPlayer").play("shake")
	var bodies = melee_hitbox.get_overlapping_bodies()
	var hit = false
	for body in bodies:
		if body.name == "Player":
			hit = true
			if body.has_method("take_damage"):
				body.take_damage(bite_damage)
			if body.has_method("apply_knockback"):
				var kb_dir = (body.global_position - global_position).normalized()
				body.apply_knockback(kb_dir * knockback_force)
	
	if hit:
		_play_sfx(SFX_BITE)

	if hit and bite_lifesteal > 0.0:
		hp = minf(hp + bite_lifesteal, max_hp)
		_update_boss_ui()

	if hit:
		_change_state(State.BITING)
	else:
		_change_state(State.WHIFF_STUN)

func _do_spawn_minions():
	var count = 2 if phase == 1 else 3
	for i in count:
		var angle = (TAU / count) * i
		var offset = Vector2(cos(angle), sin(angle)) * 40
		var minion = MINION_SCENE.instantiate()
		minion.global_position = global_position + offset
		minion.target_player = player
		get_parent().add_child(minion)

func _emerge_from_shadow():
	# Muncul di belakang player
	if player:
		var behind_dir = (global_position - player.global_position).normalized()
		global_position = player.global_position + behind_dir * 50
	_play_sfx(SFX_BOSS_APPEAR)
	_change_state(State.SHADOW_EMERGE)

func _on_melee_hitbox_entered(body: Node2D):
	if body.name == "Player":
		# Pemain menyenggol Boss! Jika boss sedang lengah (Idle/Chase), langsung hukum dengan gigitan!
		if current_state in [State.IDLE, State.CHASE]:
			print("Pemain menyentuh Boss! Boss Counter-Attack!")
			_change_state(State.FULL_ATTACK)

# ============================================================
# DAMAGE & HP SYSTEM
# ============================================================
func take_damage(amount: float):
	if current_state == State.DEAD:
		return
	hit_sfx.play()
	
	hp -= amount
	hp = maxf(hp, 0.0)
	print("Boss HP: ", hp, "/", max_hp)
	_update_boss_ui()
	
	# Flash sprite merah saat terkena damage
	sprite.modulate = Color(1.5, 0.3, 0.3, 1.0)
	damage_flash_timer = 0.15
	
	# Cek flask drop di threshold HP
	for threshold in HP_DROP_THRESHOLDS:
		if hp <= threshold and threshold not in dropped_at:
			dropped_at.append(threshold)
			_spawn_health_flask()
			
	# Cek barrel drop di threshold HP
	for threshold in BARREL_DROP_THRESHOLDS:
		if hp <= threshold and threshold not in barrel_dropped_at:
			barrel_dropped_at.append(threshold)
			_spawn_barrel()

	# Cek power flask drop di threshold HP
	for threshold in POWER_DROP_THRESHOLDS:
		if hp <= threshold and threshold not in power_dropped_at:
			power_dropped_at.append(threshold)
			_spawn_power_flask()
	
	# Cek transisi Fase 2
	if hp <= 250 and not phase2_active:
		_enter_phase2()
	
	if hp <= 0:
		_update_boss_ui()
		_change_state(State.DEAD)
	else:
		# HANYA masuk ke state HURT jika sedang santai. 
		# Jika sedang menyerang (Magic/Dash), Boss memiliki HYPER ARMOR agar tidak bisa di-stunlock pemain!
		if current_state in [State.IDLE, State.CHASE]:
			_change_state(State.HURT)

func _enter_phase2():
	phase2_active = true
	phase = 2
	chase_speed = 100.0  # 40% lebih cepat
	var boss_ui := get_tree().get_first_node_in_group("boss_ui")
	if boss_ui and boss_ui.has_method("show_phase2_effect"):
		boss_ui.show_phase2_effect()
	_play_sfx(SFX_BLOOD_MODE)
	print("=== FASE 2: THE BLOODTHIRSTY BEAST ===")

func _get_cooldown() -> float:
	return phase2_cooldown if phase == 2 else phase1_cooldown

func _spawn_health_flask():
	var flask = HEALTH_FLASK_SCENE.instantiate()
	flask.global_position = global_position + Vector2(randi_range(-30, 30), randi_range(-30, 30))
	get_parent().add_child(flask)
	print("Health Flask muncul!")

func _spawn_barrel():
	var barrel = BARREL_SCENE.instantiate()
	barrel.global_position = global_position + Vector2(randi_range(-40, 40), randi_range(-40, 40))
	get_parent().add_child(barrel)
	print("Barrel muncul saat pertarungan!")

func _spawn_power_flask():
	var flask = POWER_FLASK_SCENE.instantiate()
	flask.global_position = global_position + Vector2(randi_range(-30, 30), randi_range(-30, 30))
	get_parent().add_child(flask)
	print("Power Flask muncul!")

# ============================================================
# DETEKSI PLAYER
# ============================================================
func _on_detection_body_entered(body: Node2D):
	if body.name == "Player":
		player = body
		if current_state == State.IDLE and (not wait_for_intro or encounter_started):
			_change_state(State.CHASE)

func _on_detection_body_exited(body: Node2D):
	if body == player:
		player = null
		if current_state == State.CHASE:
			_change_state(State.IDLE)

func _update_boss_ui() -> void:
	var boss_ui := get_tree().get_first_node_in_group("boss_ui")
	if boss_ui and boss_ui.has_method("bind_to_boss"):
		boss_ui.bind_to_boss(self)
	if boss_ui and boss_ui.has_method("update_health"):
		boss_ui.update_health(hp, max_hp)

func start_encounter(target: Node2D = null) -> void:
	encounter_started = true
	if target:
		player = target
		_face_player()
	_change_state(State.CHASE if player else State.IDLE)

func _play_sfx(stream: AudioStream, extra_volume: float = 0.0) -> void:
	if not stream:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.bus = "SFX"
	sfx.volume_db = extra_volume
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
