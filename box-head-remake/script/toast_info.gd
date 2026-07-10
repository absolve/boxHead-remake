extends Control

var labelList = []
var label = preload("res://scene/toast_label.tscn")


func _ready() -> void:
	#display('1111111111111')
	pass

func display(_str: String, color: Color = Color.WHITE):
	var temp = label.instantiate()
	temp.remove.connect(removeLabel)
	temp.s = _str
	temp.color = color
	add_child(temp)
	labelList.push_front(temp)
	for i in range(labelList.size()):
		if labelList[i] != null:
			labelList[i].movePos(i)
	

func removeLabel(node):
	for i in labelList:
		if i == node:
			labelList.erase(i)
			break
