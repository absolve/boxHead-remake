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


## 过期时间（秒，0 表示永不过期）
@export var expiredTime: int = 0
## 回血阈值：血量占最大血量的比例低于它时，箱子改为回血
@export var healThreshold: float = 0.5


## 计时器节点
@onready var timer: Timer = $Timer
## 动画节点
@onready var player: AnimationPlayer = $player


## 初始化
func _ready() -> void:
	add_to_group("box")
	# 如果设置了过期时间，启动计时器
	if expiredTime != 0:
		timer.start(expiredTime)


## 玩家进入碰撞区域时触发
# @param body 进入的玩家身体节点
func _on_body_entered(body: Node2D) -> void:
	# 只有玩家能开箱：僵尸/恶魔/其它 CharacterBody2D 碰上来会没有 pickItem（Devil 报错就是这个）
	if body == null or not body.has_method("pickItem"):
		return
	content = rollContent(body) as Game.boxContent

	# 让玩家拾取物品。
	# 不能在 body_entered 回调里直接加武器节点（物理回调中改碰撞体会报
	# area_set_shape_disabled 错误），所以延后一帧执行。
	var b := body
	var c = content
	b.call_deferred("pickItem", c)

	# 显示拾取通知
	Game.notice.emit("%s %s" % [tr("Pickup"), tr(Game.getBoxContentName(c))])

	queue_free()


## 决定箱子内容
# 血量低于阈值就回血，否则在已解锁武器里均匀抽；没有可抽的就回血
func rollContent(body: Node2D) -> int:
	if body != null and body.get("hp") != null and body.get("maxHp") != null:
		var hp: float = float(body.hp)
		var maxHp: float = float(body.maxHp)
		if maxHp > 0.0 and hp <= maxHp * healThreshold:
			return Game.boxContent.Life

	var pool: Array = MapData.weaponUnlock
	if pool.is_empty():
		return Game.boxContent.Life

	return Game.WeaponType2BoxContent(pool[randi() % pool.size()])


## 受击；签名与角色一致（箱子不吃伤害，保留接口给爆炸统一调用）
func hit(_damage: int, _attackPos: Vector2 = Vector2.ZERO,
		_knockDir: Vector2 = Vector2.ZERO, _fromExplosion: bool = false) -> void:
	pass


## 过期计时器超时回调
# 播放淡出动画后销毁箱子
func _on_timer_timeout() -> void:
	player.play("fadeOut")
	await player.animation_finished
	queue_free()
