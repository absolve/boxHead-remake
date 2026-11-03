extends "res://script/item/item.gd"

## 奖励箱子脚本
##
## 内容规则照搬原版 `CThing_Creature_Player.RandomPickup`（:355-397），**不是均匀的**：
##   1. 候选池 = 已解锁的非手枪武器（原版取 `mActive && mNameID != "pistol"`）；
##      每把的权重 = `(1 - 当前弹/上限弹) × 0.75 + 0.25`
##      → 越缺弹的枪越容易抽到，满弹也保留 0.25 的底，不会被完全排除。
##      玩家还没持有这把枪时按"空弹"算（权重 1.0，最高）。
##   2. 血量未满时再加一项"回血"，权重 = `(1 - hp/maxHp) × 武器权重总和`
##      → 血越少越可能回血，且与武器项同量级（原版就是这么算的）。
##   3. 原版有个值得注意的推论：**一把武器都还没解锁时，箱子什么都不给**——
##      因为回血权重是 `(1-hp/maxHp) × 武器权重总和`，总和为 0 时回血权重也是 0。
##      也就是说开局前几次开箱在原版里是"空箱"。这里保持与原版一致；
##      想要更慷慨（新手期开箱必给血），把 life 项改成固定权重即可。
##
## 固定刷新点（map.gd 的 itemSpawnPoint）和连杀掉落（killRewardBox）
## 用的是同一个箱子场景，所以两者规则一致。


## 过期时间（秒，0 表示永不过期）
@export var expiredTime: int = 0


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
	content = rollContent(body)

	# content < 0 = 这次没有任何可给的东西（池子为空且满血）。
	# 原版也是照样吃掉箱子、播音效，只是没有收益，所以这里不 pickItem。
	if content >= 0:
		# 让玩家拾取物品。
		# 不能在 body_entered 回调里直接加武器节点（物理回调中改碰撞体会报
		# area_set_shape_disabled 错误），所以延后一帧执行。
		var b := body
		var c = content
		b.call_deferred("pickItem", c)

		# 显示拾取通知
		Game.notice.emit("%s %s" % [tr("Pickup"), tr(Game.getBoxContentName(c))])

	queue_free()


## 决定箱子内容：原版 RandomPickup 的加权抽签（见文件头规则）
# @return Game.boxContent 之一；-1 表示没有任何可给的东西
func rollContent(body: Node2D) -> int:
	var entries: Array = []
	var total: float = 0.0

	# 1. 候选池 = 已解锁的非手枪武器，权重按"缺多少弹"给
	for wt in MapData.weaponUnlock:
		if wt == Game.weaponType.Pistol:
			continue
		var c: Variant = Game.WeaponType2BoxContent(wt)
		if c == null:
			continue
		total += ammoWeight(body, wt)
		entries.append({"c": c, "acc": total})

	# 2. 血量未满 → 加一项"回血"，权重 = (1 - hp/maxHp) × 武器权重总和
	#    （原版就是把 life 累加到同一个 total 上，所以血越少越可能回血）
	if body != null and body.get("hp") != null and body.get("maxHp") != null:
		var hp: float = float(body.hp)
		var maxHp: float = float(body.maxHp)
		if maxHp > 0.0 and hp < maxHp:
			total += (1.0 - hp / maxHp) * total
			entries.append({"c": Game.boxContent.Life, "acc": total})

	if total <= 0.0 or entries.is_empty():
		return -1

	# 3. 落在累加区间上取第一个命中的项
	var r: float = randf() * total
	for e in entries:
		if r < float(e.acc):
			return int(e.c)
	return int(entries[entries.size() - 1].c)


## 一把武器进箱的权重：0.25（满弹）~ 1.0（空弹/还没持有）
func ammoWeight(body: Node2D, weaponType: int) -> float:
	var d: Dictionary = MapData.allWeaponData.get(weaponType, {})
	var maxAmmo: int = int(d.get('maxAmmoNum', 0))
	if maxAmmo <= 0:
		# 无限弹药（表里只有手枪是 0），按满弹算，只保留 0.25 的底
		return 0.25
	var cur: int = 0
	if body != null and body.has_method("getWeapon"):
		var w = body.getWeapon(weaponType)
		if w != null:
			cur = int(w.ammoNum)
	return (1.0 - float(cur) / float(maxAmmo)) * 0.75 + 0.25


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
