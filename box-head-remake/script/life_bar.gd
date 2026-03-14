extends Control

@onready var bar=$TextureProgressBar

var tween=null
var alwaysShows=false

@export var hp=10:
	set(val):
		hp=val
		bar.value=val

@export var maxHp=10:
	set(val):
		maxHp=val
		bar.max_value=val
