class_name StateMachine
extends Node

## StateMachine —— 节点式有限状态机（参考 AwesomeTanks2 的 GDQuest 风格 FSM）
##
## 场景结构（zombie.tscn 里）：
##   [zombie (CharacterBody2D, script: zombie.gd)]
##   └─ [StateMachine (script: state_machine.gd)]
##       ├─ Spawn   (script: zombie_spawn.gd,  extends State)
##       ├─ Chase   (script: zombie_chase.gd)
##       ├─ Turn    (script: zombie_turn.gd)
##       ├─ Attack  (script: zombie_attack.gd)
##       ├─ Hurt    (script: zombie_hurt.gd)
##       └─ Dead    (script: zombie_dead.gd)
##
## 约定：
##   - actor：状态机宿主，默认取 get_parent()（状态机挂在宿主下）。
##   - initialState：初始状态子节点名；留空则取第一个 State 子节点。
##   - 状态名按节点名注册（大小写不敏感）。
##   - 每物理帧转发 physicsUpdate 并累加 stateTime；每渲染帧转发 processUpdate。
##   - transitionTo(name, msg)：exit 旧状态 → enter 新状态 → 广播 stateChanged。
##
## 与参考实现的一处差异：初始状态的切换用 call_deferred 延后到本帧末。
## 子节点的 _ready 早于父节点，若立刻 enter()，状态里访问 actor 的 @onready 变量时
## 它们还没赋值（会是 null）。延后一帧后父节点的 _ready 已经跑完，宿主字段可用。


signal stateChanged(fromName: StringName, toName: StringName)


## 宿主（为空时取父节点）
@export var actor: Node2D = null

@export var actorPath: NodePath = NodePath("..")

## 初始状态子节点名（留空 = 自动取第一个 State 子节点）
@export var initialState: StringName = &""

## 是否在 _ready 后自动启动（关闭则由宿主自行调用 start()）
@export var autostart: bool = true


## 状态名(小写) -> State
var states: Dictionary = {}

## 当前状态
var currentState: State = null

## 置 false 可整体暂停 AI（死亡/冰冻）
var enabled: bool = true

var lastState: StringName = &""


func _ready() -> void:
	if actor == null:
		if not actorPath.is_empty():
			actor = get_node_or_null(actorPath) as Node2D
		if actor == null:
			actor = get_parent() as Node2D

	for child in get_children():
		if child is State:
			registerState(child)

	if autostart:
		# 见文件头说明：必须延后，等宿主的 _ready 跑完
		start.call_deferred()


## 启动状态机。name 非空时用它覆盖 initialState。
func start(name_: StringName = &"") -> void:
	if currentState != null:
		return

	var target: StringName = name_ if name_ != &"" else initialState
	if target != &"" and not hasState(target):
		push_warning("StateMachine %s: initial state '%s' not found" % [name, target])
		target = &""

	if target == &"":
		for child in get_children():
			if child is State:
				target = child.name as StringName
				break

	if target != &"":
		transitionTo(target)


func registerState(s: State) -> void:
	var key: StringName = StringName(str(s.name).to_lower())
	states[key] = s
	s.stateMachine = self
	s.actor = actor if actor is Node2D else get_parent() as Node2D
	s.stateTime = 0.0


func hasState(name_: StringName) -> bool:
	return states.has(StringName(str(name_).to_lower()))


## 切换状态。name 用状态子节点名（大小写不敏感）。
func transitionTo(name_: StringName, msg: Dictionary = {}) -> void:
	var key: StringName = StringName(str(name_).to_lower())
	if not states.has(key):
		push_warning("StateMachine %s: no state named '%s'" % [self.name, name_])
		return

	var next: State = states[key]

	if next == currentState:
		# 允许重入（例如刷新计时）
		if currentState != null:
			currentState.exit()
			currentState.enter(msg)
			currentState.stateTime = 0.0
			stateChanged.emit(lastState, name_)
		return

	lastState = currentState.name as StringName if currentState != null else &""
	if currentState != null:
		currentState.exit()
	currentState = next
	next.enter(msg)
	next.stateTime = 0.0
	stateChanged.emit(lastState, name_)


## 供外部（冻结/解冻、指定初始状态）强制当前状态处理事件
func sendEvent(methodName: StringName, arg: Variant = null) -> void:
	if currentState != null and currentState.has_method(methodName):
		if arg == null:
			currentState.call(methodName)
		else:
			currentState.call(methodName, arg)


func getCurrentState() -> State:
	return currentState


## 当前状态名（未启动时为空）
func currentName() -> StringName:
	return currentState.name as StringName if currentState != null else &""


func _physics_process(delta: float) -> void:
	if not enabled or currentState == null:
		return
	currentState.stateTime += delta
	currentState.physicsUpdate(delta)


func _process(delta: float) -> void:
	if not enabled or currentState == null:
		return
	currentState.processUpdate(delta)
