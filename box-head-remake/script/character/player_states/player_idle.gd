extends State

## Idle 状态：移动 / 瞄准 / 开火 / 切武器
##
## 具体逻辑仍在 player.gd 的 updateIdle()，这里只负责状态切换。

var p: Player:
	get:
		return actor as Player


func enter(_msg: Dictionary = {}) -> void:
	p.onIdleEnter()


func physicsUpdate(delta: float) -> void:
	p.updateIdle(delta)
	# 受伤 → Hurt（由 player.hit 里 transitionTo 触发，这里只兜底）
	if p.hp <= 0:
		transitionTo(&"Dead")
	elif p.state == Game.playerState.hurt:
		transitionTo(&"Hurt")


func exit() -> void:
	p.onIdleExit()
