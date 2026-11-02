# 原版 XSI 烘焙素材替换（玩家 / 僵尸 / 恶魔）

记录 `box-head-remake` 的角色素材从「MoreRooms 烘焙图 + 色相换色」换成「原版 2Play 的 XSI 渲染离线烘焙图」的做法与约定：
玩家补上原本缺失的 3 套角色皮肤，僵尸与恶魔换成同一套管线烘出来的帧。

## 1. 素材来源

原版 `Boxhead_2Play.swf` 里**没有**整张角色贴图：玩家/僵尸/恶魔都是运行时用 XSI 多边形数据
（`DefineSprite_755_TMP2639qh3hat`，约 830KB AS 数据）+ 自带渲染器
（`CDrawPrimitive_XSI_DI.Render` 画多边形，`CDrawPrimitive_XSI_Animation.RenderToBitmap` 栅格化）现算出来的。
所以想要"原版画面"，必须先把这套渲染离线烘焙成 PNG。

本次使用的导出结果（第三方同人项目里跑通的那套烘焙管线），三个 run 同一套约定：

```
F:\boxhead_remake-main\generated\creature-art\run-2026-11-02021836-player-body-s2    玩家（4 变体）
F:\boxhead_remake-main\generated\creature-art\run-2026-11-02022039-zombie-body-s2    僵尸
F:\boxhead_remake-main\generated\creature-art\run-2026-11-02022039-devil-body-s2     恶魔
├── frames/<变体>/<动画集>/d<方向>_f<帧>.png   统一画布单帧
├── sheets/<变体>-<动画集>.png                 整组预览（灰框=画布，蓝十字=锚点）
└── manifest.json                              画布/锚点/每帧相对锚点的 ink rect
```

- 变体（=原版 4 个角色样式表）：`SWAT`、`BOND`、`GIJOE`、`BAMBO`
- 统一画布：`80 × 78` 逻辑像素 = `160 × 156` 设备像素（`scale=2`）
- 锚点（脚底，原版 `mDisp`）固定在画布 `(41, 51)` 逻辑 = `(82, 102)` 设备，**所有帧相同**
- 含地面投影，与游戏内画面一致

## 2. 与项目约定的对应关系

| 项目侧 | 素材侧 | 说明 |
|---|---|---|
| 朝向 `angle` 0~7 | 方向索引 `d00..d15` / `d00..d07` | 两边都是「`d00` 朝屏幕右（世界 +X），索引顺时针递增」；`angle = wrapi(round(atan2/(PI/4)),0,8)` |
| 站立/持枪动画 8 方向 | 导出 16 方向 | 取偶数序号：`dir = angle × 2`（`d04` 朝镜头 = `angle 2`，`d08` 朝左 = `angle 4`，`d12` 背对 = `angle 6`） |
| 行走 / 受击 8 方向 | 导出 8 方向 | 直接一一对应 |
| 倒地 / 尸体 4 方向 | 导出 4 方向 | 直接对应；`fallDown_<angle/2>` 的换算沿用 `player.gd` 里原有的 `mini(roundi(angle/2),3)` |
| `stand` / `walk` | `stand` / `walk` | 空手（`_other`） |
| `_<武器>` | `pistolstand` / `uziwalk` / … | `Game.weaponName` 的 Pistol/UZI/Shotgun/Rocket/Railgun 五个有独立持枪动画，其余武器（Mine/ChargePack/Wall/Barrel/Grenade）走 `_other`（`aniException`） |
| `hitFront_<a>` | `shothit_2` | 原版 `Player_HitFront` 加载的文件名就是 `shothit_2` |
| `hitRear_<a>` | `shothit_1` | 原版 `Player_HitRear` |
| `fallDown_<d>` | `dying`（4 方向 × 5 帧） | |
| `dead_<d>` | `dead`（4 方向 × 1 帧） | |

动画名沿用原有格式，只去掉写死的皮肤号：`stand_1_4_Pistol` → `stand_4_Pistol`
（皮肤由整套 `SpriteFrames` 资源区分，名字里不再重复）。

## 3. 产物布局

```
box-head-remake/sprite/player/skin1/frames.tres     SWAT
box-head-remake/sprite/player/skin2/frames.tres     BOND
box-head-remake/sprite/player/skin3/frames.tres     GIJOE
box-head-remake/sprite/player/skin4/frames.tres     BAMBO
box-head-remake/sprite/player/skinN/<动画组>/<角度>[_<帧>].png
```

每个 `frames.tres` 都是 120 组动画（488 帧），组名、帧数、`speed`、`loop` 与替换前的
`player.tscn` 内联 `SpriteFrames` 完全一致，只有贴图路径换成新素材。
PNG 是原样拷贝，**不缩放、不重采样**。

## 4. 精灵变换（锚点换算）

`player.tscn` 的 `ani` 节点：

```
position = Vector2(-1, -9)
scale    = Vector2(0.5, 0.5)
```

推导：原版 1 逻辑像素 = 重制版 1 世界像素（两边 `cellSize` 都是 32，见 `CMap_Cell.mCellSize`），
素材是 2 倍设备像素 → `scale = 0.5`。锚点相对画布中心偏移 `(2, 24)` 设备像素 = `(1, 12)` 世界像素，
要让脚底落在玩家原点下方 3px（与旧素材的投影底边一致，旧素材脚底世界 y = +13），
节点位置就是 `(-1, -9)`。

对齐验证用离线合成图做的（旧素材按 0.4 缩放、新素材按 0.5 缩放叠到同一世界坐标），
头顶/脚底/投影底边偏差都在 2px 以内；碰撞圆 `radius = 14.4` 与 z 排序未改。

## 5. 皮肤选择链路

1. 地图选择界面的 4 张角色卡（`character_card.gd`）→ `MapData.playerSlotChars[slot]`
2. `map.gd` 生成玩家时写入 `p.skinIndex = MapData.playerSlotChars[slot]`
3. `player.gd::applyPlayerSkin()` 在 `_ready` 里 `load(PLAYER_SKINS[skinIndex])` 换 `ani.sprite_frames`
4. `Game.playerName` 的角色名改成与头像/素材一致：`SWAT / BOND / GIJOE / BAMBO`
   （下标 0~3 依次对应 `skin1..skin4`，与四张头像 `sprite/ui/12,2,3,4.png` 同序）

换色材质（`shader/player_tint.gdshader`）现在**常驻挂在 `ani` 上**，因为受伤变红那层也走同一个 shader；
色相旋转本身仍然只在**多个槽位选了同一个角色**时才启用（`hue_shift = 0` 时材质是恒等的）：
4 套素材本身配色不同，再套色相旋转会破坏原版配色；撞角色时才用绿/红/蓝/黄区分。
`skinIndex = -1`（测试场景、未指定皮肤的场合）沿用旧行为：默认 `skin1` + 按槽位染色。

血量低于 75% 后按 `((0.75 - ratio) / 0.75) ^ 1.4` 渐进染成暗红（`damage_tint`，
`player.gd::updateDamageTint()`，每帧随 hp/自动回血更新）。**原版没有这层表现**——
反编译脚本里 `mColor` 只在构造时赋一次（恶魔/僵尸红、玩家绿），渲染入口
`_Render(oBMD, pos, tAlpha)` 也没有颜色参数，唯一随血量变化的是地面血迹贴花的量
（`CThing_Affect_Bullet.as` 的 `1 - mLife/mMaxLife`），所以这是重制版新增的可读性提示。
肤色像素（脸/手）由 shader 里的 `is_skin` 判定保护，不参与染色。

## 6. 重新生成

```powershell
python doc\tools\gen_player_skins.py      # 玩家 4 套皮肤 -> sprite/player/skin1..4
python doc\tools\gen_creature_skins.py    # 僵尸/恶魔 -> sprite/enemies/{zombie,devil}
python doc\tools\gen_offset_dir.py        # 5 把射线武器的 offsetDir 数值（见 §8）
python doc\tools\gen_player_skins.py --dry-run   # 只校验帧数/路径
```

这些脚本都会读对应场景现有的动画表，逐条核对帧数（不一致直接报错退出），所以动画组增删后重跑即可。

**新 PNG 需要 Godot 导入一次**：首次用编辑器打开项目会自动生成 `.import`；
命令行可用 `Godot_v4.7.2 --headless --path box-head-remake --import`。
未导入前 `load("res://sprite/player/skin1/frames.tres")` 会拿不到贴图。

## 7. 僵尸 / 恶魔（同一套管线）

导出目录：

```
run-2026-11-02022039-zombie-body-s2   画布 70×72 逻辑 = 140×144 设备，锚点 (37,49) 逻辑 = (74,98) 设备
run-2026-11-02022039-devil-body-s2    画布 90×90 逻辑 = 180×180 设备，锚点 (45,61) 逻辑 = (90,122) 设备
```

生成脚本 `doc/tools/gen_creature_skins.py`，产物 `sprite/enemies/zombie/`、`sprite/enemies/devil/`
（各带一个 `frames.tres`）。**目录名必须避开旧素材**：Windows 文件系统不区分大小写，
写 `sprite/devil/` 会直接落进已有的 `sprite/Devil/`，所以怪物素材统一放 `sprite/enemies/<怪>/`。

动画组与旧素材逐组对齐（僵尸 49 组 200 帧、恶魔 48 组 184 帧，帧数与替换前完全一致）：

| 项目动画 | 导出集 | 备注 |
|---|---|---|
| `stand_<a>` | `stand`（16 方向 × 1 帧） | 取 `dir = angle×2` |
| `walk_<a>` | `walk`（8 × 8） | |
| `attack_<a>` | `attack`（8 × 4） | 僵尸旧素材是 5 帧 → 用末帧补到 5 帧，保持 `attackHitFrame = 2` 的判定帧号不变 |
| `hitFront_<a>` / `hitRear_<a>` | `shothit_2` / `shothit_1` | 原版加载表：`Player_HitFront` 用 `shothit_2`，`Player_HitRear` 用 `shothit_1` |
| `fallDown_<d>` | `dying`（4 × 5） | |
| `dead_<d>` | `dead`（4 × 1） | |
| `rotate`（仅僵尸，32 帧） | 用 `stand` 的 16 方向帧每帧重复 2 次拼出 | 原版没有转身动画；`TurnState` 按 `framesPerDir = 32/8 = 4`、`startFrame = angle×4` 取帧，正好和 `dir = angle×2` 的映射吻合 |

恶魔的 `stand` 旧素材是 4 帧呼吸动画，XSI 的 `Player_Stand` 只有 1 帧 → 末帧补成 4 帧（画面静止，
但保留 `playAnim` 的循环与帧号假设）。

精灵变换（`ani` 节点）：

| 角色 | 旧 | 新 |
|---|---|---|
| 僵尸 | `scale 0.4`、`offset (-15,-35)` | `scale 0.5`、`offset (-4,-13)` |
| 恶魔 | `scale 0.42`、`offset (0,-46)` | `scale 0.5`、`offset (0,-27)` |

`offset` 会被 `scale` 缩放，所以换算时世界坐标 = `offset × scale + (像素 - 画布中心) × scale`。
两档数值都是先按「锚点（脚底）落在角色原点」定出 x，再用旧素材的着墨底边（世界 y）反解 y：
离线合成实测站立/行走/受击的地面线偏差 ≤1px（僵尸）、≤3px（恶魔），恶魔身体比旧素材高约 5~7px，
这是原版真实比例（XSI 站立 72 逻辑像素 ≈ 72 世界像素），碰撞圆 `14.4 / 13` 未动。

## 8. 手持武器的枪口锚点（`offsetDir`）

`offsetDir` 不只是贴图摆位：它同时是视觉枪口——曳光起点（`_draw`）、枪口火光位置、
火箭弹出膛点，还被 `hitEnd()` 用来补射程长度。旧数值是按 MoreRooms 烘焙图（`scale 0.4`）
手调的，换成 XSI 素材（`scale 0.5`、枪已烘进帧里）后必然错位，所以按导出锚点重算。

数据源是 `generated/weapon-anchors/run-2026-11-02023656-player-body-s2/`
（`muzzles.json` 是整理好的表，`anchors.json` / `anchors.md` 是逐条明细）：
原版 `XSI_Model_GunPosition_Right`，即 `CThing_Weapon.Fire(mParent.GetWeaponPosition(), …)`
真正用的发射点，单位是相对脚底锚点的屏幕像素（+x 右、+y 下）。

换算：

- 1 逻辑像素 = 1 世界像素（§4），所以锚点值可以直接当世界偏移用；
- 站立/持枪是 16 方向 → `dir = angle × 2`（同 §2）；
- 锚点相对的是脚底，而 §4 把脚底摆在玩家原点下方 3px，所以
  `offsetDir[angle] = muzzle[dir] + (0, 3)`；
- 每把枪取自己的集：`pistolstand` / `uzistand` / `shotgunstand` / `rocketstand` / `railgunstand`
  （旧代码是 5 把枪共用一组手调值，现在霰弹枪明显更低、火箭筒更短）；
- 4 个变体（SWAT/BOND/GIJOE/BAMBO）的锚点逐条相同，所以皮肤之间不需要分别配；
- 行走集的枪口随步伐上下浮动 ≤0.5px，忽略，统一取站立值。

放置类武器（Mine / ChargePack / Wall / Barrel / Grenade）不读 `offsetDir`，
基类里保持 `Vector2.ZERO` 即可。命中判定也不依赖它：射线从 `hitOrigin()`（身体中心 `y = -15`）
出发，只有曳光和射程补偿跟着枪口走。

校验：`python doc\tools\check_muzzle_overlay.py` 会把 8 个方向的 `offsetDir` 画回
`sprite/player/skin1/stand_<武器>/<角度>.png` 的实际贴图（青十字 = 脚底锚点，红叉 = 枪口），
逐方向确认落在枪管口上。

方向下标统一走 `weapon.gd::dirIdx()`（`roundi` 取最近方向，和 `player.gd` 算 `angle` 的规则一致）。
之前是 `int(angle / (PI/4))` 向零截断，负角度会少一格，导致上半圈整体偏一个方向
（朝正左打却拿到左上的枪口），别改回去。

## 9. 遗留

- 旧素材目录 `sprite/player/DefineSprite_*`、`sprite/Zombie2/`、`sprite/Devil/` 已经不再被任何场景/脚本引用，
  确认新画面没问题后可以删除。
- 站立/持枪导出是 16 方向，本项目仍按 8 方向播放；要更细的朝向需要把
  `player.gd` 的 `angle` 换算改成 `PI/8`，并同步武器 `offsetDir`。
