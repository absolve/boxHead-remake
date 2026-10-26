extends State

## 恶魔 Hurt —— 受击硬直 + 击退


var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	# 原版随机二选一，不区分前后
	d.playAnim("hitFront" if randi() % 2 == 1 else "hitRear", true)


## 25Hz 累积器（和僵尸一致）
var moveAcc: float = 0.0


func physicsUpdate(delta: float) -> void:
	moveAcc += delta
	var step: float = 1.0 / MapData.TICKS_PER_SEC
	while moveAcc >= step and d.knockbackFrames > 0 and d.knockbackDelta.length() > 0.01:
		moveAcc -= step
		d.knockbackFrames -= 1
		var next: Vector2 = d.global_position + d.knockbackDelta * MapData.cellSize
		d.move_and_collide(next - d.global_position)
		d.knockbackDelta *= 0.65
	if d.knockbackFrames <= 0 or d.knockbackDelta.length() < 0.01:
		d.knockbackDelta = Vector2.ZERO
		d.knockbackFrames = 0

	if stateTime >= d.hurtDelay and d.knockbackFrames <= 0:
		if d.dying:
			d.die()
			return
		stateMachine.transitionTo(&"Chase")
