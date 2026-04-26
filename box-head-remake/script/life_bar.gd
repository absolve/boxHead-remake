extends Control

@onready var bar=$TextureProgressBar
@onready var timer=$Timer

var tween:Tween=null
var alwaysShows=false

@export var hp=10:
	set(val):
		hp=val
		bar.value=val
		if hp>0:
			showLifeBar()
		
@export var maxHp=10:
	set(val):
		maxHp=val
		bar.max_value=val

func _ready() -> void:
	bar.max_value=hp
	bar.value=hp
	showLifeBar()
	
	
	
func showLifeBar():
	if tween!=null && tween.is_valid():
		tween.kill()
	bar.modulate.a=1
	timer.start()
	
	
	
func _on_timer_timeout() -> void:
	tween=create_tween()
	tween.tween_property(bar,"modulate:a",0,0.5)
	
	
