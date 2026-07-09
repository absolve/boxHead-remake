extends Label

signal  remove

var displayTime=2 #显示 秒
var s:String:  #字符串
	set(value):
		s=value
		text=str(value)
var margin={'top':10,'bottom':10,'left':10,'right':10}
var screenSize:Rect2
var color:Color=Color.WHITE
var fixedOffsetY=70  #底部偏移位置

func _ready() -> void:
	screenSize=get_viewport_rect()
	modulate =color
	init()
	
func init():
	position=Vector2(screenSize.size.x/2-size.x/2,screenSize.size.y-fixedOffsetY-size.y-margin.bottom/2)			
	var tween=create_tween()
	tween.tween_property(self,"modulate:a", 0, 0)
	tween.tween_property(self,"modulate:a", 1, 0.5)
	tween.tween_interval(displayTime)
	tween.tween_property(self,"modulate:a", 0, 1)
	tween.tween_callback(removeLabel)
	

func movePos(index):
	var tween=create_tween()
	var offsetY=0
	offsetY=screenSize.size.y-fixedOffsetY-(size.y+margin.bottom/2)*(index+1)
	tween.tween_property(self, "position",Vector2(position.x,offsetY),0.4)	
	tween.set_trans(Tween.TRANS_SINE)
	
	
func removeLabel():
	remove.emit(self)
	queue_free()
