extends Node2D
class_name WorldHealthBar

@export var hide_when_empty: bool = true
@export var hide_when_full: bool = true  # [BARU] Centang untuk menyembunyikan saat darah 100%
@export var smooth_speed: float = 10.0

var max_health: float = 1.0
var target_value: float = 1.0
var displayed_value: float = 1.0

@onready var progress: TextureProgressBar = $Progress

func _ready() -> void:
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = 100.0

func _process(delta: float) -> void:
	displayed_value = lerpf(displayed_value, target_value, minf(delta * smooth_speed, 1.0))
	progress.value = displayed_value * 100.0
	
	# --- [PERBAIKAN LOGIKA VISIBILITY] ---
	var should_be_visible: bool = true
	
	if hide_when_empty and target_value <= 0.0:
		should_be_visible = false
		
	if hide_when_full and target_value >= 1.0:
		should_be_visible = false
		
	visible = should_be_visible
	# -------------------------------------

func setup(new_max_health: float, current_health: float = -1.0) -> void:
	max_health = maxf(new_max_health, 1.0)
	if current_health < 0.0:
		current_health = max_health
	set_health(current_health, max_health, true)

func set_health(current_health: float, new_max_health: float = -1.0, snap: bool = false) -> void:
	if new_max_health > 0.0:
		max_health = maxf(new_max_health, 1.0)
	target_value = clampf(current_health / max_health, 0.0, 1.0)
	if snap:
		displayed_value = target_value
		progress.value = displayed_value * 100.0
