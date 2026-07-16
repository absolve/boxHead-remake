extends AudioStreamPlayer2D

## 音效播放器脚本
# 用于播放临时音效的轻量级脚本
# 播放完毕后自动销毁


## 初始化
func _ready() -> void:
	# 开始播放音效
	play()
	
	# 等待播放完毕后销毁
	await finished
	queue_free()
