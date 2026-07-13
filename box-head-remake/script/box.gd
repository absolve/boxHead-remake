extends "res://script/item.gd"

@onready var timer=$Timer
@onready var player=$player
@export var expiredTime = 0 # 过期时间

func _ready():
	if expiredTime!=0:
		timer.start(expiredTime)
	if MapData.weaponUnlock.size() > 0:
		content = Game.WeaponType2BoxContent(MapData.weaponUnlock[randi()%MapData.weaponUnlock.size()])
	
func _on_body_entered(body):
	#Game.pickItem.emit(content)
	var p = randi() % 10
	if body.hp < body.maxHp:
		if p >= 4:
			content = Game.boxContent.Life
			
	body.pickItem(content)
	Game.notice.emit("%s %s" % [tr("Pickup"), Game.getBoxContentName(content)])
	queue_free()


func _on_timer_timeout():
	player.play("fadeOut")
	await player.animation_finished
	queue_free()
