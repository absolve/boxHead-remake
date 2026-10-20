extends TurnState

## 恶魔的 Turn 状态 —— 原地转身。
##
## 逻辑全部在 [TurnState]（script/fsm/turn_state.gd），这里只保留恶魔自己的入口。
## 恶魔素材目前没有 rotate 动画，进入后会在下一个物理帧直接对齐朝向再交棒。
