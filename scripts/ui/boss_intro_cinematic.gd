extends Node2D

@export var player_path: NodePath = NodePath("../Player")
@export var boss_path: NodePath = NodePath("../VampireBoss")
@export var player_ui_path: NodePath = NodePath("../PlayerUi")
@export var boss_ui_path: NodePath = NodePath("../BossUI")

@onready var trigger: Area2D = $Trigger
@onready var cinematic_camera: Camera2D = $CinematicCamera
@onready var overlay: ColorRect = $CanvasLayer/Overlay
@onready var dialog_panel: Control = $CanvasLayer/DialogPanel
@onready var dialog_label: Label = $CanvasLayer/DialogPanel/Margin/DialogLabel
@onready var fight_label: Label = $CanvasLayer/FightLabel
@onready var domain_sfx: AudioStreamPlayer = $DomainSfx
@onready var fight_sfx: AudioStreamPlayer = $FightSfx

var has_played := false
var player: Node2D
var boss: Node2D
var player_ui: CanvasLayer
var boss_ui: CanvasLayer
var player_camera: Camera2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	trigger.body_entered.connect(_on_trigger_body_entered)
	overlay.modulate.a = 0.0
	dialog_panel.modulate.a = 0.0
	fight_label.modulate.a = 0.0
	boss_ui = get_node_or_null(boss_ui_path) as CanvasLayer
	if boss_ui:
		boss_ui.hide()

func _on_trigger_body_entered(body: Node2D) -> void:
	if has_played or body.name != "Player":
		return
	has_played = true
	_play_intro()

func _play_intro() -> void:
	player = get_node_or_null(player_path) as Node2D
	boss = get_node_or_null(boss_path) as Node2D
	player_ui = get_node_or_null(player_ui_path) as CanvasLayer
	boss_ui = get_node_or_null(boss_ui_path) as CanvasLayer
	if not player or not boss:
		return

	player_camera = player.get_node_or_null("Camera2D")
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	if player_ui:
		_fade_canvas(player_ui, 0.0, 0.25)
	if boss_ui:
		boss_ui.hide()

	cinematic_camera.global_position = player.global_position
	cinematic_camera.zoom = player_camera.zoom if player_camera else Vector2.ONE
	cinematic_camera.make_current()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay, "modulate:a", 0.42, 0.45)
	tween.parallel().tween_property(cinematic_camera, "global_position", boss.global_position + Vector2(0, -16), 1.25)
	tween.parallel().tween_property(cinematic_camera, "zoom", Vector2(1.75, 1.75), 1.25)
	tween.tween_callback(_boss_roar)
	tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.35)
	tween.tween_interval(2.3)
	tween.tween_property(dialog_panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(cinematic_camera, "global_position", player.global_position, 0.8)
	tween.parallel().tween_property(cinematic_camera, "zoom", Vector2.ONE, 0.8)
	tween.tween_callback(_show_fight)
	tween.tween_interval(0.55)
	tween.tween_callback(_finish_intro)

func _boss_roar() -> void:
	domain_sfx.play()
	if boss:
		boss.modulate = Color(1.35, 0.45, 0.45, 1.0)
	var shake := create_tween()
	for offset in [Vector2(4, 0), Vector2(-5, 2), Vector2(3, -3), Vector2.ZERO]:
		shake.tween_property(cinematic_camera, "offset", offset, 0.055)
	if boss:
		shake.parallel().tween_property(boss, "modulate", Color.WHITE, 0.35)

func _show_fight() -> void:
	if boss_ui:
		boss_ui.show()
	fight_sfx.play()
	fight_label.modulate.a = 1.0
	var slam := create_tween()
	slam.tween_property(fight_label, "scale", Vector2(1.2, 1.2), 0.08)
	slam.tween_property(fight_label, "scale", Vector2.ONE, 0.12)
	slam.tween_property(fight_label, "modulate:a", 0.0, 0.35)

func _finish_intro() -> void:
	if player_camera:
		player_camera.make_current()
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	if player_ui:
		_fade_canvas(player_ui, 1.0, 0.25)
	if boss and boss.has_method("start_encounter"):
		boss.start_encounter(player)
	create_tween().tween_property(overlay, "modulate:a", 0.0, 0.35)

func _fade_canvas(canvas: CanvasLayer, alpha: float, duration: float) -> void:
	if alpha <= 0.0:
		canvas.hide()
	else:
		canvas.show()
