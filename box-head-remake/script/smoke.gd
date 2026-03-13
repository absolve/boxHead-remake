extends AnimatedSprite2D

@export var type:Game.smokeType=Game.smokeType.RocketSmoke

func _ready() -> void:
	if type==Game.smokeType.RocketSmoke:
		play("0")
	elif type==Game.smokeType.SmokeCloud:
		play("0")
	await animation_finished
	queue_free()
