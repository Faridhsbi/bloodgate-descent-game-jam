extends Node2D

# Membuat menu dropdown di Inspector
@export_enum("tree", "tree2", "skull1", "skull2", "skull3") var jenis_dekorasi: String = "tree"

# Mengambil referensi ke child node AnimatedSprite2D Anda
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D 

func _ready() -> void:
	# Menyuruh child node memainkan animasi sesuai pilihan
	anim_sprite.play(jenis_dekorasi)
