extends Node

## 测试桥（TestBridge）
##
## 只在启动参数带 `--test-bridge` 时启用，监听 127.0.0.1:8765，
## 按行收发 JSON，供外部脚本/AI 读取运行时状态、注入操作。
##
## 用法：
##   Godot...exe --headless --path . res://scene/test/test_cpu.tscn -- --test-bridge
##   可选：--test-bridge-port=8766
##
## 安全：只监听本机回环；不带参数时 `_ready` 直接 queue_free，正式包不会启用。

const DEFAULT_PORT := 28765

var _server: TCPServer = null
var _clients: Array = []

## 卡住检测：inst_id -> {"pos": Vector2, "t": int(ms)}
var _track: Dictionary = {}

## 是否输出调试日志（--test-bridge-verbose）
var _verbose := false

## 长跑用：无敌保护 / 物理帧计数
var _god := false
var _godAtMs := 0
var _ticks := 0


func _ready() -> void:
	# 暂停时也要能响应（玩家的 pause 测试要用）
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dbg("ready user_args=" + str(OS.get_cmdline_user_args()))
	var args := OS.get_cmdline_user_args()
	if not args.has("--test-bridge"):
		_dbg("disabled (no flag)")
		queue_free()
		return
	_verbose = args.has("--test-bridge-verbose")
	var port := DEFAULT_PORT
	for a in args:
		if a.begins_with("--test-bridge-port="):
			port = int(a.get_slice("=", 1))
		elif a.begins_with("--time-scale="):
			Engine.time_scale = clampf(float(a.get_slice("=", 1)), 0.1, 10.0)
		elif a.begins_with("--slots="):
			# 在 map 场景加载前设置玩家槽位（1P/2P/CPU）
			MapData.playerSlots.clear()
			for v in a.get_slice("=", 1).split(","):
				MapData.playerSlots.append(int(v))
	_server = TCPServer.new()
	var err := _server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("TestBridge: 监听 127.0.0.1:%d 失败 (err=%d)" % [port, err])
		_dbg("listen failed port=%d err=%d" % [port, err])
		return
	print("[TestBridge] listening on 127.0.0.1:%d" % port)


func _process(_delta: float) -> void:
	if _server == null:
		return

	if _god and Time.get_ticks_msec() - _godAtMs > 1000:
		_godAtMs = Time.get_ticks_msec()
		_apply_god()

	while _server.is_connection_available():
		var peer := _server.take_connection()
		_clients.append({"peer": peer, "buf": ""})
		print("[TestBridge] client connected")

	for i in range(_clients.size() - 1, -1, -1):
		var c: Dictionary = _clients[i]
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		var st := peer.get_status()
		if st != StreamPeerTCP.STATUS_CONNECTED:
			_clients.remove_at(i)
			continue

		var avail := peer.get_available_bytes()
		if avail > 0:
			var res: Array = peer.get_data(avail)
			if int(res[0]) != OK:
				continue
			c["buf"] += (res[1] as PackedByteArray).get_string_from_utf8()

		while true:
			var buf: String = c["buf"]
			var idx := buf.find("\n")
			if idx < 0:
				break
			var line := buf.substr(0, idx)
			c["buf"] = buf.substr(idx + 1)
			if line.strip_edges().is_empty():
				continue
			var req = JSON.parse_string(line)
			if typeof(req) != TYPE_DICTIONARY:
				_send(peer, {"ok": false, "err": "bad json"})
				continue
			_dbg("cmd " + str(req.get("cmd", "?")))
			var resp: Dictionary = _handle(req)
			_send(peer, resp)


func _send(peer: StreamPeerTCP, obj: Dictionary) -> void:
	var txt := JSON.stringify(obj)
	if txt.is_empty():
		_dbg("SERIALIZE EMPTY keys=" + str(obj.keys()))
		txt = '{"ok":false,"err":"serialize"}'
	_dbg("send " + str(txt.length()))
	peer.put_data((txt + String.chr(10)).to_utf8_buffer())


func _dbg(msg: String) -> void:
	if not _verbose:
		return
	var f := FileAccess.open("user://testbridge.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("user://testbridge.log", FileAccess.WRITE)
	else:
		f.seek_end()
	if f != null:
		f.store_line("%d %s" % [Time.get_ticks_msec(), msg])


# ---------------------------------------------------------------- 命令分发

func _handle(req: Dictionary) -> Dictionary:
	match str(req.get("cmd", "")):
		"ping":
			return {"ok": true}
		"snapshot":
			return _snapshot()
		"spawn":
			return _cmd_spawn(req)
		"clear_enemies":
			return _cmd_clear_enemies()
		"set_hp":
			return _cmd_set_hp(req)
		"grant_weapons":
			return _cmd_grant_weapons(req)
		"teleport":
			return _cmd_teleport(req)
		"set_setting":
			return _cmd_set_setting(req)
		"pause":
			get_tree().paused = bool(req.get("paused", true))
			return {"ok": true, "paused": get_tree().paused}
		"god":
			_god = bool(req.get("on", true))
			_apply_god()
			return {"ok": true, "god": _god}
		"input":
			return _cmd_input(req)
		"screenshot":
			return _cmd_screenshot(req)
		"quit":
			get_tree().quit(int(req.get("code", 0)))
			return {"ok": true}
		_:
			return {"ok": false, "err": "unknown cmd"}


# ---------------------------------------------------------------- 快照

func _snapshot() -> Dictionary:
	var players: Array = []
	var cpus: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		var w = p.get("currWeapon")
		var entry := {
			"id": p.get("playerId"),
			"isCpu": p.get("isCpu") == true,
			"hp": p.get("hp"),
			"maxHp": p.get("maxHp"),
			"dead": p.get("isDead") == true,
			"state": p.get("state"),
			"pos": [p.global_position.x, p.global_position.y],
			"weapon": null,
			"ammo": 0,
			"weaponName": "",
		}
		if w != null:
			entry["weapon"] = w.type if w.get("type") != null else -1
			entry["weaponName"] = str(Game.weaponName.get(w.type, "")) if w.get("type") != null else ""
			entry["ammo"] = w.ammoNum if w.get("ammoNum") != null else 0
		players.append(entry)

		var brain = p.get("cpuBrain")
		if brain != null and is_instance_valid(brain):
			var act = brain.tree.get_running_action() if brain.tree != null else null
			var dist := -1.0
			if brain.target != null and is_instance_valid(brain.target):
				dist = p.global_position.distance_to(brain.target.global_position)
			cpus.append({
				"id": p.get("playerId"),
				"strategy": brain.strategyName() if brain.has_method("strategyName") else "",
				"branch": String(act.name) if act != null else "",
				"hasTarget": brain.target != null and is_instance_valid(brain.target),
				"targetDist": dist,
				"wantFire": p.get("cpuWantFire") == true,
				"boxTarget": brain.boxTarget != null,
				"props": brain.props.size(),
				"stuckMs": int(float(p.get("cpuStuck")) * 1000.0) if p.get("cpuStuck") != null else 0,
			})

	var enemies: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		enemies.append({
			"type": e.get("type"),
			"hp": e.get("hp"),
			"state": e.get("state"),
			"pos": [e.global_position.x, e.global_position.y],
			"id": e.get_instance_id(),
		})

	var metrics := _enemy_metrics(enemies)

	var decal_count := 0
	for d in get_tree().get_nodes_in_group("decal"):
		if is_instance_valid(d) and d.get("splats") != null:
			decal_count = (d.get("splats") as Array).size()

	return {
		"ok": true,
		"pid": OS.get_process_id(),
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "",
		"mapSize": [MapData.mapSize.x, MapData.mapSize.y],
		"paused": get_tree().paused,
		"fps": Engine.get_frames_per_second(),
		"players": players,
		"cpus": cpus,
		"enemies": enemies,
		"metrics": metrics,
		"decalCount": decal_count,
		"boxCount": get_tree().get_nodes_in_group("box").size(),
		"nodeCount": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphanCount": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"memMb": OS.get_static_memory_usage() / 1048576.0,
		"ticks": _ticks,
		"simTimeSec": _ticks / 60.0 * Engine.time_scale,
		"wave": int(get_tree().current_scene.get("currWave")) if get_tree().current_scene != null and get_tree().current_scene.get("currWave") != null else -1,
		"score": MapData.score,
		"settings": {
			"friendlyFire": MapData.friendlyFireOn(),
			"blood": bool(MapData.mapConfig.get("blood", true)),
			"screenShake": bool(MapData.mapConfig.get("screenShake", true)),
		},
	}


func _enemy_metrics(enemies: Array) -> Dictionary:
	var n := enemies.size()
	var cell_w := int(MapData.mapSize.x / MapData.cellSize)
	var cell_h := int(MapData.mapSize.y / MapData.cellSize)
	var min_d := 9999.0
	var overlap := 0
	var cells := {}
	var obstacle := 0
	var stuck := 0
	var now := Time.get_ticks_msec()

	for i in range(n):
		var a: Array = enemies[i]["pos"]
		var pa := Vector2(a[0], a[1])
		var cell := MapData.worldToCell(pa)
		cells[MapData.cellKey(cell)] = int(cells.get(MapData.cellKey(cell), 0)) + 1
		# 只统计"已经进场"的敌人：出生/从场外走进来时不算法
		var in_map := cell.x >= 0 and cell.y >= 0 and cell.x < cell_w and cell.y < cell_h
		var spawning: bool = int(enemies[i].get("state", -1)) == int(Game.enemyState.init)
		var out_of_map := cell.x < 0 or cell.y < 0 or cell.x >= cell_w or cell.y >= cell_h
		if not out_of_map and not spawning and MapData.isObstacle(cell):
			obstacle += 1

		# 卡住：5 秒内位移 < 8px
		var id: int = enemies[i]["id"]
		var rec: Dictionary = _track.get(id, {})
		if rec.is_empty() or now - int(rec.get("t", 0)) > 5000:
			_track[id] = {"pos": pa, "t": now}
		else:
			var moved: float = pa.distance_to(rec["pos"])
			if now - int(rec.get("t", 0)) >= 4500 and moved < 8.0:
				stuck += 1

		for j in range(i + 1, n):
			var b: Array = enemies[j]["pos"]
			var d := pa.distance_to(Vector2(b[0], b[1]))
			if d < min_d:
				min_d = d
			if d < 26.0:
				overlap += 1

	var max_per := 0
	for k in cells.keys():
		max_per = maxi(max_per, int(cells[k]))

	return {
		"count": n,
		"minPairDist": min_d if n > 1 else -1.0,
		"overlapPairs": overlap,
		"maxPerCell": max_per,
		"obstacleCount": obstacle,
		"stuckCount": stuck,
	}


# ---------------------------------------------------------------- 操作

func _physics_process(_delta: float) -> void:
	_ticks += 1


func _apply_god() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		p.set("invincible", true)
		p.set("invincibleTime", 0.0)
		if p.get("ani") != null:
			p.ani.modulate.a = 1.0


func _cmd_spawn(req: Dictionary) -> Dictionary:
	var kind := str(req.get("kind", "zombie"))
	var pos := Vector2(float(req.get("x", 0.0)), float(req.get("y", 0.0)))
	var path := ""
	match kind:
		"zombie":
			path = "res://scene/character/zombie.tscn"
		"devil":
			path = "res://scene/character/devil.tscn"
		"box":
			path = "res://scene/item/box.tscn"
		"barrel":
			path = "res://scene/item/barrel_obj.tscn"
		_:
			return {"ok": false, "err": "unknown kind"}

	var packed := load(path) as PackedScene
	if packed == null:
		return {"ok": false, "err": "load failed"}

	var e := packed.instantiate() as Node2D
	if e == null:
		return {"ok": false, "err": "instantiate failed"}

	if kind == "zombie" or kind == "devil":
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		e.global_position = pos - dir * 20.0
		e.set("velocity", dir)
		if "initPos" in e:
			e.set("initPos", pos)
		if "state" in e:
			e.set("state", Game.enemyState.init)
		if "speed" in e:
			e.set("speed", float(req.get("speed", 60.0)))
	else:
		e.global_position = pos

	var hp := int(req.get("hp", -1))
	if hp > 0 and e.get("hp") != null:
		e.set("hp", hp)

	get_tree().current_scene.add_child(e)
	return {"ok": true, "id": e.get_instance_id()}


func _cmd_clear_enemies() -> Dictionary:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
			n += 1
	return {"ok": true, "cleared": n}


func _cmd_set_hp(req: Dictionary) -> Dictionary:
	var pid := int(req.get("playerId", 1))
	var hp := int(req.get("hp", 100))
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and int(p.get("playerId")) == pid:
			p.set("hp", hp)
			if p.get("lifeBar") != null:
				p.lifeBar.hp = hp
			return {"ok": true, "playerId": pid, "hp": hp}
	return {"ok": false, "err": "player not found"}


func _cmd_grant_weapons(req: Dictionary) -> Dictionary:
	var pid := int(req.get("playerId", -1))
	var granted := 0
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.get("isCpu") != true:
			continue
		if pid >= 0 and int(p.get("playerId")) != pid:
			continue
		for content in [Game.boxContent.UZI, Game.boxContent.Shotgun,
				Game.boxContent.Railgun, Game.boxContent.Rocket]:
			p.pickItem(content)
		granted += 1
	return {"ok": true, "cpus": granted}


func _cmd_teleport(req: Dictionary) -> Dictionary:
	var pid := int(req.get("playerId", 1))
	var pos := Vector2(float(req.get("x", 0.0)), float(req.get("y", 0.0)))
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and int(p.get("playerId")) == pid:
			p.global_position = pos
			MapData.flowDirty = true
			return {"ok": true, "playerId": pid}
	return {"ok": false, "err": "player not found"}


func _cmd_set_setting(req: Dictionary) -> Dictionary:
	var key := str(req.get("key", ""))
	var value = req.get("value", null)
	if key.is_empty():
		return {"ok": false, "err": "missing key"}
	MapData.mapConfig[key] = value
	return {"ok": true, "key": key, "value": MapData.mapConfig.get(key)}


func _cmd_input(req: Dictionary) -> Dictionary:
	var action := str(req.get("action", ""))
	var pressed := bool(req.get("pressed", true))
	if action.is_empty() or not InputMap.has_action(action):
		return {"ok": false, "err": "unknown action"}
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	return {"ok": true}


func _cmd_screenshot(req: Dictionary) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"ok": false, "err": "headless: no rendering"}
	var path := str(req.get("path", "user://shot.png"))
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	return {"ok": err == OK, "path": path}
