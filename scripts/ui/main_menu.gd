extends Control

const SAVE_PATH := "user://savegame.save"

@onready var start_button: Button = $Center/Panel/Margin/List/StartButton
@onready var continue_button: Button = $Center/Panel/Margin/List/ContinueButton
@onready var settings_button: Button = $Center/Panel/Margin/List/SettingsButton
@onready var exit_button: Button = $Center/Panel/Margin/List/ExitButton
@onready var settings_menu: Control = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PixelMenuTheme.apply_buttons_recursive(self, 7)
	start_button.pressed.connect(MenuManager.start_new_game)
	continue_button.pressed.connect(MenuManager.continue_game)
	settings_button.pressed.connect(_open_settings)
	exit_button.pressed.connect(MenuManager.quit_to_desktop)

	if not FileAccess.file_exists(SAVE_PATH):
		continue_button.hide()

	if settings_menu:
		settings_menu.set("show_backdrop", false)
		settings_menu.closed.connect(_close_settings)
		settings_menu.hide()

	start_button.grab_focus()

func _open_settings() -> void:
	if settings_menu and settings_menu.visible:
		return
	if settings_menu:
		settings_menu.show()
		$Center.hide()

func _close_settings() -> void:
	if settings_menu:
		settings_menu.hide()
	$Center.show()
