extends CharacterBody2D

# --- PROPERTI PERGERAKAN ---
@export var base_speed: float = 100.0
@export var sprint_speed: float = 250.0 # Lebih cepat karena ini dash
@export var exhausted_speed: float = 30.0
@export var push_force: float = 120.0 # Kekuatan dorongan pemain
var current_speed: float = base_speed

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

# --- PROPERTI STAMINA ---
@export var max_stamina: float = 100.0
var current_stamina: float = max_stamina
@export var stamina_drain_sprint: float = 35.0 # Stamina yang berkurang per detik saat sprint
@export var stamina_regen: float = 15.0 # Stamina yang pulih per detik

var is_exhausted: bool = false
var exhausted_timer: float = 0.0
@export var exhausted_duration: float = 3.0 # Berapa detik karakter kena status Exhausted

# --- PROPERTI DARAH (HP) ---
@export var max_hp: float = 100.0
var current_hp: float = max_hp
var damage_flash_timer: float = 0.0

# --- PROPERTI ATTACK (PROJECTILE & FIREBALL) ---
var fireball_ammo: int = 0
const PROJECTILE = preload("res://scenes/Projectile.tscn")
const FIREBALL = preload("res://scenes/Fireball.tscn")
const SFX_DASH := preload("res://audio/dash.wav")
const SFX_FIREBALL := preload("res://audio/04_Fire_explosion_04_medium.wav")
const SFX_DEFAULT_SHOOT := preload("res://audio/laser-one-shot-1.wav")
const SFX_FOOTSTEP := preload("res://audio/620334__marb7e__footsteps_leather_wood_walk04.wav")
const SFX_DEATH := preload("res://audio/mati player.wav")
var last_shoot_dir: Vector2 = Vector2.RIGHT
var shoot_cooldown: float = 0.0
@export var fire_rate: float = 0.8 # Cooldown antar tembakan (detik)

var is_dead: bool = false
var is_sprinting: bool = false
var has_key: bool = false  # Apakah player sudah memiliki kunci dungeon?
var knockback_velocity: Vector2 = Vector2.ZERO  # Gaya dorong dari serangan boss
var controls_locked: bool = false
@onready var _footstep_player: AudioStreamPlayer2D = $FootstepPlayer

# --- NODE REFERENSI ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var anim_state = animation_tree.get("parameters/playback")

var dash_cooldown_max: float = 1.0 # [BARU] Simpan max cooldown untuk dikirim ke UI

# [BARU] Referensi UI
var ui: PlayerUI

func _ready() -> void:
	add_to_group("player")
	animation_tree.active = true
	
	# Mencari PlayerUI secara otomatis
	ui = get_tree().get_first_node_in_group("player_ui")
	
	if ui:
		# --- [TAMBAHKAN 2 BARIS INI] ---
		# Jika UI belum siap, tunggu sampai sinyal "ready" dari UI terpancar
		if not ui.is_node_ready():
			await ui.ready
		# ------------------------------
			
		ui.initialize_player(max_hp, max_stamina, dash_cooldown_max)
		ui.update_weapon_display(fireball_ammo)
	if _footstep_player:
		_footstep_player.stream = SFX_FOOTSTEP
		_footstep_player.bus = "SFX"
		_footstep_player.max_distance = 240.0
		_footstep_player.attenuation = 2.0
		if _footstep_player.stream is AudioStreamWAV:
			_footstep_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

func _physics_process(delta: float) -> void:
	if is_dead:
		_set_footsteps_playing(false)
		return

	if controls_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_footsteps_playing(false)
		return
		
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if damage_flash_timer <= 0:
			sprite.modulate = Color.WHITE
	
	# Proses knockback (jika sedang terdorong oleh serangan)
	if knockback_velocity.length() > 5:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
		move_and_slide()
		_set_footsteps_playing(false)
		return
	else:
		knockback_velocity = Vector2.ZERO
		
	# --- [TAMBAHKAN KEMBALI KODE INI] ---
	if shoot_cooldown > 0:
		shoot_cooldown -= delta
	# ------------------------------------

	# [UPDATE] Update Cooldown Dash dan kirim data ke UI setiap frame
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if ui:
			ui.update_dash_cooldown(dash_cooldown_timer, dash_cooldown_max)
	else:
		# Pastikan bar penuh saat siap
		if ui:
			ui.update_dash_cooldown(0.0, dash_cooldown_max)
			
	if dash_timer > 0:
		dash_timer -= delta
		
	# Menembak Instan saat tombol ditekan, tanpa menghentikan gerakan
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_exhausted and shoot_cooldown <= 0.0:
		shoot_cooldown = fire_rate
		var mouse_pos = get_global_mouse_position()
		last_shoot_dir = (mouse_pos - global_position).normalized()
		
		# Wajah menoleh ke arah tembakan
		animation_tree.set("parameters/Idle/blend_position", last_shoot_dir)
		animation_tree.set("parameters/Walk/blend_position", last_shoot_dir)
		
		# Lemparkan Peluru Langsung Tanpa Menunggu
		var new_bullet
		if fireball_ammo > 0:
			new_bullet = FIREBALL.instantiate()
			fireball_ammo -= 1
			print("Sisa Hellfire Orb Ammo: ", fireball_ammo)
			if ui:
				ui.update_weapon_display(fireball_ammo)
			_play_sfx(SFX_FIREBALL, 4.0)
		else:
			new_bullet = PROJECTILE.instantiate()
			_play_sfx(SFX_DEFAULT_SHOOT, -2.0)
			
		new_bullet.global_position = global_position + (last_shoot_dir * 10)
		new_bullet.direction = last_shoot_dir
		get_parent().add_child(new_bullet)
		
	_handle_stamina(delta)
	_handle_movement(delta)

func _handle_stamina(delta: float) -> void:
	if is_exhausted:
		exhausted_timer -= delta
		if exhausted_timer <= 0.0:
			is_exhausted = false
			# [BARU] Matikan efek kedut merah karena stamina sudah pulih
			if ui:
				ui.set_exhausted_effect(false)
	else:
		if is_sprinting:
			current_stamina -= stamina_drain_sprint * delta
			if current_stamina <= 0.0:
				current_stamina = 0.0
				is_exhausted = true
				exhausted_timer = exhausted_duration
				
				# [BARU] Nyalakan efek kedut merah instan saat kehabisan napas!
				if ui:
					ui.set_exhausted_effect(true)
					
			if ui:
				ui.update_stamina(current_stamina, true)
		else:
			current_stamina += stamina_regen * delta
			if current_stamina > max_stamina:
				current_stamina = max_stamina
			if ui:
				ui.update_stamina(current_stamina, false)
				
	# -- TAMBAHKAN BARIS INI UNTUK DEBUGGING --
	# Menampilkan status Exhausted dan nilai Stamina yang dibulatkan (1 desimal)
	if is_exhausted:
		print("EXHAUSTED! Tunggu ", snapped(exhausted_timer, 0.1), " detik")
	else:
		#print("Sisa Stamina: ", snapped(current_stamina, 0.1))
		pass
				
	# Nantinya Anda bisa menghubungkan current_stamina ke sistem UI Bar di sini

func _handle_movement(_delta: float) -> void:
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_set_footsteps_playing(input_vector != Vector2.ZERO and dash_timer <= 0.0)
	
	# [UPDATE] Gunakan variabel dash_cooldown_max
	if Input.is_action_pressed("dash") and not is_exhausted and input_vector != Vector2.ZERO and dash_cooldown_timer <= 0.0 and dash_timer <= 0.0:
		dash_timer = 0.2 
		dash_cooldown_timer = dash_cooldown_max # [UPDATE]
		_play_sfx(SFX_DASH)
		
	if dash_timer > 0.0:
		is_sprinting = true
		current_speed = sprint_speed
	else:
		is_sprinting = false
		if is_exhausted:
			current_speed = exhausted_speed
		else:
			current_speed = base_speed
			
	var target_state = "Idle"
	
	if input_vector != Vector2.ZERO:
		if is_sprinting:
			target_state = "Dash"
			animation_tree.set("parameters/Dash/blend_position", input_vector)
		else:
			target_state = "Walk"
			animation_tree.set("parameters/Walk/blend_position", input_vector)
			
		# Sinkronkan arah Idle dan Death dengan arah input terakhir
		animation_tree.set("parameters/Idle/blend_position", input_vector)
		animation_tree.set("parameters/Death/blend_position", input_vector)
		
		velocity = input_vector * current_speed
	else:
		velocity = Vector2.ZERO
		
	# Update Animasi (menggunakan metode 'start' agak transisi tidak error jika Anda belum mengatur garis transisinya)
	if anim_state.get_current_node() != target_state and not is_dead:
		anim_state.start(target_state)
		
	move_and_slide()
	_handle_pushing()

# Panggil fungsi ini jika karakter terkena hitbox serangan boss atau ledakan tong
func die() -> void:
	if is_dead: return
	is_dead = true
	velocity = Vector2.ZERO
	anim_state.start("Death")
	_play_sfx(SFX_DEATH, 0.0)
	var menu_manager := get_node_or_null("/root/MenuManager")
	if menu_manager:
		menu_manager.call_deferred("show_game_over_after_delay", 1.7)

# --- SISTEM PERTARUNGAN ---
func take_damage(amount: float) -> void:
	if is_dead: return
	
	current_hp -= amount
	print("Pemain terkena serangan! Sisa HP: ", current_hp)
	if ui:
		ui.update_health(current_hp)
	# Efek kemerahan dan semi-transparan sebentar
	sprite.modulate = Color(1.0, 0.4, 0.4, 0.8)
	damage_flash_timer = 0.15
	
	if current_hp <= 0:
		current_hp = 0
		die()
		
# Di dalam player.gd
func heal(amount: float) -> void:
	if is_dead: return
	if current_hp >= max_hp: return
		
	current_hp += amount
	if current_hp > max_hp:
		current_hp = max_hp
		
	print("HP dipulihkan! Sisa HP: ", current_hp)
	
	# INI KUNCINYA: Memberitahu UI agar bar-nya bergerak!
	if ui:
		ui.update_health(current_hp)
		
# --- SISTEM ITEM ---
func pickup_key() -> void:
	has_key = true
	if ui:
		ui.set_has_dungeon_key(true)
	print("Player mendapatkan Kunci Dungeon!")

func use_key() -> void:
	has_key = false
	if ui:
		ui.set_has_dungeon_key(false)
	print("Kunci Dungeon digunakan!")

# --- SISTEM KNOCKBACK ---
func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force

func set_controls_locked(is_locked: bool) -> void:
	controls_locked = is_locked
	if controls_locked:
		velocity = Vector2.ZERO
	
	
func _handle_pushing() -> void:
	# Hanya bisa mendorong jika pemain sedang bergerak (bukan sekadar nempel)
	if velocity.length() == 0:
		return

	# get_slide_collision_count() mengecek semua benda yang disentuh player di frame ini
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Jika benda yang ditabrak punya wujud fungsi "push" (seperti Barrel kita)
		if collider.has_method("push"):
			var push_direction = -collision.get_normal()
			var item_weight = 1.0
			if "weight" in collider:
				item_weight = collider.weight
			
			# Panggil fungsi push di Barrel dengan gaya yang dikurangi beratnya
			collider.push(push_direction * (push_force / item_weight))

func add_fireball_ammo(amount: int) -> void:
	if is_dead: return
	
	fireball_ammo += amount
	print("Dapat Power Flask! Senjata berubah jadi Hellfire Orb. Total Ammo: ", fireball_ammo)
	
	# Beritahu UI untuk mengubah ikon dan angka!
	if ui:
		ui.update_weapon_display(fireball_ammo)

func _set_footsteps_playing(playing: bool) -> void:
	if not _footstep_player:
		return
	if playing:
		if not _footstep_player.playing:
			_footstep_player.play()
	else:
		if _footstep_player.playing:
			_footstep_player.stop()

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
