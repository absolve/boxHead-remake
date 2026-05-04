extends Area2D

@export var type:Game.mapSign=Game.mapSign.Zombie
@export var dir:Game.mapSignDir=Game.mapSignDir.Down
@export var debug=false

@onready var ani=$ani

func _ready() -> void:
	if debug:
		ani.visible=true
		if type==Game.mapSign.Zombie:
			ani.play("0")
		elif type==Game.mapSign.Devil:	
			ani.play("1")
		elif type==Game.mapSign.Player:		
			ani.play("3")
		elif type==Game.mapSign.Item:	
			ani.play("2")		

func hasBlock():
	return has_overlapping_areas()||has_overlapping_bodies()
