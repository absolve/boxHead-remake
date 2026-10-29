extends ConditionLeaf

## 黑板里是否有仍然有效的目标


func tick(_actor: Node, blackboard: Blackboard) -> int:
	var t: Node2D = blackboard.get_value("target")
	if t == null or not is_instance_valid(t):
		return FAILURE
	if t.get("isDead") == true:
		return FAILURE
	return SUCCESS
