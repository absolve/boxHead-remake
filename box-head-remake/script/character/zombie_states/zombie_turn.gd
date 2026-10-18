extends State

## Turn 状态 —— 原地转身（播 rotate 动画）
##
## 对应原版僵尸的旋转动画：8 个朝向 × 每 45° 若干子帧（本素材 32 帧 / 每 45° 4 帧）。
##
## 旧实现的问题，这里一并修掉：
##   1) **会绕整圈**：旧代码每物理帧 `frame + 1` 然后判断"是否等于目标帧"。
##      如果一开始就已经在目标帧，或者单帧内推进了多帧，就会直接跨过目标帧，
##      于是永远不相等，一直转到绕满 32 帧才停。
##      现在：进入时先判断"已在目标帧 → 立刻完成"，推进时"一到目标帧就停"。
##   2) 旋转方向按最短路径决定（>180° 反向转），不会为了 45° 绕一大圈。
##   3) 帧推进按时间（turnFrameSpeed 帧/秒）而不是每物理帧 +1，
##      帧率高低不影响转身快慢。
##   4) 没有 rotate 素材时直接瞬间转身，不会报错卡死。
##
## 切换参数（msg）：
##   to   = 目标朝向 0..7
##   next = 转完之后进哪个状态（默认 Chase）

## 宿主
var z: Zombie:
	get:
		return actor as Zombie

## 目标朝向
var targetAngle: int = 0
## 转完后的下一个状态
var nextState: StringName = &"Chase"
## 旋转方向：+1 顺时针，-1 逆时针
var stepDir: int = 1
## rotate 每个朝向占用几帧（32 帧 / 8 方向 = 4；换成 128 帧素材也自适应）
var framesPerDir: int = 4
## 总帧数
var totalFrames: int = 32
## 不足一帧的时间累积
var frameAcc: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	targetAngle = wrapi(int(msg.get("to", z.angle)), 0, 8)
	nextState = StringName(str(msg.get("next", "Chase")))
	z.velocity = Vector2.ZERO
	frameAcc = 0.0

	# 没有旋转素材 → 直接瞬间转身
	# （用 deferred 交棒：在 enter() 里同步再切状态会造成状态机重入）
	if not z.ani.sprite_frames.has_animation("rotate"):
		z.oldAngle = targetAngle
		z.angle = targetAngle
		stateMachine.transitionTo.call_deferred(nextState)
		return

	totalFrames = maxi(z.ani.sprite_frames.get_frame_count("rotate"), 8)
	framesPerDir = maxi(int(totalFrames / 8.0), 1)

	var fromFrame := (z.oldAngle * framesPerDir) % totalFrames
	var toFrame := targetFrame()
	var deltaFrames := (toFrame - fromFrame + totalFrames) % totalFrames
	stepDir = 1 if deltaFrames <= totalFrames * 0.5 else -1

	z.ani.stop()
	z.ani.animation = "rotate"
	z.ani.frame = fromFrame


func physicsUpdate(delta: float) -> void:
	# 已经对准了（包括进入时就在目标帧）→ 立刻完成，绝不空转
	if z.ani.frame == targetFrame():
		finishTurn()
		return

	frameAcc += delta * maxf(z.turnFrameSpeed, 1.0)
	while frameAcc >= 1.0:
		frameAcc -= 1.0
		z.ani.frame = wrapi(z.ani.frame + stepDir, 0, totalFrames)
		# 一到目标帧就停，不要跨过去
		if z.ani.frame == targetFrame():
			finishTurn()
			return


## 目标帧
func targetFrame() -> int:
	return (targetAngle * framesPerDir) % totalFrames


## 收尾：对齐朝向并交棒
func finishTurn() -> void:
	z.oldAngle = targetAngle
	z.angle = targetAngle
	stateMachine.transitionTo(nextState)
