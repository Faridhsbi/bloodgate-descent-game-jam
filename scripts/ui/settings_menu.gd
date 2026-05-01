extends Control

signal closed

@export var show_backdrop := true

@onready var backdrop: ColorRect = $Backdrop
@onready var back_button: Button = $Center/Panel/Margin/List/BackButton
@onready var tabs: TabContainer = $Center/Panel/Margin/List/Tabs
@onready var master_slider: HSlider = $Center/Panel/Margin/List/Tabs/Audio/MasterRow/MasterSlider
@onready var bgm_slider: HSlider = $Center/Panel/Margin/List/Tabs/Audio/BGMRow/BGMSlider
@onready var sfx_slider: HSlider = $Center/Panel/Margin/List/Tabs/Audio/SFXRow/SFXSlider
@onready var brightness_slider: HSlider = $Center/Panel/Margin/List/Tabs/Video/BrightnessRow/BrightnessSlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MenuManager.ensure_audio_buses()
	backdrop.visible = show_backdrop
	PixelMenuTheme.apply_buttons_recursive(self, 7)
	_style_tabs()

	master_slider.value = _bus_volume_percent("Master")
	bgm_slider.value = _bus_volume_percent("BGM")
	sfx_slider.value = _bus_volume_percent("SFX")

	master_slider.value_changed.connect(func(value: float): _set_bus_volume("Master", value))
	bgm_slider.value_changed.connect(func(value: float): _set_bus_volume("BGM", value))
	sfx_slider.value_changed.connect(func(value: float): _set_bus_volume("SFX", value))

	brightness_slider.value = MenuManager.get_brightness()
	brightness_slider.value_changed.connect(MenuManager.set_brightness)

	back_button.pressed.connect(func(): closed.emit())
	back_button.grab_focus()

func _style_tabs() -> void:
	var tab_bar := tabs.get_tab_bar()
	tab_bar.tab_alignment = 1
	tab_bar.add_theme_font_override("font", PixelMenuTheme.font())
	tab_bar.add_theme_font_size_override("font_size", 5)
	tab_bar.add_theme_color_override("font_selected_color", Color(0.31764707, 0.9882353, 0.49411765))
	tab_bar.add_theme_color_override("font_unselected_color", Color(0.31764707, 0.9882353, 0.49411765))
	tab_bar.add_theme_color_override("font_hovered_color", Color(0.83137256, 0.99607843, 0.47058824))
	tab_bar.add_theme_constant_override("h_separation", 8)

func _bus_volume_percent(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return 100.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(value / 100.0, 0.001)))
