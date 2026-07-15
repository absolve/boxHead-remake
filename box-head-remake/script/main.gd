extends Node2D

## 主脚本（调试用）
# 用于调试的主场景脚本
# 显示地图网格和当前语言信息


## 初始化
func _ready():
	# 打印当前系统语言
	print(OS.get_locale_language())


## 绘制
# 绘制地图网格（调试用）
func _draw() -> void:
	for i in range(27):
		draw_line(Vector2(i * MapData.cellSize, 0), Vector2(i * MapData.cellSize, MapData.cellSize * 26), Color.GRAY, 0.5, true)
	for i in range(27):
		draw_line(Vector2(0, i * MapData.cellSize), Vector2(MapData.cellSize * 26, i * MapData.cellSize), Color.GRAY, 0.5, true)