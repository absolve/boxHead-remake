extends TurnState

## 僵尸的 Turn 状态 —— 原地转身。
##
## 逻辑全部在 [TurnState]（script/fsm/turn_state.gd），这里只保留僵尸自己的入口。
## 僵尸素材有完整的 32 帧 rotate 动画（8 朝向 × 每 45° 4 帧），
## 所以僵尸转身是逐帧播出来的，而不是瞬间对齐。

## 离开 Turn 时做标记，供 Chase 判断"刚转完身、方向又不对"要停 1/3 秒
func exit() -> void:
	var z := host as Zombie
	if z != null:
		z.justTurned = true
