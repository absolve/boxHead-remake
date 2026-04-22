extends Node2D

@onready var setting=$gameSetting
@onready var mapImg=$Control/mapImg
@onready var mapName=$Control/mapName
@onready var mapIndex=$Control/mapIndex

var img=[]
var index=0

func _ready() -> void:
	for i in Game.mapId:
		var temp=load(i.img)
		img.append({'id':i.id,'img':temp,'name':i.name})

	showMapInfo()

func showMapInfo():
	mapImg.texture=img[index].img
	mapName.text=str(img[index].name)
	mapIndex.text="%s/%s"%[index+1,img.size()]



func _on_map_img_mouse_entered() -> void:
	mapImg.modulate=Color("#e29999")
	


func _on_map_img_mouse_exited() -> void:
	mapImg.modulate=Color.WHITE


func _on_btn_prev_pressed() -> void:
	index=wrapi(index-1,0,img.size())
	showMapInfo()
	SoundUtil.playClick()
	
func _on_btn_next_pressed() -> void:
	index=wrapi(index+1,0,img.size())
	showMapInfo()
	SoundUtil.playClick()

func _on_btn_option_pressed() -> void:
	SoundUtil.playClick()
	setting.popup_centered()


func _on_btn_back_pressed() -> void:
	SoundUtil.playChange()
	get_tree().change_scene_to_file("res://scene/welcome.tscn")
