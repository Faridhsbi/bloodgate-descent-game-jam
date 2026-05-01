extends Node2D
## Bendera dekoratif — hanya animasi berkibar, tanpa interaksi.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("wave")
