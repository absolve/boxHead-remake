class_name TurnState
extends State

## Turn 状态 —— 原地转身（播 rotate 动画）
##
## 僵尸和恶魔共用这一份实现（各自的 zombie_turn.gd / devil_turn.gd 只负责 extends）。
## 对应原版生物的旋转动画：8 个朝向 × 每 45° 若干子帧（僵尸素材 32 帧 / 每 45° 4 帧）。
##
## 实现方式：**进入时把要走的路径算成一条定长的帧序列，之后按时间沿它推进。**
##   1) enter() 算好起始帧 startFrame、方向 stepDir、总帧数 stepCount：
##      沿最短路径（最多半圈），不会为了 45° 绕一大圈。
##   2) physicsUpdate() 只做一件事：`walked += delta * turnFrameSpeed`，
##      取整后夹在 stepCount 上再写回 ani.frame。
##      没有 while 循环、没有余数累积，所以：
##        - 一步最多走到终点，永远不会跨过目标帧；
##        - 低帧率下只会跳帧，不会永远转不完；
##        - stepCount == 0（进入时就已经对准）直接交棒，不空转。
##   3) 没有 rotate 素材（例如恶魔）时直接瞬间转身，不会报错卡死。
##
## 切换参数（msg）：
##   to   = 目标朝向 0..7
##   next = 转完之后进哪个状态（默认 Chase）


## 宿主
var host: Character:
	get:
		return actor as Character

## 目标朝向
var targetAngle: int = 0
## 转完后的下一个状态
var nextState: StringName = &"Chase"
## 旋转方向：+1 顺时针，-1 逆时针
var stepDir: int = 1
## 起始帧（enter 时按 oldAngle 对齐）
var startFrame: int = 0
## 沿 stepDir 还要走多少帧（0 = 已经对准）
var stepCount: int = 0
## 已经走过的帧数（浮点，按时间累积）
var walked: float = 0.0
## rotate 每个朝向占用几帧（32 帧 / 8 方向 = 4；换成 128 帧素材也自适应）
var framesPerDir: int = 4
## 总帧数
var totalFrames: int = 32


func enter(msg: Dictionary = {}) -> void:
	targetAngle = wrapi(int(msg.get("to", host.angle)), 0, 8)
	nextState = StringName(str(msg.get("next", "Chase")))
	host.velocity = Vector2.ZERO
	stepDir = 1
	stepCount = 0
	walked = 0.0

	# 没有旋转素材 → 不碰动画，stepCount 保持 0，下一个物理帧直接交棒
	if not host.ani.sprite_frames.has_animation("rotate"):
		return

	totalFrames = maxi(host.ani.sprite_frames.get_frame_count("rotate"), 8)
	framesPerDir = maxi(int(totalFrames / 8.0), 1)
	startFrame = (host.oldAngle * framesPerDir) % totalFrames

	# 沿最短路径走：超过半圈就反向
	var deltaFrames := (targetFrame() - startFrame + totalFrames) % totalFrames
	stepDir = 1 if deltaFrames <= totalFrames * 0.5 else -1
	stepCount = deltaFrames if stepDir > 0 else totalFrames - deltaFrames

	host.ani.stop()
	host.ani.animation = "rotate"
	host.ani.frame = startFrame


func physicsUpdate(delta: float) -> void:
	# 没素材 / 进入时就已经对准 → 本帧直接交棒
	# （不写在 enter() 里：在状态切换过程中同步再切状态会造成状态机重入）
	if stepCount <= 0:
		finishTurn()
		return

	walked = minf(walked + delta * maxf(host.turnFrameSpeed, 1.0), float(stepCount))
	host.ani.frame = wrapi(startFrame + stepDir * int(walked), 0, totalFrames)
	if walked >= stepCount:
		finishTurn()


## 目标帧
func targetFrame() -> int:
	return (targetAngle * framesPerDir) % totalFrames


## 收尾：对齐朝向并交棒
func finishTurn() -> void:
	host.oldAngle = targetAngle
	host.angle = targetAngle
	stateMachine.transitionTo(nextState)
