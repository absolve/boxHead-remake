extends PopupPanel


@onready var btnLevel1=$VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel1
@onready var btnLevel2=$VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel2
@onready var btnLevel3=$VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel3
@onready var btnLevel4=$VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel4

@onready var btnCollisionOff=$VBoxContainer/VBoxContainer2/HBoxContainer/HBoxContainer/btnCollisionOff
@onready var btnCollisionOn=$VBoxContainer/VBoxContainer2/HBoxContainer/HBoxContainer/btnCollisionOn

@onready var btnDevilsOff=$VBoxContainer/VBoxContainer3/HBoxContainer/HBoxContainer/btnDevilsOff
@onready var btnDevilsOn=$VBoxContainer/VBoxContainer3/HBoxContainer/HBoxContainer/btnDevilsOn

@onready var btnFireOff=$VBoxContainer/VBoxContainer4/HBoxContainer/HBoxContainer/btnFireOff
@onready var btnFireOn=$VBoxContainer/VBoxContainer4/HBoxContainer/HBoxContainer/btnFireOn

@onready var btnSlow=$VBoxContainer/VBoxContainer5/HBoxContainer/HBoxContainer/btnSlow
@onready var btnNormal=$VBoxContainer/VBoxContainer5/HBoxContainer/HBoxContainer/btnNormal
@onready var btnFast=$VBoxContainer/VBoxContainer5/HBoxContainer/HBoxContainer/btnFast



func _ready() -> void:
	setConfig()
	
	
func setConfig():
	if MapData.mapConfig.collision:
		btnCollisionOn.button_pressed=true
	if MapData.mapConfig.Devils:
		btnDevilsOn.button_pressed=true
	if MapData.mapConfig.friendlyFire:
		btnFireOn.button_pressed=true


func _on_btn_close_pressed() -> void:
	SoundUtil.playClick()
	hide()


func _on_button_pressed() -> void:
	MapData.resetMapConfig()
	setConfig()
