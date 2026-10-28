# 血迹与爆炸印记（地面贴花）功能实现

> 目标：把原版的"地面贴花"（血渍 `BloodSplat` / 焦痕 `ScorchMark`）在重制版里实现出来，
> 并在设置里提供"显示 / 不显示血迹"的开关。
>
> **引用约定**：不带前缀的 `F:\scripts` 路径 = 原版全量明文 AS2 源码，行号为该 `.as` 文件中的行号。
> 重制版文件路径相对 `box-head-remake/`。

---

## 0. 一句话结论

原版血迹**不是显示对象，是像素**：命中时把血斑直接 `copyPixels` 进关卡初始化时就分配好的
一张地面位图里。所以原版**没有"删除血迹"、也没有"数量上限"的概念**——一个人打和四个人同时打，
内存与显存开销完全一样，只是同一批像素被反复覆盖。

重制版的对应做法是**一张贴花图层 + 事件发生时往上盖一张图**，场景里的节点数恒为 1。
只要不把它实现成"每滩血一个 `Sprite2D`"，就不需要池化、不需要淡出、不需要删除。

---

## 1. 原版的实现（事实）

### 1.1 谁在什么时候画

| 事件 | 代码位置 | 画什么 |
|---|---|---|
| 子弹 / 火球命中生物 | `State_BulletHit_Init()` → `F:\scripts\__Packages\Thing\Creature\CThing_Creature.as:308` | 血 1 张 |
| 硬直期间（每个 tick） | 同文件 `:334`（`State_BulletHit()`） | 血 1 张 / tick |
| 爆炸命中 | `:291-298` → `State_ExplosionHit_Init` 转调 `State_BulletHit_Init` | 同上 |
| 僵尸抓咬命中 | `:283-285` → `State_ZombieHit_Init` 转调 `State_BulletHit_Init` | 同上（**玩家被咬也出血**） |
| 死亡动画期间（每个 tick） | 同文件 `:365`（`State_Dying()`） | 血 1 张 / tick |
| 尸体落地 | 同文件 `:378`（`State_Dead_Init`，传 `tAmount=5`） | 血 1 张（见 §1.4 坑 ①） |
| 爆炸（油桶 / 火箭 / 智能弹） | `F:\scripts\__Packages\Thing\Effect\CThing_Effect_Explosion.as:86` | 焦痕 1 张 |
| 墙被打碎 | `F:\scripts\__Packages\Thing\Object\CThing_Object_Wall.as:129` | 焦痕 1 张 |

也就是说：**出血量只跟"命中次数 × 硬直时长"有关**，跟伤害数值、武器类型、玩家人数都无直接关系。

### 1.2 画一张贴花做的四步

`F:\scripts\__Packages\World\Map\CMap_Decal.as:24-41`（`Draw_BloodSplat`）：

1. 懒加载素材：`new CDrawPrimitive_MovieClip_Directional("Effect.BloodSplat", 3)`，
   同时把全局缩放设成 `pGlobalScale = (1, 0.6)` —— 竖方向压扁成俯视透视（`:26-30`）。
2. `Animate_Random()`：随机取一帧（`:37`）。
3. 定位：`格坐标 × 格尺寸 ± 0.25 格`的随机抖动（`:38-39`）。
4. 落笔：`QRender_Mask(bmFloor, dPoint, random(3), bmDecalMask)`（`:40`），
   实现在 `F:\scripts\__Packages\DrawPrimitive\MovieClip\CDrawPrimitive_MovieClip_Directional.as:87-95`，
   本质就是一行：

```as
bmDraw.copyPixels(sBMD, sBMD.rectangle, dPoint, tMask, dPoint, true);
//               源血斑  源矩形          目标点     遮罩   遮罩取样点  mergeAlpha
```

`Draw_ScorchMark`（`CMap_Decal.as:42-54`）完全同构，只差两点：**不抖动**（用格子原点）、素材换成
`"Effect.ScorchMark"`。

### 1.3 三张位图的生命周期（决定了"不需要删除"）

| 位图 | 创建 | 内容 | 释放 |
|---|---|---|---|
| `bmFloor` | `F:\scripts\__Packages\World\CWorld.as:113` | 整张房间地面，血迹就烧在这里 | `CWorld.as:88`（关卡 `Dispose`） |
| `bmDecalMask` | `CWorld.as:114` | 遮罩，见下 | `CWorld.as:89` |
| `bmCover` | `CWorld.as:115` | 墙/桌等"盖在生物上面"的一层 | `CWorld.as:90` |

- 尺寸 = **整张房间**（`mArea`），不是视口，一次分配、整局不变。
- 遮罩的生成：先建全透明 → 每个地图块把自己的"禁止画血区"（墙根、道具阴影）画进遮罩
  （`F:\scripts\__Packages\World\Init\CWorld_Init_Piece.as:19`）→ 关卡初始化末尾整体反相
  （`CWorld.as:183` → `F:\scripts\__Packages\DrawPrimitive\CDrawPrimitive.as:19-29`，
  用 `paletteMap` 的 alpha 通道表把 0↔255 调过来）。
- 结论：**贴花是固定开销**。640×480 一张 RGBA ≈ 1.2 MB，打多少血都不会再涨。

### 1.4 两个坑（照抄前先知道）

**坑 ①：`tAmount` 是死参数。**
`Draw_BloodSplat(p, tAmount)` 里那个 `while(_loc2_) { _loc2_ = _loc2_ - 1; }` 是**空循环**
（`CMap_Decal.as:33-36`，FFDec 直接反编译 `Boxhead_2Play.swf` 字节码确认过，不是反编译丢代码）。
所以传 1 还是传 5 都只画一张；原版"死亡 5 张"的实际观感来自 `State_Dying` 每 tick 一张 + 尸体一张。

**坑 ②：这条链是兼容性重灾区，重制版不要照抄。**
全 SWF 里 `paletteMap` 只出现在 `InvertAlpha` 一处，带 `alphaBitmap` 的 `copyPixels` 只出现在
`QRender_Mask` 两处（即血迹 + 焦痕）。所以在 BitmapData 支持不全的播放器（旧版 Ruffle、第三方
SWF 模拟器）上，典型症状就是**血迹和焦痕同时消失、其他一切正常**；而且它**与画质 / Detail 设置无关**
（贴花函数里没有任何 `_root._quality` 判断，质量只影响 `CWorld.as:276` 的平滑与亮度滤镜）。
重制版用 GPU 合成（下面 §2）天然绕开这条链。

---

## 2. 重制版实现方案

### 2.1 结构：一张贴花图层

```
DecalLayer (Node2D)            # 关卡场景的子节点，z_index 在地面之上、实体与阴影之下
├── SubViewport                # size = MapData.mapSize，transparent_bg=true
│                              # render_target_clear_mode = CLEAR_NEVER
│                              # render_target_update_mode = UPDATE_DISABLED，msaa 关闭
└── Sprite2D                   # centered=false，texture = SubViewport.get_texture()
```

为什么用 `SubViewport` 累积而不是 `Image` 逐像素：

- `CLEAR_NEVER` + 每次只切 `UPDATE_ONCE` → **平时完全不产生渲染开销**，盖一张画一帧。
- 临时 `Sprite2D` 在 `frame_post_draw` 后 `queue_free`，像素留在纹理里，节点数归零。
- 全程 GPU 混合，不碰 CPU 像素，也不会有 §1.4 坑 ② 那类问题。
- 备选（想离线保存 / 精确遮罩时）：一个 `Image` + `blend_rect()` + 每帧最多一次
  `ImageTexture.update()`，代价是每次上传整张纹理，只适合 ≤1024² 的小房间。

### 2.2 代码骨架 `script/fx/decal_layer.gd`

```gdscript
class_name DecalLayer
extends Node2D

@export var bloodFrames: Array[Texture2D] = []     # Effect.BloodSplat 导出的帧
@export var scorchFrames: Array[Texture2D] = []    # Effect.ScorchMark 导出的帧
@export var squash := 0.6                          # 原版 pGlobalScale.y
@export var jitterCells := 0.25                    # 原版 ±0.25 格

@onready var vp: SubViewport = $SubViewport
@onready var sprite: Sprite2D = $Sprite2D


func blood(pos: Vector2) -> void:
	if not enabled:
		return
	var j := Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)) * MapData.cellSize
	_stamp(bloodFrames, pos + j)


func scorch(pos: Vector2) -> void:
	if not enabled:
		return
	_stamp(scorchFrames, pos)                          # 原版烧痕不抖动


func _stamp(frames: Array[Texture2D], pos: Vector2) -> void:
	if frames.is_empty():
		return
	var s := Sprite2D.new()
	s.texture = frames.pick_random()
	s.position = pos - global_position
	s.scale = Vector2(1.0, squash)
	s.rotation = TAU * randf()                         # 原版是 random(3) 三个朝向
	vp.add_child(s)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(s.queue_free, CONNECT_ONE_SHOT)


## 换关卡 / 关掉开关时整层清空（不需要逐条删除）
func clear() -> void:
	vp.render_target_clear_mode = SubViewport.CLEAR_ONCE
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_NEVER
```

### 2.3 挂点

| 事件 | 重制版位置 | 调用 |
|---|---|---|
| 僵尸被命中 | `script/character/zombie.gd:568` `hit()` | `Decals.blood(global_position)`（按 §2.4 节流） |
| 僵尸死亡 | `script/character/zombie.gd:599` `die()` | `Decals.blood(...)` |
| 恶魔被命中 / 死亡 | `script/character/devil.gd` 的 `hit()` / `die()` | 同上 |
| 玩家被抓咬 | `script/character/player.gd` 的 `hit()` | 同上（原版会出血，别漏） |
| 爆炸 | `script/fx/explosion.gd` 结算处 | `Decals.scorch(center)` |
| 墙被打碎 | 墙对象的破坏分支 | `Decals.scorch(...)` |

`Decals` 建议做成关卡场景里的一个节点（随关卡释放），通过 `MapData` 或 `get_node` 拿到，
不要做成 autoload——它的尺寸和内容都是关卡级的。

### 2.4 频率对齐（重要）

原版是 **25 Hz tick**，硬直期间每 tick 一张血；重制版是 **60 Hz 物理帧**。
如果照抄"每帧一张"，血迹密度会变成 **2.4 倍**，画面会明显更脏。

```gdscript
const BLOOD_INTERVAL := 1.0 / 25.0      # 对齐原版 25Hz
var bloodCooldown := 0.0

# hit() / 硬直每帧：
bloodCooldown -= delta
if bloodCooldown <= 0.0:
	Decals.blood(global_position)
	bloodCooldown = BLOOD_INTERVAL
```

多人模式不需要额外处理：每个实体自己节流，两个人同时打一只僵尸就是各出一张，密度约等于单人 ×2，
不会随帧数或人数爆炸。

### 2.5 素材导出（已验证可行）

```
F:\ffdec_25.1.2\ffdec-cli.exe -selectid 600 -export sprite <out> oldGame\Boxhead_2Play.swf   # Effect.BloodSplat
F:\ffdec_25.1.2\ffdec-cli.exe -selectid 614 -export sprite <out> oldGame\Boxhead_2Play.swf   # Effect.ScorchMark
```

两个符号在 SWF 里都**只有 1 帧**（3 个朝向是代码旋转出来的），所以各导一张 PNG 就够：
血斑是红色团块、焦痕是浅灰放射状。原版靠 `copyPixels` 的 alpha 与地面混合，重制版直接叠即可，
觉得太抢眼就把贴花层 `modulate.a` 压到 0.7~0.8。

### 2.6 遮罩（可选，第二阶段）

原版 `bmDecalMask` 的作用只有一个：**血不要糊在墙根和道具阴影上**。重制版两种做法：

- 给 `Sprite2D` 挂 `canvas_item` shader：`COLOR.a *= texture(mask, UV).a`，
  `mask` 是一张"白 = 允许画血"的纹理（可由地图的墙 / 阴影层离线生成）。
- 或者在 `blood()` 里按格子判断：目标格是墙 / 不可走就跳过。粒度粗，但零成本。

不做也能跑，只是血会盖住墙脚。**不要**为了这个去做 `paletteMap` 反相那套（§1.4 坑 ②）。

---

## 3. 设置开关：显示 / 不显示血迹

沿用项目现成的三段式（与 `collision`、`Devils` 完全同构）：

| 层 | 文件 | 要做的事 |
|---|---|---|
| 数据 | `autoload/mapData.gd:133` `mapConfig` | 加 `'bloodDecals': true` |
| 持久化 | `autoload/settings.gd:152` / `:162`（`loadGame` / `saveGame`） | 各加一行，section `game`，key `bloodDecals` |
| UI | `script/ui/game_setting_panel.gd` | `rows` 里加一条 `{"key": "bloodDecals", "label": "Blood decals:", "tip": ...}`，并在选中分支、回填分支、`resetDefaults` 各加一处 |

**关闭时的语义（推荐 A）：**

- **A. 关 = 立即清空 + 之后不再生成。** `Decals.clear()` + 在 `blood()` / `scorch()` 顶部
  `if not enabled: return`。玩家点下去画面马上干净，之后也不再脏，符合"不想看到血迹"的直觉。
- B. 关 = 只隐藏图层（`sprite.visible = false`），仍在生成 → 再打开会看到关掉期间打的位置。
  省不了多少，语义还怪。

补充约定：

- 血和焦痕**共用这一个开关**（原版本来就是同一套贴花系统）。以后要分开再加 `scorchDecals`。
- `enabled` 从 `MapData.mapConfig.bloodDecals` 读，切换时同步给 `DecalLayer`（信号或直接调用），
  不要每帧轮询。
- early-return 要放在最前面，避免白算随机数、白建 `Sprite2D`；关闭状态下等于零开销。
- 这个开关**与画质 / 细节无关**：原版贴花不受 `_root._quality` 影响（§1.4 坑 ②），
  重制版也不要把它接到分辨率或特效等级那类设置上。

---

## 4. 需要"删除血迹"吗？—— 不需要

| 问题 | 回答 |
|---|---|
| 多人同时打会不会越积越多？ | 不会。盖的是同一张贴花纹理的同一批像素，节点数恒为 1，显存恒定。 |
| 要不要做上限 / 池化？ | 不需要（只有"每滩血一个节点"的方案才需要）。 |
| 要不要淡出 / 超时消失？ | 不做。原版永久保留到关卡结束（`CWorld.as:88` 整张释放）。 |
| 什么时候要清？ | 只有换关卡。让 `DecalLayer` 随关卡场景一起 free 即可；复用节点才需要 `clear()`。 |
| 真嫌画面太脏怎么办？ | 用**每格预算**（一格最多 N 张，超了覆盖最旧的）或调低 `modulate.a`，而不是删节点。 |

---

## 5. 验收清单

- [ ] 手枪命中僵尸 → 1 张血斑，落在格内随机偏移，竖方向压扁 0.6
- [ ] 硬直期间持续出血，密度约等于原版 25 Hz（不是 60 Hz）
- [ ] 僵尸死亡 →  dying 期间连续几张 + 尸体位置一叠
- [ ] 玩家被僵尸抓咬 → 也出血（原版行为）
- [ ] 油桶爆炸 → 1 张焦痕，位置不抖动；墙被打碎同样出焦痕
- [ ] 两个玩家同时打一只僵尸 → 帧率无变化，血迹密度 ≈ 单人 ×2
- [ ] 设置里关掉"血迹" → 现有痕迹立即消失且不再产生；重开游戏后设置仍生效
- [ ] 换关卡 → 贴花层清空，无残留
- [ ] 性能：整局只有 1 张贴花纹理，显存 ≈ `mapSize.x * mapSize.y * 4` 字节；无逐血节点

---

## 6. 明确不做的事

- 不做"每滩血一个 `Node2D`/`Sprite2D`"（那才需要池化、淡出、上限，多人下节点数会爆）。
- 不做血迹淡出 / 定时消失（原版永久）。
- 不做网络 / 回放同步（纯本地表现，各端自己画自己的）。
- 不照抄 `paletteMap` 反相 + 带 `alphaBitmap` 的 `copyPixels` 这条链（模拟器兼容坑，见 §1.4 坑 ②）。
- 大地图（非当前房间尺寸）若显存吃紧，贴花纹理按半分辨率生成 + `Sprite2D.scale = 2`，
  而不是拆成多张图层。
