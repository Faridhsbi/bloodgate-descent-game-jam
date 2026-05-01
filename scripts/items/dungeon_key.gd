extends Area2D
## Kunci Dungeon — muncul dari Chest, diambil Player untuk membuka pintu keluar.

const SFX_KEY := preload("res://audio/keys_jingling.wav")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("spin")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		# Tandai bahwa player telah memiliki kunci
		if body.has_method("pickup_key"):
			body.pickup_key()
		else:
			# Fallback: set variabel langsung
			body.set("has_key", true)
		_play_sfx(SFX_KEY)
		print("Kunci berhasil diambil!")
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
