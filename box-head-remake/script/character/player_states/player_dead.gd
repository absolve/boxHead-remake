extends State

## Dead 状态：倒地演出，等待复活

var p: Player:
	get:
		return actor as Player


func enter(_msg: Dictionary = {}) -> void:
	p.onDeadEnter()


func physicsUpdate(delta: float) -> void:
	p.updateDead(delta)
	if not p.isDead:
		transitionTo(&"Idle")
