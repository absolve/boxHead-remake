extends State

## 恶魔 Dead —— 关碰撞 + 倒地 + 淡出回收


## 尸体停留时间（秒）
const CORPSE_TIME: float = 3.0

## 淡出时长（秒）
const FADE_TIME: float = 1.0


var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	d.velocity = Vector2.ZERO
	d.disableHitbox()
	d.playFallAnim()

	var t := d.create_tween()
	t.tween_interval(CORPSE_TIME)
	t.tween_property(d.ani, "modulate:a", 0.0, FADE_TIME)
	t.tween_callback(d.queue_free)
