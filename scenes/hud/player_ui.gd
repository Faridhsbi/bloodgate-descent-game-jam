extends CanvasLayer
class_name PlayerUI

@onready var health_bar: TextureProgressBar = $Control/HealthBar
@onready var stamina_bar: TextureProgressBar = $Control/StaminaBar
@onready var dash_bar: TextureProgressBar = $Control/DashBar
@onready var exhausted_overlay: ColorRect = $ExhaustedOverlay
@onready var weapon_icon: TextureRect = $Control/WeaponDisplay/WeaponIcon
@onready var weapon_name_label: Label = $Control/WeaponDisplay/WeaponFrame/TitleLabel
@onready var ammo_label: Label = $Control/WeaponDisplay/AmmoLabel
@onready var infinity_icon_node: TextureRect = $Control/WeaponDisplay/InfinityIcon
@onready var key_inventory: Control = $Control/KeyInventory
@onready var key_glow: ColorRect = $Control/KeyInventory/KeyGlow
@onready var key_icon: TextureRect = $Control/KeyInventory/KeyFrame/KeyIcon
var _health_tween: Tween
var _stamina_tween: Tween
var _key_tween: Tween
var _exhausted_tween: Tween 
var _exhausted_label: Label

@export var icon_default: Texture2D
@export var icon_default_scale: Vector2 = Vector2(0.5, 0.5)
@export var icon_fireball_scale: Vector2 = Vector2.ONE
var icon_fireball = preload("res://assets/2D Pixel Dungeon Asset Pack v2.0/2D Pixel Dungeon Asset Pack/items and trap_animation/flamethrower/flamethrower_2_2.png")

func _ready() -> void:
	set_has_dungeon_key(false, true)
	_create_exhausted_label()

# Tambahkan max_dash_cd di parameter
func initialize_player(max_hp: float, max_stamina: float, max_dash_cd: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = max_hp
	
	stamina_bar.max_value = max_stamina
	stamina_bar.value = max_stamina
	
	# Setup Dash Bar
	dash_bar.max_value = max_dash_cd
	dash_bar.value = max_dash_cd # Bar penuh = Dash siap digunakan

func update_health(new_hp: float) -> void:
	if _health_tween and _health_tween.is_running():
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(health_bar, "value", new_hp, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func update_stamina(new_stamina: float, is_instant: bool = false) -> void:
	if _stamina_tween and _stamina_tween.is_running():
		_stamina_tween.kill()
	if is_instant:
		stamina_bar.value = new_stamina
	else:
		_stamina_tween = create_tween()
		_stamina_tween.tween_property(stamina_bar, "value", new_stamina, 0.1)

# Fungsi khusus untuk Dash Bar (Tanpa Tween karena kita kirim delta setiap frame)
func update_dash_cooldown(current_cd: float, max_cd: float) -> void:
	# Bar akan kosong saat cooldown dimulai, lalu terisi seiring waktu
	dash_bar.value = max_cd - current_cd
	
func set_exhausted_effect(is_exhausted: bool) -> void:
	# Matikan tween lama jika ada agar tidak bentrok
	if _exhausted_tween and _exhausted_tween.is_running():
		_exhausted_tween.kill()
		
	if is_exhausted:
		_exhausted_label.show()
		_exhausted_label.modulate = Color(1, 0.82, 0.34, 0.0)
		stamina_bar.modulate = Color(1.45, 0.45, 0.35, 1.0)
		dash_bar.modulate = Color(0.85, 0.38, 0.32, 1.0)
		# Buat animasi berulang (looping)
		_exhausted_tween = create_tween().set_loops()
		
		# Animasi Kedut: Merah muncul (0.3 opacity) selama 0.4 detik, lalu memudar (0.0 opacity) selama 0.4 detik
		_exhausted_tween.tween_property(exhausted_overlay, "modulate:a", 0.38, 0.32).set_trans(Tween.TRANS_SINE)
		_exhausted_tween.parallel().tween_property(_exhausted_label, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)
		_exhausted_tween.tween_property(exhausted_overlay, "modulate:a", 0.06, 0.38).set_trans(Tween.TRANS_SINE)
		_exhausted_tween.parallel().tween_property(_exhausted_label, "modulate:a", 0.35, 0.38).set_trans(Tween.TRANS_SINE)
	else:
		# Jika sudah tidak exhausted, pastikan layar kembali bening secara perlahan
		_exhausted_tween = create_tween()
		_exhausted_tween.tween_property(exhausted_overlay, "modulate:a", 0.0, 0.3)
		_exhausted_tween.parallel().tween_property(_exhausted_label, "modulate:a", 0.0, 0.25)
		_exhausted_tween.parallel().tween_property(stamina_bar, "modulate", Color.WHITE, 0.25)
		_exhausted_tween.parallel().tween_property(dash_bar, "modulate", Color.WHITE, 0.25)
		_exhausted_tween.tween_callback(_exhausted_label.hide)
		
func update_weapon_display(ammo: int) -> void:
	if ammo > 0:
		# Mode Hellfire Orb
		weapon_icon.texture = icon_fireball
		weapon_icon.scale = icon_fireball_scale
		weapon_name_label.text = "HELLFIRE  ORB"
		
		# Tampilkan angka peluru, sembunyikan ikon infinity
		ammo_label.text = str(ammo)
		ammo_label.show()
		infinity_icon_node.hide()
	else:
		# Mode Default
		weapon_icon.texture = icon_default
		weapon_icon.scale = icon_default_scale
		weapon_name_label.text = "SOUL DART"
		
		# Sembunyikan angka peluru, tampilkan ikon infinity
		ammo_label.hide()
		infinity_icon_node.show()

func set_has_dungeon_key(has_key: bool, instant: bool = false) -> void:
	if _key_tween and _key_tween.is_running():
		_key_tween.kill()

	if has_key:
		key_inventory.show()
		key_inventory.pivot_offset = Vector2(54, 24)
		if instant:
			key_inventory.modulate.a = 1.0
			key_inventory.scale = Vector2.ONE
			key_glow.modulate.a = 0.22
			return

		key_inventory.modulate.a = 0.0
		key_inventory.scale = Vector2(0.82, 0.82)
		key_glow.modulate.a = 0.0
		_key_tween = create_tween()
		_key_tween.set_parallel(true)
		_key_tween.tween_property(key_inventory, "modulate:a", 1.0, 0.22)
		_key_tween.tween_property(key_inventory, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_key_tween.tween_property(key_glow, "modulate:a", 0.22, 0.3)
		_key_tween.tween_property(key_icon, "scale", Vector2(1.16, 1.16), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_key_tween.set_parallel(false)
		_key_tween.tween_property(key_icon, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		key_inventory.hide()
		key_inventory.modulate.a = 0.0
		key_inventory.scale = Vector2.ONE

func _create_exhausted_label() -> void:
	_exhausted_label = Label.new()
	_exhausted_label.text = "EXHAUSTED"
	_exhausted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exhausted_label.anchor_left = 0.5
	_exhausted_label.anchor_right = 0.5
	_exhausted_label.offset_left = -70
	_exhausted_label.offset_right = 70
	_exhausted_label.offset_top = 50
	_exhausted_label.offset_bottom = 70
	_exhausted_label.add_theme_font_override("font", load("res://font/Pixeled.ttf"))
	_exhausted_label.add_theme_font_size_override("font_size", 8)
	_exhausted_label.add_theme_color_override("font_color", Color(1, 0.82, 0.34))
	_exhausted_label.add_theme_constant_override("outline_size", 3)
	_exhausted_label.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.02))
	_exhausted_label.modulate.a = 0.0
	_exhausted_label.hide()
	add_child(_exhausted_label)
	
