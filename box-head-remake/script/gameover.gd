extends Node2D

@onready var sound=$sound

func _ready():
	sound.play()
	pass


func _on_ui_label_3_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MouseButton.MOUSE_BUTTON_LEFT&&event.is_pressed():
			get_tree().change_scene_to_file("res://scene/welcome.tscn")
