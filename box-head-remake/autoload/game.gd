extends Node

## 全局游戏状态管理单例
# 负责定义游戏中所有枚举类型、常量和全局信号
# 作为自动加载节点，可在任何脚本中通过 Game.xxx 访问


## 武器类型枚举
# 定义游戏中所有可用武器的类型标识
enum weaponType {
	Pistol,       # 手枪（初始武器）
	Railgun,      # 轨道炮（高穿透武器）
	Rocket,       # 火箭发射器（发射火箭弹）
	Shotgun,      # 霰弹枪（扇形散射攻击）
	UZI,          # UZI冲锋枪（连发射击）
	Mine,         # 地雷（放置后触发爆炸）
	ChargePack,   # 充电包（定时爆炸装置）
	Wall,         # 墙壁（临时障碍物）
	Barrel,       # 油桶（可放置的爆炸物）
	Grenade       # 手榴弹（投掷后弹跳爆炸）
}

## 物品类型枚举
# 定义游戏场景中可交互物品的类型
enum itemType {
	Box = 99,           # 奖励箱子
	Mine,               # 地雷物体
	ChargePack,         # 充电包物体
	Wall,               # 墙壁物体
	Barrel,             # 油桶物体
	Grenade,            # 手榴弹物体
	RocketBullet,       # 火箭弹
	Explosion           # 爆炸效果
}

## 奖励箱子内容枚举
# 定义打开箱子后可能获得的奖励类型
enum boxContent {
	Railgun = 500,      # 轨道炮
	Rocket,             # 火箭发射器
	Shotgun,            # 霰弹枪
	UZI,                # UZI冲锋枪
	Mine,               # 地雷
	ChargePack,         # 充电包
	Wall,               # 墙壁
	Barrel,             # 油桶
	Grenade,            # 手榴弹
	Life                # 生命恢复
}

## 角色类型枚举
# 定义游戏中所有角色的类型标识
enum roleType {
	Player = 400,       # 玩家
	Zombie,             # 僵尸敌人
	Devil               # 恶魔敌人
}

## 武器名称映射
# 将武器类型枚举转换为可读的英文名称
const weaponName = {
	weaponType.Pistol: 'Pistol',
	weaponType.Railgun: 'Railgun',
	weaponType.Rocket: 'Rocket',
	weaponType.Shotgun: 'Shotgun',
	weaponType.UZI: 'UZI',
	weaponType.Mine: 'Mine',
	weaponType.ChargePack: 'ChargePack',
	weaponType.Wall: 'Wall',
	weaponType.Barrel: 'Barrel',
	weaponType.Grenade: 'Grenade',
}

## 烟雾类型枚举
# 定义不同类型的烟雾效果
enum smokeType {
	RocketSmoke = 200,  # 火箭弹烟雾轨迹
	SmokeCloud          # 爆炸烟雾云
}

## 爆炸类型枚举
# 定义不同类型的爆炸效果
enum explosionType {
	normal = 600,       # 普通地面爆炸
	air                  # 空中爆炸
}

## 标记点类型枚举
# 定义地图上特殊标记点的类型
enum markerPointType {
	ZombieSpawnPoint,   # 僵尸出生点
	DevilSpawnPoint     # 恶魔出生点
}

## 玩家状态枚举
# 定义玩家角色的各种状态
enum playerState {
	Idle,               # 空闲状态
	hurt,               # 受伤状态
	dead                # 死亡状态
}

## 敌人状态枚举
# 定义敌人角色的各种状态
enum enemyState {
	Idle,               # 空闲状态
	ffp,                # 流场寻路状态（Flow Field Pathfinding）
	findDir,            # 寻找移动方向状态
	hurt,               # 受伤状态
	fallDown,           # 倒地状态
	dead,               # 死亡状态
	attack,             # 攻击状态
	rotate,             # 旋转状态
	rotate_wait,        # 旋转等待状态
	init                # 初始化状态（移动到出生点）
}

## 地图标志枚举
# 定义地图上各种标志点的类型
enum mapSign {
	Player = 700,       # 玩家出生点标志
	Zombie,             # 僵尸出生点标志
	Devil,              # 恶魔出生点标志
	Box                 # 箱子刷新点标志
}

## 地图标志方向枚举
# 定义标志点的朝向（用于敌人出生时的初始方向）
enum mapSignDir {
	Left,               # 向左
	Right,              # 向右
	Up,                 # 向上
	Down                # 向下
}

## 地图列表配置
# 存储所有可用地图的信息（名称、ID、预览图）
var mapId = [ 
	{'name': 'Boxy', 'id': 0, 'img': "res://sprite/409.jpg"}, 
	{'name': 'Buttons', 'id': 2, 'img': "res://sprite/427.png"},
	{'name': 'Mazey', 'id': 3, 'img': "res://sprite/431.png"}, 
	{'name': 'Gladiator', 'id': 4, 'img': "res://sprite/435.jpg"},
	{'name': 'Strip', 'id': 5, 'img': "res://sprite/439.png"}, 
	{'name': 'Tight', 'id': 6, 'img': "res://sprite/443.png"},
	{'name': 'Columns', 'id': 7, 'img': "res://sprite/447.jpg"}, 
	{'name': 'Castle', 'id': 8, 'img': "res://sprite/451.jpg"},
	{'name': 'Big Boxy', 'id': 9, 'img': "res://sprite/455.jpg"}, 
	{'name': 'Recty', 'id': 10, 'img': "res://sprite/460.png"},
	{'name': 'Patchy', 'id': 11, 'img': "res://sprite/464.jpg"}, 
	{'name': 'Forrest box', 'id': 12, 'img': "res://sprite/468.jpg"},
	{'name': 'Tight 2', 'id': 13, 'img': "res://sprite/472.png"}, 
	{'name': 'Massive', 'id': 14, 'img': "res://sprite/476.png"},
	{'name': 'Thin line', 'id': 15, 'img': "res://sprite/480.png"}, 
	{'name': '4 Castles', 'id': 16, 'img': "res://sprite/484.png"},
	{'name': 'The strips', 'id': 17, 'img': "res://sprite/488.png"}, 
	{'name': 'Big one', 'id': 18, 'img': "res://sprite/492.jpg"}
]

## 玩家角色列表配置
# 存储所有可用玩家角色的信息（名称、ID、头像）
var playerName = [ 
	{'name': 'bambo', 'id': 1, 'img': "res://sprite/ui/12.png"},
	{'name': 'bon', 'id': 2, 'img': "res://sprite/ui/2.png"},
	{'name': 'bind', 'id': 3, 'img': "res://sprite/ui/3.png"},
	{'name': 'bert', 'id': 4, 'img': "res://sprite/ui/4.png"}
]

## 全局信号定义

# 武器升级信号
# 当玩家连杀达到一定数量触发武器升级时发出
@warning_ignore("unused_signal")
signal weaponUpgrade

# 拾取物品信号
# 当玩家拾取物品时发出
@warning_ignore("unused_signal")
signal pickItem

# 敌人被击杀信号
# 参数：被击杀敌人的位置（Vector2）
@warning_ignore("unused_signal")
signal enemyKilled

# 消息通知信号
# 参数：通知文本（String），通知颜色（Color，可选）
@warning_ignore("unused_signal")
signal notice


## 将箱子内容类型转换为名称
# @param type 箱子内容类型（boxContent枚举值）
# @return 对应的英文名称（String）
func getBoxContentName(type):
	if type == boxContent.Railgun:
		return 'Railgun'
	elif type == boxContent.Rocket:
		return 'Rocket'
	elif type == boxContent.Shotgun:
		return 'Shotgun'
	elif type == boxContent.UZI:
		return 'UZI'
	elif type == boxContent.Mine:
		return 'Mine'
	elif type == boxContent.ChargePack:
		return 'ChargePack'
	elif type == boxContent.Wall:
		return 'Wall'
	elif type == boxContent.Barrel:
		return 'Barrel'
	elif type == boxContent.Grenade:
		return 'Grenade'
	elif type == boxContent.Life:
		return 'Life'

## 将箱子内容类型转换为武器类型
# @param type 箱子内容类型（boxContent枚举值）
# @return 对应的武器类型（weaponType枚举值），无对应时返回null
func getBoxContentWeaponType(type):
	if type == boxContent.Railgun:
		return weaponType.Railgun
	elif type == boxContent.Rocket:
		return weaponType.Rocket
	elif type == boxContent.Shotgun:
		return weaponType.Shotgun
	elif type == boxContent.UZI:
		return weaponType.UZI
	elif type == boxContent.Mine:
		return weaponType.Mine
	elif type == boxContent.ChargePack:
		return weaponType.ChargePack
	elif type == boxContent.Wall:
		return weaponType.Wall
	elif type == boxContent.Barrel:
		return weaponType.Barrel
	elif type == boxContent.Grenade:
		return weaponType.Grenade

## 将武器类型转换为箱子内容类型
# @param type 武器类型（weaponType枚举值）
# @return 对应的箱子内容类型（boxContent枚举值），无对应时返回null
func WeaponType2BoxContent(type):
	if type == weaponType.Railgun:
		return boxContent.Railgun
	elif type == weaponType.Rocket:
		return boxContent.Rocket
	elif type == weaponType.Shotgun:
		return boxContent.Shotgun
	elif type == weaponType.UZI:
		return boxContent.UZI
	elif type == weaponType.Mine:
		return boxContent.Mine
	elif type == weaponType.ChargePack:
		return boxContent.ChargePack
	elif type == weaponType.Wall:
		return boxContent.Wall
	elif type == weaponType.Barrel:
		return boxContent.Barrel
	elif type == weaponType.Grenade:
		return boxContent.Grenade