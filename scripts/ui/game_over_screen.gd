extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var fade: ColorRect = $Fade
	var center: Control = $Center
	var title: Label = $Center/Panel/Margin/List/Title
	var subtitle: Label = $Center/Panel/Margin/List/Subtitle
	var restart_button: Button = $Center/Panel/Margin/List/ButtonList/RestartButton
	var main_menu_button: Button = $Center/Panel/Margin/List/ButtonList/MainMenuButton

	PixelMenuTheme.apply_buttons_recursive(self, 7)
	if _is_boss_arena_game_over():
		title.text = "DEVOURED"
		var title_settings := title.label_settings.duplicate() as LabelSettings
		title_settings.font_size = 20
		title_settings.font_color = Color(0.938, 0.001, 0.0, 1.0)
		title.label_settings = title_settings
		subtitle.text = "Your flesh becomes a feast for the darkness."
		var subtitle_settings := subtitle.label_settings.duplicate() as LabelSettings
		subtitle_settings.font_color = Color(0.76, 0.74, 0.7)
		subtitle.label_settings = subtitle_settings
		subtitle.show()
		$BossDevouredSfx.play()
	else:
		subtitle.hide()
	$GameOverSfx.play()
	restart_button.pressed.connect(MenuManager.restart_current_level)
	main_menu_button.pressed.connect(MenuManager.return_to_main_menu)

	center.modulate.a = 0.0
	fade.color.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(fade, "color:a", 0.8 if _is_boss_arena_game_over() else 0.86, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var center_tween := create_tween()
	center_tween.tween_interval(0.5)
	center_tween.tween_property(center, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _is_boss_arena_game_over() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://scenes/BossArena.tscn"
