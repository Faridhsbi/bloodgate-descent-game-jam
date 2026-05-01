extends Area2D
## Health Flask — memulihkan 30 HP Player saat diambil.

const SFX_HEAL := preload("res://audio/02_Heal_02.wav")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("shimmer")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		
		# Cek apakah objek yang menyentuh punya fungsi 'heal'
		if body.has_method("heal"):
			
			# Jangan dimakan kalau darah sudah penuh (biarkan botolnya di lantai)
			if body.current_hp >= body.max_hp:
				return
				
			# Suruh player menyembuhkan dirinya sendiri!
			body.heal(30)
			_play_sfx(SFX_HEAL)
			
			# Botolnya hilang setelah diminum
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
