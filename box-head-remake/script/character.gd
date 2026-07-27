extends CharacterBody2D

## 角色基类
# 所有可移动角色（玩家和敌人）的基类
# 定义了角色的基本属性和状态管理


## 当前朝向角度（0-7，对应8个方向）
var angle = 0
## 当前动画名称
var currAni = ""
## 是否已死亡
var isDead = false
## 是否处于无敌状态
var invincible = false
## 当前状态（由子类定义具体状态枚举）
var state
## 上一帧状态
var lastState

## 碰撞形状节点（在_ready后获取）
@onready var shape = $shape
## 角色碰撞体大小
@export var bodySize: Vector2 = Vector2(20, 25)
## 当前血量
@export var hp: int = 10
## 移动速度
@export var speed = 120
## 角色类型（Game.roleType枚举值）
@export var type: Game.roleType = Game.roleType.Player
## 最大血量
@export var maxHp: int = 10
