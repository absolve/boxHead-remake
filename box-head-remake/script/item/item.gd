extends Area2D

## 物品基类
## 所有可放置物品（如油桶、地雷、墙壁等）的基类
## 定义了物品的基本属性，并统一处理"被销毁时从流场里摘掉障碍"


## 物品类型（Game.itemType枚举值）
@export var type: Game.itemType = Game.itemType.Box

## 物品碰撞体大小
@export var itemSize: Vector2 = Vector2(15, 15)

## 是否阻挡敌人寻路
## 放置类武器（油桶 / 喷墙）会把它设成 true，并在 cell 里记下自己占的格子；
## 物品被销毁（爆炸 / 打碎 / 场景切换）时由 _exit_tree 统一摘掉，
## 不用每个子类各写一遍，也不会漏。
@export var blocksPath: bool = false

## 命中特效要抬高多少像素（贴图视觉高度 - 碰撞脚印高度的差）
@export var hitLift: float = 12.0


## 是否由武器放置产生（true = 用武器的当前数值；false = 场景预摆，从数值表同步）
var fromWeapon: bool = false

## 自己占用的格子（-1 表示未登记）
var cell: Vector2i = Vector2i(-1, -1)

## 子爆炸档位：0 = 无，1 = BigBang，2 = BiggerBang（仅爆炸类物体使用）
# 原版 BigBang 生成 6 个延迟子爆炸、BiggerBang 4 个（反直觉，属原版数值 bug）；
# 这里改为单调递增 6 / 10，属新增设计，见 doc/03 §6.4
var biggerBang: int = 0

## 分裂弹数量：>0 时爆出若干枚分裂弹（ClusterExplode，原版固定 4 枚）
var clusterExplode: int = 0

## 持有者ID（放置该物品的玩家ID）
var ownerId: Variant = null

## 箱子内容类型（仅用于箱子类物品，Game.boxContent枚举值）
var content: Game.boxContent = Game.boxContent.Life


## 动画节点
@onready var ani: AnimatedSprite2D = $ani


func _exit_tree() -> void:
	if not blocksPath or cell.x < 0:
		return

	# 从流场障碍里摘掉
	MapData.removeObstacleAt(cell)

	# 顺手清掉格子占用登记：实例 ID 会被引擎复用，
	# 不清的话以后可能出现"这个格子被占了"却找不到占用者的假阳性
	var key := MapData.cellKey(cell)
	if MapData.mapTile.get(key) == get_instance_id():
		MapData.mapTile.erase(key)
