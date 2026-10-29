# boxHead remake 代码设计规范（Code Design Guidelines）

> 本文档是本项目的**唯一编码规范**：手写代码、AI 生成代码、代码审查一律以它为准。
> 目的是让不同时间、不同人（或不同 AI）写出来的代码风格保持一致，降低阅读与维护成本。

| 项目 | 内容 |
| --- | --- |
| 适用项目 | boxHead remake（Godot 4.7，GDScript，GL Compatibility，640×480） |
| 文档版本 | v1.0 |
| 更新日期 | 2026-10-16 |
| 主要依据 | Godot 官方《GDScript style guide》《Static typing in GDScript》+ 本项目既定约定 |
| 数值依据 | **反编译文档见 `doc/`**（`doc/04-enemy-stats.md`、`doc/03-weapons.md`、`doc/02-pathfinding.md`）。数值/规则改动请以 `doc/` 为准，不要凭手感改 |

> ⚠️ **务必注意**：文中标注「**本项目约定**」的条目，是对 Godot 官方风格的**有意偏离**。
> 生成或审查代码时**不要**按官方默认风格去"纠正"它（例如把 camelCase 改成 snake_case、
> 把内置虚函数挪到文件开头、把显式类型改成 `:=`），否则会破坏全文一致性。

---

## 目录

- [0. 强制规则速查（写代码前必读）](#0-强制规则速查写代码前必读)
- [1. 格式规范](#1-格式规范)
- [2. 命名规范](#2-命名规范)
- [3. 类型与静态类型](#3-类型与静态类型)
- [4. 文档注释](#4-文档注释)
- [5. 代码顺序](#5-代码顺序)
- [6. 项目架构设计](#6-项目架构设计)
- [7. Godot 最佳实践](#7-godot-最佳实践)
- [8. 提交前审查清单](#8-提交前审查清单)

---

## 0. 强制规则速查（写代码前必读）

> 完整细节见后续章节；这里是压缩版，写代码前扫一眼。

1. **节点在场景里建，不在代码里搭**（§6.3）：能预置的结构写进 `.tscn`；
   只有运行期才确定数量的（子弹、敌人、爆炸）才用 `PackedScene` 实例化。
2. **禁止占用 Godot 内置名**（§2.2）：`name`、`position`、`scale`、`text`、`size` 等
   不能当变量名/参数名。
3. **`.tscn` / `.tres` 里不能写 `#` 注释**（§6.3），写了直接 `Parse Error`。
4. **所有声明写显式类型**（§3.1）。
5. **脚本顺序**（§5.1）：常量 → `@export` → 成员 → `@onready` → `_ready` → 自定义函数 → 内置虚函数。
6. **不要用正则在 `.tscn` 里改结构**：`animations`、节点块这类用工具或编辑器改，
   正则误伤过一次（吞掉整段动画、删掉 `ani` 节点）。

> 下面 12 条是最容易"跑偏"的地方，生成代码前先过一遍。

| # | 规则 | 备注 |
| --- | --- | --- |
| 1 | 函数、变量用 **camelCase** | 官方是 snake_case，**本项目不用** |
| 2 | 常量用 **CONSTANT_CASE**、类名用 **PascalCase** | 见 §2 |
| 3 | 不得占用 Godot 内置名 | 如 `position`/`scale`/`name`/`visible`/`get`/`set` |
| 4 | 顺序：`常量 → @export → 成员变量 → @onready → _ready → 自定义函数 → 其它内置虚函数放最后` | 本项目约定，与官方相反 |
| 5 | 成员 / 参数 / 返回值**显式声明类型** | 局部变量可省略类型；不用 `:=` 推断 |
| 6 | 私有成员**不加 `_` 前缀**（引擎回调除外） | `var attackDelay`，不是 `var _attackDelay` |
| 7 | 场景能设的属性在**编辑器 Inspector** 里设 | 不要全塞进代码 |
| 8 | 可复用功能先做**基础场景 + 基础脚本** | 子类只覆盖差异 |
| 9 | 缩进 **Tab**、行宽 ≤ 100、**UTF-8 无 BOM**、**LF** 换行 | 见 §1.1 |
| 10 | 注释符号后**必须一个空格**：`# 文字`、`## 文字` | 被注释掉的代码除外：`#print(...)` |
| 11 | **`.tscn` / `.tres` 里绝对不能写 `#` 注释** | 会整个场景加载失败，见 §6.3 |
| 12 | 玩家可见文案走 `tr()` + `lang/lang.zh.translation` | 不硬编码中文/英文 |
| 13 | 成员声明**连续写，中间不空行** | 同一类别内部不空行；类别之间可空一行，见 §1.3 |

---

## 1. 格式规范

### 1.1 文件与编码

- 换行用 **LF**（`\n`），不要 CRLF。
- 文件结尾保留**一个**换行。
- 编码 **UTF-8，无 BOM**。
  > **⚠️ 踩过的坑**：用 PowerShell `Set-Content -Encoding utf8` 改 `.tscn` 会写入 **UTF-8 BOM**，
  > Godot 直接报 `Parse Error: Expected '['`（首个字符不是 `[`），场景加载不出来。
  > 脚本化改 `.tscn` 时务必用 `UTF8Encoding($false)` / `encoding="utf-8"`（Python 默认无 BOM）。
- 缩进用 **Tab**，不用空格。
- 保存前用编辑器格式化：脚本编辑器内 `Ctrl + Alt + L`。

### 1.2 缩进

- 每个代码块比外层多一级缩进。
- 换行的**连续行**用**两级**缩进，以便与普通代码块区分。
- **例外**：数组、字典、枚举的续行只用**一级**缩进。

```gdscript
# 好：普通连续行用 2 级缩进
var need: int = clampf(level * 2.5,
		level * 1.2, 999)

# 好：数组 / 字典 / 枚举用 1 级缩进
const DIRS: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(0, 1),
]
```

### 1.3 空行

- 函数之间空**两行**；函数内部用**一行**分隔逻辑段落。
- 成员声明块内部（signal/enum/const/export/var/@onready）**不空行**。
  同类成员连续写，不要一个变量一个空行：

  ```gdscript
  # 好：连续声明
  @onready var btn: Button = $Control/vbox/btn_start
  @onready var btn_instructions: Button = $Control/vbox/btn_instructions
  @onready var btn_about: Button = $Control/vbox/btn_about

  # 不好：每个变量之间夹空行，浪费纵向空间
  @onready var btn: Button = $Control/vbox/btn_start

  @onready var btn_instructions: Button = $Control/vbox/btn_instructions

  @onready var btn_about: Button = $Control/vbox/btn_about
  ```

- 例外：**不同类别**的成员块之间可以空一行（例如 `@export` 块 → `@onready` 块），
  让"配置项"和"节点引用"分得开；同一类别内部仍然不空行。
- `##` 文档注释紧贴它所描述的成员，注释与成员之间不空行。

### 1.4 行宽

- 单行**不超过 100 字符**，尽量控制在 80 以内（便于并排看代码）。

### 1.5 一行一语句

```gdscript
# 好
if hp <= 0:
	die()

# 坏
if hp <= 0: die()
```

唯一例外是三元表达式：

```gdscript
nextState = "attack" if inRange else "chase"
```

### 1.6 多行语句排版

长条件、长表达式用**括号**换行（优于反斜杠），并把 `and` / `or` 放在**续行行首**。

```gdscript
if (
		position.x > 200 and position.x < 400
		and position.y > 300 and position.y < 400
):
	pass
```

### 1.7 不要多余的括号

```gdscript
# 好
if hasTarget():
	return

# 坏
if (hasTarget()):
	return
```

### 1.8 布尔运算符

用 `and` / `or` / `not`，不要 `&&` / `||` / `!`。

> 现有代码里存在 `if !MapData.checkHasMapItem(pos)` 这类旧写法，**触碰时再改**，不要全量替换。

### 1.9 注释

- 普通注释用 `#`、文档注释用 `##`，符号后**必须跟一个空格**。
- 被注释掉的**代码不加空格**：`#print("disabled")`。
- 优先把注释写在**独立一行**；行尾注释只用于很短的说明。
- 注释用中文，说明**为什么**这么做，而不是复述代码在做什么。
- 数值型常量旁建议注明出处（例如 `# 原版：CUpgrades.InitLists()`），便于日后对照 `doc/` 校正。

### 1.10 空白 / 引号 / 数字

- 运算符两侧、逗号后各留一个空格；不要为"对齐"加多余空格。
- 字符串默认用**双引号**；仅当能减少转义时才用单引号。
- 浮点数不省略前后 0：写 `0.234`、`13.0`（不写 `.234`、`13.`）。
- 十六进制用小写：`0xff0000`。
- 大数字用下划线分隔：`1_234_567_890`（小于 100 万的数一般不必）。

### 1.11 尾随逗号

多行数组 / 字典 / 枚举的最后一项**加尾随逗号**（便于 diff 与增删条目）；单行列表**不加**。

---

## 2. 命名规范

### 2.1 总表

| 对象 | 本项目约定 | 示例 | 来源 |
| --- | --- | --- | --- |
| 函数 | **camelCase** | `func startNextWave()` | 本项目约定（官方为 snake_case） |
| 变量 | **camelCase** | `var attackDelay` | 本项目约定（官方为 snake_case） |
| 私有函数 / 变量 | **camelCase，不加 `_` 前缀** | `var hasHit`、`func swing()` | 本项目约定（官方为 `_snake_case`） |
| 常量 | **CONSTANT_CASE** | `const CELL_SIZE = 32` | 官方 |
| 类名 `class_name` | **PascalCase** | `class_name Zombie` | 官方 |
| 节点名 | **camelCase** | `attackArea`、`spawnTimer` | 本项目约定（沿用现有场景，官方为 PascalCase） |
| 枚举名 | **camelCase** | `enum enemyState` | 本项目约定（因为全文都用 `Game.enemyState.Idle`） |
| 枚举成员 | **PascalCase** | `enemyState.Idle` | 本项目约定（沿用现有 11 个枚举） |
| 信号 | **camelCase，过去式** | `signal enemyKilled` | 官方过去式 + 本项目 camelCase |
| Autoload 单例 | **PascalCase** | `Game`、`MapData`、`SoundUtil` | 官方 |
| 脚本 / 场景文件名 | **snake_case** | `barrel_obj.gd`、`wall_shape_001.tscn` | 官方（避免跨平台大小写问题） |

> **例外**：**Godot 引擎回调必须保留 `_` 前缀**（`_ready`、`_process`、`_physics_process`、
> `_input`、`_draw`、`_exit_tree`、`_notification`、`_init` 等），它们由引擎按名字调用，改名即失效。
>
> **另一个例外**：编辑器信号面板自动生成的回调仍是 `_on_xxx_yyy`（如 `_on_spawn_timer_timeout`），
> 它们的方法名写死在 `.tscn` 的 `[connection method=...]` 里。**不要为了统一风格去改**，
> 那需要同时改场景文件，收益极低。

> **现状说明**：现有代码命名新旧混用（`mapData.gd` / `sfxManage.gd` 是 camelCase 文件名，
> `cellSize` / `weaponName` 是 camelCase 常量）。**新写代码一律按上表执行**；
> 改造旧文件时**只改本次触碰到的部分**，不要为了统一风格做全量重命名。

### 2.2 禁止占用 Godot 内置名（强制）

自定义变量 / 函数**不得**与 Godot 内置属性、方法、常量、信号重名，否则会产生遮蔽（shadowing）警告，
严重时导致运行期行为异常。

常见必须避开的名称（非完整清单）：

- **节点通用**：`name`、`owner`、`process_mode`、`scene_file_path`
- **`Node2D`**：`position`、`global_position`、`rotation`、`scale`、`skew`、`transform`、`z_index`、`visible`、`modulate`
- **`Control`**：`size`、`pivot_offset`、`focus_mode`、`theme`、`text`
- **`CollisionObject2D`**：`collision_layer`、`collision_mask`
- **`CharacterBody2D`**：`velocity`、`move_and_slide`、`move_and_collide`
- **常见方法**：`get`、`set`、`connect`、`call`、`free`、`queue_free`、`duplicate`、`to_string`
- **全局函数**：`abs`、`min`、`max`、`clamp`、`lerp`、`randf`、`randi`、`print`、`range`、`sign`、`snapped`

> 拿不准就去 Godot 类文档里搜同名项；编辑器出现 “shadowed variable” 警告即说明已踩线。
> 注意 `character.gd` 里的 `var angle` 是**安全**的（`Node2D` 只有 `rotation`，没有 `angle` 属性），
> 但 `var size`、`var scale`、`var position` 会被遮蔽，必须换名。

### 2.3 函数参数不得与成员变量同名（强制）

参数名与成员变量同名会产生**遮蔽**：函数体内引用的是参数，而不是你以为的成员。

```gdscript
# ❌ 错：参数 speed 遮蔽了 Zombie.speed 成员
func beginKnockback(dir: Vector2, speed: float) -> void:
	knockbackDelta = dir * speed          # 用的是参数，不是僵尸移动速度

# ✅ 对：换个参数名，语义也更清楚
func beginKnockback(dir: Vector2, knockSpeed: float) -> void:
	knockbackDelta = dir * knockSpeed
```

| 场景 | 做法 |
|---|---|
| 参数与成员同名 | 给参数换个更具体的名字（`speed` → `knockSpeed`、`damage` → `dmg`） |
| 参数确实用不到 | 加下划线前缀（`_delta`、`_fromExplosion`） |
| 布尔参数 | 用 `is` / `has` / `can` / `from` 开头（`isDead`、`fromExplosion`） |

### 2.4 可受击对象的 `hit()` 签名必须统一（强制）

所有“能被伤害”的对象（角色、油桶、假墙、箱子……）必须使用**同一套参数**，
否则调用方（武器、爆炸、恶魔拆障碍）会因参数个数不匹配在运行时报
`Invalid call to function 'hit' ... Expected N argument(s)`。

```gdscript
## 统一签名
func hit(damage: int, attackPos: Vector2 = Vector2.ZERO,
		knockDir: Vector2 = Vector2.ZERO, fromExplosion: bool = false) -> void:
```

- 后三个参数**必须有默认值**，这样 `obj.hit(100000)` 这类简化调用也能用。
- `knockDir` 是**击退方向**（世界坐标向量），由调用方给：
  - 枪械 → 射击方向（8 方向）
  - 爆炸 → `目标位置 - 爆炸位置`
  - 近战 → `目标位置 - 攻击者位置`
  - 火球 → `Vector2.ZERO`（只造伤害、不击退）
- `knockDir == Vector2.ZERO` 表示**不击退**，不再用负数当哨兵值。
- 击退力度由被击方按伤害公式自己算（`knockbackSpeed()`），调用方不用关心。
- 用不到的参数加下划线前缀（`_knockDir`、`_fromExplosion`），避免未使用警告。
- 新增可受击对象时，直接复制这个签名，不要自创。

当前实现（保持一致）：

| 文件 | 说明 |
|---|---|
| `script/character/zombie.gd` | 僵尸（含击退） |
| `script/character/devil.gd` | 恶魔 |
| `script/character/player.gd` | 玩家 |
| `script/item/barrel_obj.gd` | 油桶（忽略后 3 个参数） |
| `script/item/wall_obj.gd` | 假墙（忽略后 3 个参数） |

---

## 3. 类型与静态类型

### 3.1 所有声明都写显式类型（本项目约定）

> 官方风格是「能推断就用 `:=`」，**本项目相反**：为了可读性与统一，
> **成员变量、函数参数、返回值**一律写显式类型，不使用 `:=` 推断。
> **例外**：函数内部的**局部变量**可以不写类型（如 `var count = 0`）。

```gdscript
# 好
@export var damage: int = 2
var attackRange: float = 35.0
var target: Node2D = null
var enemies: Array[Node2D] = []

const DIRS: Array[Vector2] = [Vector2(1, 0)]

func heal(amount: int) -> void:
	pass

func sum(a: float, b: float) -> float:
	return a + b
```

```gdscript
# 坏：用 := 或干脆不写类型
@export var damage := 2
func heal(amount):
	pass
```

### 3.2 具体类型标注

- 变量 / 参数 / 返回值：`名字: 类型`；返回类型用 `-> 类型`。
- 数组元素类型：`Array[Vector2]`；字典键值类型：`Dictionary[String, int]`。
  **不支持嵌套**，如 `Array[Array[int]]` 是非法的。
- 即使不做泛型约束，成员变量也至少写 `Array` / `Dictionary`，不要留裸 `var`（局部变量除外）。
- `$路径` 无法被推断类型，必须显式声明：

```gdscript
@onready var ani: AnimatedSprite2D = $ani
```

### 3.3 空值安全

- 用 `as` 强转会**静默变 `null`**：拿到结果后必须判空再使用。
- 对象可能已被释放时，先用 `is_instance_valid()` 判断再访问。

```gdscript
var z := node as Zombie
if z == null:
	return
```

### 3.4 建议开启的警告

「项目设置 → Debug → GDScript」（需开启高级设置）中启用：
`UNTYPED_DECLARATION`、`INFERRED_DECLARATION` 以及 `UNSAFE_*` 系列，让编辑器帮忙盯住类型问题。

---

## 4. 文档注释

### 4.1 写法

- 文档注释用 `##`，写在**被说明成员的正上方**。
- 推荐分三块：**脚本类概述 / 脚本类详细描述 / 特殊标记**，块与块之间用一行空的 `##` 分隔。
- 普通块内注释用 `#`；只有会被导出到文档的内容才用 `##`。

```gdscript
extends Node2D
## 僵尸敌人脚本（状态机版本）。
##
## 只保留宿主能力：数值、取目标、流场取方向、碰撞探测、转向、命中判定、受伤与死亡。
## 具体行为拆到 StateMachine 下的 6 个状态节点：Spawn / Chase / Turn / Attack / Hurt / Dead。
```

### 4.2 特殊标记

| 用途 | 标记 |
| --- | --- |
| 文字教程 | `@tutorial: https://example.com` |
| 已弃用 | `@deprecated` / `@deprecated: 请改用 [AnotherClass]。` |
| 实验性 | `@experimental` |

### 4.3 交叉引用

文档注释内用 BBCode 引用其它符号，方便在编辑器里跳转：
`[method _ready]`、`[member hp]`、`[signal enemyKilled]`、`[Zombie]`、`[b]粗体[/b]`。

---

## 5. 代码顺序

### 5.1 脚本内顺序（本项目约定）

> **本项目约定**：常量/导出/成员在前，`_ready` 之后先写**自定义函数**，
> 其它 Godot 内置虚函数（`_process` / `_physics_process` / `_input` …）**放最后**。
> 这与官方推荐（`_init` / `_ready` 在最前、內置函数紧随）**正好相反**——生成代码时不要"纠正"它。

```text
01. @tool / @icon / @static_unload
02. class_name
03. extends
04. ## 类文档注释
05. signals
06. enums
07. constants
08. @export 变量
09. 普通成员变量（public 在前，private 在后；private 不加 `_` 前缀）
10. @onready 变量
11. _ready()（或初始化函数）
12. 自定义函数（public 在前，private 在后）
13. 其它 Godot 内置虚函数 / 回调（放最后）：
      _init / _enter_tree / _process / _physics_process /
      _input / _unhandled_input / _draw / _notification / _exit_tree ……
14. 内部类（inner class）
```

示例（`script/character/zombie.gd` 就是按这个顺序写的，可直接参考）：

```gdscript
class_name Zombie
extends "res://script/character/character.gd"
## 僵尸敌人脚本。

const DIRS: Array[Vector2] = [Vector2(1, 0)]

@export var damage: int = 2

var target = null

@onready var ani: AnimatedSprite2D = $ani

func _ready() -> void:
	pass

# ---- 自定义函数放前面 ----
func dealDamage() -> bool:
	return true


# ---- Godot 内置虚函数放最后 ----
func _physics_process(_delta: float) -> void:
	pass
```

### 5.2 成员变量与局部变量

- 只在单个方法里用到的值，**不要**提成成员变量，就写成局部变量。
- 局部变量**就近声明**，靠近首次使用处。
- `@onready` 只用于缓存节点引用（它在 `_ready` 之前求值），不要在 `_init` 里用 `$路径`。

---

## 6. 项目架构设计

### 6.1 目录结构

```text
boxHead-remake/                     # 仓库根（本文档所在位置）
├── doc/                            # 原版逆向文档（数值与规则的依据）
├── oldGame/                        # 原版 SWF 与其反编译产物（不入库）
└── box-head-remake/                # Godot 工程根（project.godot 所在）
    ├── autoload/                   # 全局单例：game.gd、mapData.gd、sfxManage.gd、sound_util.gd
    ├── script/                     # 脚本，按类别分子目录（与 scene/ 一一对应）
    │   ├── character/              # character、player、zombie、devil
    │   │   └── zombie_states/      # 僵尸的 6 个状态节点：spawn/chase/turn/attack/hurt/dead
    │   ├── weapon/                 # weapon 基类 + hand_gun、shotgun、uzi、railgun、rocket、
    │   │                           #   grenade、mine、chargePack、wall、barrel
    │   ├── item/                   # item 基类 + box、barrel_obj、mine_obj、chargePackObj、wall_obj
    │   ├── projectile/             # rocket_bullet、grenade_obj、bomb
    │   ├── fx/                     # explosion、smoke、sfx
    │   ├── level/                  # level 基类、room_001、map_sign、marker_point
    │   ├── ui/                     # welcome、map_select、game_setting、gameover、life_bar、
    │   │                           #   character_card、information_panel、toast_*、ui_label
    │   ├── fsm/                    # 通用有限状态机：state.gd、state_machine.gd
    │   └── main.gd / map.gd        # 入口与主游戏场景脚本，留在根部
    ├── scene/                      # 场景，按类别分子目录（与 script/ 同名对应）
    │   ├── character/              # character、player、zombie、devil
    │   ├── weapon/                 # weapon 基类 + 11 把武器
    │   ├── item/                   # item 基类 + box、barrel_obj、mine_obj、chargePackObj、wall_obj
    │   ├── projectile/             # rocket_bullet、grenade_obj、bomb
    │   ├── fx/                     # explosion、smoke、sfx
    │   ├── level/                  # level 基类、room_001、map_sign、marker_point、wall_shape*
    │   ├── ui/                     # welcome、map_select、game_setting、gameover、life_bar、
    │   │                           # character_card、information_panel、toast_*、ui_label
    │   └── main.tscn / map.tscn    # 入口与主游戏场景，留在根部
    ├── sprite/  sound/  font/  theme/  lang/   # 资源
    └── addons/                     # 第三方插件（phantom_camera 等）
```

规则：

1. **`script/` 与 `scene/` 的目录结构一一对应**：同一个类别用同名子目录，
   `scene/weapon/pistol.tscn` ↔ `script/weapon/hand_gun.gd`，找场景就能找到脚本。
2. **新文件放对应类别的子目录**；移动/改名文件后必须同步更新所有引用
   （`preload` / `load` 的 `res://` 路径、`extends` 的路径、`.tscn` 的 `[ext_resource path]`、
   `project.godot` 的 autoload、`change_scene_to_file` 的字符串）。**别忘了 `.gd.uid` 边车要一起搬。**
3. 只有被多个类别共用的基础场景/脚本才留在 `scene/`、`script/` 根部。
4. 场景名与脚本名尽量对应（`zombie.tscn` ↔ `zombie.gd`；历史遗留的 `pistol.tscn` ↔ `hand_gun.gd`
   保留不动），便于查找。

> **移动文件的标准做法**：改完用 `godot --headless --editor --path box-head-remake --quit`
> 跑一遍，确认没有 `Parse Error` / `Failed to load`，再跑一次游戏场景确认无运行时报错。

### 6.2 复用：基础场景 + 基础脚本（本项目约定）

> 出现可复用的功能时，**先做一份基础场景 + 基础脚本**，后续同类对象继承 / 实例化它，只覆盖差异。

现有映射（新增同类对象时挂到对应基类下）：

| 基类场景 / 脚本 | 子类 | 关系 |
| --- | --- | --- |
| `scene/character/character.tscn` + `script/character/character.gd` | player、zombie、devil | 继承场景 |
| `scene/weapon/weapon.tscn` + `script/weapon/weapon.gd` | pistol、shotgun、uzi、railgun、rocket、grenade、mine、chargePack、wall、barrel | 继承场景 |
| `scene/item/item.tscn` + `script/item/item.gd` | box、barrel_obj、mine_obj、chargePackObj、wall_obj | 继承场景 |
| `scene/level/level.tscn` + `script/level/level.gd` | room_001 | 继承场景 |

- **数值差异优先在子场景的 Inspector 里改**，不要在子脚本里重新赋值。
- 只有**行为差异**才在子脚本里覆盖方法。
- 现有代码用 `extends "res://script/<类别>/xxx.gd"`（路径继承）而不是 `class_name`，原因是基类没有 `class_name`；
  新增基类时优先给它加 `class_name`，子类就能写 `extends BaseName`。

### 6.3 节点与属性设置（本项目约定）

> **节点一律在 `.tscn` 里创建，不要在脚本里用 `Node.new()` + `add_child()` 去搭结构。**

能在编辑器里画出来的东西，就属于场景：

| 情况 | 做法 |
|---|---|
| 结构固定、场景里能预置的节点（相机、监听器、UI、地砖、出生点……） | **`.tscn` 里创建** |
| 数量和内容在运行期才确定（子弹、敌人、爆炸、掉落物） | 代码实例化 `PackedScene` |

```gdscript
# 好：节点在场景里，脚本只拿引用
@onready var listener: AudioListener2D = $audioListener

# 坏：场景里本来就能画出来，却在代码里造
listener = AudioListener2D.new()
listener.name = "audioListener"
add_child(listener)
```

理由：

- 结构能在编辑器里**看见**，调位置/调参数不用跑游戏
- 实例化 `PackedScene` 比 `new()` + 一堆属性赋值更快、更不容易漏
- 代码只管**逻辑**，不负责**搭场景**，职责清晰
- 像 `AudioListener2D` 这种"必须调方法才生效"的节点，节点放场景、只在 `_ready()` 调
  `make_current()` 也完全够用 —— 不要因为要调方法就把整个节点搬到代码里

> 在场景里添加节点时，属性**尽量在编辑器 Inspector 里直接设置**，不要全用代码赋值。

- 位置、尺寸、颜色、层级、碰撞层、锚点、主题等**静态属性** → Inspector。
- 只有**运行期才确定**的值才在代码里设置。

> **⚠️ 场景资源文件里不能写注释。** `.tscn` / `.tres` 是 Godot 的**文本资源格式**，
> 它**不支持 `#` 注释** —— 写了会让整个资源报 `Parse Error`，场景直接加载失败。
> 要给某个属性留说明，写到**脚本的 `##` 文档注释**、本文档、`doc/` 或提交信息里。
>
> 同理，脚本化改 `.tscn` 时不要引入 **UTF-8 BOM**（见 §1.1）。

### 6.4 单例（Autoload）

- 跨场景共享的状态与事件放在 `autoload/`，用 **PascalCase** 命名，全局直接访问
  （`Game`、`MapData`、`SfxManage`、`SoundUtil`）。
- 单例之间不要强耦合；对外用 `signal` 暴露事件，其它系统监听而非直接调用。
- 注意：**Autoload 的枚举值不是编译期常量**，所以用它做 key 的表只能写 `var`，不能写 `const`
  （`MapData.allWeaponData` 就是这样，保持 `var`）。

### 6.5 数据与逻辑分离

- 数值、武器表、敌人表集中在 `MapData`（`allWeaponData` / `enemyData`），逻辑只读数据，不硬编码分支。
- 目标：**新增条目只加数据、不改逻辑**。
- 关卡的每关配额等曲线用**纯函数**表达（如 `map.gd` 的 `waveQuota(wave)`），便于单测与校对。

### 6.6 状态机（本项目约定）

敌人 AI 用**节点式状态机**，不要写成一长串 `if state == ...`：

```text
[zombie (CharacterBody2D, script: zombie.gd)]
└─ [StateMachine (script: fsm/state_machine.gd)]
    ├─ Spawn / Chase / Turn / Attack / Hurt / Dead   ← 每个是 Node + extends State
```

- 状态脚本 `extends State`，实现 `enter()` / `exit()` / `physicsUpdate()` / `processUpdate()`。
- 状态**只声明"想去哪"**，调用 `transitionTo("状态名", msg)`；切换由 `StateMachine` 统一执行。
- 状态自身不持有宿主逻辑，通过 `actor` 访问宿主（`var z: Zombie: get: return actor as Zombie`）。
- 需要传参就用 `msg`（如 `{"to": 3, "next": "Attack"}`），不要状态之间直接互相引用。

### 6.7 信号驱动

- 模块间通信优先用 `signal`，少用直接引用。
- 信号名用**过去式 + camelCase**：`enemyKilled`、`playerDead`、`weaponUpgrade`。
- 在 `_ready()` 里连接；连接到节点的信号会在节点释放时自动断开，无需手动 `disconnect`。

### 6.8 分组与物理层

- 同类对象入组，方便批量查找：`player`、`enemy`、`box`、`sign`、`markerPoint`。
- 物理层严格按 `project.godot` 的 `layer_names` 使用，不要凭记忆写数字：

| 位值 | 层 | 名称 | 谁在用 |
| ---: | ---: | --- | --- |
| 1 | 1 | player | 玩家本体（`player.tscn` 根 CharacterBody2D，mask = 15） |
| 2 | 2 | enemy | 僵尸本体（`zombie.tscn` 根，mask = 11） |
| 4 | 3 | item | 可放置物：油桶 / 喷墙 / 地雷 / 充电包（`wall_obj`、`barrel_obj` 等） |
| 8 | 4 | staticWall | 房间墙体（`wall_shape*.tscn`） |
| 16 | 5 | playerBody | 玩家的受击 Area2D |
| 32 | 6 | enemyBody | 敌人的受击 Area2D |
| 64 | 7 | box | 奖励箱 |

> **注意一处不对称**：玩家 mask = 15（含 item 层 4），僵尸 mask = 11（**不含** item）。
> 也就是说**僵尸不与放置物发生物理碰撞**，它靠 `ShapeCast2D`（mask = 14，含 item）探测到障碍后绕行；
> 绕不开就停下。这是有意设计（避免僵尸被油桶挤飞），改层时别顺手"对齐"。

### 6.9 国际化

- 所有玩家可见文案用 `tr()`，文案集中在 `lang/lang.zh.translation` / `lang/lang.en.translation`
  （源表为 `lang/lang.csv`）。
- **不要**把翻译结果缓存到成员变量（切换语言不会重载场景，缓存会变旧）。

---

## 7. Godot 最佳实践

### 7.1 节点引用

- 用 `@onready` + `$路径` 缓存节点引用，不要在 `_process` 里反复 `get_node()`。
- `$路径` 只在父节点**已就绪**（`_ready` 之后）时才可用，`_init` 里不能用。

### 7.2 生命周期与性能

- 不需要每帧更新的节点，用 `set_process(false)` / `set_physics_process(false)` 关掉回调。
- 移动 / 动画优先用 `Tween`、`AnimationPlayer`，少在 `_process` 里手写插值。
- 计时用 `Timer` 节点或 `await get_tree().create_timer(秒).timeout`，少用自增计数。
- `_process` / `_physics_process` 里避免分配对象（新建 `Vector2(...)`、数组、拼接字符串）。
- **流场寻路**：`MapData.computeFields()` 的代价随格子数平方级增长，不要每帧每玩家重算；
  按 `MapData.flowDirty` 脏标记或固定间隔刷新（见 `map.gd`）。

### 7.3 资源加载

- 固定路径的资源用 `preload()`（编译期加载，路径写错立即报错）。
- 只有运行期才知道路径的才用 `load()`。
- 频繁复用的场景 / 资源缓存到常量或成员变量，不要每次使用都 `load`。
- ⚠️ `preload` 的路径是**硬编码**的：移动场景文件后务必同步改（见 §6.1 规则 1）。

### 7.4 信号连接

```gdscript
func _ready() -> void:
	$Button.pressed.connect(onButtonPressed)
	Game.enemyKilled.connect(onEnemyKilled)
```

- 优先在代码里 `.connect()`（便于检索），或使用编辑器「节点 → 信号」面板连接。
- 回调命名统一 `onXxxYyy`（camelCase）。**编辑器连的旧信号仍是 `_on_xxx`，不要改**（见 §2.1）。
- ⚠️ 在**编辑器**里连的信号，方法名写死在 `.tscn` 的 `[connection ... method=...]` 里，改名时必须一起改。

### 7.5 安全与健壮性

- 对象可能已被释放时，先用 `is_instance_valid(node)` 判断再访问。
- 节点 `free()` 之后读取它的成员**不会报错，但会静默变 `null`**；需要的数据必须在 `free()` **之前**取出。
- `await` 之后要确认目标仍然有效，再继续操作。
- 释放节点用 `queue_free()`，不要直接 `free()`。
- 需要下一帧再执行用 `call_deferred()`。
  > 状态机首次启动就用了它：子节点的 `_ready` 早于父节点，立刻 `enter()` 会让状态访问到
  > 还没赋值的 `@onready` 变量。新增"在 `_ready` 里驱动子节点"的逻辑时注意同样的顺序问题。
- 除法/取模前先确认分母不为 0（如出生点数组可能为空）。

---

## 8. 提交前审查清单

- [ ] 命名：函数/变量 camelCase，常量 CONSTANT_CASE，类 PascalCase，信号过去式。
- [ ] 私有成员**没有** `_` 前缀；Godot 引擎回调**保留** `_`。
- [ ] 没有与 Godot 内置名（属性 / 方法 / 全局函数）重名。
- [ ] 成员变量 / 参数 / 返回值类型全部显式声明；无 `:=` 推断、无裸 `var`（局部变量可省略类型）。
- [ ] 脚本顺序：`常量 → @export → 成员 → @onready → _ready → 自定义函数 → 其它内置虚函数放最后`。
- [ ] 静态属性都在场景 Inspector 里设置，没有堆在代码里。
- [ ] 可复用逻辑已抽成「基础场景 + 基础脚本」，没有重复造轮子。
- [ ] 敌人 AI 走状态机（`StateMachine` + `State` 子节点），没有重新写回 `if state == ...`。
- [ ] Tab 缩进、行宽 ≤ 100、**UTF-8 无 BOM**、LF 换行。
- [ ] 注释：`#` / `##` 后有空格；文档注释用 `##` 写在成员上方。
- [ ] 文案走 `tr()`，并已加入 `lang/lang.csv`。
- [ ] 模块间用信号通信；信号在 `_ready` 中连接。
- [ ] 无 `get_node()` 出现在 `_process`；无用回调已 `set_process(false)`。
- [ ] 节点释放 / `await` 之后访问做了有效性判断；除法做了除零保护。
- [ ] **移动或改名文件后**，所有引用（`preload` / `load` / `.tscn` 的 `[ext_resource]` / autoload /
      `change_scene_to_file`）已同步更新。
- [ ] `.tscn` / `.tres` 里**没有 `#` 注释**，且文件**没有 BOM**。
- [ ] 数值改动已与 `doc/` 下的逆向文档核对过（`doc/03-weapons.md`、`doc/04-enemy-stats.md`），
      或在提交信息里说明为何偏离。
- [ ] 跑过 `godot --headless --editor --path box-head-remake --quit`，无 `Parse Error` / `Failed to load`；
      并跑过一次 `godot --headless --path box-head-remake res://scene/map.tscn --quit-after 600`，无 `SCRIPT ERROR`。
