extends Node2D

## 音效工具类单例
# 负责管理游戏中的UI音效，如点击、切换、开始关卡等


## 点击音效节点
@onready var click = $click

## 切换音效节点
@onready var change = $change

## 开始关卡音效节点
@onready var startLevel = $startLevel


## 播放点击音效
func playClick():
	click.play()


## 播放切换音效
func playChange():
	change.play()


## 播放开始关卡音效
func playStartLevel():
	startLevel.play()
