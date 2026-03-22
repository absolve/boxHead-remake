extends Area2D

@export var type:Game.itemType=Game.itemType.Box
@export var itemSize:Vector2=Vector2(15,15) #物体的大小
@onready var ani=$ani

var content:Game.boxContent=Game.boxContent.UZI
