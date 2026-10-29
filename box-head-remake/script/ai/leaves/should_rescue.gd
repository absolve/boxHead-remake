extends ConditionLeaf

## 救援条件：人类队友血量过低 / 弹药将尽，且离自己不算远
##
## 距离太远就不去（保存实力）。救援有 8 秒上限，超时后冷却 5 秒再评估，
## 避免追着队友跑一整天。

const HP_RATIO: float = 0.35
const HP_EXIT_RATIO: float = 0.50
const AMMO_RATIO: float = 0.15
const MAX_RESCUE_CELLS: float = 12.0
const RESCUE_MAX_MS: int = 8000
const RESCUE_COOLDOWN_MS: int = 5000


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var now := Time.get_ticks_msec()
	if now < int(blackboard.get_value("rescue_blocked_until", 0)):
		return FAILURE

	var ally := b.nearestAlly()
	if ally == null:
		blackboard.set_value("rescue_start", 0)
		return FAILURE

	if p.global_position.distance_to(ally.global_position) > MAX_RESCUE_CELLS * MapData.cellSize:
		blackboard.set_value("rescue_start", 0)
		return FAILURE

	var ratio: float = float(ally.hp) / maxf(float(ally.maxHp), 1.0)
	var active: bool = int(blackboard.get_value("rescue_start", 0)) > 0
	# 滞回：进入阈值 35%，已经在救援中则要到 50% 才结束（否则回血会在阈值附近来回抖）
	var lowHp: bool = ratio < (HP_EXIT_RATIO if active else HP_RATIO)
	var lowAmmo: bool = false
	var w = ally.currWeapon
	if w != null and w.maxAmmoNum > 0:
		lowAmmo = float(w.ammoNum) / float(w.maxAmmoNum) < AMMO_RATIO

	if not lowHp and not lowAmmo:
		blackboard.set_value("rescue_start", 0)
		return FAILURE

	# 8 秒救援上限
	var start: int = int(blackboard.get_value("rescue_start", 0))
	if start == 0:
		blackboard.set_value("rescue_start", now)
	elif now - start > RESCUE_MAX_MS:
		blackboard.set_value("rescue_start", 0)
		blackboard.set_value("rescue_blocked_until", now + RESCUE_COOLDOWN_MS)
		return FAILURE

	blackboard.set_value("rescue_ally", ally)
	blackboard.set_value("rescue_low_hp", lowHp)
	return SUCCESS
