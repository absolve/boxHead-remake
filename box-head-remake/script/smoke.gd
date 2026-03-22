extends AnimatedSprite2D

@export var type:Game.smokeType=Game.smokeType.RocketSmoke

func _ready() -> void:
	if type==Game.smokeType.RocketSmoke:
		play("0")
	elif type==Game.smokeType.SmokeCloud:
		scale=Vector2(0.2,0.2)
		position.y-=10
		play("1")
	await animation_finished
	queue_free()
