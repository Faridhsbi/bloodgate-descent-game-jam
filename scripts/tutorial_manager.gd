extends Node

const TUTORIAL_OVERLAY_SCENE := preload("res://scenes/ui/TutorialOverlay.tscn")
const TUTORIALS := {
	"Tutorial1": "Use W, A, S, D to move.",
	"Tutorial2": "Aim with your Mouse and Left Click to shoot. Avoid enemies or you will lose HP.",
	"Tutorial3": "Press [SHIFT] to Dash. Dashing consumes Stamina.",
	"Tutorial4": "Drink a Power Flask to cast Hellfire. Ammo is limited!",
	"Tutorial5": "Shoot the red barrels to make them explode.",
	"Tutorial6": "Use barrel explosions to destroy cracked walls."
}

var _seen: Dictionary = {}
var _overlay: TutorialOverlay
var _showing := false

func _ready() -> void:
	_overlay = TUTORIAL_OVERLAY_SCENE.instantiate()
	add_child(_overlay)
	await get_tree().process_frame
	_connect_tutorial_areas()

func _connect_tutorial_areas() -> void:
	for area_name in TUTORIALS.keys():
		var area := find_child(area_name, true, false)
		if area is Area2D:
			area.body_entered.connect(_on_tutorial_body_entered.bind(area_name))

func _on_tutorial_body_entered(body: Node2D, area_name: String) -> void:
	if _showing or body.name != "Player" or _seen.has(area_name):
		return

	_seen[area_name] = true
	_showing = true
	get_tree().paused = true
	_overlay.show_tutorial(TUTORIALS[area_name])
	await _overlay.dismissed
	get_tree().paused = false
	_showing = false
