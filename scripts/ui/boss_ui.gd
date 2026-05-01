extends CanvasLayer
class_name BossUI

var boss: Node
var health_value := 1.0
var displayed_value := 1.0
var death_fade_started := false
var phase2_started := false

@onready var root: Control = $Root
@onready var health_fill: TextureProgressBar = $Root/Holder/BarFrame/HealthFill
@onready var phase2_flash: ColorRect = $Root/Phase2Flash
@onready var phase2_label: Label = $Root/Phase2Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	call_deferred("_bind_boss")

func _process(delta: float) -> void:
	if not is_instance_valid(boss):
		_bind_boss()
		return
	displayed_value = lerpf(displayed_value, health_value, minf(delta * 8.0, 1.0))
	health_fill.value = displayed_value * 100.0

func bind_to_boss(target: Node) -> void:
	boss = target
	if boss and boss.get("max_hp") != null and boss.get("hp") != null:
		update_health(float(boss.get("hp")), float(boss.get("max_hp")))

func update_health(current_hp: float, max_hp: float) -> void:
	health_value = clampf(current_hp / max_hp, 0.0, 1.0)
	if current_hp <= 0.0 and not death_fade_started and is_inside_tree():
		death_fade_started = true
		var tween := create_tween()
		tween.tween_interval(0.35)
		tween.tween_property(root, "modulate:a", 0.0, 0.45)

func show_phase2_effect() -> void:
	if phase2_started or not is_inside_tree():
		return
	phase2_started = true
	phase2_flash.modulate.a = 0.0
	phase2_label.modulate.a = 0.0
	phase2_label.show()
	var tween := create_tween()
	tween.tween_property(phase2_flash, "modulate:a", 0.45, 0.15)
	tween.parallel().tween_property(phase2_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(health_fill, "modulate", Color(1.65, 0.2, 0.2), 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(phase2_flash, "modulate:a", 0.0, 0.65)
	tween.parallel().tween_property(phase2_label, "modulate:a", 0.0, 0.65)
	tween.parallel().tween_property(health_fill, "modulate", Color.WHITE, 0.65)
	tween.tween_callback(phase2_label.hide)

func _bind_boss() -> void:
	var found := get_tree().get_first_node_in_group("boss")
	if found:
		bind_to_boss(found)
