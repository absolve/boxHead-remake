extends "res://script/item.gd"



@onready var sound=$sound
@export var damage=0 #伤害

var playerId=1
var splitNum=0  #分裂成小爆炸
var splitRadius=80 #分裂半径
