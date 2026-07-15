extends PopupPanel

## 游戏设置弹窗脚本
# 实现游戏配置的UI界面，支持调整难度、碰撞、敌人类型等设置


## 难度按钮节点
@onready var btnLevel1 = $VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel1
@onready var btnLevel2 = $VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel2
@onready var btnLevel3 = $VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel3
@onready var btnLevel4 = $VBoxContainer/VBoxContainer/HBoxContainer/HBoxContainer/btnLevel4

## 碰撞开关按钮节点
@onready var btnCollisionOff = $VBoxContainer/VBoxContainer2/HBoxContainer/HBoxContainer/btnCollisionOff
@onready var btnCollisionOn = $VBoxContainer/VBoxContainer2/HBoxContainer/HBoxContainer/btnCollisionOn

## 恶魔开关按钮节点
@onready var btnDevilsOff = $VBoxContainer/VBoxContainer3/HBoxContainer/HBoxContainer/btnDevilsOff
@onready var btnDevilsOn = $VBoxContainer/VBoxContainer3/HBoxContainer/HBoxContainer/btnDevilsOn

## 友军伤害开关按钮节点
@onready var btnFireOff = $VBoxContainer/VBoxContainer4/HBoxContainer/HBoxContainer/btnFireOff
@onready var btnFireOn = $VBoxContainer/VBoxContainer4/HBoxContainer/HBoxContainer/btnFireOn

## 游戏速度按钮节点
@onready var btnSlow = $VBoxContainer/VBoxContainer5/HBoxContainer/HBoxContainer/btnSlow
@onready var btnNormal = $VBoxContainer/VBoxContainer5/HBoxContainer/HBoxContainer/btnNormal
@onready var btnFast = $VBoxContainer/VBoxContainer5/HBoxContainer/HBoxContainer/btnFast


## 初始化
func _ready() -> void:
	# 根据当前配置设置按钮状态
	setConfig()


## 设置按钮状态
# 根据全局地图配置更新所有按钮的选中状态
func setConfig():
	# 设置碰撞开关
	if MapData.mapConfig.collision:
		btnCollisionOn.button_pressed = true
	
	# 设置恶魔开关
	if MapData.mapConfig.Devils:
		btnDevilsOn.button_pressed = true
	
	# 设置友军伤害开关
	if MapData.mapConfig.friendlyFire:
		btnFireOn.button_pressed = true
	
	# 设置难度等级
	match MapData.mapConfig.difficulty:
		1:
			btnLevel1.button_pressed = true
		2:
			btnLevel2.button_pressed = true
		3:
			btnLevel3.button_pressed = true
		4:
			btnLevel4.button_pressed = true
		_:
			btnLevel1.button_pressed = true
	
	# 设置游戏速度
	match MapData.mapConfig.gameSpeed:
		1:
			btnSlow.button_pressed = true
		2:
			btnNormal.button_pressed = true
		3:
			btnFast.button_pressed = true


## 关闭按钮点击回调
func _on_btn_close_pressed() -> void:
	SoundUtil.playClick()
	hide()


## 重置按钮点击回调
# 重置所有配置到默认值
func _on_button_pressed() -> void:
	MapData.resetMapConfig()
	setConfig()


## 碰撞关闭按钮点击回调
func _on_btn_collision_off_pressed():
	MapData.mapConfig.collision = false


## 碰撞开启按钮点击回调
func _on_btn_collision_on_pressed():
	MapData.mapConfig.collision = true


## 恶魔关闭按钮点击回调
func _on_btn_devils_off_pressed():
	MapData.mapConfig.Devils = false


## 恶魔开启按钮点击回调
func _on_btn_devils_on_pressed():
	MapData.mapConfig.Devils = true


## 友军伤害关闭按钮点击回调
func _on_btn_fire_off_pressed():
	MapData.mapConfig.friendlyFire = false


## 友军伤害开启按钮点击回调
func _on_btn_fire_on_pressed():
	MapData.mapConfig.friendlyFire = true


## 慢速按钮点击回调
func _on_btn_slow_pressed():
	MapData.mapConfig.gameSpeed = 1


## 正常速度按钮点击回调
func _on_btn_normal_pressed():
	MapData.mapConfig.gameSpeed = 2


## 快速按钮点击回调
func _on_btn_fast_pressed():
	MapData.mapConfig.gameSpeed = 3


## 难度1按钮点击回调
func _on_btn_level_1_pressed():
	MapData.mapConfig.difficulty = 1


## 难度2按钮点击回调
func _on_btn_level_2_pressed():
	MapData.mapConfig.difficulty = 2


## 难度3按钮点击回调
func _on_btn_level_3_pressed():
	MapData.mapConfig.difficulty = 3


## 难度4按钮点击回调
func _on_btn_level_4_pressed():
	MapData.mapConfig.difficulty = 4