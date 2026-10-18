class_name State
extends Node

## State —— 有限状态机中的单个状态节点（参考 AwesomeTanks2 的 GDQuest 风格 FSM）
##
## 使用方式：
##   1) 在角色的 StateMachine 节点下挂一个 Node，脚本 `extends State`；
##   2) StateMachine._ready 会统一注入 stateMachine / actor，并按节点名注册；
##   3) 各状态实现 enter() / exit() / physicsUpdate() / processUpdate()；
##   4) 想切状态就调用 transitionTo("状态节点名", msg)。
##
## 设计约定：
##   - 状态自身不持有宿主逻辑，只通过 actor 访问宿主（这里是 zombie）；
##   - 状态只声明"我想去哪"，真正的切换由 StateMachine 统一执行；
##   - 每帧更新由机器转发给当前状态，避免宿主里手写一堆 if/else 分支。

## 状态机（由父级 StateMachine 节点注入）
var stateMachine: StateMachine = null

## 状态机所属宿主（zombie），由 state_machine.actor 下发
var actor: Node2D = null

## 本状态已持续时长（enter 时清零，由 StateMachine 每物理帧累加）
var stateTime: float = 0.0


## 进入状态（首次进入或由其它状态切换而来）。msg 可携带切换参数。
func enter(_msg: Dictionary = {}) -> void:
	pass


## 离开状态（切走前调用一次，用于清理或恢复属性）
func exit() -> void:
	pass


## 每物理帧更新；仅当本状态是当前状态时被调用
func physicsUpdate(_delta: float) -> void:
	pass


## 每渲染帧更新（可选；AI 逻辑一般放 physicsUpdate）
func processUpdate(_delta: float) -> void:
	pass


## 便捷：请求状态机切换到其它状态
func transitionTo(targetName: StringName, msg: Dictionary = {}) -> void:
	if stateMachine != null:
		stateMachine.transitionTo(targetName, msg)
