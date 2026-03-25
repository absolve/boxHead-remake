extends Node

#武器类型
enum weaponType{Pistol,Railgun,Rocket,Shotgun,
				UZI,Mine,RemoteMine,Wall,Barrel,Grenade }
#物体类型
enum itemType{Box=99,Mine,RemoteMine,Wall,Barrel,Grenade,RocketBullet,Explosion}

#奖励箱子的内容
enum boxContent{Railgun=500,Rocket,Shotgun,
				UZI,Mine,RemoteMine,Wall,Barrel,Grenade}

#武器名字
const weaponName={
	weaponType.Pistol:'Pistol',
	weaponType.Railgun:'Railgun',
	weaponType.Rocket:'Rocket',
	weaponType.Shotgun:'Shotgun',
	weaponType.UZI:'UZI',
	weaponType.Mine:'Mine',
	weaponType.RemoteMine:'RemoteMine',
	weaponType.Wall:'Wall',
	weaponType.Barrel:'Barrel',
	weaponType.Grenade:'Grenade',
}

#烟雾类型
enum smokeType{RocketSmoke=200,SmokeCloud,}

#爆炸类型
enum explosionType{normal=600,air}

enum enemyState{Idle,hurt,dead}

@warning_ignore("unused_signal")
signal weaponUpgrade
@warning_ignore("unused_signal")
signal pickItem
