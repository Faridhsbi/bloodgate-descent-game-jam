extends Area2D
## Ramuan Stamina — mengembalikan stamina Player ke 100 saat diambil.

const SFX_STAMINA := preload("res://audio/48_Speed_up_02.wav")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("shimmer")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		# Jangan lakukan apa-apa jika stamina sudah penuh
		if body.current_stamina >= body.max_stamina:
			return
		
		if body.has_method("restore_stamina_full"):
			body.restore_stamina_full()
		else:
			body.current_stamina = body.max_stamina
			body.is_exhausted = false
			body.exhausted_timer = 0.0
			if body.ui:
				body.ui.update_stamina(body.current_stamina, true)
				body.ui.set_exhausted_effect(false)
		print("Stamina dipulihkan ke 100!")
		_play_sfx(SFX_STAMINA)
		queue_free()

func _play_sfx(stream: AudioStream) -> void:
	if not stream:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.bus = "SFX"
	sfx.max_distance = 240.0
	sfx.attenuation = 2.0
	var parent := get_tree().current_scene
	if parent:
		parent.add_child(sfx)
	else:
		add_child(sfx)
	sfx.global_position = global_position
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
