extends Node2D

@onready var click= $click
@onready var change=$change
@onready var startLevel=$startLevel

func playClick():
	click.play()

func playChange():
	change.play()

func playStartLevel():
	startLevel.play()
