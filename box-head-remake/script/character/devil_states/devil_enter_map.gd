extends State

## 恶魔 EnterMap（原版继承 State_EnterMap，CThing_Creature.as:127-158）
##
## 原版入场时先把 mBaseStateID 设成 State_GotoPlayer，再因为恶魔自己定义了
## State_RemoveObject，直接 `SetState(State_RemoveObject)`（即先尝试拆一次挡路的物件）。
## 本项目的出生朝向已由 map.gd 在 add_child 前写入 velocity 决定，
## 所以这里不重复扫描邻格，只负责把流程交棒给 RemoveObject。


var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	d.velocity = Vector2.ZERO
	d.playAnim("stand", true)


func physicsUpdate(_delta: float) -> void:
	if d.isDead:
		return
	d.velocity = Vector2.ZERO
	# 原版：SetState(State_RemoveObject != undefined ? State_RemoveObject : State_CellToCell)
	stateMachine.transitionTo(&"RemoveObject")
