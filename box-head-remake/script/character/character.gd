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

## 致命伤后的“演出中”状态：血已扣光但还在播受击/击退，
## 演完才真正 die()（原版 State_BulletHit → CheckForDead → State_Dying）
var dying: bool = false

## 质量：击退距离 = 公式结果 / 质量（僵尸 1、玩家 2、恶魔按手感也用 1）
@export var mass: float = 1.0
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


## 击退初速（px/s）
##
## 原版 `CThing_Creature.as:471-489`：
##   子弹/火球 max(dmg×2/5/32, 0.3) / mass
##   爆炸     min(dmg×2/5/32 / mass, 0.3)
func knockbackSpeed(dmg: int, fromExplosion: bool = false) -> float:
	var raw: float = float(dmg) * 2.0 / 5.0 / MapData.cellSize
	var cells: float
	if fromExplosion:
		cells = minf(raw / mass, 0.3)
	else:
		cells = maxf(raw, 0.3) / mass
	return cells * MapData.cellSize * MapData.TICKS_PER_SEC


## 受击硬直时长（秒）
##
## 原版 State_BulletHit_Init 用击退衰减帧数当硬直，之后 State_Sleep 再 3 tick。
func hurtTimeFrom(knockFrames: int) -> float:
	return float(knockFrames) / MapData.TICKS_PER_SEC + 3.0 / MapData.TICKS_PER_SEC
