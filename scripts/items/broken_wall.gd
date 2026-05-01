extends StaticBody2D

@export var max_hp: float = 30.0
var current_hp: float

@onready var sprite = $Sprite2D

func _ready():
	current_hp = max_hp

func take_damage(amount: float):
	current_hp -= amount
	print("Tembok retak tertembak! Sisa HP: ", current_hp)
	
	if current_hp <= 0:
		die()

func die():
	print("Tembok Hancur!")
	
	# Hancurkan tembok dari arena
	queue_free()
