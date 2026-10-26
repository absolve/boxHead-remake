extends Node2D

## 武器基类
# 所有武器的抽象基类，定义了武器的通用属性和方法


## 没有脚本的静态墙（wall_shape_*）使用的默认抬升量
# 静态墙贴图 205x89、碰撞 193x64 且下移 18，视觉中线比碰撞脚印高约 32px
const DEFAULT_STATIC_WALL_LIFT: float = 32.0


## 武器类型（Game.weaponType枚举值）
@export var type: Game.weaponType
## 伤害值
@export var damage: int = 0
## 射程（像素）
@export var wRange: int = 0
## 开火延迟（秒）
@export var delay: float = 0.0
## 当前弹药量
@export var ammoNum: int = 0
## 最大弹药量（0表示无限弹药）
@export var maxAmmoNum: int = 0
## 是否自动连射
@export var automatic: bool = false


## 是否激活
var active: bool = false
## 是否可以射击（受延迟限制）
var canShoot: bool = true
## 检测碰撞的帧数（射击后持续检测碰撞的时间）
var detecframes: int = 0
## 武器方向（玩家朝向）
var vector: Vector2 = Vector2.RIGHT
## 武器偏移方向（8个方向的偏移量）
#
# 它同时是"枪口位置"：射线类武器直接用 offsetDir[idx]
# 作为枪口（局部坐标），再换算成射线起点，所以画面上枪口在哪，射线就从哪出发。
var offsetDir: Dictionary = {
	0: Vector2.ZERO, 1: Vector2.ZERO, 2: Vector2.ZERO,
	3: Vector2.ZERO, 4: Vector2.ZERO, 5: Vector2.ZERO,
	6: Vector2.ZERO, 7: Vector2.ZERO
}
## 武器持有者的RID（用于碰撞检测时排除自身）
var ownerId: Variant = null
## 武器持有者节点（用于收集它身上所有碰撞 RID，投射物据此忽略自己）
var ownerNode: Node = null
## 投射物要排除的对象列表（节点或 RID），由持有者填
var excludeList: Array[RID] = []
## 碰撞检测掩码（默认检测玩家、敌人、物品、墙壁）
var collisionMask: int = 4 + 8 + 16 + 32
## 子爆炸档位：0 = 无，1 = BigBang，2 = BiggerBang（仅爆炸类武器）
var biggerBang: int = 0
## 分裂爆数量：>0 表示已获得 ClusterExplode（仅爆炸类武器）
var clusterExplode: int = 0
## 已处理碰撞的对象列表（避免重复伤害）
var excludeObj: Array = []
## 烟雾效果预加载
var smoke: PackedScene = preload("res://scene/fx/smoke.tscn")


## 音效节点
@onready var sound: AudioStreamPlayer2D = $sound
## 冷却计时器节点
@onready var timer: Timer = $Timer


## 冷却计时器回调
# 当延迟时间结束时，允许再次射击
func _on_timer_timeout() -> void:
	canShoot = true


## 射击方法（抽象）
# 子类必须重写此方法实现具体射击逻辑
# @param _angle 射击方向（Vector2）
func fire(_angle: Vector2) -> void:
	pass


## 命中特效要抬高多少像素
# 碰撞体是"地面脚印"，贴图是竖起来的；不补偿的话烟雾会落在墙角
## 命中判定射线的高度：角色身体中心
##
## 玩家/敌人的原点都在脚底，碰撞体挂在 y = -15，射线必须走这个高度，
## 否则会从敌人脚下穿过去（表现就是“某些方向打不到”）。
const HIT_ORIGIN_HEIGHT: float = -15.0


## 命中判定的射线起点：身体中心（与美术枪口无关）
func hitOrigin() -> Vector2:
	return global_position + Vector2(0, HIT_ORIGIN_HEIGHT)


## 命中判定的射线终点
##
## 视觉枪口有偏移，判定从身体中心出发，所以把偏移长度补进射程，
## 保证 8 个方向的有效距离一致。
func hitEnd(dir: Vector2) -> Vector2:
	return hitOrigin() + dir * (float(wRange) + muzzleOffset(dir).length())


## 曳光终点（局部坐标）
##
## 沿瞄准方向 dir 从美术枪口出发，长度取「身体中心 → 命中点」在 dir 上的投影。
## 这样线始终和瞄准方向平行；直接把枪口连到命中点会看起来是斜的。
func tracerEnd(muzzle: Vector2, dir: Vector2, hitWorld: Vector2) -> Vector2:
	var centerLocal := Vector2(0, HIT_ORIGIN_HEIGHT)
	var toHit: Vector2 = (hitWorld - global_position) - centerLocal
	return muzzle + dir * maxf(toHit.dot(dir), 0.0)


## 当前方向的视觉枪口（局部坐标，只用于摆贴图和画曳光）
func muzzleOffset(dir: Vector2) -> Vector2:
	var idx: int = wrapi(int(dir.angle() / (PI / 4)), 0, 8)
	var v: Variant = offsetDir.get(idx, Vector2.ZERO)
	return v if v is Vector2 else Vector2.ZERO


func resolveHitLift(collider: Node2D) -> float:
	if collider == null or not is_instance_valid(collider):
		return 0.0

	var n = collider
	# 角色的受击区是 Area2D，真正的数据挂在 owner（角色本体）上
	if n is Area2D and n.owner != null and is_instance_valid(n.owner) and n.get("hitLift") == null:
		n = n.owner

	var v = n.get("hitLift")
	if v != null:
		return float(v)
	if n is StaticBody2D:
		return DEFAULT_STATIC_WALL_LIFT
	return 0.0


## 添加烟雾效果
# 在指定位置创建烟雾粒子效果
# @param pos 烟雾生成位置（Vector2）
func addSmoke(pos: Vector2) -> void:
	var temp = smoke.instantiate()
	temp.global_position = pos
	temp.type = Game.smokeType.SmokeCloud
	get_tree().current_scene.add_child(temp)


## 没打中任何物体时，终点是否已飞出**可活动区域**
##
## 注意用的是 getPlayRect()（相机可视/可走区域），不是整张地图：
## 只有射线一路飞到区域外沿时才算“打到边界”，才需要烟雾。
func outOfPlayArea(to: Vector2) -> bool:
	return not MapData.getPlayRect().has_point(to)


## 没打中时的烟雾位置：夹到可活动区域的边界上
func noHitSmokePos(to: Vector2) -> Vector2:
	var r: Rect2 = MapData.getPlayRect()
	return to.clamp(r.position, r.end)
