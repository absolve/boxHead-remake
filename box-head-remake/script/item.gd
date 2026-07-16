extends Area2D

## 物品基类
# 所有可放置物品（如油桶、地雷、墙壁等）的基类
# 定义了物品的基本属性


## 物品类型（Game.itemType枚举值）
@export var type: Game.itemType = Game.itemType.Box

## 物品碰撞体大小
@export var itemSize: Vector2 = Vector2(15, 15)

## 动画节点
@onready var ani = $ani

## 持有者ID（放置该物品的玩家ID）
var ownerId = null

## 箱子内容类型（仅用于箱子类物品，Game.boxContent枚举值）
var content: Game.boxContent = Game.boxContent.Life
