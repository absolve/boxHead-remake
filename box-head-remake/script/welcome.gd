extends Node2D

@onready var label=$Control/vbox/Label

var noise: FastNoiseLite=null
var startShake=false
@export var shake_strength: float = 8.0
@export var shake_duration: float = 0.4
@export var shake_speed: float = 15.0  # 抖动变化速度

func _ready():
	noise=FastNoiseLite.new()
	noise.seed = randi()
	noise.fractal_octaves = 4
	

	
func _process(_delta):
	if startShake:
		# 用噪声生成偏移（2D）
		var offset_x: float = noise.get_noise_2d(noise.seed, 0) * shake_strength 
		var offset_y: float = noise.get_noise_2d(noise.seed, 10) * shake_strength 
		var offset: Vector2 = Vector2(offset_x, offset_y)
		label.position+=offset
		print(1)


func _on_label_mouse_entered():
	startShake=true
	pass # Replace with function body.


func _on_label_mouse_exited():
	startShake=false
	pass # Replace with function body.
