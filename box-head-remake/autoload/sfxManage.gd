extends Node

## 音效管理器单例
# 负责管理游戏中的特殊音效，如爆炸音效等


## SFX场景资源预加载
var sfx = preload("res://scene/sfx.tscn")

## 爆炸音效资源预加载
var ex = preload("res://sound/548_548 Effect.Explosion.mp3")


## 播放爆炸音效
# 创建一个临时的SFX节点播放爆炸音效，播放完成后自动销毁
func playExplosion():
	var temp = sfx.instantiate()
	temp.stream = ex
	temp.bus = "sfx"
	add_child(temp)
