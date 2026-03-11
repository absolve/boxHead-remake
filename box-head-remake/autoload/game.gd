extends Node

#武器类型
enum weaponType{HandGun,Railgun,Rocket,Shotgun,
				UZI,Mine,RemoteMine,Wall,Barrel,Grenade }

enum itemType{Box=99,Mine,RemoteMine,Wall,Barrel,Grenade}

#武器名字
const weaponName={
	weaponType.HandGun:'HandGun',
	weaponType.Railgun:'Railgun',
	weaponType.Rocket:'Rocket',
	weaponType.Shotgun:'Shotgun',
	weaponType.UZI:'UZI',
	weaponType.Mine:'other',
	weaponType.RemoteMine:'other',
	weaponType.Wall:'other',
	weaponType.Barrel:'other',
	weaponType.Grenade:'other',
}

@warning_ignore("unused_signal")
signal weaponUpgrade
@warning_ignore("unused_signal")
signal pickItem
