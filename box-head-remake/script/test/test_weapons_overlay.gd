extends Node2D

## 枪口可视化叠加层
##
## 放在 z_index = 100 的独立节点上，画在角色贴图之上。
## （直接画在 TestWeapons 根节点会被它自己的子节点盖住，有的方向看不见红点。）


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var player = host.get("player")
	if player == null or not is_instance_valid(player):
		return
	if player.currWeapon == null:
		return

	var w = player.currWeapon
	var dir: Vector2 = player.vector
	if dir == Vector2.ZERO:
		return

	# 枪口（局部）/ 判定起点（局部，身体中心）
	var muzzle: Vector2 = w.muzzleOffset(dir)
	var center_local: Vector2 = Vector2(0, w.HIT_ORIGIN_HEIGHT)
	var end_world: Vector2 = w.hitEnd(dir)

	# 实际命中点（判定射线）
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(player.global_position + center_local, end_world,
			w.collisionMask)
	q.collide_with_areas = true
	q.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)

	var world_hit: Vector2 = end_world
	if not hit.is_empty():
		world_hit = hit.position

	# 灰线：满射程；白线：实际曳光（从枪口沿瞄准方向）
	draw_line(player.global_position + muzzle, end_world, Color(0.55, 0.55, 0.55, 0.45), 1.0)
	draw_line(player.global_position + muzzle, player.global_position + w.tracerEnd(muzzle, dir, world_hit),
			Color(1, 1, 1, 0.9), 2.0)

	# 判定起点（青）+ 美术枪口（红）
	draw_circle(player.global_position + center_local, 4.0, Color(0.1, 0.9, 1.0, 0.95))
	draw_circle(player.global_position + muzzle, 5.0, Color(1.0, 0.15, 0.15, 0.95))
	draw_arc(player.global_position + muzzle, 8.0, 0.0, TAU, 16, Color(1.0, 0.3, 0.3, 0.8), 1.5)

	# 命中点
	if not hit.is_empty():
		draw_circle(world_hit, 5.0, Color(1, 1, 1, 1))
		draw_arc(world_hit, 9.0, 0.0, TAU, 20, Color(1, 0.45, 0.1, 0.9), 1.5)
