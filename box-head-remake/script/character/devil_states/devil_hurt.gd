extends State

## 恶魔 Hurt —— 受击硬直 + 击退

var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	d.playAnim("hitFront" if d.hitFromFront else "hitRear", true)


func physicsUpdate(delta: float) -> void:
	d.velocity = d.velocity.lerp(Vector2.ZERO, minf(8.0 * delta, 1.0))
	if d.velocity.length() > 1.0:
		d.move_and_collide(d.velocity * delta)

	if stateTime >= d.hurtDelay:
		stateMachine.transitionTo(&"Chase")
