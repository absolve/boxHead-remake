extends Node2D

@onready var label=$Control/vbox/Label
@onready var btn=$Control/vbox/Button

var tween:Tween
var originalPos:Vector2
var duration=0.3 #频率
var offset=4  #偏移

func _ready():
	tween=create_tween()
	tween.set_loops()
	tween.tween_method(updatePos,null,null,duration)
	tween.stop()

	
func updatePos(_progress):
	var random_x = randf_range(-offset, offset)
	var random_y = randf_range(-offset, offset)	
	btn.position=originalPos + Vector2(random_x, random_y)

func _on_label_mouse_entered():
	
	pass # Replace with function body.


func _on_label_mouse_exited():
	
	pass # Replace with function body.


func _on_button_mouse_entered() -> void:
	if tween!=null:
		tween.stop()
	originalPos=btn.position	
	tween.bind_node(btn)
	tween.play()


func _on_button_mouse_exited() -> void:
	if tween!=null:
		tween.stop()
	btn.position=originalPos
