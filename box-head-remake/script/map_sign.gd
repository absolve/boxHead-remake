extends Area2D

@export var type: Game.mapSign = Game.mapSign.Zombie
@export var dir: Game.mapSignDir = Game.mapSignDir.Down
@export var debug = false

@onready var ani = $ani

func _ready() -> void:
	if debug:
		ani.visible = true
		if type == Game.mapSign.Zombie:
			ani.play("0")
		elif type == Game.mapSign.Devil:
			ani.play("1")
		elif type == Game.mapSign.Player:
			ani.play("3")
		elif type == Game.mapSign.Box:
			ani.play("2")
			
	if type == Game.mapSign.Box:
		collision_mask = 64
	elif type in [Game.mapSign.Zombie, Game.mapSign.Devil]:
		collision_mask = 2


func hasBlock():
	return has_overlapping_areas() || has_overlapping_bodies()
