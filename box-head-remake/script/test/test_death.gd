extends Node2D

## 多玩家死亡/复活测试场景
##
## 加载一张大地图（room_0018）和完整的地图逻辑（map.tscn），
## 可以随时让指定玩家死亡，观察复活位置。
##
## 操作：
##   1 / 2 / 3 / 4   让对应玩家死亡
##   K              让所有玩家死亡
##   R              立即触发一次复活判定
##   C              切换显示相机可走区域
##   ↑ / ↓          把玩家传送到相机上/下边界（方便测远距离复活）


## 使用的大地图
const ROOM: String = "res://scene/level/room_0018.tscn"


var map: Node = null


@onready var label: Label = $ui/label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	MapData.playerCount = 4
	MapData.selectedMapId = 17      # room_0018

	map = load("res://scene/map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	updateLabel()


## 把第一个玩家传送到相机可走区域的上下边界
func teleportToEdge(top: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var r: Rect2 = MapData.getPlayRect()
	var p = players[0]
	p.global_position = Vector2(r.get_center().x, r.position.y + 40 if top else r.end.y - 40)


func updateLabel() -> void:
	if label == null:
		return
	var players := get_tree().get_nodes_in_group("player")
	var dead := 0
	for p in players:
		if p.isDead:
			dead += 1
	var r: Rect2 = MapData.getPlayRect()
	label.text = (
			"房间 room_0018  %d x %d 格 | 玩家 %d（存活 %d / 死亡 %d） | "
			+ "相机区 (%.0f,%.0f)-(%.0f,%.0f)\n1~4 杀死对应玩家   K 全杀   "
			+ "R 立即复活   C 显示相机区   ↑↓ 传送到边界") % [
		int(MapData.mapSize.x / MapData.cellSize), int(MapData.mapSize.y / MapData.cellSize),
		players.size(), players.size() - dead, dead,
		r.position.x, r.position.y, r.end.x, r.end.y]


func _process(_delta: float) -> void:
	updateLabel()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).physical_keycode
	var players := get_tree().get_nodes_in_group("player")
	players.sort_custom(func(a, b) -> bool: return a.playerId < b.playerId)

	match key:
		KEY_1, KEY_2, KEY_3, KEY_4:
			var idx: int = key - KEY_1
			if idx < players.size():
				players[idx].hit(99999, Vector2.ZERO, 0, true)
		KEY_K:
			for p in players:
				if not p.isDead:
					p.hit(99999, Vector2.ZERO, 0, true)
		KEY_R:
			if map != null and map.has_method("_on_resurrection_timer_timeout"):
				map._on_resurrection_timer_timeout()
		KEY_C:
			MapData.debugCamera = not MapData.debugCamera if "debugCamera" in MapData else true
		KEY_UP:
			teleportToEdge(true)
		KEY_DOWN:
			teleportToEdge(false)
