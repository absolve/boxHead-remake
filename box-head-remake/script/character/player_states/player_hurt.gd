extends State

## Hurt 状态：25Hz 击退 + 硬直，结束后回 Idle

var p: Player:
	get:
		return actor as Player


func enter(_msg: Dictionary = {}) -> void:
	p.onHurtEnter()


func physicsUpdate(delta: float) -> void:
	p.updateHurt(delta)
	if p.isDead or p.dying:
		transitionTo(&"Dead")
	elif p.hurtFinished():
		transitionTo(&"Idle")


func exit() -> void:
	p.onHurtExit()
