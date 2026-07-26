extends Node2D

## 武器基类
# 所有武器的抽象基类，定义了武器的通用属性和方法


## 是否激活
var active = false

## 武器类型（Game.weaponType枚举值）
@export var type: Game.weaponType
## 伤害值
@export var damage = 0
## 射程（像素）
@export var wRange = 0
## 开火延迟（秒）
@export var delay = .0
## 当前弹药量
@export var ammoNum: int = 0
## 最大弹药量（0表示无限弹药）
@export var maxAmmoNum: int = 0
## 被击中目标的反馈速度（击退效果）
@export var hitFeedback = 0
## 是否自动连射
@export var automatic = false

## 是否可以射击（受延迟限制）
var canShoot = true

## 检测碰撞的帧数（射击后持续检测碰撞的时间）
var detecframes = 0

## 武器方向（玩家朝向）
var vector: Vector2 = Vector2.RIGHT

## 武器偏移方向（8个方向的偏移量，用于调整武器显示位置）
var offsetDir = {
	0: Vector2.ZERO, 1: Vector2.ZERO, 2: Vector2.ZERO,
	3: Vector2.ZERO, 4: Vector2.ZERO, 5: Vector2.ZERO,
	6: Vector2.ZERO, 7: Vector2.ZERO
}

## 武器持有者的RID（用于碰撞检测时排除自身）
var ownerId = null

## 碰撞检测掩码（默认检测玩家、敌人、物品、墙壁）
var collisionMask = 4 + 8 + 16 + 32

## 已处理碰撞的对象列表（避免重复伤害）
var excludeObj = []

## 烟雾效果预加载
var smoke = preload("res://scene/smoke.tscn")


## 音效节点
@onready var sound = $sound

## 冷却计时器节点
@onready var timer = $Timer


## 冷却计时器回调
# 当延迟时间结束时，允许再次射击
func _on_timer_timeout() -> void:
	canShoot = true


## 射击方法（抽象）
# 子类必须重写此方法实现具体射击逻辑
# @param _angle 射击方向（Vector2）
func fire(_angle): 
	pass


## 添加烟雾效果
# 在指定位置创建烟雾粒子效果
# @param pos 烟雾生成位置（Vector2）
func addSmoke(pos):
	var temp = smoke.instantiate()
	temp.global_position = pos
	temp.type = Game.smokeType.SmokeCloud
	get_tree().root.add_child(temp)
