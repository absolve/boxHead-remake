extends "res://script/item/item.gd"

## 奖励箱子脚本
##
## 内容规则（由玩家在拾取瞬间的血量决定）：
##   1. 血量低于 maxHp × healThreshold → 回血（Life）
##   2. 否则 → 在当前**已解锁武器**里均匀随机抽一个
##   3. 还没有解锁任何武器（开局）→ 回退成回血
##
## 固定刷新点（map.gd 的 itemSpawnPoint）和连杀掉落（killRewardBox）
## 用的是同一个箱子场景，所以两者规则一致。

## 计时器节点
@onready var timer = $Timer
## 动画节点
@onready var player = $player
## 过期时间（秒，0 表示永不过期）
@export var expiredTime = 0
## 回血阈值：血量占最大血量的比例低于它时，箱子改为回血
@export var healThreshold: float = 0.5


## 初始化
func _ready():
	# 如果设置了过期时间，启动计时器
	if expiredTime != 0:
		timer.start(expiredTime)


## 玩家进入碰撞区域时触发
# @param body 进入的玩家身体节点
func _on_body_entered(body):
	content = rollContent(body)

	# 让玩家拾取物品
	body.pickItem(content)

	# 显示拾取通知
	Game.notice.emit("%s %s" % [tr("Pickup"), Game.getBoxContentName(content)])

	queue_free()


## 决定箱子内容
# 血量低于阈值就回血，否则在已解锁武器里均匀抽；没有可抽的就回血
func rollContent(body) -> int:
	if body != null and body.get("hp") != null and body.get("maxHp") != null:
		var hp: float = float(body.hp)
		var maxHp: float = float(body.maxHp)
		if maxHp > 0.0 and hp <= maxHp * healThreshold:
			return Game.boxContent.Life

	var pool: Array = MapData.weaponUnlock
	if pool.is_empty():
		return Game.boxContent.Life

	return Game.WeaponType2BoxContent(pool[randi() % pool.size()])


## 过期计时器超时回调
# 播放淡出动画后销毁箱子
func _on_timer_timeout():
	player.play("fadeOut")
	await player.animation_finished
	queue_free()
