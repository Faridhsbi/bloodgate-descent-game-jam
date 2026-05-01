extends RefCounted
class_name PixelMenuTheme

const FONT_PATH := "res://font/Pixeled.ttf"
const GUI_PATH := "res://assets/Cryo's Mini GUI/GUI/GUI_1x.png"
const MENU_BUTTON_PATH := "res://assets/MenuButton.png"
const FRAME_REGION := Rect2(128, 32, 16, 15.795)
const BUTTON_REGION := Rect2(690, 454, 1014, 410)

static func font() -> FontFile:
	return load(FONT_PATH)

static func gui_texture() -> Texture2D:
	return load(GUI_PATH)

static func menu_button_texture() -> Texture2D:
	return load(MENU_BUTTON_PATH)

static func atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = gui_texture()
	texture.region = region
	return texture

static func frame(min_size: Vector2 = Vector2(230, 160)) -> NinePatchRect:
	var rect := NinePatchRect.new()
	rect.texture = gui_texture()
	rect.region_rect = FRAME_REGION
	rect.patch_margin_left = 5
	rect.patch_margin_top = 5
	rect.patch_margin_right = 5
	rect.patch_margin_bottom = 5
	rect.custom_minimum_size = min_size
	return rect

static func button_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = menu_button_texture()
	style.region_rect = BUTTON_REGION
	style.texture_margin_left = 10
	style.texture_margin_top = 10
	style.texture_margin_right = 10
	style.texture_margin_bottom = 10
	return style

static func apply_text(control: Control, size: int = 8) -> void:
	control.add_theme_font_override("font", font())
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", Color(0.31764707, 0.9882353, 0.49411765))
	control.add_theme_color_override("font_focus_color", Color(0.31764707, 0.9882353, 0.49411765))
	control.add_theme_color_override("font_hover_color", Color(0.83137256, 0.99607843, 0.47058824))
	control.add_theme_color_override("font_pressed_color", Color(0.22, 0.78, 0.36))
	control.add_theme_color_override("font_disabled_color", Color(0.38, 0.34, 0.31))
	control.add_theme_constant_override("outline_size", 2)
	control.add_theme_color_override("font_outline_color", Color.BLACK)

static func apply_button(button: Button, size: int = 7) -> void:
	button.add_theme_stylebox_override("normal", button_style())
	button.add_theme_stylebox_override("hover", button_style())
	button.add_theme_stylebox_override("pressed", button_style())
	button.add_theme_stylebox_override("focus", button_style())
	button.add_theme_stylebox_override("disabled", button_style())
	apply_text(button, size)

static func apply_buttons_recursive(root: Node, size: int = 7) -> void:
	if root is Button:
		apply_button(root, size)
	for child in root.get_children():
		apply_buttons_recursive(child, size)

static func title(text: String, size: int = 13) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_text(label, size)
	return label

static func label(text: String, size: int = 7) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_text(item, size)
	return item

static func button(text: String) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(150, 26)
	item.focus_mode = Control.FOCUS_ALL
	apply_button(item, 7)
	return item

static func option_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 25)
	row.add_theme_constant_override("separation", 8)
	var text_label := label(text, 6)
	text_label.custom_minimum_size = Vector2(82, 0)
	row.add_child(text_label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

static func add_dark_background(root: Control, alpha: float = 0.78) -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.018, 0.025, alpha)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	return bg
