extends Area2D
## Power Flask memberikan senjata Hellfire Orb dengan 5 ammo ke Player.

const SFX_POWER := preload("res://audio/16_Atk_buff_04.wav")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("shimmer")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		# Cek dengan aman apakah player punya sistem penambah ammo fireball
		if body.has_method("add_fireball_ammo"):
			
			# Suruh player menambahkan 5 ammo ke dirinya sendiri
			body.add_fireball_ammo(5)
			_play_sfx(SFX_POWER)
			
			# Setelah diambil, botolnya hilang
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
