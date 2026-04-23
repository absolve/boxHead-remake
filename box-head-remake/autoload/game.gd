extends Node

#武器类型
enum weaponType {Pistol, Railgun, Rocket, Shotgun,
				UZI, Mine, ChargePack, Wall, Barrel, Grenade}
#物体类型
enum itemType {Box = 99, Mine, ChargePack, Wall, Barrel, Grenade, RocketBullet, Explosion}

#奖励箱子的内容
enum boxContent {Railgun = 500, Rocket, Shotgun,
				UZI, Mine, ChargePack, Wall, Barrel, Grenade}

#角色类型
enum roleType {Player = 400, Zombie, Devil}

#武器名字
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

#烟雾类型
enum smokeType {RocketSmoke = 200, SmokeCloud, }

#爆炸类型
enum explosionType {normal = 600, air}

#标记点类型
enum markerPointType{ZombieSpawnPoint,DevilSpawnPoint}

#玩家状态
enum playerState{Idle,hurt,dead}

enum enemyState {Idle, hurt, fallDown, dead,attack,rotate}


var mapId=[{'name':'Boxy','id':0,'img':"res://sprite/409.jpg"},{'name':'Buttons','id':2,'img':"res://sprite/427.png"},
			{'name':'Mazey','id':3,'img':"res://sprite/431.png"},{'name':'Gladiator','id':4,'img':"res://sprite/435.jpg"}
			,{'name':'Strip','id':5,'img':"res://sprite/439.png"},{'name':'Tight','id':6,'img':"res://sprite/443.png"}
			,{'name':'Columns','id':7,'img':"res://sprite/447.jpg"},{'name':'Castle','id':8,'img':"res://sprite/451.jpg"}
			,{'name':'Big Boxy','id':9,'img':"res://sprite/455.jpg"},{'name':'Recty','id':10,'img':"res://sprite/460.png"}
			,{'name':'Patchy','id':11,'img':"res://sprite/464.jpg"},{'name':'Forrest box','id':12,'img':"res://sprite/468.jpg"}
			,{'name':'Tight 2','id':13,'img':"res://sprite/472.png"},{'name':'Massive','id':14,'img':"res://sprite/476.png"}
			,{'name':'Thin line','id':15,'img':"res://sprite/480.png"},{'name':'4 Castles','id':16,'img':"res://sprite/484.png"}
			,{'name':'The strips','id':17,'img':"res://sprite/488.png"},{'name':'Big one','id':18,'img':"res://sprite/492.jpg"}]

var playerName=[{'name':'bambo','id':1,'img':"res://sprite/ui/12.png"},
				{'name':'bon','id':2,'img':"res://sprite/ui/2.png"},
				{'name':'bind','id':3,'img':"res://sprite/ui/3.png"},
				{'name':'bert','id':4,'img':"res://sprite/ui/4.png"}]

@warning_ignore("unused_signal")
signal weaponUpgrade
@warning_ignore("unused_signal")
signal pickItem
@warning_ignore("unused_signal")
signal enemyKilled
