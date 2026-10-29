extends ConditionLeaf

## 撤退条件：血量过低且敌人贴脸（保存实力）

const HP_RATIO: float = 0.30
const DANGER_CELLS: float = 4.0


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE

	if float(p.hp) / maxf(float(p.maxHp), 1.0) > HP_RATIO:
		return FAILURE

	var t: Node2D = blackboard.get_value("target")
	if t == null or not is_instance_valid(t):
		return FAILURE

	return SUCCESS if p.global_position.distance_to(t.global_position) \
			< DANGER_CELLS * MapData.cellSize else FAILURE
