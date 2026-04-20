extends Control


@onready var img=$img
@onready var idNode=$id
@onready var nameNode=$name

@export var ids=1:
	set(v):
		ids=v
		#idNode.text=str(ids)
		
@export var charName=''


func _ready() -> void:
	print(ids)
	idNode.text=str(ids)
	
