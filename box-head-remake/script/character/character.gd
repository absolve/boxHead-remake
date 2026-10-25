class_name Character
extends CharacterBody2D

## 角色基类
# 所有可移动角色（玩家和敌人）的基类
# 定义了角色的基本属性和状态管理


## 角色碰撞体大小
@export var bodySize: Vector2 = Vector2(20, 25)

## 当前血量
@export var hp: int = 10

## 移动速度
@export var speed: float = 120

## 转身动画速度（帧/秒；rotate 共 32 帧，4 帧 = 45°）
@export var turnFrameSpeed: float = 40.0

## 角色类型（Game.roleType枚举值）
@export var type: Game.roleType = Game.roleType.Player

## 最大血量
@export var maxHp: int = 10

## 命中特效要抬高多少像素
# 受击区（body Area2D）在脚下，但贴图是竖着画的，不补偿烟雾会落在脚底
@export var hitLift: float = 18.0


## 当前朝向角度（0-7，对应8个方向）
var angle: int = 0

## 上一次稳定下来的朝向（转身动画的起点）
var oldAngle: int = 0

## 当前动画名称
var currAni: String = ""

## 是否已死亡
var isDead: bool = false

## 是否处于无敌状态
var invincible: bool = false

## 当前状态（由子类定义具体状态枚举）
var state: int

## 上一帧状态
var lastState: int


## 碰撞形状节点（在_ready后获取）
@onready var shape: CollisionShape2D = $shape

## 动画节点（各角色场景都有同名子节点）
@onready var ani: AnimatedSprite2D = $ani
