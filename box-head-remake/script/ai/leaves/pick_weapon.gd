extends ActionLeaf

## 选枪：按目标距离挑一把枪；滞回 / 冷却 / 空弹判断在 CpuBrain.bestGun 里


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var t: Node2D = blackboard.get_value("target")
	var dist := 9999.0
	if t != null and is_instance_valid(t):
		dist = p.global_position.distance_to(t.global_position)

	var w = b.bestGun(dist)
	if w != null and w != p.currWeapon:
		var before = p.currWeapon
		p.cpuRequestWeapon(w.type)
		if p.currWeapon != before:
			b.lastSwitchMs = Time.get_ticks_msec()
	return SUCCESS
