extends State

## 恶魔 Hurt —— 受击硬直 + 击退


var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	d.playAnim("hitFront" if d.hitFromFront else "hitRear", true)


func physicsUpdate(delta: float) -> void:
	# 和僵尸一致：按 knockbackDelta 逐帧后退，每帧衰减 0.65
	if d.knockbackFrames > 0 and d.knockbackDelta.length() > 0.01:
		d.knockbackFrames -= 1
		var next: Vector2 = d.global_position + d.knockbackDelta * MapData.cellSize
		d.move_and_collide(next - d.global_position)
		d.knockbackDelta *= 0.65
	else:
		d.knockbackDelta = Vector2.ZERO
		d.knockbackFrames = 0

	if stateTime >= d.hurtDelay and d.knockbackFrames <= 0:
		stateMachine.transitionTo(&"Chase")
