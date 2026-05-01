extends CanvasLayer
class_name TutorialOverlay

signal dismissed

@onready var panel: NinePatchRect = $Panel
@onready var tutorial_label: Label = $Panel/Margin/List/TutorialText
@onready var click_label: Label = $Panel/Margin/List/ClickLabel

var _can_dismiss := false
var _type_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.modulate.a = 0.0
	click_label.modulate.a = 0.0
	hide()

func show_tutorial(text: String) -> void:
	if _type_tween and _type_tween.is_running():
		_type_tween.kill()

	show()
	_can_dismiss = false
	tutorial_label.text = text
	tutorial_label.visible_characters = 0
	click_label.modulate.a = 0.0

	_type_tween = create_tween()
	_type_tween.tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_type_tween.tween_property(tutorial_label, "visible_characters", text.length(), maxf(text.length() * 0.025, 0.35))
	_type_tween.tween_property(click_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	_type_tween.tween_callback(func(): _can_dismiss = true)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _can_dismiss:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_dismiss()

func _dismiss() -> void:
	_can_dismiss = false
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(hide)
	tween.tween_callback(dismissed.emit)
