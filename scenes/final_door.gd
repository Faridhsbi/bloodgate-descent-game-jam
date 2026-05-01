extends StaticBody2D
class_name FinalDoor

const SFX_DOOR_OPEN := preload("res://audio/05_door_open_2.mp3")

@export_file("*.tscn") var boss_arena_path: String = "res://scenes/BossArena.tscn"
@export var cinematic_title: String = "THE BLOOD GATE OPENS"
@export var cinematic_subtitle: String = "The vampire lord waits beyond the last chamber."

var is_open: bool = false
var is_player_near: bool = false
var is_transitioning: bool = false
var _anim_timer: float = 0.0
var _anim_frame: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var portal_effect: Polygon2D = $PortalEffect
@onready var room_detector: Area2D = $RoomDetector
@onready var interact_area: Area2D = $InteractArea
@onready var prompt_label: Label = $PromptLabel
@onready var overlay: ColorRect = $CanvasLayer/Overlay
@onready var title_label: Label = $CanvasLayer/TitleLabel
@onready var subtitle_label: Label = $CanvasLayer/SubtitleLabel
@onready var boss_transition_sfx: AudioStreamPlayer2D = $BossTransitionSfx

func _ready() -> void:
	# Pastikan portal tersembunyi dan transparan sejak awal
	portal_effect.hide()
	portal_effect.color.a = 0.0 # Transparansi 0
	
	prompt_label.hide()
	overlay.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	title_label.text = cinematic_title
	subtitle_label.text = cinematic_subtitle
	
	interact_area.body_entered.connect(_on_player_entered)
	interact_area.body_exited.connect(_on_player_exited)
	if boss_transition_sfx:
		boss_transition_sfx.max_distance = 240.0
		boss_transition_sfx.attenuation = 2.0
	
	# HAPUS _setup_portal_animation() dari sini!
	# Jangan mainkan animasi saat baru mulai.

func _physics_process(delta: float) -> void:
	_animate_sprite(delta)
	
	# Selalu update status jika player ada di dekat pintu
	if is_player_near and not is_transitioning:
		_check_door_status()

# 1. Animasi Bawaan Sprite (Api hijau bergerak)
func _animate_sprite(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= 0.1: # Kecepatan frame
		_anim_timer = 0.0
		# Karena hframes=6, vframes=3, total ada 18 frame (0-17)
		_anim_frame = (_anim_frame + 1) % 18
		sprite.frame = _anim_frame

# 2. Pengecekan Musuh di Area Tertentu
func _check_door_status() -> void:
	if is_open:
		prompt_label.text = "[E] Enter Boss Arena"
		prompt_label.modulate = Color(0.5, 1.0, 0.5)
		return
		
	var enemies_left: int = 0
	var bodies = room_detector.get_overlapping_bodies()
	
	for body in bodies:
		if body.is_in_group("enemies") and not body.is_queued_for_deletion():
			enemies_left += 1
			
	if enemies_left > 0:
		prompt_label.text = "Locked (" + str(enemies_left) + " Enemies Left)"
		prompt_label.modulate = Color(1.0, 0.3, 0.3) # Merah
	else:
		_open_door()

# 3. Logika Pintu Terbuka
func _open_door() -> void:
	if is_open:
		return # Mencegah pintu terbuka 2 kali
		
	is_open = true
	_play_sfx(SFX_DOOR_OPEN)
	prompt_label.text = "[E] Enter Boss Arena"
	prompt_label.modulate = Color(0.5, 1.0, 0.5) # Hijau terang
	
	portal_effect.show()
	_setup_portal_animation() # PANGGIL ANIMASI DI SINI!

# 4. Efek Portal Berkedip (Kelap-kelip)
func _setup_portal_animation() -> void:
	# Efek muncul perlahan lalu mulai kelap-kelip
	var tween = create_tween().set_loops()
	tween.tween_property(portal_effect, "color:a", 0.75, 0.8) # Menerang
	tween.tween_property(portal_effect, "color:a", 0.35, 0.8) # Meredup
	
# 5. Deteksi Tombol E
func _unhandled_input(event: InputEvent) -> void:
	if is_player_near and is_open and not is_transitioning:
		if event.is_action_pressed("interact"):
			_enter_boss_arena()

func _enter_boss_arena() -> void:
	is_transitioning = true
	set_process_unhandled_input(false)
	prompt_label.hide()

	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(portal_effect, "color:a", 1.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(func(): boss_transition_sfx.play())
	tween.tween_interval(1.55)
	tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(title_label, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_go_to_boss_arena)

func _go_to_boss_arena() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(boss_arena_path)

# --- Sinyal Interaksi ---
func _on_player_entered(body: Node2D) -> void:
	if body.name == "Player":
		is_player_near = true
		prompt_label.show()
		_check_door_status()

func _on_player_exited(body: Node2D) -> void:
	if body.name == "Player":
		is_player_near = false
		prompt_label.hide()

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
