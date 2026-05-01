extends Control

signal closed

@onready var resume_button: Button = $Center/Panel/Margin/List/ResumeButton
@onready var settings_button: Button = $Center/Panel/Margin/List/SettingsButton
@onready var main_menu_button: Button = $Center/Panel/Margin/List/MainMenuButton
@onready var quit_button: Button = $Center/Panel/Margin/List/QuitButton
@onready var confirm_panel: Control = $ConfirmPanel
@onready var confirm_yes: Button = $ConfirmPanel/ConfirmCenter/ConfirmFrame/ConfirmMargin/ConfirmList/ConfirmRow/ConfirmYes
@onready var confirm_no: Button = $ConfirmPanel/ConfirmCenter/ConfirmFrame/ConfirmMargin/ConfirmList/ConfirmRow/ConfirmNo
@onready var settings_menu: Control = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	PixelMenuTheme.apply_buttons_recursive(self, 7)
	resume_button.pressed.connect(func(): closed.emit())
	settings_button.pressed.connect(_open_settings)
	main_menu_button.pressed.connect(_show_confirm)
	quit_button.pressed.connect(MenuManager.quit_to_desktop)
	confirm_yes.pressed.connect(MenuManager.return_to_main_menu)
	confirm_no.pressed.connect(_hide_confirm)

	confirm_panel.hide()
	if settings_menu:
		settings_menu.closed.connect(_close_settings)
		settings_menu.hide()

	resume_button.grab_focus()

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

func _show_confirm() -> void:
	confirm_panel.show()
	confirm_yes.grab_focus()

func _hide_confirm() -> void:
	confirm_panel.hide()
	main_menu_button.grab_focus()
