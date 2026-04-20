extends Node2D

@onready var setting=$gameSetting
@onready var mapImg=$Control/mapImg
@onready var mapName=$Control/mapName
@onready var mapBorderImg=$Control/mapBorderImg

var img=[]
var index=0

func _ready() -> void:
	for i in Game.mapId:
		var temp=load(i.img)
		img.append({'id':i.id,'img':temp,'name':i.name})

	mapImg.texture=img[0].img
	mapName.text=str(img[0].name)

func _on_map_img_mouse_entered() -> void:
	mapImg.modulate=Color("#e6000050")
	mapBorderImg.modulate=Color("#e6000050")


func _on_map_img_mouse_exited() -> void:
	mapImg.modulate=Color.WHITE
	mapBorderImg.modulate=Color.WHITE

func _on_btn_prev_pressed() -> void:
	if index-1>=0:
		index-=1
		mapImg.texture=img[index].img
		mapName.text=str(img[0].name)


func _on_btn_next_pressed() -> void:
	if index+1<=img.size()-1:
		index+=1
		mapImg.texture=img[index].img
		mapName.text=str(img[0].name)


func _on_btn_option_pressed() -> void:
	setting.popup_centered()
