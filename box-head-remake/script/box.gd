extends "res://script/item.gd"

## 奖励箱子脚本
# 继承自item.gd，实现奖励箱子的逻辑
# 玩家靠近时自动打开，给予随机奖励（武器或生命）


## 计时器节点
@onready var timer = $Timer

## 动画节点
@onready var player = $player

## 过期时间（秒，0表示永不过期）
@export var expiredTime = 0


## 初始化
func _ready():
	# 如果设置了过期时间，启动计时器
	if expiredTime != 0:
		timer.start(expiredTime)
	
	# 如果有已解锁的武器，随机选择一个作为奖励
	if MapData.weaponUnlock.size() > 0:
		content = Game.WeaponType2BoxContent(MapData.weaponUnlock[randi() % MapData.weaponUnlock.size()])


## 玩家进入碰撞区域时触发
# 给予玩家奖励并销毁箱子
# @param body 进入的玩家身体节点
func _on_body_entered(body):
	# 40%概率给予生命恢复（如果玩家血量不满）
	var p = randi() % 10
	if body.hp < body.maxHp:
		if p >= 4:
			content = Game.boxContent.Life
	
	# 让玩家拾取物品
	body.pickItem(content)
	
	# 显示拾取通知
	Game.notice.emit("%s %s" % [tr("Pickup"), Game.getBoxContentName(content)])
	
	# 销毁箱子
	queue_free()


## 过期计时器超时回调
# 播放淡出动画后销毁箱子
func _on_timer_timeout():
	player.play("fadeOut")
	await player.animation_finished
	queue_free()
