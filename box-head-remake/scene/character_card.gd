extends Control


@onready var img=$img
@onready var idNode=$id
@onready var nameNode=$name

@export var ids=1:
	set(v):
		ids=v
		#idNode.text=str(ids)
		
@export var charName=''

var index=0
var player=[]

func _ready() -> void:
	print(ids)
	idNode.text=str(ids)
	for i in Game.playerName:
		var temp=load(i.img)
		player.append({'id':i.id,'name':i.name,'img':temp})
	showInfo()
		
func showInfo():
	nameNode.text=str(player[index].name)		
	img.texture=	player[index].img


func _on_btn_prev_pressed():
	index=wrapi(index-1,0,player.size())
	showInfo()
	SoundUtil.playClick()

func _on_btn_next_pressed():
	index=wrapi(index+1,0,player.size())
	showInfo()
	SoundUtil.playClick()
	
