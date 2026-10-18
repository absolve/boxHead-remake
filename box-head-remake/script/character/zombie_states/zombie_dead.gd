extends State

## Dead 状态 —— 死亡
##
## 对应原版僵尸的 State_Sleep / dying / dead 动画段：
##   - 关掉碰撞与受击（不再被子弹打到、也不再挤其他僵尸）；
##   - 播 fallDown_0..3（按朝向 /2 取四方之一）；
##   - 停留 3 秒后淡出并回收。
##
## 注意 zombie._die() 在切进本状态后会把状态机 enabled 置 false，
## 所以这里不依赖 physicsUpdate，收尾全部用 Tween 驱动。

## 宿主
var z: Zombie:
	get:
		return actor as Zombie

## 尸体停留时间（秒）
const CORPSE_TIME := 3.0
## 淡出时长（秒）
const FADE_TIME := 1.0


func enter(_msg: Dictionary = {}) -> void:
	z.velocity = Vector2.ZERO
	z.disableHitbox()
	z.playFallAnim()

	var t := z.create_tween()
	t.tween_interval(CORPSE_TIME)
	t.tween_property(z.ani, "modulate:a", 0.0, FADE_TIME)
	t.tween_callback(z.queue_free)
