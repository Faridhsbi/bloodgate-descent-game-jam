extends StaticBody2D

const SFX_DOOR_OPEN := preload("res://audio/05_door_open_2.mp3")
const SFX_DOOR_LOCKED := preload("res://audio/321087__benjaminnelan__door-locked.wav")

@onready var sprite = $Sprite2D
@onready var interaction_area = $InteractionArea
@onready var prompt_label = $PromptLabel
@onready var collision_shape = $CollisionShape2D

const CLOSED_FRAME := 5
const OPEN_ANIMATION_FRAMES := [6, 7, 8, 9]

var is_player_near: bool = false
var player_ref: Node2D = null
var is_open: bool = false
var is_opening: bool = false

@export var open_frame_delay: float = 0.08

func _ready():
	prompt_label.hide() # Sembunyikan teks saat game dimulai
	sprite.region_enabled = false
	sprite.hframes = 5
	sprite.vframes = 6
	sprite.frame = CLOSED_FRAME
	
	# Sambungkan sinyal dari InteractionArea
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body.name == "Player" and not is_open and not is_opening:
		is_player_near = true
		player_ref = body
		prompt_label.show()
		
		# Cek apakah pemain sudah punya kunci atau belum
		if player_ref.has_key:
			prompt_label.text = "[E] Unlock Door"
			prompt_label.modulate = Color.WHITE # Warna putih
		else:
			prompt_label.text = "Locked (Needs Key)"
			prompt_label.modulate = Color.RED # Warna merah peringatan

func _on_body_exited(body: Node2D):
	if body.name == "Player":
		is_player_near = false
		player_ref = null
		prompt_label.hide()

# Mengecek input keyboard SETIAP KALI ada tombol yang ditekan
func _unhandled_input(event):
	if is_player_near and not is_open and not is_opening:
		# Jika tombol interact ditekan
		if event.is_action_pressed("interact"):
			if player_ref and player_ref.has_key:
				open_door()
			else:
				_play_sfx(SFX_DOOR_LOCKED)
				print("Kamu butuh Dungeon Key untuk membuka pintu ini!")

func open_door():
	is_opening = true
	prompt_label.hide()
	_play_sfx(SFX_DOOR_OPEN)
	if player_ref and player_ref.has_method("use_key"):
		player_ref.use_key()
	elif player_ref:
		player_ref.set("has_key", false)
	
	for frame_index in OPEN_ANIMATION_FRAMES:
		sprite.frame = frame_index
		await get_tree().create_timer(open_frame_delay).timeout
	
	# Matikan tembok fisik agar pemain bisa lewat (gunakan set_deferred agar tidak crash)
	is_open = true
	is_opening = false
	collision_shape.set_deferred("disabled", true)
	print("Pintu terbuka!")

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
