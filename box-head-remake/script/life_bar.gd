extends Control

@onready var bar=$TextureProgressBar


@export var hp=10:
	set(val):
		hp=val
		bar.value=val
