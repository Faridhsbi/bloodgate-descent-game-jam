extends StaticBody2D
## Peti Harta — menjatuhkan Key Scene.
## Bisa dikonfigurasi apakah harus membunuh semua musuh atau bisa langsung dibuka.

const SFX_CHEST_OPEN := preload("res://audio/chest_open.wav")

@export var key_scene: PackedScene 
@export var enemies_group: String = "enemies" 

# [BARU] Opsi saklar di Inspector: Centang untuk wajib bunuh musuh, hilangkan centang untuk gratis
@export var require_all_enemies_dead: bool = true 

var is_opened: bool = false
var is_player_near: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var prompt_label: Label = $PromptLabel # [BARU] Hubungkan Label

func _ready():
	sprite.play("closed")
	prompt_label.hide()
	
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

# --- DETEKSI KEDEKATAN ---
func _on_body_entered(body: Node2D):
	if body.name == "Player" and not is_opened:
		is_player_near = true
		_update_prompt_label()
		prompt_label.show()

func _on_body_exited(body: Node2D):
	if body.name == "Player":
		is_player_near = false
		prompt_label.hide()

# --- UPDATE TEKS BERDASARKAN SYARAT ---
func _update_prompt_label():
	if require_all_enemies_dead:
		var enemies_alive = get_tree().get_nodes_in_group(enemies_group).size()
		if enemies_alive > 0:
			prompt_label.text = "Locked (" + str(enemies_alive) + " Enemies Left)"
			prompt_label.modulate = Color.RED
		else:
			prompt_label.text = "[E] Open Chest"
			prompt_label.modulate = Color.WHITE
	else:
		# Jika tidak butuh syarat bunuh musuh
		prompt_label.text = "[E] Open Chest"
		prompt_label.modulate = Color.WHITE

# --- DETEKSI TOMBOL 'E' ---
func _unhandled_input(event):
	if is_player_near and not is_opened:
		if event.is_action_pressed("interact"):
			_try_open_chest()

# --- LOGIKA MEMBUKA PETI ---
func _try_open_chest():
	# Jika butuh syarat, cek musuh dulu
	if require_all_enemies_dead:
		var enemies_alive = get_tree().get_nodes_in_group(enemies_group)
		if enemies_alive.size() > 0:
			# Update teks jika pemain memaksa pencet E tapi musuh masih ada
			_update_prompt_label()
			return
	
	# Buka peti!
	is_opened = true
	prompt_label.hide() # Sembunyikan teks saat peti sudah terbuka
	_play_sfx(SFX_CHEST_OPEN)
	sprite.play("open")
	
	await sprite.animation_finished
	_spawn_key()

func _spawn_key():
	if key_scene:
		var key_instance = key_scene.instantiate()
		key_instance.global_position = global_position + Vector2(0, 12)
		get_parent().add_child(key_instance)
	else:
		push_warning("PERINGATAN: key_scene belum di-assign di Inspector pada peti ini!")

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
