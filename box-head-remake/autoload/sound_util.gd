extends Node2D

@onready var click= $click
@onready var change=$change

func playClick():
	click.play()

func playChange():
	change.play()
