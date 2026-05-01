extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const GAMEPLAY_SCENE := "res://scenes/level 1.tscn"
const LEVEL_2_SCENE := "res://scenes/level 2.tscn"
const BOSS_ARENA_SCENE := "res://scenes/BossArena.tscn"
const PAUSE_MENU_SCENE := preload("res://scenes/ui/PauseMenu.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/GameOverScreen.tscn")
const WIN_SCREEN_SCENE := preload("res://scenes/ui/WinScreen.tscn")
const SAVE_PATH := "user://savegame.save"

var pause_menu: Control
var game_over_screen: Control
var win_screen: Control
@onready var brightness_overlay: ColorRect = $BrightnessOverlay
var brightness_value := 50.0

func _ready() -> void:
	_ensure_input_actions()
	_ensure_audio_buses()
	set_brightness(brightness_value)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _is_gameplay_scene() and not game_over_screen and not win_screen:
		if pause_menu:
			hide_pause_menu()
		else:
			show_pause_menu()
		get_viewport().set_input_as_handled()

func start_new_game() -> void:
	_clear_menus()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)

func continue_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		start_new_game()

func show_pause_menu() -> void:
	if pause_menu or not _is_gameplay_scene():
		return
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.closed.connect(hide_pause_menu)
	add_child(pause_menu)
	get_tree().paused = true

func hide_pause_menu() -> void:
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	get_tree().paused = false

func show_game_over() -> void:
	if game_over_screen or win_screen:
		return
	get_tree().call_group("scene_music", "stop")
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	game_over_screen = GAME_OVER_SCENE.instantiate()
	game_over_screen.tree_exited.connect(func(): game_over_screen = null)
	add_child(game_over_screen)
	get_tree().paused = true

func show_game_over_after_delay(delay: float = 1.6) -> void:
	await get_tree().create_timer(delay).timeout
	show_game_over()

func show_win_screen() -> void:
	if win_screen or game_over_screen:
		return
	get_tree().call_group("scene_music", "stop")
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	win_screen = WIN_SCREEN_SCENE.instantiate()
	win_screen.tree_exited.connect(func(): win_screen = null)
	add_child(win_screen)
	get_tree().paused = true

func show_win_screen_after_delay(delay: float = 0.8) -> void:
	await get_tree().create_timer(delay).timeout
	show_win_screen()

func restart_current_level() -> void:
	if game_over_screen:
		game_over_screen.queue_free()
		game_over_screen = null
	if win_screen:
		win_screen.queue_free()
		win_screen = null
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_main_menu() -> void:
	_clear_menus()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func quit_to_desktop() -> void:
	get_tree().quit()

func set_brightness(value: float) -> void:
	brightness_value = clampf(value, 0.0, 100.0)
	if not brightness_overlay:
		return
	if brightness_value < 50.0:
		brightness_overlay.color = Color(0, 0, 0, (50.0 - brightness_value) / 70.0)
	else:
		brightness_overlay.color = Color(1, 1, 1, (brightness_value - 50.0) / 130.0)

func get_brightness() -> float:
	return brightness_value

func ensure_audio_buses() -> void:
	_ensure_audio_buses()

func _clear_menus() -> void:
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	if game_over_screen:
		game_over_screen.queue_free()
		game_over_screen = null
	if win_screen:
		win_screen.queue_free()
		win_screen = null

func _is_gameplay_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path in [GAMEPLAY_SCENE, LEVEL_2_SCENE, BOSS_ARENA_SCENE]

func _ensure_audio_buses() -> void:
	for bus_name in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)

func _ensure_input_actions() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var pause_event := InputEventKey.new()
		pause_event.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", pause_event)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var interact_event := InputEventKey.new()
		interact_event.physical_keycode = KEY_E
		InputMap.action_add_event("interact", interact_event)
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		for key in [KEY_SHIFT, KEY_SPACE]:
			var dash_event := InputEventKey.new()
			dash_event.keycode = key
			InputMap.action_add_event("dash", dash_event)
