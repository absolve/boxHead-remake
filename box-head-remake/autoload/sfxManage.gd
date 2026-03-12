extends Node

var sfx=preload("res://scene/sfx.tscn")

var ex=preload("res://sound/548_548 Effect.Explosion.mp3")


func playExplosion():
	var temp =sfx.instantiate()
	temp.stream=ex
	temp.bus="sfx"
	add_child(temp)
