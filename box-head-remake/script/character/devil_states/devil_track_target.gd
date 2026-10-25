extends State

## 恶魔 TrackTarget（原版 State_TrackTarget，CThing_Creature_Devil.as:196-202）
##
## 原版进入时只把动画设成 stand，函数体是空的。全工程没有任何
## SetState("State_TrackTarget") 调用，所以它是**保留但未接入的占位状态**。
## 这里照原版保留同样的空行为，不参与现有状态迁移。


var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	d.velocity = Vector2.ZERO
	d.playAnim("stand", true)


func physicsUpdate(_delta: float) -> void:
	# 原版函数体为空；占位状态不做任何决策
	d.velocity = Vector2.ZERO
