extends ConditionLeaf

## 是否有火球正朝自己飞过来（危险物由感知 Area2D 收集）

const DETECT_RANGE: float = 176.0
const APPROACH_DOT: float = 0.7


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE

	for h in blackboard.get_value("hazards", []):
		if h == null or not is_instance_valid(h):
			continue
		var raw = h.get("dir")
		if typeof(raw) != TYPE_VECTOR2:
			continue
		var dir: Vector2 = raw
		var to: Vector2 = p.global_position - h.global_position
		var d: float = to.length()
		if d < 1.0 or d > DETECT_RANGE:
			continue
		if to.normalized().dot(dir) < APPROACH_DOT:
			continue
		# 朝垂直方向闪，优先选没被障碍挡住的一侧
		var side: Vector2 = dir.orthogonal()
		if p.blockedByCell(p.global_position + side * MapData.cellSize):
			side = -side
		blackboard.set_value("hazard_side", side)
		return SUCCESS
	return FAILURE
