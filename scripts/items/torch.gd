extends Node2D
## Obor / Lilin dekoratif — hanya animasi berputar, tanpa interaksi.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("flicker")
