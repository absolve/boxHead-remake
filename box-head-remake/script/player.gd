extends CharacterBody2D

@onready var ani=$ani

var angle=0  #移动
var speed=50 #移动速度
var playerId=1
var currAni="stand"

func _ready():
	pass
	
	
func  _physics_process(_delta):
	currAni="stand"
	var input_dir = Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
	if input_dir.length() != 0:
		angle = input_dir.angle() / (PI/4)
		angle = wrapi(int(angle), 0, 8)
		currAni="walk"
	velocity = input_dir * speed
	move_and_slide()
	ani.play(currAni+"_%s"%playerId+"_%s"%angle)
