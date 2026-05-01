extends Node2D

@export_file("*.tscn") var next_scene_path: String = "res://scenes/BossArena.tscn"
@export var require_all_enemies_dead: bool = true
@export var cinematic_title: String = "THE BLOOD GATE OPENS"
@export var cinematic_subtitle: String = "The air grows colder beyond this threshold."
@export var transition_sfx: AudioStream

var player_near := false
var is_transitioning := false

@onready var portal_area: Area2D = $PortalArea
@onready var enemy_detector: Area2D = $EnemyDetector
@onready var prompt_label: Label = $PromptLabel
@onready var lock_label: Label = $LockLabel
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var overlay: ColorRect = $CanvasLayer/Overlay
@onready var title_label: Label = $CanvasLayer/TitleLabel
@onready var subtitle_label: Label = $CanvasLayer/SubtitleLabel
@onready var marker: AnimatedSprite2D = $Marker
@onready var portal_glow: PointLight2D = $PortalGlow
@onready var transition_sfx_player: AudioStreamPlayer2D = $TransitionSfx

var _marker_start_scale := Vector2.ONE
var _portal_glow_start_energy := 0.0
var _idle_tween: Tween

func _ready() -> void:
	portal_area.body_entered.connect(_on_body_entered)
	portal_area.body_exited.connect(_on_body_exited)
	prompt_label.hide()
	lock_label.hide()
	overlay.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	title_label.text = cinematic_title
	subtitle_label.text = cinematic_subtitle
	marker.play("wave")
	_marker_start_scale = marker.scale
	_portal_glow_start_energy = portal_glow.energy
	_setup_idle_polish()
	if transition_sfx_player:
		transition_sfx_player.max_distance = 240.0
		transition_sfx_player.attenuation = 2.0

func _process(_delta: float) -> void:
	if player_near and not is_transitioning:
		_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not player_near or is_transitioning:
		return
	if event.is_action_pressed("interact"):
		if require_all_enemies_dead and _has_living_enemies():
			_pulse_locked()
			return
		_start_transition()

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	player_near = true
	_update_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.name != "Player":
		return
	player_near = false
	prompt_label.hide()
	lock_label.hide()

func _update_prompt() -> void:
	var enemies_left := _get_living_enemy_count()
	if require_all_enemies_dead and enemies_left > 0:
		lock_label.text = "PURGE THE ROOM (%d)" % enemies_left
		prompt_label.hide()
		lock_label.show()
	else:
		lock_label.hide()
		prompt_label.show()

func _has_living_enemies() -> bool:
	return _get_living_enemy_count() > 0

func _get_living_enemy_count() -> int:
	var enemies_left := 0
	for body in enemy_detector.get_overlapping_bodies():
		if body.is_in_group("enemies") and not body.is_queued_for_deletion():
			enemies_left += 1
	return enemies_left

func _setup_idle_polish() -> void:
	_idle_tween = create_tween().set_loops()
	var tween := _idle_tween
	tween.set_parallel(true)
	tween.tween_property(portal_glow, "energy", _portal_glow_start_energy * 1.35, 0.85)
	tween.tween_property(marker, "scale", _marker_start_scale * 1.08, 0.85)
	tween.set_parallel(false)
	tween.tween_interval(0.05)
	tween.set_parallel(true)
	tween.tween_property(portal_glow, "energy", _portal_glow_start_energy * 0.85, 0.85)
	tween.tween_property(marker, "scale", _marker_start_scale, 0.85)

func _pulse_locked() -> void:
	lock_label.show()
	var tween := create_tween()
	tween.tween_property(lock_label, "scale", Vector2(1.08, 1.08), 0.08)
	tween.tween_property(lock_label, "scale", Vector2.ONE, 0.12)

func _start_transition() -> void:
	is_transitioning = true
	if _idle_tween:
		_idle_tween.kill()
	prompt_label.hide()
	lock_label.hide()
	canvas_layer.show()
	overlay.show()
	title_label.show()
	subtitle_label.show()

	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", _marker_start_scale * 1.55, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portal_glow, "energy", _portal_glow_start_energy * 3.2, 0.65)
	tween.tween_property(overlay, "modulate:a", 1.0, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.85).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "scale", Vector2(1.04, 1.04), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 1.05).set_trans(Tween.TRANS_SINE)
	tween.set_parallel(false)
	tween.tween_callback(_play_transition_sfx)
	tween.tween_interval(1.45)
	tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(title_label, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_go_next)

func _go_next() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(next_scene_path)

func _play_transition_sfx() -> void:
	if not transition_sfx:
		return
	transition_sfx_player.stream = transition_sfx
	transition_sfx_player.play()
