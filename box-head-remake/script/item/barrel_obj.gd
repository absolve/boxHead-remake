extends "res://script/item/item.gd"

## 油桶物体脚本
# 继承自item.gd，实现油桶的逻辑
# 被击中时会爆炸，支持分裂成多个小爆炸


## 伤害值
@export var damage: int = 0

@export var wRange: int = 0 #爆炸范围


## 爆炸效果场景预加载
var explosion: PackedScene = preload("res://scene/fx/explosion.tscn")

## 爆炸烟团（原版 Effect.SmokeCloud 的 15 帧）
var smoke: PackedScene = preload("res://scene/fx/smoke.tscn")

## 是否正在爆炸中
var startExploding: bool = false

## 分裂爆炸数量
var splitExplosion: int = 0


## 初始化
func _ready() -> void:
	syncFromTable()


## 场景预摆的油桶（不是武器放置的）从数值表取伤害
## .tscn 里烘死的 damage 是历史旧值（4），不覆盖的话爆炸只有 4 伤害
func syncFromTable() -> void:
	if fromWeapon:
		return
	if not MapData.allWeaponData.has(Game.weaponType.Barrel):
		return
	var d: Dictionary = MapData.allWeaponData[Game.weaponType.Barrel]
	damage = d['damage']
	splitExplosion = d.get('splitExplosion', 0)
	biggerBang = d.get('biggerBang', 0)
	clusterExplode = d.get('clusterExplode', 0)


## 武器升级处理
# 根据武器类型更新油桶属性
# @param weaponType 武器类型（Game.weaponType枚举值）
func weaponUpgrade(weaponType: int) -> void:
	if weaponType == Game.weaponType.Barrel:
		var d: Dictionary = MapData.allWeaponData[Game.weaponType.Barrel]
		damage = d['damage']
		splitExplosion = d.get('splitExplosion', 0)
		biggerBang = d.get('biggerBang', 0)
		clusterExplode = d.get('clusterExplode', 0)


## 受伤处理
# 被击中后触发爆炸
# @param _damage 伤害值（int）
## 受击；签名与角色一致（爆炸会传 4 个参数，其余忽略）
func hit(_damage: int, _attackPos: Vector2 = Vector2.ZERO,
		_knockDir: Vector2 = Vector2.ZERO, _fromExplosion: bool = false) -> void:
	if startExploding:
		return

	startExploding = true

	# 延迟3帧后爆炸
	for i in range(3):
		await get_tree().physics_frame

	# 创建主爆炸
	var temp = explosion.instantiate()
	temp.global_position = global_position
	temp.damage = damage
	temp.biggerBang = biggerBang
	temp.clusterExplode = clusterExplode
	get_tree().current_scene.add_child(temp)

	# 爆炸烟团（只跟主爆炸走，分裂的小爆炸不再各来一团）
	var s = smoke.instantiate()
	s.global_position = global_position
	s.type = Game.smokeType.ExplosionSmoke
	get_tree().current_scene.add_child(s)

	# 如果配置了分裂爆炸，创建多个小爆炸
	if splitExplosion > 0:
		for i in range(splitExplosion):
			var t = explosion.instantiate()
			t.damage = damage
			t.biggerBang = 0
			t.clusterExplode = 0
			t.global_position = global_position + Vector2.RIGHT.rotated(i * ((2 * PI) / splitExplosion)) * 15
			get_tree().current_scene.add_child(t)
			for z in range(3):
				await get_tree().physics_frame

	# 销毁油桶
	queue_free()
