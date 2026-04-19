extends Node2D

@onready var setting=$gameSetting
@onready var mapImg=$Control/mapImg


func _ready() -> void:
	pass
	


func _on_map_img_mouse_entered() -> void:
	mapImg.modulate=Color("#e6000020")
	


func _on_map_img_mouse_exited() -> void:
	mapImg.modulate=Color.WHITE


func _on_btn_prev_pressed() -> void:
	pass # Replace with function body.


func _on_btn_next_pressed() -> void:
	pass # Replace with function body.


func _on_btn_option_pressed() -> void:
	setting.popup_centered()
