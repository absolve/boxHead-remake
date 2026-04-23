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
	match  MapData.mapConfig.difficulty:
		1:
			btnLevel1.button_pressed=true
		2:
			btnLevel2.button_pressed=true
		3:
			btnLevel3.button_pressed=true
		4:
			btnLevel4.button_pressed=true
		_:
			btnLevel1.button_pressed=true
	match MapData.mapConfig.gameSpeed:
		1:
			btnSlow.button_pressed=true
		2:
			btnNormal.button_pressed=true
		3:
			btnFast.button_pressed=true
			
func _on_btn_close_pressed() -> void:
	SoundUtil.playClick()
	hide()


func _on_button_pressed() -> void:
	MapData.resetMapConfig()
	setConfig()


func _on_btn_collision_off_pressed():
	MapData.mapConfig.collision=false


func _on_btn_collision_on_pressed():
	MapData.mapConfig.collision=true


func _on_btn_devils_off_pressed():
	MapData.mapConfig.Devils=false


func _on_btn_devils_on_pressed():
	MapData.mapConfig.Devils=true


func _on_btn_fire_off_pressed():
	MapData.mapConfig.friendlyFire=false


func _on_btn_fire_on_pressed():
	MapData.mapConfig.friendlyFire=true


func _on_btn_slow_pressed():
	MapData.mapConfig.gameSpeed=1


func _on_btn_normal_pressed():
	MapData.mapConfig.gameSpeed=2


func _on_btn_fast_pressed():
	MapData.mapConfig.gameSpeed=3


func _on_btn_level_1_pressed():
	MapData.mapConfig.difficulty=1


func _on_btn_level_2_pressed():
	MapData.mapConfig.difficulty=2


func _on_btn_level_3_pressed():
	MapData.mapConfig.difficulty=3


func _on_btn_level_4_pressed():
	MapData.mapConfig.difficulty=4
