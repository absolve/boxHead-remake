extends State

## Sleep 状态 —— 无动画硬直（对应原版 `State_Sleep`，2P/CThing_Creature.as:217-227）
##
## 原版两个用途：
##   1) 攻击命中后停 10 帧（CMain.mFPS = 25 → 0.4 秒）
##   2) 刚转完身、方向又不对 → 停 CMain.mFPS/3 = 9 帧（≈0.36 秒，防抖）
##
## 切换参数（msg）：
##   next = 结束后进入的状态（默认 Chase）
##   time = 停顿秒数（默认 0.4，即攻击后的 10 帧）


## 宿主
var z: Zombie:
	get:
		return actor as Zombie

## 结束后进入的状态
var nextState: StringName = &"Chase"
## 剩余时间
var timer: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	nextState = StringName(str(msg.get("next", "Chase")))
	timer = float(msg.get("time", 0.4))
	z.velocity = Vector2.ZERO
	z.playAnim("stand")


func exit() -> void:
	z.velocity = Vector2.ZERO


func physicsUpdate(delta: float) -> void:
	if z.isDead:
		return
	timer -= delta
	if timer <= 0.0:
		stateMachine.transitionTo(nextState)
