extends Node

#武器类型
enum weaponType{HandGun,Railgun,Rocket,Shotgun,
				UZI,Mine,RemoteMine,Wall,Barrel,Grenade }
#物体类型
enum itemType{Box=99,Mine,RemoteMine,Wall,Barrel,Grenade,RocketBullet,Explosion}

#奖励箱子的内容
enum boxContent{Railgun=500,Rocket,Shotgun,
				UZI,Mine,RemoteMine,Wall,Barrel,Grenade}

#武器名字
const weaponName={
	weaponType.HandGun:'HandGun',
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

enum smokeType{RocketSmoke=200,SmokeCloud}

@warning_ignore("unused_signal")
signal weaponUpgrade
@warning_ignore("unused_signal")
signal pickItem
