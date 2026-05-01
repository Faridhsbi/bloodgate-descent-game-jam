extends Control

@onready var fade: ColorRect = $Fade
@onready var panel: Control = $Center/Panel
@onready var title_label: Label = $Center/Panel/Margin/List/Title
@onready var subtitle_label: Label = $Center/Panel/Margin/List/Subtitle
@onready var win_bgm: AudioStreamPlayer = $WinBgm

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	PixelMenuTheme.apply_buttons_recursive(self, 7)
	win_bgm.play()
	panel.modulate.a = 0.0
	fade.color.a = 0.0
	title_label.modulate = Color(1.0, 0.92, 0.55, 1.0)
	subtitle_label.modulate = Color(0.86, 0.82, 0.72, 1.0)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.82, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

func _on_restart_pressed() -> void:
	MenuManager.restart_current_level()

func _on_main_menu_pressed() -> void:
	MenuManager.return_to_main_menu()

func _on_quit_pressed() -> void:
	MenuManager.quit_to_desktop()
