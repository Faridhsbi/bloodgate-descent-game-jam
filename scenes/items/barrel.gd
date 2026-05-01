extends CharacterBody2D # Pastikan root node Barrel Anda adalah StaticBody2D agar peluru bisa menabraknya

const SFX_BARREL_EXPLODE := preload("res://audio/bomb_explosion.ogg")

# --- PROPERTI TONG ---
# Darah tong. Karena damage peluru = 10, maka 30 HP = butuh tepat 3 tembakan!
@export var max_hp: float = 30.0 
var current_hp: float
@export var push_friction: float = 600.0 # Semakin besar, semakin cepat tong berhenti
@export var weight: float = 3.0 # Berat tong, mempengaruhi kelambatan player saat mendorong
# --- PROPERTI LEDAKAN ---
@export var explosion_damage: float = 50.0 # Damage yang diberikan ledakan ke area sekitar
@onready var animation_player = $AnimatedSprite2D 
@onready var explosion_radius = $ExplosionRadius # Area2D untuk radius ledakan
@onready var health_bar: WorldHealthBar = $WorldHealthBar

var is_exploding: bool = false 

func _ready() -> void:
	# Set HP penuh saat awal mulai
	current_hp = max_hp
	health_bar.setup(max_hp, current_hp)
	
	# Putar animasi spawn saat pertama kali muncul
	animation_player.play("spawn")
	
	# Sambungkan signal animasi selesai
	animation_player.animation_finished.connect(_on_animation_finished)

# --- FUNGSI MENERIMA TEMBAKAN ---
# Fungsi ini otomatis dipanggil oleh peluru karena nama fungsinya "take_damage"
func take_damage(amount: float) -> void:
	# Jika sedang meledak, abaikan peluru tambahan
	if is_exploding: 
		return 

	current_hp -= amount
	health_bar.set_health(current_hp, max_hp)
	print("Tong tertembak! Sisa HP Tong: ", current_hp)

	# Opsional: Bikin tong berkedip merah sedikit saat tertembak agar ada feedback
	modulate = Color(1, 0.5, 0.5) 
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)

	# Jika HP habis (sudah 3x tertembak), ledakkan!
	if current_hp <= 0:
		explode()

# --- FUNGSI LEDAKAN ---
func explode() -> void:
	is_exploding = true
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_node("ShakeAnimationPlayer"):
		cam.get_node("ShakeAnimationPlayer").play("shake")
	_play_sfx(SFX_BARREL_EXPLODE)
	animation_player.play("explode") # Memutar animasi ledakan
	
	# Matikan collision box tong agar pemain/musuh bisa lewat
	if is_instance_valid($CollisionShape2D):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# Berikan damage ke objek di sekitarnya
	_apply_aoe_damage()

func _apply_aoe_damage() -> void:
	# Deteksi semua yang ada di dalam Area2D (ExplosionRadius)
	var overlapping_bodies = explosion_radius.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		# Abaikan tong ini sendiri
		if body == self:
			continue
			
		# Jika yang kena ledakan punya fungsi take_damage (Pemain, Musuh, atau Tong lain)
		if body.has_method("take_damage"):
			body.take_damage(explosion_damage)
			print("LEDAKAN mengenai: ", body.name, " sebesar ", explosion_damage, " damage!")

# Signal saat animasi ledakan selesai
func _on_animation_finished() -> void:
	if animation_player.animation == "explode":
		# Hapus tong dari arena setelah animasinya selesai
		queue_free()
func _physics_process(delta: float) -> void:
	# Terapkan gesekan: Jika tong memiliki kecepatan, pelan-pelan kurangi jadi 0
	if velocity.length() > 0:
		velocity = velocity.move_toward(Vector2.ZERO, push_friction * delta)
		
	# Jalankan pergerakan fisik
	move_and_slide()
	
func push(push_velocity: Vector2) -> void:
	velocity = push_velocity

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
